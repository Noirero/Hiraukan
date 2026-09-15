import '../models/work.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';

class UnifiedSourceRegistry {
  UnifiedSourceRegistry._();

  static final UnifiedSourceRegistry instance = UnifiedSourceRegistry._();

  final Map<int, UnifiedWorkBundle> _byWorkId = {};
  final Map<String, UnifiedWorkBundle> _byCanonicalKey = {};

  UnifiedWorkBundle? bundleFor(int workId) => _byWorkId[workId];

  UnifiedWorkBundle? bundleForCanonical(String canonicalKey) =>
      _byCanonicalKey[canonicalKey];

  bool contains(int workId) => _byWorkId.containsKey(workId);

  void register(UnifiedWorkBundle bundle) {
    final existing =
        _byCanonicalKey[bundle.canonicalKey] ?? _byWorkId[bundle.work.id];
    if (existing == null) {
      _store(bundle);
      return;
    }

    final refs = <UnifiedSourceKind, UnifiedSourceRef>{
      for (final ref in existing.sources) ref.source: ref,
      for (final ref in bundle.sources) ref.source: ref,
    };
    final merged = UnifiedWorkBundle(
      work: bundle.work,
      canonicalKey: bundle.canonicalKey,
      sources: refs.values.toList(growable: false)
        ..sort((a, b) => a.source.priority.compareTo(b.source.priority)),
    );

    // Keep old ids as aliases so history written by an earlier development
    // build can still recover the richer canonical bundle.
    _byWorkId[existing.work.id] = merged;
    _byWorkId[bundle.work.id] = merged;
    _byCanonicalKey[bundle.canonicalKey] = merged;
  }

  void registerAll(Iterable<UnifiedWorkBundle> bundles) {
    for (final bundle in bundles) {
      register(bundle);
    }
  }

  /// Recreates enough source metadata for persisted history/library entries to
  /// remain usable after an app restart. A persisted multi-source bundle is
  /// loaded asynchronously by UnifiedSourceService before this fallback is used.
  UnifiedWorkBundle? ensureFromWork(Work work) {
    final canonical = SourceHtmlParser.canonicalMatchKey(
      work.sourceId ?? work.title,
    );
    final canonicalKey = canonical == null ? null : 'id:$canonical';
    final existing = _byWorkId[work.id] ??
        (canonicalKey == null ? null : _byCanonicalKey[canonicalKey]);
    if (existing != null) {
      _byWorkId[work.id] = existing;
      return existing;
    }

    final source = _inferSource(work);
    if (source == null) return null;

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
      canonicalKey: canonicalKey ?? 'source:${source.id}:$localId',
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

  void _store(UnifiedWorkBundle bundle) {
    _byWorkId[bundle.work.id] = bundle;
    _byCanonicalKey[bundle.canonicalKey] = bundle;
  }

  void clear() {
    _byWorkId.clear();
    _byCanonicalKey.clear();
  }
}
