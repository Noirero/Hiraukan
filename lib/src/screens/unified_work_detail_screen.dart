import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/audio_track.dart';
import '../models/work.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/subtitle_controller_provider.dart';
import '../sources/unified_source_models.dart';
import '../sources/unified_source_preferences.dart';
import '../sources/unified_source_provider.dart';
import '../sources/unified_source_registry.dart';
import '../services/track_playback_progress_store.dart';
import '../widgets/global_audio_player_wrapper.dart';

class UnifiedWorkDetailScreen extends ConsumerStatefulWidget {
  final Work work;

  const UnifiedWorkDetailScreen({super.key, required this.work});

  @override
  ConsumerState<UnifiedWorkDetailScreen> createState() =>
      _UnifiedWorkDetailScreenState();
}

class _UnifiedWorkDetailScreenState
    extends ConsumerState<UnifiedWorkDetailScreen> {
  Work? _detail;
  UnifiedWorkBundle? _hydratedBundle;
  ResolvedSourceTracks? _resolved;
  ResolvedSourceDownloads? _resolvedDownloads;
  List<AudioTrack> _tracks = const [];
  List<_DownloadEntry> _downloadEntries = const [];
  Map<UnifiedSourceKind, UnifiedSourceHealth> _health = const {};
  UnifiedSourceKind? _preferredSource;
  bool _loadingDetail = true;
  bool _loadingTracks = true;
  bool _loadingDownloads = false;
  String? _detailError;
  String? _trackError;
  String? _downloadError;
  Map<String, TrackPlaybackProgress> _trackProgress = const {};
  StreamSubscription<String>? _trackProgressSubscription;

  UnifiedWorkBundle? get _bundle => _hydratedBundle ??
      UnifiedSourceRegistry.instance.bundleFor(widget.work.id) ??
      UnifiedSourceRegistry.instance.ensureFromWork(widget.work);

  @override
  void initState() {
    super.initState();
    _trackProgressSubscription =
        TrackPlaybackProgressStore.instance.changes.listen((identity) {
      final relevant = _tracks.any(
        (track) =>
            TrackPlaybackProgressStore.instance.identityFor(track) == identity,
      );
      if (relevant) unawaited(_reloadTrackProgress());
    });
    _restorePreferenceAndLoad();
    _refreshHealth();
  }

  @override
  void dispose() {
    _trackProgressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restorePreferenceAndLoad() async {
    final service = ref.read(unifiedSourceServiceProvider);
    final bundle = await service.hydrateWork(widget.work);
    var preferred = await UnifiedSourcePreferences.loadPreferredSource();

    // Preferences from older builds may contain EroVoice. Playback preference
    // is now capability-aware, so a download-only source can never be selected
    // as a player or fallback.
    final preferredIsPlayable = preferred != null &&
        preferred.canPlay &&
        (bundle?.playableSources.any((ref) => ref.source == preferred) ?? false);
    if (preferred != null && !preferredIsPlayable) {
      preferred = null;
      await UnifiedSourcePreferences.savePreferredSource(null);
    }

    if (!mounted) return;
    setState(() {
      _hydratedBundle = bundle;
      _preferredSource = preferred;
    });
    await _loadContent();
  }

  Future<void> _loadContent() async {
    final bundle = _bundle;
    final futures = <Future<void>>[_loadDetail(), _loadTracks()];
    if (bundle?.downloadOnlySources.isNotEmpty == true) {
      futures.add(_loadDownloads());
    }
    await Future.wait<void>(futures);
  }

  Future<void> _loadDetail() async {
    if (mounted) {
      setState(() {
        _loadingDetail = true;
        _detailError = null;
      });
    }
    try {
      final detail = await ref.read(unifiedSourceServiceProvider).resolveDetail(
            widget.work,
            preferredSource: _preferredSource,
          );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _hydratedBundle =
            UnifiedSourceRegistry.instance.bundleFor(widget.work.id) ??
                _hydratedBundle;
        _loadingDetail = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _detailError = error.toString();
        _loadingDetail = false;
      });
    }
  }

  Future<void> _loadTracks() async {
    final bundle = _bundle;
    if (bundle?.canPlay != true) {
      if (!mounted) return;
      setState(() {
        _resolved = null;
        _tracks = const [];
        _trackProgress = const {};
        _trackError = null;
        _loadingTracks = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingTracks = true;
        _trackError = null;
        _tracks = const [];
        _trackProgress = const {};
      });
    }
    try {
      final service = ref.read(unifiedSourceServiceProvider);
      final resolved = await service.resolveTracks(
        widget.work,
        preferredSource: _preferredSource,
      );
      final auth = ref.read(authProvider);
      final tracks = service.buildAudioTracks(
        work: _detail ?? widget.work,
        resolved: resolved,
        host: auth.host ?? '',
        token: auth.token ?? '',
      );
      if (tracks.isEmpty) {
        throw StateError(
          '${resolved.source.source.label} returned no playable audio tracks',
        );
      }
      if (!mounted) return;
      setState(() {
        _resolved = resolved;
        _hydratedBundle =
            UnifiedSourceRegistry.instance.bundleFor(widget.work.id) ??
                _hydratedBundle;
        _tracks = tracks;
        _loadingTracks = false;
      });
      await _reloadTrackProgress(tracks);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _trackError = error.toString();
        _loadingTracks = false;
      });
    }
  }

  Future<void> _reloadTrackProgress([Iterable<AudioTrack>? tracks]) async {
    final targetTracks = (tracks ?? _tracks).toList(growable: false);
    if (targetTracks.isEmpty) {
      if (mounted) setState(() => _trackProgress = const {});
      return;
    }
    final progress =
        await TrackPlaybackProgressStore.instance.loadForTracks(targetTracks);
    if (!mounted) return;
    setState(() => _trackProgress = progress);
  }

  Future<void> _loadDownloads() async {
    final bundle = _bundle;
    final downloadOnly = bundle?.downloadOnlySources ?? const [];
    if (downloadOnly.isEmpty) {
      if (!mounted) return;
      setState(() {
        _resolvedDownloads = null;
        _downloadEntries = const [];
        _downloadError = null;
        _loadingDownloads = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingDownloads = true;
        _downloadError = null;
        _downloadEntries = const [];
      });
    }

    try {
      final source = downloadOnly.first.source;
      final resolved = await ref.read(unifiedSourceServiceProvider).resolveDownloads(
            widget.work,
            preferredSource: source,
          );
      final entries = _extractDownloadEntries(resolved.files);
      if (!mounted) return;
      setState(() {
        _resolvedDownloads = resolved;
        _downloadEntries = entries;
        _loadingDownloads = false;
        if (entries.isEmpty) {
          _downloadError = 'File unduhan belum dapat dibaca otomatis.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolvedDownloads = null;
        _downloadEntries = const [];
        _downloadError = 'File unduhan belum dapat dibaca otomatis.';
        _loadingDownloads = false;
      });
    }
  }

  List<_DownloadEntry> _extractDownloadEntries(List<dynamic> files) {
    final result = <_DownloadEntry>[];

    void visit(List<dynamic> items) {
      for (final raw in items) {
        if (raw is! Map) continue;
        final file = Map<String, dynamic>.from(raw);
        final children = file['children'];
        if (children is List) visit(children);

        final url = file['mediaDownloadUrl']?.toString().trim() ??
            file['mediaStreamUrl']?.toString().trim() ??
            file['url']?.toString().trim();
        if (url == null || url.isEmpty) continue;
        final uri = Uri.tryParse(url);
        if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
          continue;
        }
        final title = file['title']?.toString().trim() ??
            file['name']?.toString().trim() ??
            uri.pathSegments.lastOrNull ??
            'File unduhan';
        result.add(_DownloadEntry(title: title, url: url));
      }
    }

    visit(files);
    return result;
  }

  Future<void> _refreshHealth() async {
    try {
      final result = await ref.read(unifiedSourceServiceProvider).checkHealth();
      if (mounted) setState(() => _health = result);
    } catch (_) {
      // Source health is advisory only; playback fallback remains independent.
    }
  }

  Future<void> _setPreferredSource(UnifiedSourceKind? source) async {
    if (source?.canPlay == false) return;
    if (_preferredSource == source) return;
    setState(() => _preferredSource = source);
    await UnifiedSourcePreferences.savePreferredSource(source);
    await Future.wait<void>([_loadDetail(), _loadTracks()]);
  }

  Future<void> _playTrack(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await ref.read(audioPlayerControllerProvider.notifier).playTracks(
          _tracks,
          startIndex: index,
          work: _detail ?? widget.work,
        );
  }

  Future<void> _playAll() async {
    if (_tracks.isEmpty) return;
    await ref.read(audioPlayerControllerProvider.notifier).playTracks(
          _tracks,
          work: _detail ?? widget.work,
        );
  }

  Future<void> _openSource(UnifiedSourceRef source) async {
    final uri = Uri.tryParse(source.detailUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openDownload(_DownloadEntry entry) async {
    final uri = Uri.tryParse(entry.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _displayTitle(Work work) {
    var title = work.title.trim();
    final id = work.displayId.trim();
    if (id.isNotEmpty) {
      final escaped = RegExp.escape(id);
      title = title
          .replaceFirst(
            RegExp(
              '^\\s*[\\[]?\\s*$escaped\\s*[\\]]?\\s*[-:：|]?\\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
    }
    return title.isEmpty ? work.title : title;
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final work = _detail ?? widget.work;
    if (bundle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail karya')),
        body: const Center(
          child: Text('Unified source metadata is unavailable.'),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final showSourcePreference = bundle.playableSources.length > 1;
    final showPlaybackStatus =
        bundle.hasPlaybackFallback || _resolved?.usedFallback == true;
    final activeTrack = ref.watch(currentTrackProvider).asData?.value;
    final activePosition =
        ref.watch(positionProvider).asData?.value ?? Duration.zero;
    final activeDuration = ref.watch(durationProvider).asData?.value;
    final activeSubtitle = ref.watch(currentTimedSubtitleProvider);
    final primarySource = _resolved?.source.source ??
        _preferredSource ??
        (bundle.sources.isEmpty ? null : bundle.sources.first.source);
    final hasHls = _tracks.any(
      (track) =>
          Uri.tryParse(track.url)?.path.toLowerCase().endsWith('.m3u8') == true,
    );
    final hasChapter = _tracks.any((track) => track.isSegmented);
    final hasSubtitleCapability = work.hasSubtitle == true ||
        bundle.sources.any((source) => source.source.canProvideSubtitles);

    return GlobalAudioPlayerWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail karya'),
          actions: [
            IconButton(
              onPressed: () async {
                final futures = <Future<void>>[
                  _loadDetail(),
                  _loadTracks(),
                  _refreshHealth(),
                ];
                if (bundle.downloadOnlySources.isNotEmpty) {
                  futures.add(_loadDownloads());
                }
                await Future.wait<void>(futures);
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh semua sumber',
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primary.withValues(alpha: 0.06),
                scheme.surface.withValues(alpha: 0),
              ],
              stops: const [0, 0.30],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              final futures = <Future<void>>[
                _loadDetail(),
                _loadTracks(),
                _refreshHealth(),
              ];
              if (bundle.downloadOnlySources.isNotEmpty) {
                futures.add(_loadDownloads());
              }
              await Future.wait<void>(futures);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _buildHero(work, bundle),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _PillBadge(
                      icon: Icons.confirmation_number_outlined,
                      label: work.displayId,
                      emphasized: true,
                    ),
                    if (primarySource != null)
                      _PillBadge(
                        icon: Icons.language_rounded,
                        label: primarySource.label,
                        emphasized: true,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _displayTitle(work),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 25,
                        height: 1.16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                ),
                if (work.name?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    work.name!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const SizedBox(height: 14),
                _buildPrimaryMetadata(work),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (bundle.canPlay)
                      const _CapabilityBadge(
                        icon: Icons.play_arrow_rounded,
                        label: 'Play',
                      ),
                    if (bundle.canDownload)
                      const _CapabilityBadge(
                        icon: Icons.download_outlined,
                        label: 'Download',
                      ),
                    if (hasSubtitleCapability)
                      const _CapabilityBadge(
                        icon: Icons.subtitles_outlined,
                        label: 'Subtitle',
                      ),
                    if (hasHls)
                      const _CapabilityBadge(
                        icon: Icons.stream_rounded,
                        label: 'HLS',
                      ),
                    if (hasChapter)
                      const _CapabilityBadge(
                        icon: Icons.segment_rounded,
                        label: 'Chapter',
                      ),
                  ],
                ),
                if (_detailError != null) ...[
                  const SizedBox(height: 14),
                  _ErrorCard(message: _detailError!),
                ],
                if (showSourcePreference) ...[
                  const SizedBox(height: 20),
                  _buildSourcePreference(bundle),
                ],
                if (showPlaybackStatus) ...[
                  const SizedBox(height: 12),
                  _buildPlaybackStatus(bundle),
                ],
                const SizedBox(height: 22),
                if (bundle.canPlay) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasChapter ? 'Track & chapter' : 'Track',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      if (_tracks.isNotEmpty)
                        Text(
                          '${_tracks.length} item',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loadingTracks)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_trackError != null)
                    _ErrorCard(
                      message: _trackError!,
                      action: TextButton.icon(
                        onPressed: _loadTracks,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba lagi'),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _tracks.isEmpty ? null : _playAll,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Putar semua (${_tracks.length})'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._tracks.asMap().entries.map((entry) {
                      final track = entry.value;
                      final isActive = activeTrack?.id == track.id;
                      final identity =
                          TrackPlaybackProgressStore.instance.identityFor(track);
                      final savedProgress = _trackProgress[identity];
                      final subtitleAvailable = isActive &&
                          activeSubtitle != null &&
                          activeSubtitle.trackId == track.id &&
                          !activeSubtitle.isEmpty;
                      return _TrackTile(
                        index: entry.key,
                        track: track,
                        onTap: () => _playTrack(entry.key),
                        isActive: isActive,
                        activePosition:
                            isActive ? activePosition : Duration.zero,
                        activeDuration: isActive ? activeDuration : null,
                        savedProgress: savedProgress,
                        subtitleAvailable: subtitleAvailable,
                      );
                    }),
                  ],
                ] else ...[
                  _InfoCard(
                    icon: bundle.canDownload
                        ? Icons.download_for_offline_outlined
                        : Icons.info_outline,
                    title: bundle.canDownload
                        ? 'Khusus unduhan'
                        : 'Metadata saja',
                    message: bundle.canDownload
                        ? 'Karya ini tersedia melalui ' +
                            bundle.downloadSources
                                .map((source) => source.source.label)
                                .join(', ') +
                            ' sebagai sumber unduhan.'
                        : 'Sumber ini menyediakan katalog dan detail. '
                            'Capability pemutaran belum tersedia.',
                  ),
                ],
                if (bundle.downloadOnlySources.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildDownloadFiles(bundle),
                ],
                if (_loadingDetail) ...[
                  const SizedBox(height: 18),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 24),
                _buildSecondaryMetadata(work),
                const SizedBox(height: 20),
                _buildSources(bundle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryMetadata(Work work) {
    final items = <({IconData icon, String label, String value})>[];
    if (work.vas?.isNotEmpty == true) {
      items.add(
        (
          icon: Icons.record_voice_over_outlined,
          label: 'CV',
          value: work.vas!.map((va) => va.name).join(', '),
        ),
      );
    }
    if (work.duration != null && work.duration! > 0) {
      items.add(
        (
          icon: Icons.schedule_outlined,
          label: 'Durasi',
          value: _duration(Duration(seconds: work.duration!)),
        ),
      );
    }
    if (work.release?.trim().isNotEmpty == true) {
      items.add(
        (
          icon: Icons.calendar_today_outlined,
          label: 'Rilis',
          value: work.release!.trim(),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => _MetadataFact(
              icon: item.icon,
              label: item.label,
              value: item.value,
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildSecondaryMetadata(Work work) {
    final theme = Theme.of(context);
    final tags = work.tags
            ?.map((tag) => tag.name.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final voices = work.vas
            ?.map((va) => va.name.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final hasDescription = work.description?.trim().isNotEmpty == true;
    final hasMetadata = hasDescription ||
        tags.isNotEmpty ||
        voices.isNotEmpty ||
        work.name?.trim().isNotEmpty == true ||
        work.release?.trim().isNotEmpty == true ||
        work.age?.trim().isNotEmpty == true;

    if (!hasMetadata) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi karya',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (hasDescription) ...[
              const SizedBox(height: 14),
              Text(work.description!.trim()),
            ],
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Tags',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: tags.map((tag) => Chip(label: Text(tag))).toList(),
              ),
            ],
            if (voices.isNotEmpty) ...[
              const SizedBox(height: 14),
              _MetadataLine(label: 'Voice actors', value: voices.join(', ')),
            ],
            if (work.name?.trim().isNotEmpty == true)
              _MetadataLine(label: 'Circle', value: work.name!.trim()),
            if (work.release?.trim().isNotEmpty == true)
              _MetadataLine(label: 'Release', value: work.release!.trim()),
            if (work.age?.trim().isNotEmpty == true)
              _MetadataLine(label: 'Rating', value: work.age!.trim()),
          ],
        ),
      ),
    );
  }

  String _duration(Duration duration) {
    final hours = duration.inHours;
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Widget _buildHero(Work work, UnifiedWorkBundle bundle) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    String? cover;
    if (work.images?.isNotEmpty == true) cover = work.images!.first;
    cover ??= bundle.coverUrl;
    if (cover == null &&
        bundle.hasSource(UnifiedSourceKind.asmrOne) &&
        (auth.host ?? '').isNotEmpty) {
      cover = work.getCoverImageUrl(auth.host!, token: auth.token ?? '');
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.13),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.28 : 0.10),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: cover == null
              ? ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.graphic_eq, size: 72)),
                )
              : CachedNetworkImage(
                  imageUrl: cover,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.graphic_eq, size: 72)),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSources(UnifiedWorkBundle bundle) {
    final playable = bundle.playableSources;
    final downloadOnly = bundle.downloadOnlySources;
    final metadataOnly = bundle.metadataOnlySources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (playable.isNotEmpty)
          _SourceSectionCard(
            title: 'Sumber Pemutaran',
            icon: Icons.play_circle_outline,
            sources: playable,
            health: _health,
            subtitleFor: (source, health) => source.source.canDownload
                ? _healthLabel(health) + ' · Putar & unduh'
                : _healthLabel(health) + ' · Putar',
            onOpen: _openSource,
          ),
        if (playable.isNotEmpty && downloadOnly.isNotEmpty)
          const SizedBox(height: 12),
        if (downloadOnly.isNotEmpty)
          _SourceSectionCard(
            title: 'Sumber Unduhan',
            icon: Icons.download_outlined,
            sources: downloadOnly,
            health: _health,
            subtitleFor: (source, health) =>
                _healthLabel(health) + ' · Khusus unduhan',
            onOpen: _openSource,
          ),
        if ((playable.isNotEmpty || downloadOnly.isNotEmpty) &&
            metadataOnly.isNotEmpty)
          const SizedBox(height: 12),
        if (metadataOnly.isNotEmpty)
          _SourceSectionCard(
            title: 'Sumber Metadata',
            icon: Icons.info_outline,
            sources: metadataOnly,
            health: _health,
            subtitleFor: (source, health) =>
                _healthLabel(health) + ' · Metadata saja',
            onOpen: _openSource,
          ),
      ],
    );
  }

  Widget _buildSourcePreference(UnifiedWorkBundle bundle) {
    final playable = bundle.playableSources;
    if (playable.length <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih sumber pemutaran',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Otomatis'),
              selected: _preferredSource == null,
              onSelected: (_) => _setPreferredSource(null),
            ),
            ...playable.map(
              (source) => ChoiceChip(
                label: Text(source.source.label),
                selected: _preferredSource == source.source,
                onSelected: (_) => _setPreferredSource(source.source),
              ),
            ),
          ],
        ),
        if (bundle.hasPlaybackFallback) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.autorenew,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Fallback otomatis hanya berpindah di antara sumber yang memang bisa diputar.',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPlaybackStatus(UnifiedWorkBundle bundle) {
    final resolved = _resolved;
    if (resolved == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: const Icon(Icons.play_circle_outline, size: 18),
          label: Text('Memutar dari ${resolved.source.source.label}'),
        ),
        if (resolved.usedFallback)
          const Chip(
            avatar: Icon(Icons.check_circle_outline, size: 18),
            label: Text('Fallback digunakan'),
          )
        else if (bundle.hasPlaybackFallback)
          const Chip(
            avatar: Icon(Icons.shield_outlined, size: 18),
            label: Text('Fallback siap'),
          ),
      ],
    );
  }

  Widget _buildDownloadFiles(UnifiedWorkBundle bundle) {
    final source = _resolvedDownloads?.source ?? bundle.downloadOnlySources.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File Unduhan · ${source.source.label}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingDownloads)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_downloadEntries.isNotEmpty)
              ..._downloadEntries.asMap().entries.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text('${entry.key + 1}'),
                      ),
                      title: Text(
                        entry.value.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: const Text('Buka file unduhan'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openDownload(entry.value),
                    ),
                  )
            else ...[
              Text(
                _downloadError ?? 'Belum ada file unduhan yang terdeteksi.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openSource(source),
                icon: const Icon(Icons.open_in_new),
                label: Text('Buka ${source.source.label}'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _healthLabel(UnifiedSourceHealth health) => switch (health) {
        UnifiedSourceHealth.healthy => 'Tersedia',
        UnifiedSourceHealth.degraded => 'Terbatas',
        UnifiedSourceHealth.broken => 'Tidak tersedia',
        UnifiedSourceHealth.unknown => 'Belum diperiksa',
      };
}

class _SourceSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<UnifiedSourceRef> sources;
  final Map<UnifiedSourceKind, UnifiedSourceHealth> health;
  final String Function(UnifiedSourceRef, UnifiedSourceHealth) subtitleFor;
  final Future<void> Function(UnifiedSourceRef) onOpen;

  const _SourceSectionCard({
    required this.title,
    required this.icon,
    required this.sources,
    required this.health,
    required this.subtitleFor,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...sources.map((source) {
              final sourceHealth =
                  health[source.source] ?? UnifiedSourceHealth.unknown;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer.withValues(alpha: 0.70),
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(source.source.label.substring(0, 1)),
                ),
                title: Text(
                  source.source.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(subtitleFor(source, sourceHealth)),
                trailing: IconButton(
                  onPressed: () => onOpen(source),
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Buka halaman sumber',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadEntry {
  final String title;
  final String url;

  const _DownloadEntry({required this.title, required this.url});
}

class _PillBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool emphasized;

  const _PillBadge({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: 0.72)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: emphasized
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: emphasized
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CapabilityBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.72),
        ),
        borderRadius: BorderRadius.circular(999),
        color: scheme.surfaceContainerLow.withValues(alpha: 0.78),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetadataFact extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetadataFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final int index;
  final AudioTrack track;
  final VoidCallback onTap;
  final bool isActive;
  final Duration activePosition;
  final Duration? activeDuration;
  final TrackPlaybackProgress? savedProgress;
  final bool subtitleAvailable;

  const _TrackTile({
    required this.index,
    required this.track,
    required this.onTap,
    required this.isActive,
    required this.activePosition,
    required this.activeDuration,
    required this.savedProgress,
    required this.subtitleAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logicalDuration =
        activeDuration ?? savedProgress?.duration ?? track.segmentDuration;
    final logicalPosition =
        isActive ? activePosition : (savedProgress?.position ?? Duration.zero);
    final totalMs = logicalDuration?.inMilliseconds ?? 0;
    final progress = totalMs > 0
        ? (logicalPosition.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final completed = !isActive &&
        (savedProgress?.completed == true || progress >= 0.995);

    String status;
    if (isActive) {
      status = 'Sedang diputar';
    } else if (completed) {
      status = 'Selesai';
    } else if (progress > 0) {
      status = 'Terakhir ${(progress * 100).round()}%';
    } else {
      status = 'Belum diputar';
    }

    final subtitle = subtitleAvailable ? ' · Subtitle tersedia' : '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      color: isActive
          ? scheme.primaryContainer.withValues(alpha: 0.24)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isActive
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant.withValues(alpha: 0.48),
          width: isActive ? 1.0 : 0.7,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    scheme.primaryContainer.withValues(alpha: 0.72),
                foregroundColor: scheme.onPrimaryContainer,
                child: completed
                    ? const Icon(Icons.check_rounded, size: 20)
                    : Text('${index + 1}'),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: isActive
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$status$subtitle',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: isActive
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w500,
                          ),
                    ),
                    if (totalMs > 0 && progress > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (logicalDuration != null)
                    Text(
                      _formatDuration(logicalDuration),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  const SizedBox(height: 6),
                  Icon(
                    isActive
                        ? Icons.equalizer_rounded
                        : Icons.play_arrow_rounded,
                    color: scheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Widget? action;

  const _ErrorCard({required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}
