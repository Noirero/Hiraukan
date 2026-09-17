import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';

void main() {
  test('legacy AudioTrack JSON remains readable without source identity fields', () {
    final track = AudioTrack.fromJson(const <String, dynamic>{
      'id': 'legacy-track',
      'title': 'legacy.mp3',
      'url': 'https://cdn.example/legacy.mp3',
      'workId': 42,
      'hash': 'legacy-hash',
    });

    expect(track.id, 'legacy-track');
    expect(track.sourceKind, isNull);
    expect(track.sourceLocalWorkId, isNull);
    expect(track.canonicalWorkId, isNull);
    expect(track.sourceTrackId, isNull);
  });

  test('new source identity survives AudioTrack JSON round-trip', () {
    const original = AudioTrack(
      id: 'track-1',
      title: '01.mp3',
      url: 'https://cdn.example/01.mp3',
      sourceKind: 'asmr_one',
      sourceLocalWorkId: '123',
      canonicalWorkId: 'RJ123456',
      sourceTrackId: 'source-track-1',
    );

    final restored = AudioTrack.fromJson(original.toJson());

    expect(restored.sourceKind, original.sourceKind);
    expect(restored.sourceLocalWorkId, original.sourceLocalWorkId);
    expect(restored.canonicalWorkId, original.canonicalWorkId);
    expect(restored.sourceTrackId, original.sourceTrackId);
  });
}
