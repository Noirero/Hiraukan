import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/extensions/asmr_one_audio_extension.dart';
import 'package:kikoeru_flutter/src/extensions/audio_extension.dart';
import 'package:kikoeru_flutter/src/models/work.dart';
import 'package:kikoeru_flutter/src/sources/source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';

void main() {
  group('AsmrOneAudioExtension', () {
    test('supports browse, detail, tracks, and anonymous playback resolution',
        () async {
      final extension = AsmrOneAudioExtension.withAdapter(
        adapter: _FakeAsmrOneAdapter(),
        host: () => 'https://api.example.test',
        token: () => '',
      );

      final browse = await extension.browse(page: 1, pageSize: 20);
      expect(browse.items, hasLength(1));
      expect(browse.items.single.id, '123456');
      expect(browse.items.single.canonicalId, 'RJ123456');

      final detail = await extension.getDetail('123456');
      expect(detail.title, 'Reference Work');
      expect(detail.creator, 'Reference Circle');

      final tracks = await extension.getTracks('123456');
      expect(tracks, hasLength(1));
      expect(tracks.single.id, 'audio-hash');

      final playback = await extension.resolvePlayback(
        workId: '123456',
        trackId: tracks.single.id,
      );
      expect(playback.kind, AudioPlaybackKind.direct);
      expect(
        playback.uri.toString(),
        'https://api.example.test/api/media/stream/audio-hash',
      );
    });

    test('adds the optional account token only when present', () async {
      final extension = AsmrOneAudioExtension.withAdapter(
        adapter: _FakeAsmrOneAdapter(
          trackUrl: '/api/media/stream/audio-hash?quality=high',
        ),
        host: () => 'api.example.test',
        token: () => 'secret-token',
      );

      final playback = await extension.resolvePlayback(
        workId: '123456',
        trackId: 'audio-hash',
      );

      expect(
        playback.uri.queryParameters['token'],
        'secret-token',
      );
      expect(playback.uri.queryParameters['quality'], 'high');
    });

    test('declares optional authentication rather than global login', () {
      final extension = AsmrOneAudioExtension.withAdapter(
        adapter: _FakeAsmrOneAdapter(),
        host: () => 'https://api.example.test',
        token: () => '',
      );

      expect(extension.manifest.id, 'miyorare.audio.asmr_one');
      expect(extension.manifest.auth.name, 'optional');
      expect(extension.manifest.type, 'audio');
    });
  });
}

class _FakeAsmrOneAdapter implements UnifiedSourceAdapter {
  _FakeAsmrOneAdapter({this.trackUrl});

  final String? trackUrl;

  @override
  UnifiedSourceKind get kind => UnifiedSourceKind.asmrOne;

  Work get _work => const Work(
        id: 123456,
        title: 'Reference Work',
        name: 'Reference Circle',
        sourceId: 'RJ123456',
        sourceUrl: 'https://www.asmr.one/work/RJ123456',
        duration: 120,
        images: ['https://example.test/cover.jpg'],
        tags: [Tag(id: 1, name: 'ASMR')],
      );

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    return SourceSearchPage(
      items: [
        SourceWorkCandidate(
          work: _work,
          ref: const UnifiedSourceRef(
            source: UnifiedSourceKind.asmrOne,
            localId: '123456',
            canonicalId: 'RJ123456',
            detailUrl: 'https://www.asmr.one/work/RJ123456',
            coverUrl: 'https://example.test/cover.jpg',
            title: 'Reference Work',
            circle: 'Reference Circle',
            durationSeconds: 120,
          ),
        ),
      ],
      totalCount: 1,
      hasMore: false,
    );
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async => _work;

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    return [
      {
        'type': 'audio',
        'title': 'Track 01.mp3',
        'hash': 'audio-hash',
        'duration': 12.5,
        if (trackUrl != null) 'mediaStreamUrl': trackUrl,
      },
    ];
  }

  @override
  Future<UnifiedSourceHealth> checkHealth() async {
    return UnifiedSourceHealth.healthy;
  }
}
