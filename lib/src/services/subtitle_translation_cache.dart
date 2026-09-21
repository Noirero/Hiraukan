import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/ai_job_identity.dart';
import '../models/lyric.dart';

class TranslationDocumentCacheStats {
  final int documents;
  final int bytes;

  const TranslationDocumentCacheStats({
    required this.documents,
    required this.bytes,
  });
}

class DownloadedTranslationDocument {
  final List<LyricLine> lyrics;
  final String path;

  const DownloadedTranslationDocument({
    required this.lyrics,
    required this.path,
  });
}

/// Durable cache for a complete translated subtitle document.
///
/// The cache identity includes source subtitle content, stable track identity,
/// translation engine/version and post-processing/glossary versions. A changed
/// Japanese subtitle therefore never reuses an older Indonesian document.
class SubtitleTranslationCache {
  SubtitleTranslationCache._();

  static final SubtitleTranslationCache instance = SubtitleTranslationCache._();

  static const int schemaVersion = 1;
  static const int postProcessingVersion = 1;
  static const int defaultGlossaryVersion = 1;

  Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      p.join(support.path, 'hiraukan_ai', 'translation_cache'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String sourceContentHash(List<LyricLine> lyrics) {
    final canonical = lyrics
        .map(
          (line) =>
              '${line.startTime.inMilliseconds}|${line.endTime.inMilliseconds}|${line.text}',
        )
        .join('\n');
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  String _cacheId({
    required TrackIdentity track,
    required List<LyricLine> sourceLyrics,
    required String engineId,
    required String engineVersion,
    required String sourceLanguage,
    required String targetLanguage,
    required int glossaryVersion,
    required String translationStrategy,
  }) {
    final payload = [
      'schema=$schemaVersion',
      'track=${track.trackId}',
      'source=${track.sourceKey}',
      'work=${track.sourceWorkId}',
      'audio=${track.audioFingerprint}',
      'subtitle=${sourceContentHash(sourceLyrics)}',
      'engine=$engineId',
      'engineVersion=$engineVersion',
      'from=$sourceLanguage',
      'to=$targetLanguage',
      'glossary=$glossaryVersion',
      'strategy=$translationStrategy',
      'post=$postProcessingVersion',
    ].join('|');
    return sha256.convert(utf8.encode(payload)).toString();
  }

  Future<String> pathFor({
    required TrackIdentity track,
    required List<LyricLine> sourceLyrics,
    required String engineId,
    required String engineVersion,
    String sourceLanguage = 'ja',
    String targetLanguage = 'id',
    int glossaryVersion = defaultGlossaryVersion,
    String translationStrategy = 'segment-v1',
  }) async {
    final dir = await _directory();
    final id = _cacheId(
      track: track,
      sourceLyrics: sourceLyrics,
      engineId: engineId,
      engineVersion: engineVersion,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      glossaryVersion: glossaryVersion,
      translationStrategy: translationStrategy,
    );
    return p.join(dir.path, '$id.json');
  }

  Future<List<LyricLine>?> load({
    required TrackIdentity track,
    required List<LyricLine> sourceLyrics,
    required String engineId,
    required String engineVersion,
    String sourceLanguage = 'ja',
    String targetLanguage = 'id',
    int glossaryVersion = defaultGlossaryVersion,
    String translationStrategy = 'segment-v1',
  }) async {
    final dir = await _directory();
    final id = _cacheId(
      track: track,
      sourceLyrics: sourceLyrics,
      engineId: engineId,
      engineVersion: engineVersion,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      glossaryVersion: glossaryVersion,
      translationStrategy: translationStrategy,
    );
    final file = File(p.join(dir.path, '$id.json'));
    if (!await file.exists()) return null;

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['schemaVersion'] != schemaVersion) return null;
      if (decoded['sourceContentHash'] != sourceContentHash(sourceLyrics)) {
        return null;
      }
      return _decodeLines(
        decoded['lines'],
        sourceLyrics: sourceLyrics,
      );
    } catch (_) {
      return null;
    }
  }

  /// Finds an explicitly downloaded Indonesian subtitle without consulting
  /// any online service or current translation settings.
  Future<DownloadedTranslationDocument?> loadDownloadedForTrack({
    required TrackIdentity track,
    required List<LyricLine> sourceLyrics,
    String targetLanguage = 'id',
  }) async {
    if (sourceLyrics.isEmpty) return null;

    final dir = await _directory();
    final expectedSourceHash = sourceContentHash(sourceLyrics);
    DownloadedTranslationDocument? newest;
    DateTime? newestCreatedAt;

    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;

      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! Map<String, dynamic>) continue;
        if (decoded['schemaVersion'] != schemaVersion ||
            decoded['offlineDownload'] != true ||
            decoded['targetLanguage'] != targetLanguage ||
            decoded['sourceContentHash'] != expectedSourceHash) {
          continue;
        }

