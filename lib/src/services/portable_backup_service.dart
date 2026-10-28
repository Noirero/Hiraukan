import 'dart:convert';

import '../models/history_record.dart';
import '../models/listening_moment.dart';
import '../models/local_collection.dart';
import '../models/local_work_mark.dart';
import 'history_database.dart';
import 'listening_moment_service.dart';
import 'local_collection_service.dart';
import 'local_work_mark_service.dart';
import 'portable_backup_sanitizer.dart';

class PortableBackupSummary {
  const PortableBackupSummary({
    required this.historyCount,
    required this.collectionCount,
    required this.momentCount,
  });

  final int historyCount;
  final int collectionCount;
  final int momentCount;
}

class PortableBackupService {
  PortableBackupService._();

  static final PortableBackupService instance = PortableBackupService._();

  static const String kind = 'hiraukan_portable_backup';
  static const int schemaVersion = 1;
  static const PortableBackupSanitizer _sanitizer = PortableBackupSanitizer();

  Future<String> exportJson() async {
    final history = await HistoryDatabase.instance.getAllHistory();
    final collections = await LocalCollectionService.instance.load();
    final moments = await ListeningMomentService.instance.load();
    final localWorkMarks = await LocalWorkMarkService.instance.load();

    final payload = <String, dynamic>{
      'kind': kind,
      'schemaVersion': schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'containsCredentials': false,
      'history': history
          .map((item) => _sanitizer.sanitizeMap(item.toMap()))
          .toList(growable: false),
      'localCollections': collections
          .map((item) => _sanitizer.sanitizeMap(item.toJson()))
          .toList(growable: false),
      'listeningMoments': moments
          .map((item) => _sanitizer.sanitizeMap(item.toJson()))
          .toList(growable: false),
      // Optional schema-v1 field: older backups remain valid while newer
      // backups preserve Hiraukan-owned favorites and personal ratings.
      'localWorkMarks': localWorkMarks
          .map((item) => _sanitizer.sanitizeMap(item.toJson()))
          .toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  PortableBackupSummary inspect(String rawJson) {
    final root = _decodeRoot(rawJson);
    final history = root['history'];
    final collections = root['localCollections'];
    final moments = root['listeningMoments'];
    return PortableBackupSummary(
      historyCount: history is List ? history.length : 0,
      collectionCount: collections is List ? collections.length : 0,
      momentCount: moments is List ? moments.length : 0,
    );
  }

  /// Imports portable metadata using merge semantics.
  ///
  /// - history uses the existing database primary key (`work_id`) and therefore
  ///   refreshes matching records while preserving unrelated local history;
  /// - collections/moments/local marks use their stable local IDs/keys and
  ///   imported items win on collision while unrelated local items remain;
  /// - imported metadata is sanitized before parsing so a manually modified
  ///   backup cannot inject stored auth/cookie/API-key headers into playback.
  Future<PortableBackupSummary> importJson(String rawJson) async {
    final root = _decodeRoot(rawJson);
    final importedHistory = _parseHistory(root['history']);
    final importedCollections = _parseCollections(root['localCollections']);
    final importedMoments = _parseMoments(root['listeningMoments']);
    final importedMarks = _parseLocalWorkMarks(root['localWorkMarks']);

    for (final record in importedHistory) {
      await HistoryDatabase.instance.addOrUpdate(record);
    }

    final currentCollections = await LocalCollectionService.instance.load();
    final collectionMap = <String, LocalCollection>{
      for (final item in currentCollections) item.id: item,
      for (final item in importedCollections) item.id: item,
    };
    await LocalCollectionService.instance.save(
      collectionMap.values.toList(growable: false),
    );

    final currentMoments = await ListeningMomentService.instance.load();
    final momentMap = <String, ListeningMoment>{
      for (final item in currentMoments) item.id: item,
      for (final item in importedMoments) item.id: item,
    };
    final mergedMoments = momentMap.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await ListeningMomentService.instance.save(mergedMoments);

    final currentMarks = await LocalWorkMarkService.instance.load();
    final markMap = <String, LocalWorkMark>{
      for (final item in currentMarks) item.key: item,
      for (final item in importedMarks) item.key: item,
    };
    final mergedMarks = markMap.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await LocalWorkMarkService.instance.save(mergedMarks);

    return PortableBackupSummary(
      historyCount: importedHistory.length,
      collectionCount: importedCollections.length,
      momentCount: importedMoments.length,
    );
  }

  Map<String, dynamic> _decodeRoot(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw const FormatException('Backup root must be a JSON object');
    }
    final root = Map<String, dynamic>.from(decoded);
    if (root['kind'] != kind) {
      throw const FormatException('This file is not a Hiraukan portable backup');
    }
    final version = (root['schemaVersion'] as num?)?.toInt();
    if (version != schemaVersion) {
      throw FormatException(
        'Unsupported backup schema version: ${version ?? 'unknown'}',
      );
    }
    return root;
  }

  List<HistoryRecord> _parseHistory(dynamic raw) {
    if (raw is! List) return const <HistoryRecord>[];
    final result = <HistoryRecord>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(
          HistoryRecord.fromMap(
            _sanitizer.sanitizeMap(Map<String, dynamic>.from(item)),
          ),
        );
      } catch (_) {
        // One corrupt optional record must not invalidate the whole backup.
      }
    }
    return result;
  }

  List<LocalCollection> _parseCollections(dynamic raw) {
    if (raw is! List) return const <LocalCollection>[];
    final result = <LocalCollection>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final collection = LocalCollection.fromJson(
          _sanitizer.sanitizeMap(Map<String, dynamic>.from(item)),
        );
        if (collection.id.isNotEmpty && collection.name.trim().isNotEmpty) {
          result.add(collection);
        }
      } catch (_) {
        // Skip malformed records while preserving valid backup content.
      }
    }
    return result;
  }

  List<ListeningMoment> _parseMoments(dynamic raw) {
    if (raw is! List) return const <ListeningMoment>[];
    final result = <ListeningMoment>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final moment = ListeningMoment.fromJson(
          _sanitizer.sanitizeMap(Map<String, dynamic>.from(item)),
        );
        if (moment.id.isNotEmpty && moment.trackIdentity.isNotEmpty) {
          result.add(moment);
        }
      } catch (_) {
        // Skip malformed records while preserving valid backup content.
      }
    }
    return result;
  }

  List<LocalWorkMark> _parseLocalWorkMarks(dynamic raw) {
    if (raw is! List) return const <LocalWorkMark>[];
    final result = <LocalWorkMark>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final mark = LocalWorkMark.fromJson(
          _sanitizer.sanitizeMap(Map<String, dynamic>.from(item)),
        );
        if (mark.key.isNotEmpty && (mark.isFavorite || mark.rating != null)) {
          result.add(mark);
        }
      } catch (_) {
        // Skip malformed optional marks while preserving valid backup content.
      }
    }
    return result;
  }
}
