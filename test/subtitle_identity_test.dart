import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/subtitles/subtitle_identity.dart';

void main() {
  test('identity prefers canonical/source track ids when available', () {
    const track = AudioTrack(
      id: 'legacy-id',
      title: '01.mp3',
      url: 'https://cdn.example/01.mp3',
      workId: 123456,
      hash: 'audio-hash',
      sourceKind: 'hentai_asmr',
      sourceLocalWorkId: 'post-99',
      canonicalWorkId: 'RJ123456',
      sourceTrackId: 'track-1',
    );

    final identity = SubtitleIdentity.fromTrack(track);

    expect(identity.source, 'hentai_asmr');
    expect(identity.effectiveWorkId, 'RJ123456');
    expect(identity.trackId, 'track-1');
    expect(identity.audioFingerprint, 'audio-hash');
    expect(
      identity.stableKey,
      contains('hentai_asmr'),
    );
  });

  test('legacy persisted tracks remain addressable', () {
    const track = AudioTrack(
      id: 'old-track',
      title: 'old.mp3',
      url: 'https://cdn.example/old.mp3',
      workId: 42,
      hash: 'old-hash',
    );

    final identity = SubtitleIdentity.fromTrack(track);

    expect(identity.source, 'legacy');
    expect(identity.effectiveWorkId, '42');
    expect(identity.trackId, 'old-hash');
  });
}
