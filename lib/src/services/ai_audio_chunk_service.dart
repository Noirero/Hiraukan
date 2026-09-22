import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/session.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Creates short 16 kHz mono WAV chunks for fast-start local Whisper.
///
/// Whisper remains file-based, but feeding it short WAV chunks lets Hiraukan
/// publish subtitle text progressively instead of waiting for a whole MP3.
class AiAudioChunkService {
  AiAudioChunkService._();

  static final instance = AiAudioChunkService._();

  Future<File?> extractWavChunk({
    required String inputPath,
    required Duration start,
    required Duration duration,
  }) async {
    final input = File(inputPath);
    if (!await input.exists()) return null;

    final tempDir = await getTemporaryDirectory();
    final name =
        'hiraukan_asr_chunk_${DateTime.now().microsecondsSinceEpoch}_'
        '${start.inMilliseconds}.wav';
    final output = File(p.join(tempDir.path, name));

    final command = [
      '-ss',
      _seconds(start),
      '-t',
      _seconds(duration),
      '-i',
      _quote(inputPath),
      '-vn',
      '-ac',
      '1',
      '-ar',
      '16000',
      '-c:a',
      'pcm_s16le',
      '-y',
      _quote(output.path),
    ].join(' ');

    final completer = Completer<Session>();
    FFmpegKit.executeAsync(
      command,
      (session) {
        if (!completer.isCompleted) completer.complete(session);
      },
    );

    final session = await completer.future;
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code) ||
        !await output.exists() ||
        await output.length() <= 44) {
      if (await output.exists()) {
        try {
          await output.delete();
        } catch (_) {}
      }
      return null;
    }
    return output;
  }

  String _seconds(Duration value) =>
      (value.inMilliseconds / 1000).toStringAsFixed(3);

  String _quote(String value) =>
      '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
}
