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
  List<AudioTrack> _tracks = const [];
  Map<UnifiedSourceKind, UnifiedSourceHealth> _health = const {};
  UnifiedSourceKind? _preferredSource;
  bool _loadingDetail = true;
  bool _loadingTracks = true;
  String? _detailError;
  String? _trackError;

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
    final preferred = await UnifiedSourcePreferences.loadPreferredSource();
    if (!mounted) return;
    setState(() {
      _hydratedBundle = bundle;
      _preferredSource = preferred;
    });
    await _loadContent();
  }

  Future<void> _loadContent() async {
    await Future.wait<void>([
      _loadDetail(),
      _loadTracks(),
    ]);
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

  Future<void> _refreshHealth() async {
    try {
      final result = await ref.read(unifiedSourceServiceProvider).checkHealth();
      if (mounted) setState(() => _health = result);
    } catch (_) {
      // Source health is advisory only; playback fallback remains independent.
    }
  }

  Future<void> _setPreferredSource(UnifiedSourceKind? source) async {
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
                await Future.wait<void>([
                  _loadDetail(),
                  _loadTracks(),
                  _refreshHealth(),
                ]);
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh all sources',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await Future.wait<void>([
              _loadDetail(),
              _loadTracks(),
              _refreshHealth(),
            ]);
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
              const SizedBox(height: 18),
              _buildSourcePreference(bundle),
              const SizedBox(height: 18),
              _buildPlaybackStatus(),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Sources',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...bundle.sources.map((source) {
              final health =
                  _health[source.source] ?? UnifiedSourceHealth.unknown;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(source.source.label.substring(0, 1)),
                ),
                title: Text(source.source.label),
                subtitle: Text(_healthLabel(health)),
                trailing: IconButton(
                  onPressed: () => _openSource(source),
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Open source page',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcePreference(UnifiedWorkBundle bundle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferred Source',
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
            ...bundle.sources.map(
              (source) => ChoiceChip(
                label: Text(source.source.label),
                selected: _preferredSource == source.source,
                onSelected: (_) => _setPreferredSource(source.source),
              ),
            ),
          ],
        ),
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
                'Fallback is automatic when the preferred source cannot provide playable tracks.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaybackStatus() {
    final resolved = _resolved;
    if (resolved == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: const Icon(Icons.play_circle_outline, size: 18),
          label: Text('Playing source: ${resolved.source.source.label}'),
        ),
        if (resolved.usedFallback)
          const Chip(
            avatar: Icon(Icons.check_circle_outline, size: 18),
            label: Text('Fallback used'),
          )
        else if ((_bundle?.sources.length ?? 0) > 1)
          const Chip(
            avatar: Icon(Icons.shield_outlined, size: 18),
            label: Text('Fallback ready'),
          ),
      ],
    );
  }

  String _healthLabel(UnifiedSourceHealth health) => switch (health) {
        UnifiedSourceHealth.healthy => 'Available',
        UnifiedSourceHealth.degraded => 'Degraded',
        UnifiedSourceHealth.broken => 'Unavailable',
        UnifiedSourceHealth.unknown => 'Not checked',
      };
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
