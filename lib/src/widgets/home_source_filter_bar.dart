import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/audio_extension_provider.dart';
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
    final extensionRegistry = ref.watch(audioExtensionRegistryProvider);
    final enabledExtensionIds = extensionRegistry.extensions
        .map((extension) => extension.manifest.id)
        .toSet();
    final sourceOptions = availableHomeSourceFilters(enabledExtensionIds);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final knownTotal = state.totalCount > 0 ? state.totalCount : null;
    final countLabel = knownTotal != null && knownTotal > state.works.length
        ? '$knownTotal tersedia'
        : '${state.works.length} tampil';

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surfaceContainerHigh.withValues(
                alpha: isDark ? 0.88 : 0.96,
              ),
              scheme.primaryContainer.withValues(
                alpha: isDark ? 0.24 : 0.38,
              ),
              scheme.surfaceContainerLow.withValues(
                alpha: isDark ? 0.92 : 0.98,
              ),
            ],
            stops: const [0, 0.52, 1],
          ),
          border: Border.all(
            color: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.18),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: isDark ? 0.24 : 0.08),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: scheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
              blurRadius: 36,
              spreadRadius: -14,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -48,
              top: -58,
              child: IgnorePointer(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.11,
                        ),
                        scheme.primary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -38,
              bottom: 58,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        scheme.tertiary.withValues(
                          alpha: isDark ? 0.12 : 0.08,
                        ),
                        scheme.tertiary.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DiscoveryHero(
                    state: state,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sumber katalog',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Pilih sumber tanpa meninggalkan beranda.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(
                            alpha: isDark ? 0.34 : 0.58,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(
                              alpha: isDark ? 0.30 : 0.48,
                            ),
                            width: 0.7,
                          ),
                        ),
                        child: Text(
                          '${sourceOptions.length} pilihan',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: sourceOptions.map((source) {
                        final kind = source.unifiedSource;
                        final health = kind == null
                            ? null
                            : state.sourceHealth[kind] ??
                                UnifiedSourceHealth.unknown;
                        final selected = state.sourceFilter == source;

                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _SourceCard(
                            source: source,
                            health: health,
                            selected: selected,
                            onTap: () => notifier.setSourceFilter(source),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(
                        alpha: isDark ? 0.32 : 0.52,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(
                          alpha: isDark ? 0.24 : 0.38,
                        ),
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(
                              alpha: isDark ? 0.16 : 0.10,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _helperText(state),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 11.5,
                              height: 1.42,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Jelajahi karya',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(
                            alpha: isDark ? 0.15 : 0.09,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          countLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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
      return 'Populer dan Rekomendasi memakai katalog ASMR.one agar urutan kurasi tetap konsisten.';
    }
    return switch (state.sourceFilter) {
      HomeSourceFilter.all =>
        'Semua sumber digabung, lalu karya dengan ID kanonis yang sama dideduplikasi otomatis.',
      HomeSourceFilter.asmrOne =>
        'Menampilkan katalog ASMR.one dengan dukungan pengurutan penuh.',
      _ => 'Menampilkan karya dari ${state.sourceFilter.label}.',
    };
  }
}

class _DiscoveryHero extends StatelessWidget {
  const _DiscoveryHero({
    required this.state,
    required this.isDark,
  });

  final WorksState state;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final curated = state.displayMode != DisplayMode.all;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: isDark ? 0.30 : 0.20),
                scheme.tertiary.withValues(alpha: isDark ? 0.18 : 0.12),
              ],
            ),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.24),
              width: 0.8,
            ),
          ),
          child: Icon(
            Icons.graphic_eq_rounded,
            color: scheme.primary,
            size: 27,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(
                    alpha: isDark ? 0.16 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  curated ? 'KURASI HIRAUKAN' : 'DISCOVER',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.05,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                curated
                    ? 'Pilihan yang terasa lebih dekat.'
                    : 'Temukan suara untuk suasanamu.',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onSurface,
                  fontSize: 21,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.45,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                curated
                    ? 'Kurasi ringan untuk membantu kamu masuk ke pengalaman dengar tanpa banyak mencari.'
                    : 'Pilih katalog di bawah, lalu biarkan artwork memimpin penjelajahan.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.health,
    required this.selected,
    required this.onTap,
  });

  final HomeSourceFilter source;
  final UnifiedSourceHealth? health;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 142,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primaryContainer.withValues(
                    alpha: isDark ? 0.88 : 0.96,
                  ),
                  scheme.primary.withValues(
                    alpha: isDark ? 0.16 : 0.08,
                  ),
                ],
              )
            : null,
        color: selected
            ? null
            : scheme.surface.withValues(alpha: isDark ? 0.34 : 0.58),
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.44)
              : scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.28 : 0.44,
                ),
          width: selected ? 1.0 : 0.7,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(
                    alpha: isDark ? 0.12 : 0.07,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.15)
                            : scheme.surfaceContainerHighest.withValues(
                                alpha: isDark ? 0.50 : 0.72,
                              ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        source.unifiedSource == null
                            ? Icons.auto_awesome_rounded
                            : Icons.headphones_rounded,
                        size: 17,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: scheme.primary,
                      )
                    else if (health != null)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _healthColor(context, health!),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  source.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  source.unifiedSource == null
                      ? 'Semua katalog'
                      : _healthLabel(health ?? UnifiedSourceHealth.unknown),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? scheme.onPrimaryContainer.withValues(alpha: 0.72)
                        : scheme.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _healthLabel(UnifiedSourceHealth health) => switch (health) {
        UnifiedSourceHealth.healthy => 'Siap digunakan',
        UnifiedSourceHealth.degraded => 'Terbatas',
        UnifiedSourceHealth.broken => 'Tidak tersedia',
        UnifiedSourceHealth.unknown => 'Memeriksa status',
      };

  static Color _healthColor(BuildContext context, UnifiedSourceHealth health) =>
      switch (health) {
        UnifiedSourceHealth.healthy => Colors.green,
        UnifiedSourceHealth.degraded => Colors.orange,
        UnifiedSourceHealth.broken => Theme.of(context).colorScheme.error,
        UnifiedSourceHealth.unknown => Theme.of(context).colorScheme.outline,
      };
}
