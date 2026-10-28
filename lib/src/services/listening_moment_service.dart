import 'dart:convert';

import '../models/audio_track.dart';
import '../models/listening_moment.dart';
import 'log_service.dart';
import 'storage_service.dart';
import 'track_playback_progress_store.dart';

class ListeningMomentService {
  ListeningMomentService._();

  static final ListeningMomentService instance = ListeningMomentService._();
  static const String _storageKey = 'hiraukan_listening_moments_v1';

  Future<List<ListeningMoment>> load() async {
    final raw = StorageService.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const <ListeningMoment>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <ListeningMoment>[];
      final moments = decoded
          .whereType<Map>()
          .map((item) => ListeningMoment.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .where((moment) =>
              moment.id.isNotEmpty && moment.trackIdentity.isNotEmpty)
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return moments;
    } catch (error, stack) {
      LogService.instance.error(
        'Failed to decode listening moments: $error\n$stack',
        tag: 'ListeningMoments',
      );
      return const <ListeningMoment>[];
    }
  }

  Future<void> save(List<ListeningMoment> moments) async {
    await StorageService.setString(
      _storageKey,
      jsonEncode(moments.map((moment) => moment.toJson()).toList()),
    );
  }

  Future<List<ListeningMoment>> add(
    List<ListeningMoment> current, {
    required AudioTrack track,
    required Duration position,
    String note = '',
  }) async {
    final now = DateTime.now();
    final identity = TrackPlaybackProgressStore.instance.identityFor(track);
    final normalizedPosition = position < Duration.zero ? Duration.zero : position;
    final moment = ListeningMoment(
      id: '${now.microsecondsSinceEpoch}',
      trackIdentity: identity,
      track: track,
      positionMs: normalizedPosition.inMilliseconds,
      createdAt: now,
      note: note.trim(),
    );
    final next = <ListeningMoment>[moment, ...current];
    await save(next);
    return next;
  }

  Future<List<ListeningMoment>> updateNote(
    List<ListeningMoment> current,
    String id,
    String note,
  ) async {
    final next = current
        .map((moment) =>
            moment.id == id ? moment.copyWith(note: note.trim()) : moment)
        .toList(growable: false);
    await save(next);
    return next;
  }

  Future<List<ListeningMoment>> delete(
    List<ListeningMoment> current,
    String id,
  ) async {
    final next = current.where((moment) => moment.id != id).toList(growable: false);
    await save(next);
    return next;
  }
}
