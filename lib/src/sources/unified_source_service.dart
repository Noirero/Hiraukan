import 'dart:async';

import '../models/audio_track.dart';
import '../models/work.dart';
import 'source_adapter.dart';
import 'source_html_parser.dart';
import 'unified_source_models.dart';
import 'unified_source_preferences.dart';
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
    final selected =
        adapters.where((adapter) => enabled.contains(adapter.kind)).toList();
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

    final candidates =
        pages.expand((result) => result.items).toList(growable: false);
    final grouped = <String, List<SourceWorkCandidate>>{};
    for (final candidate in candidates) {
      final key = _canonicalKey(candidate);
      grouped.putIfAbsent(key, () => <SourceWorkCandidate>[]).add(candidate);
    }

    final bundles = <UnifiedWorkBundle>[];
    for (final entry in grouped.entries) {
      bundles.add(_mergeGroup(entry.key, entry.value));
    }

    bundles.sort((a, b) {
      if (a.sources.length != b.sources.length) {
        return b.sources.length.compareTo(a.sources.length);
      }
      final aRelease = a.work.release ?? '';
      final bRelease = b.work.release ?? '';
      return bRelease.compareTo(aRelease);
    });
    registry.registerAll(bundles);

    final hasMore = pages.any((item) => item.hasMore);
    final totalCount = (page - 1) * pageSize +
        bundles.length +
        (hasMore ? pageSize : 0);
    return UnifiedSearchPage(
      works: bundles.map((bundle) => bundle.work).toList(growable: false),
      totalCount: totalCount,
      hasMore: hasMore,
      health: health,
    );
  }

  /// Restores persisted mirrors for a work and remembers the richest bundle
  /// when the user actually opens/plays it.
  Future<UnifiedWorkBundle?> hydrateWork(Work work) async {
    final existing = registry.bundleFor(work.id);
    final cached = await UnifiedSourcePreferences.loadBundle(work);
    if (cached != null) registry.register(cached);

    final merged = registry.bundleFor(work.id) ??
        (cached == null
            ? null
            : registry.bundleForCanonical(cached.canonicalKey));
    if (merged != null) {
      await UnifiedSourcePreferences.saveBundle(merged);
      return merged;
    }

    if (existing != null) {
      await UnifiedSourcePreferences.saveBundle(existing);
      return existing;
    }

    final reconstructed = registry.ensureFromWork(work);
    if (reconstructed != null) {
      await UnifiedSourcePreferences.saveBundle(reconstructed);
    }
    return reconstructed;
  }

  Future<Work> resolveDetail(
    Work work, {
    UnifiedSourceKind? preferredSource,
  }) async {
    final bundle = await hydrateWork(work);
    if (bundle == null) return work;

    Object? lastError;
    final preferredMetadata =
        preferredSource?.canLoadMetadata == true ? preferredSource : null;
    for (final ref in _orderedRefs(bundle.sources, preferredMetadata)) {
      if (!ref.source.canLoadMetadata) continue;
      final adapter = _adapterFor(ref.source);
      if (adapter == null) continue;
      try {
        final detail = await adapter.loadDetail(ref);
        if (_looksLikeProviderInterstitial(detail)) {
          lastError = StateError(
            '${ref.source.label} returned a provider interstitial instead of work metadata',
          );
          continue;
        }
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

    // A catalog result is still useful even when a provider's detail page is
    // blocked by an interstitial. Download-only providers such as EroVoice
    // must not turn the whole detail screen into a fatal error.
    if (bundle.sources.isNotEmpty) {
      return _catalogFallbackDetail(work, bundle);
    }
    throw StateError('No source could load work detail: $lastError');
  }

  Future<ResolvedSourceTracks> resolveTracks(
    Work work, {
    UnifiedSourceKind? preferredSource,
  }) async {
    final bundle = await hydrateWork(work);
    if (bundle == null) {
      throw StateError(
        'Unified source metadata is missing for ${work.displayId}',
      );
    }

    final playable = bundle.playableSources;
    if (playable.isEmpty) {
      throw StateError('This work has no in-app playback source');
    }

    final playablePreferred = preferredSource?.canPlay == true
        ? preferredSource
        : null;
    Object? lastError;
    var attempted = 0;
    for (final ref in _orderedRefs(playable, playablePreferred)) {
      attempted++;
      final adapter = _adapterFor(ref.source);
      if (adapter == null) continue;
      try {
        final files = await adapter.loadTracks(ref);
        if (files.isEmpty) {
          lastError = StateError(
            '${ref.source.label} returned no playable tracks',
          );
          continue;
        }
        return ResolvedSourceTracks(
          source: ref,
          files: files,
          usedFallback:
              (playablePreferred != null && ref.source != playablePreferred) ||
                  attempted > 1,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError(
      'No playable source is currently available: $lastError',
    );
  }

  /// Resolves raw downloadable files independently from playback. This is used
  /// by download-only providers (currently EroVoice) without ever adding them
  /// to the audio fallback chain.
  Future<ResolvedSourceDownloads> resolveDownloads(
    Work work, {
    UnifiedSourceKind? preferredSource,
  }) async {
    final bundle = await hydrateWork(work);
    if (bundle == null) {
      throw StateError(
        'Unified source metadata is missing for ${work.displayId}',
      );
    }

    final downloadable = bundle.downloadSources;
    if (downloadable.isEmpty) {
      throw StateError('This work has no downloadable source');
    }

    final downloadPreferred = preferredSource?.canDownload == true
        ? preferredSource
        : null;
    Object? lastError;
    for (final ref in _orderedRefs(downloadable, downloadPreferred)) {
      final adapter = _adapterFor(ref.source);
      if (adapter == null) continue;
      try {
        final files = await adapter.loadTracks(ref);
        if (files.isEmpty) {
          lastError = StateError(
            '${ref.source.label} returned no downloadable files',
          );
          continue;
        }
        return ResolvedSourceDownloads(source: ref, files: files);
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError(
      'No downloadable files are currently available: $lastError',
    );
  }

  List<AudioTrack> buildAudioTracks({
    required Work work,
    required ResolvedSourceTracks resolved,
    required String host,
    required String token,
  }) {
    if (!resolved.source.source.canPlay) return const [];

    final flattened = <Map<String, dynamic>>[];

    void visit(List<dynamic> files) {
      for (final raw in files) {
        if (raw is! Map) continue;
        final file = Map<String, dynamic>.from(raw);
        final children = file['children'];
        if (children is List) visit(children);
        final type = file['type']?.toString().toLowerCase();
        if (type == 'folder') continue;
        final title =
            file['title']?.toString() ?? file['name']?.toString() ?? '';
        final lower = title.toLowerCase();
        final looksAudio = type == 'audio' ||
            lower.endsWith('.mp3') ||
            lower.endsWith('.m4a') ||
            lower.endsWith('.aac') ||
            lower.endsWith('.ogg') ||
            lower.endsWith('.opus') ||
            lower.endsWith('.wav') ||
            lower.endsWith('.flac') ||
            lower.endsWith('.wma') ||
            lower.endsWith('.m4b');
        if (looksAudio) flattened.add(file);
      }
    }

    visit(resolved.files);
    final normalizedHost = host.isEmpty || host.startsWith('http')
        ? host
        : 'https://$host';
    final bundle = registry.bundleFor(work.id);
    final artwork = bundle?.coverUrl ??
        (normalizedHost.isEmpty
            ? null
            : work.getCoverImageUrl(normalizedHost, token: token));

    final tracks = <AudioTrack>[];
    for (final entry in flattened.asMap().entries) {
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
        url = '$normalizedHost/api/media/stream/$hash';
      }
      if (url == null || url.isEmpty) continue;
      url = _resolveTrackUrl(
        url,
        source: resolved.source.source,
        normalizedHost: normalizedHost,
        token: token,
      );
      if (url == null) continue;

      final durationValue = file['duration'];
      final durationSeconds =
          durationValue is num ? durationValue.toDouble() : null;
      final title = file['title']?.toString() ??
          file['name']?.toString() ??
          SourceHtmlParser.basenameFromUrl(url, entry.key);
      final identity = hash ??
          '${resolved.source.source.id}:${resolved.source.localId}:${entry.key}';
      tracks.add(
        AudioTrack(
          id: identity,
          title: title,
          url: url,
          artist: work.name,
          album: work.title,
          artworkUrl: artwork,
          duration: durationSeconds == null
              ? null
              : Duration(
                  milliseconds: (durationSeconds * 1000).round(),
                ),
          workId: work.id,
          hash: hash ?? identity,
          sourcePath: resolved.source.detailUrl,
        ),
      );
    }
    return tracks;
  }

  String? _resolveTrackUrl(
    String rawUrl, {
    required UnifiedSourceKind source,
    required String normalizedHost,
    required String token,
  }) {
    var url = rawUrl.trim();
    if (url.isEmpty) return null;

    if (source == UnifiedSourceKind.asmrOne) {
      if (url.startsWith('/')) {
        if (normalizedHost.isEmpty) return null;
        url = '$normalizedHost$url';
      }
      if (token.isNotEmpty && !url.contains('token=')) {
        url = url.contains('?') ? '$url&token=$token' : '$url?token=$token';
      }
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https' && uri.scheme != 'file') {
      return null;
    }
    return url;
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
    final copy = [...refs]
      ..sort((a, b) => a.source.priority.compareTo(b.source.priority));
    if (preferred != null) {
      for (final ref in copy) {
        if (ref.source == preferred) yield ref;
      }
    }
    for (final ref in copy) {
      if (ref.source != preferred) yield ref;
    }
  }

  Work _catalogFallbackDetail(Work work, UnifiedWorkBundle bundle) {
    final primary = bundle.sources.isEmpty ? null : bundle.sources.first;
    final images = bundle.coverUrl == null ? work.images : [bundle.coverUrl!];
    return work.copyWith(
      images: images,
      sourceId: work.sourceId ?? primary?.canonicalId,
      sourceUrl: primary?.detailUrl ?? work.sourceUrl,
    );
  }

  bool _looksLikeProviderInterstitial(Work detail) {
    final title = SourceHtmlParser.stripTags(detail.title)
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty) return false;
    return title == 'sensitive content warning' ||
        title == 'content warning' ||
        title == 'blogger' ||
        title.contains('sensitive content warning') ||
        title.contains('this blog may contain sensitive content') ||
        title.contains('before you continue');
  }

  String _canonicalKey(SourceWorkCandidate candidate) {
    final canonical = SourceHtmlParser.canonicalMatchKey(
      candidate.ref.canonicalId ??
          candidate.work.sourceId ??
          candidate.work.title,
    );
    if (canonical != null) return 'id:$canonical';

    return 'source:${candidate.ref.source.id}:${candidate.ref.localId}';
  }

  int _stableWorkId(String canonicalKey) {
    if (canonicalKey.startsWith('id:')) {
      return SourceHtmlParser.stableUnifiedWorkId(canonicalKey.substring(3));
    }
    return SourceHtmlParser.stableNegativeId('unified:$canonicalKey');
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

    String? canonical;
    for (final ref in refs) {
      final value = ref.canonicalId;
      if (value != null && value.isNotEmpty) {
        canonical = value;
        break;
      }
    }

    String? cover;
    for (final ref in refs) {
      final value = ref.coverUrl;
      if (value != null && value.isNotEmpty) {
        cover = value;
        break;
      }
    }

    int? duration;
    for (final ref in refs) {
      if (ref.durationSeconds != null) {
        duration = ref.durationSeconds;
        break;
      }
    }

    final primaryWork = primary.work;
    final work = primaryWork.copyWith(
      id: _stableWorkId(key),
      sourceId: canonical ?? primaryWork.sourceId,
      sourceUrl: primary.ref.detailUrl,
      images: primaryWork.images ?? (cover == null ? null : [cover]),
      duration: primaryWork.duration ?? duration,
    );
    return UnifiedWorkBundle(
      work: work,
      canonicalKey: key,
      sources: refs,
    );
  }
}
