import 'dart:async';

import '../models/audio_track.dart';
import '../models/work.dart';
import 'source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';
import 'unified_source_registry.dart';

class UnifiedSourceService {
  final List<UnifiedSourceAdapter> adapters;
  final UnifiedSourceRegistry registry;

  const UnifiedSourceService({
    required this.adapters,
    required this.registry,
  });

  Future<UnifiedSearchPage> search({
    required String keyword,
    required int page,
    required int pageSize,
    Set<UnifiedSourceKind>? enabledSources,
  }) async {
    final enabled = enabledSources ?? UnifiedSourceKind.values.toSet();
    final selected = adapters.where((adapter) => enabled.contains(adapter.kind)).toList();
    final health = <UnifiedSourceKind, UnifiedSourceHealth>{};
    final pages = <SourceSearchPage>[];

    await Future.wait(selected.map((adapter) async {
      try {
        final result = await adapter.search(
          keyword: keyword,
          page: page,
          pageSize: pageSize,
        );
        pages.add(result);
        health[adapter.kind] = UnifiedSourceHealth.healthy;
      } catch (_) {
        health[adapter.kind] = UnifiedSourceHealth.broken;
      }
    }));

    for (final source in UnifiedSourceKind.values) {
      health.putIfAbsent(source, () => UnifiedSourceHealth.unknown);
    }

    final candidates = pages.expand((page) => page.items).toList(growable: false);
    final grouped = <String, List<SourceWorkCandidate>>{};
    for (final candidate in candidates) {
      final key = _canonicalKey(candidate);
      grouped.putIfAbsent(key, () => <SourceWorkCandidate>[]).add(candidate);
    }

    final bundles = <UnifiedWorkBundle>[];
    for (final entry in grouped.entries) {
      final bundle = _mergeGroup(entry.key, entry.value);
      bundles.add(bundle);
    }

    bundles.sort((a, b) {
      final aSources = a.sources.length;
      final bSources = b.sources.length;
      if (aSources != bSources) return bSources.compareTo(aSources);
      final aRelease = a.work.release ?? '';
      final bRelease = b.work.release ?? '';
      return bRelease.compareTo(aRelease);
    });
    registry.registerAll(bundles);

    final totalCount = pages.fold<int>(0, (sum, item) => sum + item.totalCount);
    final hasMore = pages.any((item) => item.hasMore);
    return UnifiedSearchPage(
      works: bundles.map((bundle) => bundle.work).toList(growable: false),
      totalCount: totalCount,
      hasMore: hasMore,
      health: health,
    );
  }

