import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/audio_track.dart';
import '../models/work.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../sources/unified_source_models.dart';
import '../sources/unified_source_preferences.dart';
import '../sources/unified_source_provider.dart';
import '../sources/unified_source_registry.dart';
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

  UnifiedWorkBundle? get _bundle => _hydratedBundle ??
      UnifiedSourceRegistry.instance.bundleFor(widget.work.id) ??
      UnifiedSourceRegistry.instance.ensureFromWork(widget.work);

  @override
  void initState() {
    super.initState();
    _restorePreferenceAndLoad();
    _refreshHealth();
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _trackError = error.toString();
        _loadingTracks = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final work = _detail ?? widget.work;
    if (bundle == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.work.displayId)),
        body: const Center(
          child: Text('Unified source metadata is unavailable.'),
        ),
      );
    }

    return GlobalAudioPlayerWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(work.displayId),
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
              tooltip: 'Refresh all sources',
            ),
          ],
        ),
        body: RefreshIndicator(
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
              Text(
                work.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (work.name?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 5),
                Text(work.name!, style: Theme.of(context).textTheme.bodyLarge),
              ],
              if (_detailError != null) ...[
                const SizedBox(height: 12),
                _ErrorCard(message: _detailError!),
              ],
              const SizedBox(height: 18),
              _buildSources(bundle),
              if (bundle.canPlay) ...[
                const SizedBox(height: 18),
                _buildSourcePreference(bundle),
                const SizedBox(height: 18),
                _buildPlaybackStatus(bundle),
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
                      label: const Text('Retry'),
                    ),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: _tracks.isEmpty ? null : _playAll,
                    icon: const Icon(Icons.play_arrow),
                    label: Text('Play all (${_tracks.length})'),
                  ),
                  const SizedBox(height: 8),
                  ..._tracks.asMap().entries.map(
                        (entry) => _TrackTile(
                          index: entry.key,
                          track: entry.value,
                          onTap: () => _playTrack(entry.key),
                        ),
                      ),
                ],
              ] else ...[
                const SizedBox(height: 18),
                _InfoCard(
                  icon: Icons.download_for_offline_outlined,
                  title: 'Khusus unduhan',
                  message:
                      'Karya ini tidak memiliki sumber pemutaran dalam aplikasi. EroVoice tetap tersedia untuk melihat dan mengunduh file.',
                ),
              ],
              if (bundle.downloadOnlySources.isNotEmpty) ...[
                const SizedBox(height: 18),
                _buildDownloadFiles(bundle),
              ],
              if (_loadingDetail) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(),
              ],
              if (work.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 24),
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(work.description!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(Work work, UnifiedWorkBundle bundle) {
    final auth = ref.watch(authProvider);
    String? cover;
    if (work.images?.isNotEmpty == true) cover = work.images!.first;
    cover ??= bundle.coverUrl;
    if (cover == null &&
        bundle.hasSource(UnifiedSourceKind.asmrOne) &&
        (auth.host ?? '').isNotEmpty) {
      cover = work.getCoverImageUrl(auth.host!, token: auth.token ?? '');
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: cover == null
            ? ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.graphic_eq, size: 72)),
              )
            : CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.graphic_eq, size: 72)),
                ),
              ),
      ),
    );
  }

  Widget _buildSources(UnifiedWorkBundle bundle) {
    final playable = bundle.playableSources;
    final downloadOnly = bundle.downloadOnlySources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (playable.isNotEmpty)
          _SourceSectionCard(
            title: 'Sumber Pemutaran',
            icon: Icons.play_circle_outline,
            sources: playable,
            health: _health,
            subtitleFor: (source, health) =>
                '${_healthLabel(health)} · Putar & unduh',
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
                '${_healthLabel(health)} · Khusus unduhan',
            onOpen: _openSource,
          ),
      ],
    );
  }

  Widget _buildSourcePreference(UnifiedWorkBundle bundle) {
    final playable = bundle.playableSources;
    if (playable.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sumber Pemutaran Pilihan',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Auto'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...sources.map((source) {
              final sourceHealth =
                  health[source.source] ?? UnifiedSourceHealth.unknown;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(source.source.label.substring(0, 1)),
                ),
                title: Text(source.source.label),
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

class _TrackTile extends StatelessWidget {
  final int index;
  final AudioTrack track;
  final VoidCallback onTap;

  const _TrackTile({
    required this.index,
    required this.track,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(
          track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle:
            track.duration == null ? null : Text(_duration(track.duration!)),
        trailing: const Icon(Icons.play_arrow),
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
