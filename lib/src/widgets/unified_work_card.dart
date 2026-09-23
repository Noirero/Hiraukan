import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work.dart';
import '../providers/auth_provider.dart';
import '../screens/unified_work_detail_screen.dart';
import '../sources/unified_source_models.dart';
import '../sources/unified_source_registry.dart';
import '../utils/source_request_headers.dart';

class UnifiedWorkCard extends ConsumerWidget {
  final Work work;
  final int crossAxisCount;
  final bool isListLayout;

  const UnifiedWorkCard({
    super.key,
    required this.work,
    required this.crossAxisCount,
    required this.isListLayout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = UnifiedSourceRegistry.instance.bundleFor(work.id);
    if (bundle == null) return const SizedBox.shrink();
    final auth = ref.watch(
      authProvider.select(
        (value) => (host: value.host ?? '', token: value.token ?? ''),
      ),
    );
    final cover = _coverUrl(bundle, auth.host, auth.token);

    void onTap() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UnifiedWorkDetailScreen(work: work),
        ),
      );
    }

    if (isListLayout) {
      return _ListWorkCard(
        work: work,
        bundle: bundle,
        cover: cover,
        onTap: onTap,
      );
    }

    final compact = crossAxisCount >= 4;
    return _GridWorkCard(
      work: work,
      bundle: bundle,
      cover: cover,
      compact: compact,
      onTap: onTap,
    );
  }

  String? _coverUrl(UnifiedWorkBundle bundle, String host, String token) {
    final direct = bundle.coverUrl;
    if (direct != null && direct.isNotEmpty) return direct;
    if (bundle.hasSource(UnifiedSourceKind.asmrOne) && host.isNotEmpty) {
      return work.getCoverImageUrl(host, token: token);
    }
    return work.images?.isNotEmpty == true ? work.images!.first : null;
  }
}

class _GridWorkCard extends StatelessWidget {
  const _GridWorkCard({
    required this.work,
    required this.bundle,
    required this.cover,
    required this.compact,
    required this.onTap,
  });

  final Work work;
  final UnifiedWorkBundle bundle;
  final String? cover;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.20 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.07 : 0.04),
            blurRadius: 24,
            spreadRadius: -12,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(
              alpha: isDark ? 0.30 : 0.46,
            ),
            width: 0.7,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: compact ? 1.16 : 1.08,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Cover(url: cover),
                    const _ArtworkScrim(),
                    Positioned(
                      left: compact ? 7 : 10,
                      top: compact ? 7 : 10,
                      child: _ArtworkIdBadge(
                        label: work.sourceId?.isNotEmpty == true
                            ? work.sourceId!
                            : work.displayId,
                        compact: compact,
                      ),
                    ),
                    Positioned(
                      top: compact ? 7 : 10,
                      right: compact ? 7 : 10,
                      child: _CapabilityBadge(
                        bundle: bundle,
                        compact: compact,
                      ),
                    ),
                    if (work.duration != null && work.duration! > 0)
                      Positioned(
                        right: compact ? 7 : 10,
                        bottom: compact ? 7 : 10,
                        child: _ArtworkMetaBadge(
                          icon: Icons.schedule_rounded,
                          label: _duration(work.duration!),
                          compact: compact,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 9 : 12,
                  compact ? 9 : 12,
                  compact ? 9 : 12,
                  compact ? 10 : 13,
                ),
                child: _Info(
                  work: work,
                  bundle: bundle,
                  compact: compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListWorkCard extends StatelessWidget {
  const _ListWorkCard({
    required this.work,
    required this.bundle,
    required this.cover,
    required this.onTap,
  });

  final Work work;
  final UnifiedWorkBundle bundle;
  final String? cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.16 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(
              alpha: isDark ? 0.30 : 0.46,
            ),
            width: 0.7,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 126,
                  child: AspectRatio(
                    aspectRatio: 1.12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _Cover(url: cover),
                          const _ArtworkScrim(),
                          Positioned(
                            top: 7,
                            right: 7,
                            child: _CapabilityBadge(
                              bundle: bundle,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _Info(work: work, bundle: bundle, compact: false),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;

  const _Cover({this.url});

  @override
  Widget build(BuildContext context) {
    final value = url?.trim();
    if (value == null || value.isEmpty) {
      return _CoverFallback();
    }
    return CachedNetworkImage(
      imageUrl: value,
      httpHeaders: sourceImageHeadersFor(value),
      fit: BoxFit.cover,
      placeholder: (_, __) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => const _CoverFallback(),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.78),
            scheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.graphic_eq_rounded,
            size: 32,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ArtworkScrim extends StatelessWidget {
  const _ArtworkScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.02),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
          stops: const [0, 0.58, 1],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final Work work;
  final UnifiedWorkBundle bundle;
  final bool compact;

  const _Info({
    required this.work,
    required this.bundle,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final hasCircle = work.name?.trim().isNotEmpty == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          work.title,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.22,
            letterSpacing: -0.1,
          ),
        ),
        if (hasCircle && !compact) ...[
          const SizedBox(height: 5),
          Text(
            work.name!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ],
        SizedBox(height: compact ? 7 : 10),
        Row(
          children: [
            Icon(
              bundle.canPlay
                  ? Icons.play_circle_outline_rounded
                  : Icons.download_for_offline_outlined,
              size: compact ? 14 : 16,
              color: scheme.primary,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                bundle.canPlay
                    ? '${bundle.sources.length} sumber tersedia untuk karya ini'
                    : 'Tersedia sebagai sumber unduhan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 9.5 : null,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 6 : 8),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: bundle.sources
              .map(
                (source) => _SourceChip(
                  source: source.source,
                  compact: compact,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  final UnifiedSourceKind source;
  final bool compact;

  const _SourceChip({required this.source, required this.compact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canPlay = source.canPlay;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: canPlay
            ? scheme.primaryContainer.withValues(alpha: 0.86)
            : scheme.secondaryContainer.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canPlay
              ? scheme.primary.withValues(alpha: 0.18)
              : scheme.secondary.withValues(alpha: 0.18),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            canPlay ? Icons.play_arrow_rounded : Icons.download_rounded,
            size: compact ? 11 : 13,
            color: canPlay
                ? scheme.onPrimaryContainer
                : scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            source.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: compact ? 9 : null,
                  fontWeight: FontWeight.w700,
                  color: canPlay
                      ? scheme.onPrimaryContainer
                      : scheme.onSecondaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityBadge extends StatelessWidget {
  final UnifiedWorkBundle bundle;
  final bool compact;

  const _CapabilityBadge({required this.bundle, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canPlay = bundle.canPlay;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.34),
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 4 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              canPlay ? Icons.play_arrow_rounded : Icons.download_rounded,
              size: compact ? 12 : 14,
              color: canPlay ? scheme.primary : scheme.secondary,
            ),
            const SizedBox(width: 3),
            Text(
              canPlay
                  ? (bundle.sources.length > 1
                      ? '${bundle.sources.length} sumber'
                      : 'Putar')
                  : 'Unduh',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: compact ? 9 : null,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkIdBadge extends StatelessWidget {
  const _ArtworkIdBadge({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 92 : 130),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.22),
          width: 0.7,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize: compact ? 9 : null,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ArtworkMetaBadge extends StatelessWidget {
  const _ArtworkMetaBadge({
    required this.icon,
    required this.label,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: compact ? 11 : 13),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontSize: compact ? 9 : null,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String _duration(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$secs' : '$minutes:$secs';
}
