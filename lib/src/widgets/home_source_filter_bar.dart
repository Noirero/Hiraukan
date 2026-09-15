import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/works_provider.dart';
import '../sources/unified_source_models.dart';

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
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.eco_outlined, size: 17),
                label: const Text('ASMR SFW'),
                selected: state.safetyMode == AsmrSafetyMode.sfw,
                onSelected: (_) => notifier.setSafetyMode(AsmrSafetyMode.sfw),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: const Icon(Icons.explicit_outlined, size: 17),
                label: const Text('ASMR NSFW'),
                selected: state.safetyMode == AsmrSafetyMode.nsfw,
                onSelected: (_) => notifier.setSafetyMode(AsmrSafetyMode.nsfw),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: HomeSourceFilter.values.map((source) {
              final disabled =
                  state.safetyMode == AsmrSafetyMode.sfw && source.adultOnly;
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
                          color: disabled
                              ? theme.disabledColor
                              : _healthColor(context, health),
                        ),
                  label: Text(source.label),
                  selected: state.sourceFilter == source,
                  onSelected: disabled
                      ? null
                      : (_) => notifier.setSourceFilter(source),
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
              state.safetyMode == AsmrSafetyMode.sfw
                  ? Icons.verified_user_outlined
                  : Icons.info_outline,
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
    if (state.safetyMode == AsmrSafetyMode.sfw) {
      return 'SFW ketat: konten dewasa dan metadata umur yang tidak jelas tidak ditampilkan.';
    }
    if (state.displayMode != DisplayMode.all) {
      return 'Populer dan Rekomendasi saat ini memakai katalog ASMR.one.';
    }
    if (state.sourceFilter == HomeSourceFilter.all) {
      return 'NSFW dari semua sumber digabung; karya dengan ID kanonis yang sama dideduplikasi.';
    }
    return 'Menampilkan ASMR NSFW dari ${state.sourceFilter.label}.';
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
