import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/work.dart';
import 'package:kikoeru_flutter/src/sources/source_adapter.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_registry.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CandidateAdapter implements UnifiedSourceAdapter {
  @override
  final UnifiedSourceKind kind;
  final SourceWorkCandidate candidate;

  _CandidateAdapter(this.kind, this.candidate);

  @override
  Future<SourceSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async =>
      SourceSearchPage(items: [candidate], totalCount: 1, hasMore: false);

  @override
  Future<Work> loadDetail(UnifiedSourceRef ref) async => candidate.work;

  @override
  Future<List<dynamic>> loadTracks(UnifiedSourceRef ref) async => const [];

  @override
  Future<UnifiedSourceHealth> checkHealth() async =>
      UnifiedSourceHealth.healthy;
}

SourceWorkCandidate _candidate({
  required UnifiedSourceKind source,
  required int id,
  required String localId,
  required String title,
  required String circle,
}) {
  final url = 'https://${source.id}.example/$localId';
  return SourceWorkCandidate(
    work: Work(
      id: id,
      title: title,
      name: circle,
      sourceUrl: url,
    ),
    ref: UnifiedSourceRef(
      source: source,
      localId: localId,
      detailUrl: url,
      title: title,
      circle: circle,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UnifiedSourceRegistry.instance.clear();
  });

  test('matching title and circle do not merge without canonical identity',
      () async {
    final first = _candidate(
      source: UnifiedSourceKind.hentaiAsmr,
      id: -1001,
      localId: 'post-a',
      title: 'Same Work Name',
      circle: 'Same Circle',
    );
    final second = _candidate(
      source: UnifiedSourceKind.eroVoice,
      id: -1002,
      localId: 'post-b',
      title: 'Same Work Name',
      circle: 'Same Circle',
    );

    final service = UnifiedSourceService(
      adapters: [
        _CandidateAdapter(UnifiedSourceKind.hentaiAsmr, first),
        _CandidateAdapter(UnifiedSourceKind.eroVoice, second),
      ],
      registry: UnifiedSourceRegistry.instance,
    );

    final result = await service.search(
      keyword: 'same work',
      page: 1,
      pageSize: 20,
    );

    expect(result.works, hasLength(2));
    expect(result.works.map((work) => work.id).toSet(), hasLength(2));
  });
}
