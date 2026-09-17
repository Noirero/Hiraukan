import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/work.dart';
import 'package:kikoeru_flutter/src/sources/source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_registry.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements UnifiedSourceAdapter {
  @override
  final UnifiedSourceKind kind;
  final List<SourceWorkCandidate> candidates;
  final List<dynamic> tracks;
  int trackLoadCalls = 0;

  _Adapter({
    required this.kind,
    required this.candidates,
    this.tracks = const [],
  });

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
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
    trackLoadCalls++;
    return tracks;
  }

  @override
  Future<UnifiedSourceHealth> checkHealth() async =>
      UnifiedSourceHealth.healthy;
}

SourceWorkCandidate _candidate(UnifiedSourceKind source, String localId) {
  const canonical = 'RJ123456';
  return SourceWorkCandidate(
    work: Work(
      id: source == UnifiedSourceKind.asmrOne ? 123456 : -123456,
      title: 'Capability Work',
      sourceId: canonical,
      sourceUrl: 'https://${source.id}.example/$localId',
    ),
    ref: UnifiedSourceRef(
      source: source,
      localId: localId,
      canonicalId: canonical,
      detailUrl: 'https://${source.id}.example/$localId',
      title: 'Capability Work',
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UnifiedSourceRegistry.instance.clear();
  });

  test('non-playback preferred source is skipped and playable mirror is used',
      () async {
    final erovoice = _Adapter(
      kind: UnifiedSourceKind.eroVoice,
      candidates: [_candidate(UnifiedSourceKind.eroVoice, 'RJ123456')],
      tracks: const [
        {
          'title': 'should-not-be-used.mp3',
          'type': 'audio',
          'mediaStreamUrl': 'https://ero.example/should-not-be-used.mp3',
        }
      ],
    );
    final asmr = _Adapter(
      kind: UnifiedSourceKind.asmrOne,
      candidates: [_candidate(UnifiedSourceKind.asmrOne, '123456')],
      tracks: const [
        {
          'title': '01.mp3',
          'type': 'audio',
          'hash': 'hash-01',
          'mediaStreamUrl': 'https://cdn.example/01.mp3',
        }
      ],
    );
    final service = UnifiedSourceService(
      adapters: [erovoice, asmr],
      registry: UnifiedSourceRegistry.instance,
    );

    final search = await service.search(
      keyword: 'capability',
      page: 1,
      pageSize: 20,
    );
    final work = search.works.single;
    final resolved = await service.resolveTracks(
      work,
      preferredSource: UnifiedSourceKind.eroVoice,
    );

    expect(erovoice.trackLoadCalls, 0);
    expect(resolved.source.source, UnifiedSourceKind.asmrOne);
    expect(resolved.usedFallback, isTrue);

    final tracks = service.buildAudioTracks(
      work: work,
      resolved: resolved,
      host: 'https://www.asmr.one',
      token: '',
    );
    expect(tracks, hasLength(1));
    expect(tracks.single.sourceKey, 'asmr_one');
    expect(tracks.single.sourceWorkId, '123456');
  });

  test('non-playback-only work is a capability condition, not source failure',
      () async {
    final erovoice = _Adapter(
      kind: UnifiedSourceKind.eroVoice,
      candidates: [_candidate(UnifiedSourceKind.eroVoice, 'RJ123456')],
    );
    final service = UnifiedSourceService(
      adapters: [erovoice],
      registry: UnifiedSourceRegistry.instance,
    );

    final search = await service.search(
      keyword: 'capability',
      page: 1,
      pageSize: 20,
    );

    try {
      await service.resolveTracks(search.works.single);
      fail('Expected SourcePlaybackUnavailableException');
    } on SourcePlaybackUnavailableException catch (error) {
      expect(error.unsupportedOnly, isTrue);
      expect(error.sources, contains(UnifiedSourceKind.eroVoice));
      expect(erovoice.trackLoadCalls, 0);
    }
  });
}
