import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/work.dart';
import 'package:kikoeru_flutter/src/sources/source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_registry.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_service.dart';

class _FakeAdapter implements UnifiedSourceAdapter {
  @override
  final UnifiedSourceKind kind;
  final List<SourceWorkCandidate> candidates;
  final List<dynamic> tracks;
  final bool failSearch;
  final bool failTracks;

  _FakeAdapter({
    required this.kind,
    this.candidates = const [],
    this.tracks = const [],
    this.failSearch = false,
    this.failTracks = false,
  });

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    if (failSearch) throw StateError('search failed');
    return SourceSearchPage(
      items: candidates,
      totalCount: candidates.length,
      hasMore: false,
    );
  }

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async {
    return candidates
        .firstWhere((candidate) => candidate.ref.localId == ref.localId)
        .work;
  }

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async {
    if (failTracks) throw StateError('tracks failed');
    return tracks;
  }

  @override
  Future<UnifiedSourceHealth> checkHealth() async =>
      UnifiedSourceHealth.healthy;
}

SourceWorkCandidate _candidate({
  required UnifiedSourceKind source,
  required int id,
  required String localId,
  required String title,
  String? canonical,
  String? circle,
}) {
  final url = 'https://${source.id}.example/$localId';
  return SourceWorkCandidate(
    work: Work(
      id: id,
      title: title,
      name: circle,
      sourceId: canonical,
      sourceUrl: url,
    ),
    ref: UnifiedSourceRef(
      source: source,
      localId: localId,
      canonicalId: canonical,
      detailUrl: url,
      title: title,
      circle: circle,
    ),
  );
}

void main() {
  test('same canonical id merges into one logical work', () async {
    final registry = UnifiedSourceRegistry.instance..clear();
    final asmr = _candidate(
      source: UnifiedSourceKind.asmrOne,
      id: 101,
      localId: '101',
      title: 'Rainy Night',
      canonical: 'RJ123456',
      circle: 'Circle A',
    );
    final mirror = _candidate(
      source: UnifiedSourceKind.hentaiAsmr,
      id: -202,
      localId: 'RJ123456',
      title: 'Rainy Night',
      canonical: 'RJ123456',
      circle: 'Circle A',
    );

    final service = UnifiedSourceService(
      adapters: [
        _FakeAdapter(kind: UnifiedSourceKind.asmrOne, candidates: [asmr]),
        _FakeAdapter(kind: UnifiedSourceKind.hentaiAsmr, candidates: [mirror]),
      ],
      registry: registry,
    );

    final result = await service.search(keyword: 'rain', page: 1, pageSize: 20);
    expect(result.works, hasLength(1));
    expect(result.works.single.id, 101);
    expect(registry.bundleFor(101)!.sources, hasLength(2));
  });

  test('unknown works without creator are not fuzzily merged by title', () async {
    final registry = UnifiedSourceRegistry.instance..clear();
    final first = _candidate(
      source: UnifiedSourceKind.hentaiAsmr,
      id: -1,
      localId: 'post-a',
      title: 'Same Generic Title',
    );
    final second = _candidate(
      source: UnifiedSourceKind.eroVoice,
      id: -2,
      localId: 'post-b',
      title: 'Same Generic Title',
    );

    final service = UnifiedSourceService(
      adapters: [
        _FakeAdapter(kind: UnifiedSourceKind.hentaiAsmr, candidates: [first]),
        _FakeAdapter(kind: UnifiedSourceKind.eroVoice, candidates: [second]),
      ],
      registry: registry,
    );

    final result = await service.search(keyword: 'same', page: 1, pageSize: 20);
    expect(result.works, hasLength(2));
  });

  test('one broken source does not fail federated search', () async {
    final registry = UnifiedSourceRegistry.instance..clear();
    final candidate = _candidate(
      source: UnifiedSourceKind.asmrOne,
      id: 42,
      localId: '42',
      title: 'Available Work',
      canonical: 'RJ654321',
    );
    final service = UnifiedSourceService(
      adapters: [
        _FakeAdapter(kind: UnifiedSourceKind.asmrOne, candidates: [candidate]),
        _FakeAdapter(kind: UnifiedSourceKind.eroVoice, failSearch: true),
      ],
      registry: registry,
    );

    final result = await service.search(keyword: 'available', page: 1, pageSize: 20);
    expect(result.works, hasLength(1));
    expect(result.health[UnifiedSourceKind.asmrOne], UnifiedSourceHealth.healthy);
    expect(result.health[UnifiedSourceKind.eroVoice], UnifiedSourceHealth.broken);
  });

  test('preferred source failure falls back to next source', () async {
    final registry = UnifiedSourceRegistry.instance..clear();
    final primary = _candidate(
      source: UnifiedSourceKind.asmrOne,
      id: 88,
      localId: '88',
      title: 'Fallback Work',
      canonical: 'RJ777777',
    );
    final fallback = _candidate(
      source: UnifiedSourceKind.hentaiAsmr,
      id: -89,
      localId: 'RJ777777',
      title: 'Fallback Work',
      canonical: 'RJ777777',
    );
    final service = UnifiedSourceService(
      adapters: [
        _FakeAdapter(
          kind: UnifiedSourceKind.asmrOne,
          candidates: [primary],
          failTracks: true,
        ),
        _FakeAdapter(
          kind: UnifiedSourceKind.hentaiAsmr,
          candidates: [fallback],
          tracks: const [
            {
              'title': '01.mp3',
              'type': 'audio',
              'mediaStreamUrl': 'https://cdn.example/01.mp3',
            }
          ],
        ),
      ],
      registry: registry,
    );

    final search = await service.search(keyword: 'fallback', page: 1, pageSize: 20);
    final work = search.works.single;
    final resolved = await service.resolveTracks(
      work,
      preferredSource: UnifiedSourceKind.asmrOne,
    );

    expect(resolved.source.source, UnifiedSourceKind.hentaiAsmr);
    expect(resolved.usedFallback, isTrue);
    final tracks = service.buildAudioTracks(
      work: work,
      resolved: resolved,
      host: 'https://www.asmr.one',
      token: '',
    );
    expect(tracks, hasLength(1));
    expect(tracks.single.url, 'https://cdn.example/01.mp3');
  });
}
