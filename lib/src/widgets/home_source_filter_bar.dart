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
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh.withValues(
              alpha: isDark ? 0.78 : 0.92,
            ),
            scheme.primaryContainer.withValues(
              alpha: isDark ? 0.18 : 0.30,
            ),
          ],
        ),
        border: Border.all(
          color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.16),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.18 : 0.07),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 24,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(
                      alpha: isDark ? 0.17 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih sumber',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Satu tempat, beberapa katalog.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: HomeSourceFilter.values.map((source) {
                  final kind = source.unifiedSource;
                  final health = kind == null
                      ? null
                      : state.sourceHealth[kind] ??
                          UnifiedSourceHealth.unknown;
                  final selected = state.sourceFilter == source;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      showCheckmark: false,
                      avatar: kind == null
                          ? Icon(
                              Icons.hub_outlined,
                              size: 17,
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            )
                          : Icon(
                              _healthIcon(health!),
                              size: 16,
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : _healthColor(context, health),
                            ),
                      label: Text(source.label),
                      selected: selected,
                      onSelected: (_) => notifier.setSourceFilter(source),
                      selectedColor: scheme.primaryContainer,
                      backgroundColor: scheme.surface.withValues(
                        alpha: isDark ? 0.38 : 0.58,
                      ),
                      side: BorderSide(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.38)
                            : scheme.outlineVariant.withValues(
                                alpha: isDark ? 0.34 : 0.56,
                              ),
                        width: 0.8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(
                  alpha: isDark ? 0.30 : 0.48,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _helperText(state),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
