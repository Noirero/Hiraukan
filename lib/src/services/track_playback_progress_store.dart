import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_track.dart';

class TrackPlaybackProgress {
  final Duration position;
  final Duration? duration;
  final bool completed;
  final DateTime updatedAt;

  const TrackPlaybackProgress({
    required this.position,
    required this.duration,
    required this.completed,
    required this.updatedAt,
  });

  double get fraction {
    final total = duration?.inMilliseconds ?? 0;
    if (total <= 0) return 0;
    return (position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'positionMs': position.inMilliseconds,
        'durationMs': duration?.inMilliseconds,
        'completed': completed,
        'updatedAtMs': updatedAt.millisecondsSinceEpoch,
      };

  factory TrackPlaybackProgress.fromJson(Map<String, dynamic> json) {
    final positionMs = (json['positionMs'] as num?)?.toInt() ?? 0;
    final durationMs = (json['durationMs'] as num?)?.toInt();
    final updatedAtMs = (json['updatedAtMs'] as num?)?.toInt() ?? 0;
    return TrackPlaybackProgress(
      position: Duration(milliseconds: positionMs < 0 ? 0 : positionMs),
      duration: durationMs == null
          ? null
          : Duration(milliseconds: durationMs < 0 ? 0 : durationMs),
      completed: json['completed'] == true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
    );
  }
}

/// Small per-track persistence layer used by chapter/virtual-track UI.
///
/// Work-level history remains untouched; this store only prevents multiple
/// logical tracks sharing the same source work from overwriting one another's
/// last position.
class TrackPlaybackProgressStore {
  TrackPlaybackProgressStore._();

  static final TrackPlaybackProgressStore instance =
      TrackPlaybackProgressStore._();

  static const String _prefix = 'track_playback_progress_v1:';
  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  Stream<String> get changes => _changes.stream;

  String identityFor(AudioTrack track) {
    final source = track.sourceKey ?? 'legacy';
    final work = track.sourceWorkId ?? track.workId?.toString() ?? 'unknown';
    final logicalTrack = track.sourceTrackId ?? track.id;
    return '$source|$work|$logicalTrack';
  }

  Future<TrackPlaybackProgress?> load(AudioTrack track) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(identityFor(track)));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return TrackPlaybackProgress.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, TrackPlaybackProgress>> loadForTracks(
    Iterable<AudioTrack> tracks,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, TrackPlaybackProgress>{};
    for (final track in tracks) {
      final identity = identityFor(track);
      final raw = prefs.getString(_storageKey(identity));
      if (raw == null || raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        result[identity] = TrackPlaybackProgress.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      } catch (_) {
        // Corrupt optional progress must never block playback/detail.
      }
    }
    return result;
  }

  Future<void> save(
    AudioTrack track,
    Duration position, {
    Duration? duration,
    bool completed = false,
  }) async {
    var logicalPosition = position;
    if (logicalPosition < Duration.zero) logicalPosition = Duration.zero;
    final logicalDuration = duration ?? track.segmentDuration ?? track.duration;
    if (logicalDuration != null && logicalPosition > logicalDuration) {
      logicalPosition = logicalDuration;
    }

    final nearEnd = logicalDuration != null &&
        logicalDuration > Duration.zero &&
        logicalDuration - logicalPosition <= const Duration(seconds: 1);
    final value = TrackPlaybackProgress(
      position: completed && logicalDuration != null
          ? logicalDuration
          : logicalPosition,
      duration: logicalDuration,
      completed: completed || nearEnd,
      updatedAt: DateTime.now(),
    );

    final identity = identityFor(track);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(identity), jsonEncode(value.toJson()));
    _changes.add(identity);
  }

  String _storageKey(String identity) {
    final encoded = base64Url.encode(utf8.encode(identity));
    return '$_prefix$encoded';
  }
}
