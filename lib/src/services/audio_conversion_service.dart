import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/session.dart';
import 'package:flutter/services.dart';

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

/// KikoFlu-derived WAV conversion with guarded platform strategies.
/// Conversion is opt-in and never changes Hiraukan's download layout.
class AudioConversionService {
  AudioConversionService._();
  static final instance = AudioConversionService._();

  static const _iosChannel = MethodChannel('com.kikoeru.flutter/audio_conversion');

  String outputPath(String input, WavConversionFormat format) {
    final file = File(input);
    final name = file.uri.pathSegments.last;
    final stem = name.toLowerCase().endsWith('.wav')
        ? name.substring(0, name.length - 4)
        : name;
    return '${file.parent.path}${Platform.pathSeparator}$stem${format.extension}';
  }

  bool isSupported(WavConversionFormat format) {
    if (format == WavConversionFormat.none) return true;
    if (Platform.isAndroid || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }
    if (Platform.isIOS) {
      return format == WavConversionFormat.alac || format == WavConversionFormat.aac;
    }
    return false;
  }

  List<String> _args(WavConversionFormat format, String input, String output) {
    switch (format) {
      case WavConversionFormat.flac:
        return ['-i', input, '-map_metadata', '0', '-compression_level', '8', '-f', 'flac', '-y', output];
      case WavConversionFormat.alac:
        return ['-i', input, '-map_metadata', '0', '-c:a', 'alac', '-f', 'mp4', '-y', output];
      case WavConversionFormat.aac:
        return ['-i', input, '-map_metadata', '0', '-c:a', 'aac', '-b:a', '256k', '-y', output];
      case WavConversionFormat.none:
        return const [];
    }
  }

  Future<String?> convert(
    String input,
    WavConversionFormat format, {
    void Function(double progress)? onProgress,
    bool deleteOriginal = true,
  }) async {
    if (format == WavConversionFormat.none || !isSupported(format)) return null;
    final source = File(input);
    if (!await source.exists() || !input.toLowerCase().endsWith('.wav')) return null;

    final output = outputPath(input, format);
    final out = File(output);
    if (await out.exists()) await out.delete();

    try {
      String? result;
      if (Platform.isAndroid) {
        result = await _convertAndroid(source, output, format, onProgress);
      } else if (Platform.isIOS) {
        result = await _convertIos(source, output, format);
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        result = await _convertDesktop(source, output, format);
      }

      if (result != null && deleteOriginal && await source.exists()) {
        await source.delete();
      }
      return result;
    } catch (error) {
      _log.error('Audio conversion failed: $error', tag: 'AudioConv');
      if (await out.exists()) {
        try { await out.delete(); } catch (_) {}
      }
      return null;
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
    final cmd = args.map((value) => value.contains(' ') ? '"$value"' : value).join(' ');
    final completer = Completer<Session>();

    FFmpegKit.executeAsync(
      cmd,
      (session) {
        if (!completer.isCompleted) completer.complete(session);
      },
      (_) {},
      (statistics) {
        if (inputLength > 0) {
          onProgress?.call((statistics.getSize() / inputLength).clamp(0.0, 1.0));
        }
      },
    );

    final session = await completer.future;
    final code = await session.getReturnCode();
    if (ReturnCode.isSuccess(code) && await File(output).exists()) {
      onProgress?.call(1);
      return output;
    }
    return null;
  }

  Future<String?> _convertIos(
    File input,
    String output,
    WavConversionFormat format,
  ) async {
    try {
      final value = await _iosChannel.invokeMethod<String>('convertWav', {
        'inputPath': input.path,
        'outputPath': output,
        'format': format.value,
      });
      return value == 'success' && await File(output).exists() ? output : null;
    } on MissingPluginException {
      _log.warning('Native iOS conversion channel is unavailable', tag: 'AudioConv');
      return null;
    }
  }

  Future<String?> _convertDesktop(
    File input,
    String output,
    WavConversionFormat format,
  ) async {
    final executable = await _findFfmpeg();
    if (executable == null) {
      _log.warning('ffmpeg not found; keeping original WAV', tag: 'AudioConv');
      return null;
    }

    final process = await Process.start(executable, _args(format, input.path, output));
    final stderr = StringBuffer();
    process.stdout.drain<void>();
    process.stderr.transform(const SystemEncoding().decoder).listen(stderr.write);
    final code = await process.exitCode;
    if (code == 0 && await File(output).exists()) return output;
    _log.error('ffmpeg failed ($code): ${stderr.toString()}', tag: 'AudioConv');
    return null;
  }

  Future<String?> _findFfmpeg() async {
    try {
      if (Platform.isWindows) {
        final found = await Process.run('where', ['ffmpeg.exe'], runInShell: true);
        if (found.exitCode == 0) {
          final path = found.stdout.toString().trim().split('\n').first.trim();
          if (path.isNotEmpty) return path;
        }
      } else {
        final found = await Process.run('which', ['ffmpeg']);
        if (found.exitCode == 0) {
          final path = found.stdout.toString().trim();
          if (path.isNotEmpty) return path;
        }
      }
    } catch (_) {}
    return null;
  }
}