        final rawTrack = decoded['track'];
        if (rawTrack is! Map) continue;
        if (rawTrack['trackId']?.toString() != track.trackId ||
            rawTrack['sourceKey']?.toString() != track.sourceKey ||
            rawTrack['sourceWorkId']?.toString() != track.sourceWorkId ||
            rawTrack['audioFingerprint']?.toString() !=
                track.audioFingerprint) {
          continue;
        }

        final lines = _decodeLines(
          decoded['lines'],
          sourceLyrics: sourceLyrics,
        );
        if (lines == null) continue;

        final createdAt = DateTime.tryParse(
          decoded['createdAt']?.toString() ?? '',
        );
        if (newest == null ||
            (createdAt != null &&
                (newestCreatedAt == null ||
                    createdAt.isAfter(newestCreatedAt)))) {
          newest = DownloadedTranslationDocument(
            lyrics: List.unmodifiable(lines),
            path: entity.path,
          );
          newestCreatedAt = createdAt;
        }
      } catch (_) {
        // Ignore corrupt/partial documents and continue searching.
      }
    }

    return newest;
  }

  List<LyricLine>? _decodeLines(
    dynamic rawLines, {
    required List<LyricLine> sourceLyrics,
  }) {
    if (rawLines is! List || rawLines.length != sourceLyrics.length) {
      return null;
    }

    final lines = <LyricLine>[];
    for (var i = 0; i < rawLines.length; i++) {
      final raw = rawLines[i];
      if (raw is! Map) return null;
      final source = sourceLyrics[i];
      lines.add(
        LyricLine(
          startTime: source.startTime,
          endTime: source.endTime,
          text: raw['text']?.toString() ?? source.text,
        ),
      );
    }
    return lines;
  }

  Future<String?> save({
    required TrackIdentity track,
    required List<LyricLine> sourceLyrics,
    required List<LyricLine> translatedLyrics,
    required String engineId,
    required String engineVersion,
    String sourceLanguage = 'ja',
    String targetLanguage = 'id',
    int glossaryVersion = defaultGlossaryVersion,
    String translationStrategy = 'segment-v1',
    bool offlineDownload = false,
  }) async {
    if (sourceLyrics.length != translatedLyrics.length) return null;

    final dir = await _directory();
    final id = _cacheId(
      track: track,
      sourceLyrics: sourceLyrics,
      engineId: engineId,
      engineVersion: engineVersion,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      glossaryVersion: glossaryVersion,
      translationStrategy: translationStrategy,
    );
    final destination = File(p.join(dir.path, '$id.json'));
    final temporary = File('${destination.path}.tmp');

    final payload = jsonEncode({
      'schemaVersion': schemaVersion,
      'sourceContentHash': sourceContentHash(sourceLyrics),
      'offlineDownload': offlineDownload,
      'track': {
        'trackId': track.trackId,
        'sourceKey': track.sourceKey,
        'sourceWorkId': track.sourceWorkId,
        'audioFingerprint': track.audioFingerprint,
      },
      'engineId': engineId,
      'engineVersion': engineVersion,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'glossaryVersion': glossaryVersion,
      'translationStrategy': translationStrategy,
      'postProcessingVersion': postProcessingVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'lines': [
        for (final line in translatedLyrics) {'text': line.text},
      ],
    });

    await temporary.writeAsString(payload, flush: true);
    if (await destination.exists()) {
      await destination.delete();
    }
    await temporary.rename(destination.path);
    return destination.path;
  }

  Future<TranslationDocumentCacheStats> stats() async {
    final dir = await _directory();
    var documents = 0;
    var bytes = 0;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! Map<String, dynamic> ||
            decoded['offlineDownload'] != true) {
          continue;
        }
        documents++;
        bytes += await entity.length();
      } catch (_) {
        // Ignore corrupt or concurrently removed documents.
      }
    }
    return TranslationDocumentCacheStats(
      documents: documents,
      bytes: bytes,
    );
  }

  Future<void> clearDownloaded() async {
    final dir = await _directory();
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is Map<String, dynamic> &&
            decoded['offlineDownload'] == true) {
          await entity.delete();
        }
      } catch (_) {
        // Leave unknown/corrupt legacy cache entries untouched.
      }
    }
  }

  Future<void> clear() async {
    final dir = await _directory();
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        try {
          await entity.delete();
        } catch (_) {
          // Continue clearing the rest.
        }
      }
    }
  }
}
