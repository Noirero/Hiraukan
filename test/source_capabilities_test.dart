import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/work.dart';
import 'package:kikoeru_flutter/src/sources/source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_registry.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapabilityFakeAdapter implements UnifiedSourceAdapter {
  @override
  final UnifiedSourceKind kind;
  final SourceWorkCandidate candidate;
  final List<dynamic> tracks;
  int trackCalls = 0;

  _CapabilityFakeAdapter({
    required this.kind,
    required this.candidate,
    this.tracks = const [],
  });

  @override
  Future<UnifiedSourceHealth> checkHealth() async =>
      UnifiedSourceHealth.healthy;

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async => candidate.work;

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    trackCalls++;
    return tracks;
  }

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    return SourceSearchPage(
      items: [candidate],
      totalCount: 1,
      hasMore: false,
    );
  }
}

SourceWorkCandidate _candidate(
  UnifiedSourceKind kind, {
  required int id,
  required String localId,
  required String canonicalId,
}) {
  final detailUrl = 'https://${kind.id}.example/$localId';
  return SourceWorkCandidate(
    work: Work(
      id: id,
      title: 'Test Work',
      sourceId: canonicalId,
      sourceUrl: detailUrl,
    ),
    ref: UnifiedSourceRef(
      source: kind,
      localId: localId,
      canonicalId: canonicalId,
      detailUrl: detailUrl,
      title: 'Test Work',
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UnifiedSourceRegistry.instance.clear();
  });

  test('EroVoice is catalog/download capable but not playback capable', () {
    final capabilities = UnifiedSourceKind.eroVoice.capabilities;
    expect(capabilities.catalog, isTrue);
    expect(capabilities.detail, isTrue);
    expect(capabilities.download, isTrue);
    expect(capabilities.playback, isFalse);
  });

  test('resolver skips EroVoice playback and keeps source identity on tracks',
      () async {
    final ero = _CapabilityFakeAdapter(
      kind: UnifiedSourceKind.eroVoice,
      candidate: _candidate(
        UnifiedSourceKind.eroVoice,
        id: -1,
        localId: 'RJ123456',
        canonicalId: 'RJ123456',
      ),
      tracks: const [
        {
          'id': 'should-not-be-used',
          'type': 'audio',
          'title': 'ero.mp3',
          'mediaStreamUrl': 'https://ero.example/ero.mp3',
        }
      ],
    );
    final hentai = _CapabilityFakeAdapter(
      kind: UnifiedSourceKind.hentaiAsmr,
      candidate: _candidate(
        UnifiedSourceKind.hentaiAsmr,
        id: -2,
        localId: 'RJ123456',
        canonicalId: 'RJ123456',
      ),
      tracks: const [
        {
          'id': 'track-1',
          'hash': 'hash-1',
          'type': 'audio',
          'title': '01.mp3',
          'mediaStreamUrl': 'https://cdn.example/01.mp3',
        }
      ],
    );

    final service = UnifiedSourceService(
      adapters: [ero, hentai],
      registry: UnifiedSourceRegistry.instance,
    );
    final search = await service.search(
      keyword: 'test',
      page: 1,
      pageSize: 20,
    );
    final work = search.works.single;

    final resolved = await service.resolveTracks(
      work,
      preferredSource: UnifiedSourceKind.eroVoice,
    );

    expect(ero.trackCalls, 0);
    expect(hentai.trackCalls, 1);
    expect(resolved.source.source, UnifiedSourceKind.hentaiAsmr);
    expect(resolved.usedFallback, isTrue);

    final tracks = service.buildAudioTracks(
      work: work,
      resolved: resolved,
      host: '',
      token: '',
    );
    expect(tracks, hasLength(1));
    expect(tracks.single.sourceKind, 'hentai_asmr');
    expect(tracks.single.sourceLocalWorkId, 'RJ123456');
    expect(tracks.single.canonicalWorkId, 'RJ123456');
    expect(tracks.single.sourceTrackId, 'track-1');
  });
}
