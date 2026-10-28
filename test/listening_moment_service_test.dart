import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/models/listening_moment.dart';
import 'package:kikoeru_flutter/src/services/track_playback_progress_store.dart';

void main() {
  test('virtual tracks sharing one media URL keep distinct stable identities', () {
    const first = AudioTrack(
      id: 'legacy-a',
      title: 'Chapter A',
      url: 'https://media.example/shared.m4a',
      sourceKey: 'asmr_one',
      sourceWorkId: 'RJ012345',
      sourceTrackId: 'chapter-a',
    );
    const second = AudioTrack(
      id: 'legacy-b',
      title: 'Chapter B',
      url: 'https://media.example/shared.m4a',
      sourceKey: 'asmr_one',
      sourceWorkId: 'RJ012345',
      sourceTrackId: 'chapter-b',
    );

    final store = TrackPlaybackProgressStore.instance;
    expect(store.identityFor(first), 'asmr_one|RJ012345|chapter-a');
    expect(store.identityFor(second), 'asmr_one|RJ012345|chapter-b');
    expect(store.identityFor(first), isNot(store.identityFor(second)));
  });

  test('listening moment round-trip preserves track identity and timestamp', () {
    const track = AudioTrack(
      id: 'track-1',
      title: 'Whisper',
      url: 'https://media.example/track.m4a',
      sourceKey: 'japanese_asmr',
      sourceWorkId: 'RJ999999',
      sourceTrackId: 'track-1',
      playbackHeaders: <String, String>{'Referer': 'https://source.example/'},
    );
    final identity = TrackPlaybackProgressStore.instance.identityFor(track);
    final original = ListeningMoment(
      id: 'moment-1',
      trackIdentity: identity,
      track: track,
      positionMs: 123456,
      createdAt: DateTime.utc(2026, 10, 29, 1, 2, 3),
      note: 'favorite line',
    );

    final restored = ListeningMoment.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.trackIdentity, identity);
    expect(restored.position, const Duration(milliseconds: 123456));
    expect(restored.track.sourceTrackId, 'track-1');
    expect(restored.track.playbackHeaders['Referer'], 'https://source.example/');
    expect(restored.note, 'favorite line');
  });
}
