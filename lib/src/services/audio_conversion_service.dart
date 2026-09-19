import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/session.dart';
import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

final _log = LogService.instance;

enum WavConversionFormat {
  none('Keep WAV', 'none', '.wav'),
  flac('FLAC', 'flac', '.flac'),
  alac('ALAC', 'alac', '.m4a'),
  aac('AAC', 'aac', '.m4a');

  final String displayName;
  final String value;
  final String extension;
  const WavConversionFormat(this.displayName, this.value, this.extension);

  static WavConversionFormat fromValue(String value) => values.firstWhere(
        (item) => item.value == value,
        orElse: () => WavConversionFormat.flac,
      );
}

/// KikoFlu-derived WAV conversion adapted for Hiraukan's Android path.
/// Conversion is opt-in and never changes Hiraukan's download layout.
class AudioConversionService {
  AudioConversionService._();
  static final instance = AudioConversionService._();

  String outputPath(String input, WavConversionFormat format) {
    final file = File(input);
    final name = file.uri.pathSegments.last;
    final stem = name.toLowerCase().endsWith('.wav')
        ? name.substring(0, name.length - 4)
        : name;
    return '${file.parent.path}${Platform.pathSeparator}$stem${format.extension}';
  }

  bool isSupported(WavConversionFormat format) =>
      Platform.isAndroid && format != WavConversionFormat.none;

  Future<bool> isEncoderAvailable(WavConversionFormat format) async {
    if (!Platform.isAndroid || !isSupported(format)) return false;
    // The Android FFmpeg package bundles the encoders used by the formats
    // exposed above. If that package becomes unavailable, conversion itself
    // fails closed and the original WAV is kept.
    return true;
  }

  List<String> _args(WavConversionFormat format, String input, String output) {
    switch (format) {
      case WavConversionFormat.flac:
        return [
          '-i',
          input,
          '-map_metadata',
          '0',
          '-compression_level',
          '8',
          '-f',
          'flac',
          '-y',
          output,
        ];
      case WavConversionFormat.alac:
        return [
          '-i',
          input,
          '-map_metadata',
          '0',
          '-c:a',
          'alac',
          '-f',
          'mp4',
          '-y',
          output,
        ];
      case WavConversionFormat.aac:
        return [
          '-i',
          input,
          '-map_metadata',
          '0',
          '-c:a',
          'aac',
          '-b:a',
          '256k',
          '-y',
          output,
        ];
      case WavConversionFormat.none:
        return const [];
    }
  }

  /// Create a temporary PCM16 mono 16 kHz WAV for local speech recognition.
  ///
  /// The source audio is never modified or deleted. Callers own the returned
  /// temporary path and should delete it after inference.
  Future<String?> prepareSpeechRecognitionWav(String input) async {
    if (!Platform.isAndroid) return null;
    final source = File(input);
    if (!await source.exists()) return null;

    final tempRoot = await getTemporaryDirectory();
    final dir = Directory(
      '${tempRoot.path}${Platform.pathSeparator}hiraukan_ai_asr',
    );
    if (!await dir.exists()) await dir.create(recursive: true);

    final safeId =
        '${input.hashCode.abs()}-${DateTime.now().microsecondsSinceEpoch}';
    final output =
        '${dir.path}${Platform.pathSeparator}asr-$safeId.wav';
    final escapedInput = input.replaceAll('"', '\\"');
    final escapedOutput = output.replaceAll('"', '\\"');
    final command =
        '-hide_banner -loglevel error -i "$escapedInput" '
        '-vn -ac 1 -ar 16000 -c:a pcm_s16le -f wav -y "$escapedOutput"';

    final session = await FFmpegKit.execute(command);
    final code = await session.getReturnCode();
    final out = File(output);
    if (ReturnCode.isSuccess(code) &&
        await out.exists() &&
        await out.length() > 44) {
      return output;
    }

    if (await out.exists()) {
      try {
        await out.delete();
      } catch (_) {}
    }
    return null;
  }

  Future<String?> convert(
    String input,
    WavConversionFormat format, {
    void Function(double progress)? onProgress,
    bool deleteOriginal = true,
  }) async {
    if (!Platform.isAndroid || !isSupported(format)) return null;

    final source = File(input);
    if (!await source.exists() || !input.toLowerCase().endsWith('.wav')) {
      return null;
    }
    if (!await isEncoderAvailable(format)) {
      _log.warning(
        'Encoder unavailable for ${format.displayName}; keeping original WAV',
        tag: 'AudioConv',
      );
      return null;
    }

    final output = outputPath(input, format);
    final out = File(output);
    // Never overwrite an existing download with the same stem. A collision is
    // a no-op so the original WAV remains usable.
    if (await out.exists()) {
      _log.warning(
        'Conversion target already exists; keeping original WAV: $output',
        tag: 'AudioConv',
      );
      return null;
    }

    final extension = format.extension;
    final stem = output.substring(0, output.length - extension.length);
    final temporaryOutput = '$stem.hiraukan-converting$extension';
    final temporary = File(temporaryOutput);
    if (await temporary.exists()) {
      try {
        await temporary.delete();
      } catch (_) {
        return null;
      }
    }

    try {
      final convertedTemporary = await _convertAndroid(
        source,
        temporaryOutput,
        format,
        onProgress,
      );

      if (convertedTemporary == null || !await temporary.exists()) return null;
      final convertedSize = await temporary.length();
      if (convertedSize <= 0) {
        _log.error('Converted file is empty; keeping original WAV', tag: 'AudioConv');
        return null;
      }

      await temporary.rename(output);
      if (!await out.exists() || await out.length() <= 0) {
        _log.error('Finalized converted file is invalid; keeping WAV', tag: 'AudioConv');
        return null;
      }

      if (deleteOriginal && await source.exists()) {
        await source.delete();
      }
      onProgress?.call(1);
      return output;
    } catch (error) {
      _log.error('Audio conversion failed: $error', tag: 'AudioConv');
      return null;
    } finally {
      if (await temporary.exists()) {
        try {
          await temporary.delete();
        } catch (_) {}
      }
    }
  }

  Future<String?> _convertAndroid(
    File input,
    String output,
    WavConversionFormat format,
    void Function(double progress)? onProgress,
  ) async {
    final inputLength = await input.length();
    final args = _args(format, input.path, output);
    final cmd = args
        .map((value) =>
            value.contains(' ') ? '"${value.replaceAll('"', '\\"')}"' : value)
        .join(' ');
    final completer = Completer<Session>();

    FFmpegKit.executeAsync(
      cmd,
      (session) {
        if (!completer.isCompleted) completer.complete(session);
      },
      (_) {},
      (statistics) {
        if (inputLength > 0) {
          onProgress?.call(
            (statistics.getSize() / inputLength).clamp(0.0, 0.99).toDouble(),
          );
        }
      },
    );

    final session = await completer.future;
    final code = await session.getReturnCode();
    final file = File(output);
    if (ReturnCode.isSuccess(code) &&
        await file.exists() &&
        await file.length() > 0) {
      return output;
    }
    return null;
  }
}
