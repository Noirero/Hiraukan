import '../models/work.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class UnifiedSourceRegistry {
  UnifiedSourceRegistry._();

  static final UnifiedSourceRegistry instance = UnifiedSourceRegistry._();

  final Map<int, UnifiedWorkBundle> _byWorkId = {};

  UnifiedWorkBundle? bundleFor(int workId) => _byWorkId[workId];

  bool contains(int workId) => _byWorkId.containsKey(workId);

  void register(UnifiedWorkBundle bundle) {
    _byWorkId[bundle.work.id] = bundle;
  }

  void registerAll(Iterable<UnifiedWorkBundle> bundles) {
    for (final bundle in bundles) {
      register(bundle);
    }
  }

  /// Recreates enough source metadata for persisted history/library entries to
  /// remain usable after an app restart. This intentionally restores only the
  /// source represented by the persisted Work; a later federated search can
  /// enrich the same work with additional mirrors again.
  UnifiedWorkBundle? ensureFromWork(Work work) {
    final existing = _byWorkId[work.id];
    if (existing != null) return existing;

    final source = _inferSource(work);
    if (source == null) return null;

    final canonical = SourceHtmlParser.extractCanonicalId(
      work.sourceId ?? work.title,
    );
    final detailUrl = work.sourceUrl ?? _defaultDetailUrl(source, work);
    if (detailUrl == null || detailUrl.isEmpty) return null;

    final localId = switch (source) {
      UnifiedSourceKind.asmrOne => work.id.toString(),
      UnifiedSourceKind.hentaiAsmr || UnifiedSourceKind.eroVoice =>
        canonical ?? detailUrl,
    };
    final cover = work.images?.isNotEmpty == true ? work.images!.first : null;
    final ref = UnifiedSourceRef(
      source: source,
      localId: localId,
      canonicalId: canonical,
      detailUrl: detailUrl,
      coverUrl: cover,
      title: work.title,
      circle: work.name,
      durationSeconds: work.duration,
    );
    final bundle = UnifiedWorkBundle(
      work: work,
      canonicalKey: canonical == null
          ? 'source:${source.id}:$localId'
          : 'id:${SourceHtmlParser.canonicalMatchKey(canonical) ?? canonical}',
      sources: [ref],
    );
    register(bundle);
    return bundle;
  }

  UnifiedSourceKind? _inferSource(Work work) {
    final url = work.sourceUrl;
    final host = url == null ? '' : Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('hentaiasmr.moe')) {
      return UnifiedSourceKind.hentaiAsmr;
    }
    if (host.contains('erovoice.us')) {
      return UnifiedSourceKind.eroVoice;
    }
    if (host.contains('asmr.one')) {
      return UnifiedSourceKind.asmrOne;
    }

    // Existing Kikoeru/ASMR.one works use positive backend IDs. External-only
    // results deliberately use negative IDs, so this is a safe last fallback.
    if (work.id > 0) return UnifiedSourceKind.asmrOne;
    return null;
  }

  String? _defaultDetailUrl(UnifiedSourceKind source, Work work) {
    return switch (source) {
      UnifiedSourceKind.asmrOne =>
        'https://www.asmr.one/work/${work.sourceId ?? work.id}',
      UnifiedSourceKind.hentaiAsmr => work.sourceId == null
          ? null
          : 'https://hentaiasmr.moe/${work.sourceId!.toLowerCase()}.html',
      UnifiedSourceKind.eroVoice => null,
    };
  }

  void clear() => _byWorkId.clear();
}
