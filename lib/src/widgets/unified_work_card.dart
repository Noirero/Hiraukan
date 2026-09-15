import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work.dart';
import '../providers/auth_provider.dart';
import '../screens/unified_work_detail_screen.dart';
import '../sources/unified_source_models.dart';
import '../sources/unified_source_registry.dart';

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
      authProvider.select((value) => (host: value.host ?? '', token: value.token ?? '')),
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
      return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  height: 88,
                  child: _Cover(url: cover),
                ),
                const SizedBox(width: 12),
                Expanded(child: _Info(work: work, bundle: bundle, compact: false)),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
    }

    final compact = crossAxisCount >= 4;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1.3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Cover(url: cover),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _SourceCountBadge(count: bundle.sources.length),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 7 : 10),
              child: _Info(work: work, bundle: bundle, compact: compact),
            ),
          ],
        ),
      ),
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

class _Cover extends StatelessWidget {
  final String? url;

  const _Cover({this.url});

  @override
  Widget build(BuildContext context) {
    final value = url?.trim();
    if (value == null || value.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.graphic_eq,
            size: 42,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: value,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.graphic_eq, size: 42)),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final Work work;
  final UnifiedWorkBundle bundle;
  final bool compact;

  const _Info({required this.work, required this.bundle, required this.compact});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (work.sourceId?.isNotEmpty == true)
              Flexible(
                child: Text(
                  work.sourceId!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (work.duration != null) ...[
              const Spacer(),
              Text(_duration(work.duration!), style: textTheme.labelSmall),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          work.title,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (work.name?.isNotEmpty == true && !compact) ...[
          const SizedBox(height: 3),
          Text(
            work.name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 7),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: bundle.sources
              .map((source) => _SourceChip(source: source.source, compact: compact))
              .toList(growable: false),
        ),
      ],
    );
  }

  static String _duration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$secs' : '$minutes:$secs';
  }
}

class _SourceChip extends StatelessWidget {
  final UnifiedSourceKind source;
  final bool compact;

  const _SourceChip({required this.source, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        source.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: compact ? 9 : null,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
      ),
    );
  }
}

class _SourceCountBadge extends StatelessWidget {
  final int count;

  const _SourceCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          '$count source${count == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
