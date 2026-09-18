import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/works_provider.dart';
import '../sources/unified_source_models.dart';

// Temporary compile-compatibility shim for a stale empty-state reference in
// works_screen.dart. The SFW/NSFW Home feature itself is removed: this value is
// always null, so the generic empty-state path is used and no safety filtering
// is performed. Remove together with the stale reference when works_screen is
// next refactored.
enum AsmrSafetyMode { sfw }

extension RemovedHomeSafetyCompatibility on WorksState {
  AsmrSafetyMode? get safetyMode => null;
}

class HomeSourceFilterBar extends ConsumerWidget {
  const HomeSourceFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(worksProvider);
    final notifier = ref.read(worksProvider.notifier);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: HomeSourceFilter.values.map((source) {
              final kind = source.unifiedSource;
              final health = kind == null
                  ? null
                  : state.sourceHealth[kind] ?? UnifiedSourceHealth.unknown;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: kind == null
                      ? const Icon(Icons.hub_outlined, size: 17)
                      : Icon(
                          _healthIcon(health!),
                          size: 16,
                          color: _healthColor(context, health),
                        ),
                  label: Text(source.label),
                  selected: state.sourceFilter == source,
                  onSelected: (_) => notifier.setSourceFilter(source),
                ),
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _helperText(state),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _helperText(WorksState state) {
    if (state.displayMode != DisplayMode.all) {
      return 'Populer dan Rekomendasi memakai katalog ASMR.one.';
    }
    return switch (state.sourceFilter) {
      HomeSourceFilter.all =>
        'Semua sumber digabung; karya dengan ID kanonis yang sama dideduplikasi.',
      HomeSourceFilter.asmrOne => 'Menampilkan katalog ASMR.one.',
      _ => 'Menampilkan karya dari ${state.sourceFilter.label}.',
    };
  }

  static IconData _healthIcon(UnifiedSourceHealth health) => switch (health) {
        UnifiedSourceHealth.healthy => Icons.check_circle_outline,
        UnifiedSourceHealth.degraded => Icons.warning_amber_rounded,
        UnifiedSourceHealth.broken => Icons.cancel_outlined,
        UnifiedSourceHealth.unknown => Icons.help_outline,
      };

  static Color _healthColor(BuildContext context, UnifiedSourceHealth health) =>
      switch (health) {
        UnifiedSourceHealth.healthy => Colors.green,
        UnifiedSourceHealth.degraded => Colors.orange,
        UnifiedSourceHealth.broken => Theme.of(context).colorScheme.error,
        UnifiedSourceHealth.unknown => Theme.of(context).colorScheme.outline,
      };
}
