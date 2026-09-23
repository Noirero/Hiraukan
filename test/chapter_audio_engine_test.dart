import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/models/work.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_registry.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_service.dart';
import 'package:kikoeru_flutter/src/services/track_playback_progress_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chapter Audio Engine', () {
    test('virtual track converts absolute and relative positions safely', () {
      const track = AudioTrack(
        id: 'japanese_asmr:123:track-2',
        title: 'Track 2',
        url: 'https://cdn.example/work.m4a',
        sourceKey: 'japanese_asmr',
        sourceWorkId: '123',
        sourceTrackId: 'track-2',
        startOffset: Duration(minutes: 4, seconds: 18),
        endOffset: Duration(minutes: 11, seconds: 23),
      );

      expect(track.isSegmented, isTrue);
      expect(track.segmentDuration, const Duration(minutes: 7, seconds: 5));
      expect(
        track.toRelativePosition(const Duration(minutes: 5)),
        const Duration(seconds: 42),
      );
      expect(
        track.toRelativePosition(const Duration(minutes: 3)),
        Duration.zero,
      );
      expect(
        track.toRelativePosition(const Duration(minutes: 30)),
        const Duration(minutes: 7, seconds: 5),
      );
      expect(
        track.toAbsolutePosition(Duration.zero),
        const Duration(minutes: 4, seconds: 18),
      );
      expect(
        track.toAbsolutePosition(const Duration(seconds: 42)),
        const Duration(minutes: 5),
      );
      expect(
        track.toAbsolutePosition(const Duration(minutes: 30)),
        const Duration(minutes: 11, seconds: 23),
      );
    });

    test('virtual track metadata survives JSON session round-trip', () {
      const track = AudioTrack(
        id: 'asmr18:RJ123456:chapter-4',
        title: 'Chapter 4',
        url: 'https://cdn.example/main.m3u8',
        sourceKey: 'asmr18',
        sourceWorkId: 'RJ123456',
        sourceTrackId: 'chapter-4',
        startOffset: Duration(minutes: 18, seconds: 24),
        endOffset: Duration(minutes: 33, seconds: 12),
        duration: Duration(minutes: 14, seconds: 48),
        playbackHeaders: <String, String>{
          'Referer': 'https://asmr18.fans/',
        },
      );

      final restored = AudioTrack.fromJson(track.toJson());

      expect(restored, track);
      expect(restored.sourceTrackId, 'chapter-4');
      expect(restored.startOffset, const Duration(minutes: 18, seconds: 24));
      expect(restored.endOffset, const Duration(minutes: 33, seconds: 12));
      expect(restored.segmentDuration, const Duration(minutes: 14, seconds: 48));
      expect(restored.playbackHeaders['Referer'], 'https://asmr18.fans/');
    });

    test('unified source maps chapter rows into tracks sharing one source URL', () {
      final service = UnifiedSourceService(
        adapters: const [],
        registry: UnifiedSourceRegistry.instance,
      );
      const source = UnifiedSourceRef(
        source: UnifiedSourceKind.japaneseAsmr,
        localId: '123',
        detailUrl: 'https://japaneseasmr.com/123/',
      );
      const resolved = ResolvedSourceTracks(
        source: source,
        files: <dynamic>[
          <String, dynamic>{
            'title': 'Track 1',
            'type': 'audio',
            'sourceTrackId': 'chapter-1',
            'mediaStreamUrl': 'https://cdn.example/work.m4a',
            'startOffset': '00:00:00',
            'endOffset': '00:04:18',
          },
          <String, dynamic>{
            'title': 'Track 2',
            'type': 'audio',
            'sourceTrackId': 'chapter-2',
            'mediaStreamUrl': 'https://cdn.example/work.m4a',
            'startOffset': '00:04:18',
            'endOffset': '00:11:23',
            'headers': <String, String>{
              'Referer': 'https://japaneseasmr.com/',
            },
          },
        ],
        usedFallback: false,
      );

      final tracks = service.buildAudioTracks(
        work: const Work(id: -123, title: 'Chapter Work'),
        resolved: resolved,
        host: '',
        token: '',
      );

      expect(tracks, hasLength(2));
      expect(tracks[0].url, tracks[1].url);
      expect(tracks[0].id, isNot(tracks[1].id));
      expect(tracks[1].sourceTrackId, 'chapter-2');
      expect(tracks[1].startOffset, const Duration(minutes: 4, seconds: 18));
      expect(tracks[1].endOffset, const Duration(minutes: 11, seconds: 23));
      expect(tracks[1].duration, const Duration(minutes: 7, seconds: 5));
      expect(
        tracks[1].playbackHeaders['Referer'],
        'https://japaneseasmr.com/',
      );
    });

    test('ASMR Hentai Referer survives Unified Source track mapping', () {
      final service = UnifiedSourceService(
        adapters: const [],
        registry: UnifiedSourceRegistry.instance,
      );
      const source = UnifiedSourceRef(
        source: UnifiedSourceKind.asmrHentaiNet,
        localId: 'RJ244551',
        canonicalId: 'RJ244551',
        detailUrl: 'https://asmrhentai.net/RJ244551',
      );
      const resolved = ResolvedSourceTracks(
        source: source,
        files: <dynamic>[
          <String, dynamic>{
            'title': '(すすり、水音弱め)',
            'type': 'audio',
            'hash': 'asmr_hentai_net:RJ244551:a_cpz',
            'sourceTrackId': 'a_cpz',
            'mediaStreamUrl':
                'https://newapi.asmrhentai.net/storage/RJ244551/a_cpz.opus',
            'duration': 1285,
            'startOffset': 0,
            'endOffset': 1285,
            'headers': <String, String>{
              'Referer': 'https://asmrhentai.net',
              'Origin': 'https://asmrhentai.net',
              'User-Agent': 'Hiraukan/3.8 UnifiedSources',
            },
          },
        ],
        usedFallback: false,
      );

      final tracks = service.buildAudioTracks(
        work: const Work(id: -244551, title: 'ASMR Hentai Work'),
        resolved: resolved,
        host: '',
        token: '',
      );

      expect(tracks, hasLength(1));
      expect(tracks.single.sourceKey, 'asmr_hentai_net');
      expect(tracks.single.sourceTrackId, 'a_cpz');
      expect(
        tracks.single.playbackHeaders['Referer'],
        'https://asmrhentai.net',
      );
      expect(
        tracks.single.playbackHeaders['Origin'],
        'https://asmrhentai.net',
      );
    });

    test('progress is isolated per virtual track even with one shared media hash',
        () async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      const first = AudioTrack(
        id: 'japanese_asmr:123:chapter-1',
        title: 'Track 1',
        url: 'https://cdn.example/work.m4a',
        hash: 'shared-media',
        sourceKey: 'japanese_asmr',
        sourceWorkId: '123',
        sourceTrackId: 'chapter-1',
        startOffset: Duration.zero,
        endOffset: Duration(minutes: 4, seconds: 18),
        duration: Duration(minutes: 4, seconds: 18),
      );
      const second = AudioTrack(
        id: 'japanese_asmr:123:chapter-2',
        title: 'Track 2',
        url: 'https://cdn.example/work.m4a',
        hash: 'shared-media',
        sourceKey: 'japanese_asmr',
        sourceWorkId: '123',
        sourceTrackId: 'chapter-2',
        startOffset: Duration(minutes: 4, seconds: 18),
        endOffset: Duration(minutes: 11, seconds: 23),
        duration: Duration(minutes: 7, seconds: 5),
      );

      final store = TrackPlaybackProgressStore.instance;
      expect(store.identityFor(first), isNot(store.identityFor(second)));

      await store.save(
        first,
        const Duration(minutes: 1),
        duration: first.segmentDuration,
      );
      await store.save(
        second,
        const Duration(minutes: 7, seconds: 5),
        duration: second.segmentDuration,
        completed: true,
      );

      final values = await store.loadForTracks(const [first, second]);
      final firstValue = values[store.identityFor(first)];
      final secondValue = values[store.identityFor(second)];

      expect(firstValue?.position, const Duration(minutes: 1));
      expect(firstValue?.completed, isFalse);
      expect(secondValue?.position, const Duration(minutes: 7, seconds: 5));
      expect(secondValue?.completed, isTrue);
    });
  });
}