  Future<Work> resolveDetail(
    Work work, {
    UnifiedSourceKind? preferredSource,
  }) async {
    final bundle = registry.bundleFor(work.id);
    if (bundle == null) return work;

    Object? lastError;
    for (final ref in _orderedRefs(bundle.sources, preferredSource)) {
      final adapter = _adapterFor(ref.source);
      if (adapter == null) continue;
      try {
        final detail = await adapter.loadDetail(ref);
        final cover = detail.images?.isNotEmpty == true
            ? detail.images
            : bundle.coverUrl == null
                ? work.images
                : [bundle.coverUrl!];
        return detail.copyWith(
          id: work.id,
          title: detail.title.isEmpty ? work.title : detail.title,
          name: detail.name ?? work.name,
          duration: detail.duration ?? work.duration,
          images: cover,
          sourceId: work.sourceId ?? ref.canonicalId,
          sourceUrl: ref.detailUrl,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('No source could load work detail: $lastError');
  }

  Future<ResolvedSourceTracks> resolveTracks(
    Work work, {
    UnifiedSourceKind? preferredSource,
  }) async {
    final bundle = registry.bundleFor(work.id);
    if (bundle == null) {
      throw StateError('Unified source metadata is missing for ${work.displayId}');
    }

    Object? lastError;
    var attempted = 0;
    for (final ref in _orderedRefs(bundle.sources, preferredSource)) {
      attempted++;
      final adapter = _adapterFor(ref.source);
      if (adapter == null) continue;
      try {
        final files = await adapter.loadTracks(ref);
        if (files.isEmpty) {
          lastError = StateError('${ref.source.label} returned no playable tracks');
          continue;
        }
        return ResolvedSourceTracks(
          source: ref,
          files: files,
          usedFallback: preferredSource != null && ref.source != preferredSource || attempted > 1,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('No playable source is currently available: $lastError');
  }

  List<AudioTrack> buildAudioTracks({
    required Work work,
    required ResolvedSourceTracks resolved,
    required String host,
    required String token,
  }) {
    final flattened = <Map<String, dynamic>>[];
    void visit(List<dynamic> files) {
      for (final raw in files) {
        if (raw is! Map) continue;
        final file = Map<String, dynamic>.from(raw);
        final children = file['children'];
        if (children is List) visit(children);
        final type = file['type']?.toString().toLowerCase();
        if (type == 'folder') continue;
        final title = file['title']?.toString() ?? file['name']?.toString() ?? '';
        final lower = title.toLowerCase();
        final looksAudio = type == 'audio' ||
            lower.endsWith('.mp3') ||
            lower.endsWith('.m4a') ||
            lower.endsWith('.aac') ||
            lower.endsWith('.ogg') ||
            lower.endsWith('.opus') ||
            lower.endsWith('.wav') ||
            lower.endsWith('.flac');
        if (looksAudio) flattened.add(file);
      }
    }

    visit(resolved.files);
    final normalizedHost = host.isEmpty || host.startsWith('http') ? host : 'https://$host';
    final bundle = registry.bundleFor(work.id);
    final artwork = bundle?.coverUrl ??
        (normalizedHost.isEmpty ? null : work.getCoverImageUrl(normalizedHost, token: token));

    return flattened.asMap().entries.map((entry) {
      final file = entry.value;
      final hash = file['hash']?.toString();
      var url = file['mediaStreamUrl']?.toString() ??
          file['mediaDownloadUrl']?.toString() ??
          file['url']?.toString();
      if ((url == null || url.isEmpty) &&
          hash != null &&
          hash.isNotEmpty &&
          normalizedHost.isNotEmpty &&
          resolved.source.source == UnifiedSourceKind.asmrOne) {
        url = '$normalizedHost/api/media/stream/$hash?token=$token';
      }
      if (url == null || url.isEmpty) {
        throw StateError('Track ${file['title'] ?? entry.key} has no playable URL');
      }
      final durationValue = file['duration'];
      final durationSeconds = durationValue is num ? durationValue.toDouble() : null;
      final title = file['title']?.toString() ??
          file['name']?.toString() ??
          SourceHtmlParser.basenameFromUrl(url, entry.key);
      final identity = hash ?? '${resolved.source.source.id}:${resolved.source.localId}:${entry.key}';
      return AudioTrack(
        id: identity,
        title: title,
        url: url,
        artist: work.name,
        album: work.title,
        artworkUrl: artwork,
        duration: durationSeconds == null
            ? null
            : Duration(milliseconds: (durationSeconds * 1000).round()),
        workId: work.id,
        hash: hash ?? identity,
        sourcePath: resolved.source.detailUrl,
      );
    }).toList(growable: false);
  }

  Future<Map<UnifiedSourceKind, UnifiedSourceHealth>> checkHealth() async {
    final result = <UnifiedSourceKind, UnifiedSourceHealth>{};
    await Future.wait(adapters.map((adapter) async {
      try {
        result[adapter.kind] = await adapter.checkHealth();
      } catch (_) {
        result[adapter.kind] = UnifiedSourceHealth.broken;
      }
    }));
    return result;
  }

  UnifiedSourceAdapter? _adapterFor(UnifiedSourceKind source) {
    for (final adapter in adapters) {
      if (adapter.kind == source) return adapter;
    }
    return null;
  }

  Iterable<UnifiedSourceRef> _orderedRefs(
    List<UnifiedSourceRef> refs,
    UnifiedSourceKind? preferred,
  ) sync* {
    final copy = [...refs]..sort((a, b) => a.source.priority.compareTo(b.source.priority));
    if (preferred != null) {
      for (final ref in copy) {
        if (ref.source == preferred) yield ref;
      }
    }
    for (final ref in copy) {
      if (ref.source != preferred) yield ref;
    }
  }

  String _canonicalKey(SourceWorkCandidate candidate) {
    final canonical = candidate.ref.canonicalId ??
        SourceHtmlParser.extractCanonicalId(candidate.work.sourceId) ??
        SourceHtmlParser.extractCanonicalId(candidate.work.title);
    if (canonical != null) return 'id:${canonical.toUpperCase()}';

    final title = _normalize(candidate.work.title);
    final circle = _normalize(candidate.work.name ?? candidate.ref.circle ?? '');
    if (title.isNotEmpty && circle.isNotEmpty) return 'meta:$title|$circle';

    // Avoid false merges when the canonical product id and creator are unknown.
    return 'source:${candidate.ref.source.id}:${candidate.ref.localId}';
  }

  UnifiedWorkBundle _mergeGroup(
    String key,
    List<SourceWorkCandidate> candidates,
  ) {
    final sorted = [...candidates]
      ..sort((a, b) => a.ref.source.priority.compareTo(b.ref.source.priority));
    final primary = sorted.first;
    final refs = <UnifiedSourceRef>[];
    final seenSource = <UnifiedSourceKind>{};
    for (final candidate in sorted) {
      if (seenSource.add(candidate.ref.source)) refs.add(candidate.ref);
    }

    final canonical = refs
        .map((ref) => ref.canonicalId)
        .whereType<String>()
        .cast<String?>()
        .firstWhere((value) => value != null && value.isNotEmpty, orElse: () => null);
    String? cover;
    for (final ref in refs) {
      if (ref.coverUrl != null && ref.coverUrl!.isNotEmpty) {
        cover = ref.coverUrl;
        break;
      }
    }
    final primaryWork = primary.work;
    final work = primaryWork.copyWith(
      sourceId: canonical ?? primaryWork.sourceId,
      sourceUrl: primary.ref.detailUrl,
      images: primaryWork.images ?? (cover == null ? null : [cover]),
      duration: primaryWork.duration ?? refs.map((ref) => ref.durationSeconds).whereType<int>().firstOrNull,
    );
    return UnifiedWorkBundle(work: work, canonicalKey: key, sources: refs);
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u3040-\u30ff\u3400-\u9fff]+'), '')
      .trim();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
