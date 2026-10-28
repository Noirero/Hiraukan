import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/audio_extension_provider.dart';
import '../providers/works_provider.dart';
import '../sources/asmr18_source_adapter.dart';
import '../sources/unified_source_models.dart';
import 'continue_listening_section.dart';

// Temporary compile-compatibility shim for a stale empty-state reference in
// works_screen.dart. The SFW/NSFW Home feature itself is removed: this value is
// always null, so the generic empty-state path is used and no safety filtering
// is performed. Remove together with the stale reference when works_screen is
// next refactored.
enum AsmrSafetyMode { sfw }

extension RemovedHomeSafetyCompatibility on WorksState {
  AsmrSafetyMode? get safetyMode => null;
}

/// Home discovery surface.
///
/// The previous implementation exposed source machinery as a large technical
/// dashboard. This version keeps source control available while putting the
/// listening journey first: resume recent audio, choose a catalog only when
/// needed, then browse the feed below.
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
    final sources = availableHomeSourceFilters(enabledExtensionIds);
    final copy = _HomeCopy.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ContinueListeningSection(),
        const _ResumeSpacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHigh.withValues(
                  alpha: isDark ? 0.94 : 0.98,
                ),
                scheme.primaryContainer.withValues(
                  alpha: isDark ? 0.20 : 0.34,
                ),
              ],
            ),
            border: Border.all(
              color: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      state.displayMode == DisplayMode.all
                          ? Icons.graphic_eq_rounded
                          : Icons.auto_awesome_rounded,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.displayMode == DisplayMode.all
                              ? copy.discoverTitle
                              : copy.curatedTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.displayMode == DisplayMode.all
                              ? copy.discoverSubtitle
                              : copy.curatedSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.42,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      copy.sources,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _CountPill(
                    label: state.totalCount > 0
                        ? copy.items(state.totalCount)
                        : copy.visibleItems(state.works.length),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (final source in sources)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _SourceChip(
                          source: source,
                          selected: state.sourceFilter == source,
                          health: source.unifiedSource == null
                              ? null
                              : state.sourceHealth[source.unifiedSource!] ??
                                  UnifiedSourceHealth.unknown,
                          onTap: () => notifier.setSourceFilter(source),
                        ),
                      ),
                  ],
                ),
              ),
              if (state.sourceFilter == HomeSourceFilter.asmr18) ...[
                const SizedBox(height: 14),
                Text(
                  copy.category,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final category in Asmr18CatalogCategory.values)
                      ChoiceChip(
                        selected: state.asmr18Category == category,
                        label: Text(category.label),
                        onSelected: (_) =>
                            notifier.setAsmr18Category(category),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _helperText(state, copy),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            copy.browse,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }

  static String _helperText(WorksState state, _HomeCopy copy) {
    if (state.displayMode != DisplayMode.all) {
      return copy.curatedHelper;
    }
    return switch (state.sourceFilter) {
      HomeSourceFilter.all => copy.allHelper,
      HomeSourceFilter.asmrOne => copy.asmrOneHelper,
      HomeSourceFilter.asmr18 => copy.asmr18Helper(state.asmr18Category.label),
      _ => copy.sourceHelper(state.sourceFilter.label),
    };
  }
}

class _ResumeSpacer extends ConsumerWidget {
  const _ResumeSpacer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the spacing zero when the history shelf is absent. This avoids a
    // visual hole on first launch while preserving separation when it exists.
    // The provider is already initialized by ContinueListeningSection.
    // ignore: unused_local_variable
    final _ = ref.watch(worksProvider);
    return const SizedBox(height: 16);
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.source,
    required this.selected,
    required this.health,
    required this.onTap,
  });

  final HomeSourceFilter source;
  final bool selected;
  final UnifiedSourceHealth? health;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final healthColor = switch (health) {
      UnifiedSourceHealth.healthy => Colors.green,
      UnifiedSourceHealth.degraded => Colors.orange,
      UnifiedSourceHealth.broken => Colors.red,
      _ => null,
    };

    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surface.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.45)
                  : scheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (healthColor != null) ...[
                Icon(Icons.circle, size: 8, color: healthColor),
                const SizedBox(width: 6),
              ],
              Text(
                source.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HomeCopy {
  const _HomeCopy({
    required this.discoverTitle,
    required this.discoverSubtitle,
    required this.curatedTitle,
    required this.curatedSubtitle,
    required this.sources,
    required this.category,
    required this.browse,
    required this.curatedHelper,
    required this.allHelper,
    required this.asmrOneHelper,
    required this.items,
    required this.visibleItems,
    required this.asmr18Helper,
    required this.sourceHelper,
  });

  final String discoverTitle;
  final String discoverSubtitle;
  final String curatedTitle;
  final String curatedSubtitle;
  final String sources;
  final String category;
  final String browse;
  final String curatedHelper;
  final String allHelper;
  final String asmrOneHelper;
  final String Function(int count) items;
  final String Function(int count) visibleItems;
  final String Function(String category) asmr18Helper;
  final String Function(String source) sourceHelper;

  static _HomeCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return _HomeCopy(
        discoverTitle: 'Temukan suara untuk suasanamu',
        discoverSubtitle:
            'Semua sumber aktif dapat dijelajahi dari satu feed tanpa memikirkan provider di baliknya.',
        curatedTitle: 'Pilihan untuk didengar sekarang',
        curatedSubtitle:
            'Kurasi ringan membantu kamu masuk ke pengalaman dengar tanpa banyak mencari.',
        sources: 'Sumber',
        category: 'Kategori',
        browse: 'Jelajahi karya',
        curatedHelper:
            'Feed Populer dan Rekomendasi memakai katalog ASMR.one agar urutan kurasi tetap konsisten.',
        allHelper:
            'Karya dari sumber aktif digabung dan identitas kanonis yang sama dideduplikasi otomatis.',
        asmrOneHelper:
            'ASMR.one menyediakan pengurutan dan metadata katalog paling lengkap.',
        items: (count) => '$count karya',
        visibleItems: (count) => '$count tampil',
        asmr18Helper: (category) => 'Menampilkan kategori $category dari ASMR+18.',
        sourceHelper: (source) => 'Menampilkan karya dari $source.',
      );
    }

    return _HomeCopy(
      discoverTitle: 'Find a sound for your mood',
      discoverSubtitle:
          'Browse every enabled source from one feed without thinking about the provider underneath.',
      curatedTitle: 'Something to listen to now',
      curatedSubtitle:
          'Light curation helps you start listening without spending time searching.',
      sources: 'Sources',
      category: 'Category',
      browse: 'Browse works',
      curatedHelper:
          'Popular and Recommended use the ASMR.one catalog to keep curation ordering consistent.',
      allHelper:
          'Works from enabled sources are merged and matching canonical identities are deduplicated.',
      asmrOneHelper: 'ASMR.one provides the richest sorting and catalog metadata.',
      items: (count) => '$count works',
      visibleItems: (count) => '$count visible',
      asmr18Helper: (category) => 'Showing the $category category from ASMR+18.',
      sourceHelper: (source) => 'Showing works from $source.',
    );
  }
}
