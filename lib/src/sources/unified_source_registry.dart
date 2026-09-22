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
    final normalized = _normalizeCanonicalWork(bundle);
    final existing = _byCanonicalKey[normalized.canonicalKey] ??
        _byWorkId[normalized.work.id] ??
        _byWorkId[bundle.work.id];
    if (existing == null) {
      _store(normalized, aliases: [bundle.work.id]);
      return;
    }

    final refs = <UnifiedSourceKind, UnifiedSourceRef>{
      for (final ref in existing.sources) ref.source: ref,
      for (final ref in normalized.sources) ref.source: ref,
    };
    final merged = UnifiedWorkBundle(
      work: normalized.work,
      canonicalKey: normalized.canonicalKey,
      sources: refs.values.toList(growable: false)
        ..sort((a, b) => a.source.priority.compareTo(b.source.priority)),
    );

    // Keep previous/development ids as aliases while canonical RJ identity is
    // used by new unified results and persistent state.
    _byWorkId[existing.work.id] = merged;
    _byWorkId[bundle.work.id] = merged;
    _byWorkId[merged.work.id] = merged;
    _byCanonicalKey[merged.canonicalKey] = merged;
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
      UnifiedSourceKind.hentaiAsmr ||
      UnifiedSourceKind.japaneseAsmr ||
      UnifiedSourceKind.asmr18 ||
      UnifiedSourceKind.eroVoice ||
      UnifiedSourceKind.asmrHentaiNet =>
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
    return _byWorkId[work.id] ??
        (canonicalKey == null ? null : _byCanonicalKey[canonicalKey]);
  }

  UnifiedSourceKind? _inferSource(Work work) {
    final url = work.sourceUrl;
    final host = url == null ? '' : Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('hentaiasmr.moe')) {
      return UnifiedSourceKind.hentaiAsmr;
    }
    if (host.contains('japaneseasmr.com')) {
      return UnifiedSourceKind.japaneseAsmr;
    }
    if (host.contains('asmr18.fans')) {
      return UnifiedSourceKind.asmr18;
    }
    if (host.contains('asmrhentai.net')) {
      return UnifiedSourceKind.asmrHentaiNet;
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
      UnifiedSourceKind.japaneseAsmr => null,
      UnifiedSourceKind.asmr18 => work.sourceId == null
          ? null
          : 'https://asmr18.fans/boys/' +
              work.sourceId!.toLowerCase() +
              '/',
      UnifiedSourceKind.eroVoice => null,
      UnifiedSourceKind.asmrHentaiNet => null,
    };
  }

  UnifiedWorkBundle _normalizeCanonicalWork(UnifiedWorkBundle bundle) {
    if (!bundle.canonicalKey.startsWith('id:')) return bundle;
    final stableId = SourceHtmlParser.stableUnifiedWorkId(
      bundle.canonicalKey.substring(3),
    );
    if (bundle.work.id == stableId) return bundle;
    return UnifiedWorkBundle(
      work: bundle.work.copyWith(id: stableId),
      canonicalKey: bundle.canonicalKey,
      sources: bundle.sources,
    );
  }

  void _store(UnifiedWorkBundle bundle, {Iterable<int> aliases = const []}) {
    _byWorkId[bundle.work.id] = bundle;
    for (final alias in aliases) {
      _byWorkId[alias] = bundle;
    }
    _byCanonicalKey[bundle.canonicalKey] = bundle;
  }

  void clear() {
    _byWorkId.clear();
    _byCanonicalKey.clear();
  }
}
