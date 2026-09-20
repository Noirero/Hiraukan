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

  static const int schemaVersion = 2;
  static const int legacySchemaVersion = 1;
  static const String legacyEngineId = 'whisper_existing';
  static const String legacyEngineVersion = 'compat-v1';

  // Kept as aliases so existing contracts/tests that reference the Stage 1
  // cache identity remain source-compatible while schema v2 becomes dynamic.
  static const String engineId = legacyEngineId;
  static const String engineVersion = legacyEngineVersion;

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

  String cacheIdentity({
    required TrackIdentity track,
    required String engineId,
    required String engineVersion,
    required String modelName,
  }) {
    return _cacheId(
      track: track,
      engineId: engineId,
      engineVersion: engineVersion,
      modelName: modelName,
    );
  }

  String _cacheId({
    required TrackIdentity track,
    required String engineId,
    required String engineVersion,
    required String modelName,
    int schema = schemaVersion,
  }) {
    final payload = [
      'schema=$schema',
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
    required String engineId,
    required String engineVersion,
    required String modelName,
  }) async {
    final dir = await _directory();
    final current = File(
      p.join(
        dir.path,
        '${_cacheId(
          track: track,
          engineId: engineId,
          engineVersion: engineVersion,
          modelName: modelName,
        )}.json',
      ),
    );

    final currentLines = await _read(
      current,
      expectedSchema: schemaVersion,
      expectedEngineId: engineId,
      expectedEngineVersion: engineVersion,
      expectedModelName: modelName,
    );
    if (currentLines != null) return currentLines;

    // Stage 1 used a fixed Compatibility identity. Preserve those cached
    // Japanese subtitles and migrate them lazily into the dynamic v2 cache.
    if (engineId == legacyEngineId && engineVersion == legacyEngineVersion) {
      final legacy = File(
        p.join(
          dir.path,
          '${_cacheId(
            track: track,
            engineId: legacyEngineId,
            engineVersion: legacyEngineVersion,
            modelName: modelName,
            schema: legacySchemaVersion,
          )}.json',
        ),
      );
      final legacyLines = await _read(
        legacy,
        expectedSchema: legacySchemaVersion,
        expectedEngineId: legacyEngineId,
        expectedEngineVersion: legacyEngineVersion,
        expectedModelName: modelName,
      );
      if (legacyLines != null) {
        await save(
          track: track,
          engineId: engineId,
          engineVersion: engineVersion,
          modelName: modelName,
          lines: legacyLines,
        );
        try {
          if (await legacy.exists()) await legacy.delete();
        } catch (_) {
          // Migration success must not depend on deleting the legacy file.
        }
        return legacyLines;
      }
    }

    return null;
  }

  Future<List<LyricLine>?> _read(
    File file, {
    required int expectedSchema,
    required String expectedEngineId,
    required String expectedEngineVersion,
    required String expectedModelName,
  }) async {
    if (!await file.exists()) return null;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schemaVersion'] != expectedSchema ||
          decoded['engineId'] != expectedEngineId ||
          decoded['engineVersion'] != expectedEngineVersion ||
          decoded['modelName'] != expectedModelName ||
          decoded['language'] != 'ja') {
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
    required String engineId,
    required String engineVersion,
    required String modelName,
    required List<LyricLine> lines,
  }) async {
    if (lines.isEmpty) return;

    final dir = await _directory();
    final destination = File(
      p.join(
        dir.path,
        '${_cacheId(
          track: track,
          engineId: engineId,
          engineVersion: engineVersion,
          modelName: modelName,
        )}.json',
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
