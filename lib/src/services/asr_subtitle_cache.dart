import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/ai_job_identity.dart';
import '../models/lyric.dart';

class AsrSubtitleCache {
  AsrSubtitleCache._();

  static final AsrSubtitleCache instance = AsrSubtitleCache._();

  static const int schemaVersion = 1;
  static const String engineId = 'whisper_existing';
  static const String engineVersion = 'compat-v1';

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(support.path, 'hiraukan_ai', 'asr_subtitle_cache'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _cacheId({
    required TrackIdentity track,
    required String modelName,
  }) {
    final payload = [
      'schema=$schemaVersion',
      'track=${track.trackId}',
      'source=${track.sourceKey}',
      'work=${track.sourceWorkId}',
      'audio=${track.audioFingerprint}',
      'engine=$engineId',
      'engineVersion=$engineVersion',
      'model=$modelName',
      'lang=ja',
    ].join('|');
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Future<List<LyricLine>?> load({
    required TrackIdentity track,
    required String modelName,
  }) async {
    final dir = await _directory();
    final file = File(
      p.join(
        dir.path,
        '${_cacheId(track: track, modelName: modelName)}.json',
      ),
    );
    if (!await file.exists()) return null;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schemaVersion'] != schemaVersion ||
          decoded['engineId'] != engineId ||
          decoded['engineVersion'] != engineVersion ||
          decoded['modelName'] != modelName) {
        return null;
      }

      final rawLines = decoded['lines'];
      if (rawLines is! List || rawLines.isEmpty) return null;

      final lines = <LyricLine>[];
      for (final raw in rawLines) {
        if (raw is! Map) return null;
        final startMs = raw['startMs'];
        final endMs = raw['endMs'];
        final text = raw['text'];
        if (startMs is! int || endMs is! int || text is! String) return null;
        if (endMs < startMs || text.trim().isEmpty) continue;
        lines.add(
          LyricLine(
            startTime: Duration(milliseconds: startMs),
            endTime: Duration(milliseconds: endMs),
            text: text.trim(),
          ),
        );
      }
      return lines.isEmpty ? null : List.unmodifiable(lines);
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required TrackIdentity track,
    required String modelName,
    required List<LyricLine> lines,
  }) async {
    if (lines.isEmpty) return;

    final dir = await _directory();
    final destination = File(
      p.join(
        dir.path,
        '${_cacheId(track: track, modelName: modelName)}.json',
      ),
    );
    final temporary = File('${destination.path}.tmp');

    final payload = jsonEncode({
      'schemaVersion': schemaVersion,
      'engineId': engineId,
      'engineVersion': engineVersion,
      'modelName': modelName,
      'language': 'ja',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'track': {
        'trackId': track.trackId,
        'sourceKey': track.sourceKey,
        'sourceWorkId': track.sourceWorkId,
        'audioFingerprint': track.audioFingerprint,
      },
      'lines': [
        for (final line in lines)
          {
            'startMs': line.startTime.inMilliseconds,
            'endMs': line.endTime.inMilliseconds,
            'text': line.text,
          },
      ],
    });

    await temporary.writeAsString(payload, flush: true);
    if (await destination.exists()) {
      await destination.delete();
    }
    await temporary.rename(destination.path);
  }
}
