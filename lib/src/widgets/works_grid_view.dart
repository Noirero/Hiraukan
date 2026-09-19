import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work.dart';
import '../providers/work_card_display_provider.dart';
import '../providers/works_provider.dart';
import '../providers/auth_provider.dart';
import '../sources/unified_source_registry.dart';
import '../utils/responsive_grid_helper.dart';
import '../utils/work_cover_prefetch.dart';
import 'enhanced_work_card.dart';
import 'home_artwork_work_card.dart';
import 'unified_source_filter_bar.dart';
import 'unified_work_card.dart';
import 'virtualized_sliver_collection.dart';

class WorksGridView extends ConsumerWidget {
  const WorksGridView({
    super.key,
    required this.works,
    required this.layoutType,
    this.scrollController,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
    this.loadMoreError,
    this.onRefresh,
    this.onLoadMore,
    this.onRetry,
    this.onPrefetch,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.endBuilder,
    this.showEndMessage = false,
    this.pagination,
    this.pageStorageKey,
    this.padding,
    this.sliversBefore = const [],
    this.fillEmptyViewport = true,
    this.physics,
    this.showInlineLoadingIndicator = false,
    this.unifiedSourcesEnabled = false,
    this.showUnifiedSourceFilterBar = true,
  });

  final List<Work> works;
  final LayoutType layoutType;
  final ScrollController? scrollController;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
  final Object? loadMoreError;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLoadMore;
  final VoidCallback? onRetry;
  final ValueChanged<List<Work>>? onPrefetch;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final VirtualizedErrorBuilder? errorBuilder;
  final WidgetBuilder? endBuilder;
  final bool showEndMessage;
  final VirtualizedPagination? pagination;
  final PageStorageKey<String>? pageStorageKey;
  final EdgeInsetsGeometry? padding;
  final List<Widget> sliversBefore;
  final bool fillEmptyViewport;
  final ScrollPhysics? physics;
  final bool showInlineLoadingIndicator;

  /// Unified-source rendering is opt-in. Normal All/Popular/Recommended views
  /// must never change merely because the process-wide registry saw the same id
  /// during an earlier federated search.
  final bool unifiedSourcesEnabled;

  /// Search owns the multi-source filter bar. Home supplies its own source
  /// discovery surface, so it disables this automatic search bar. Home also
  /// uses this distinction to opt into the artwork-first card treatment.
  final bool showUnifiedSourceFilterBar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displaySettings = ref.watch(workCardDisplayProvider);
    final auth = ref.watch(
      authProvider.select((state) => (state.host ?? '', state.token ?? '')),
    );
    final hasUnifiedWorks = unifiedSourcesEnabled &&
        works.any((work) => UnifiedSourceRegistry.instance.contains(work.id));
    final effectiveSliversBefore = <Widget>[
      ...sliversBefore,
      if (showUnifiedSourceFilterBar && hasUnifiedWorks)
        const SliverToBoxAdapter(child: UnifiedSourceFilterBar()),
    ];
    final useHomeArtworkCards = !showUnifiedSourceFilterBar;

    return LayoutBuilder(builder: (context, constraints) {
      final mediaSize = MediaQuery.sizeOf(context);
      final availableWidth = constraints.hasBoundedWidth
          ? constraints.maxWidth.clamp(0.0, mediaSize.width).toDouble()
          : mediaSize.width;
      final availableHeight = constraints.hasBoundedHeight
          ? constraints.maxHeight.clamp(0.0, mediaSize.height).toDouble()
          : mediaSize.height;
      final isLandscape = availableWidth > availableHeight;
      // Keep the calmer Hiraukan spacing from the validated main UI refresh
      // while preserving Beta's artwork-first home cards.
      final spacing = isLandscape ? 20.0 : 12.0;
      final defaultPadding = spacing;
      final collectionPadding = padding ?? EdgeInsets.all(defaultPadding);
      final resolvedPadding =
          collectionPadding.resolve(Directionality.of(context));
      final horizontalPadding = resolvedPadding.horizontal / 2;
      final crossAxisCount = switch (layoutType) {
        LayoutType.bigGrid => displaySettings.applyCardSize(
            ResponsiveGridHelper.getBigGridCrossAxisCount(
              context,
              availableWidth: availableWidth,
              availableHeight: availableHeight,
              horizontalPadding: horizontalPadding,
              crossAxisSpacing: spacing,
            ),
          ),
        LayoutType.smallGrid => displaySettings.applyCardSize(
            ResponsiveGridHelper.getSmallGridCrossAxisCount(
              context,
              availableWidth: availableWidth,
              availableHeight: availableHeight,
              horizontalPadding: horizontalPadding,
              crossAxisSpacing: spacing,
            ),
            minCrossAxisCount: 2,
          ),
        LayoutType.list => 1,
      };
      final isGrid = layoutType != LayoutType.list;
      return VirtualizedSliverCollection<Work>(
        controller: scrollController,
        pageStorageKey: pageStorageKey,
        sliversBefore: effectiveSliversBefore,
        items: works,
        itemId: (work) => work.id,
        itemBuilder: (context, work, index) {
          if (unifiedSourcesEnabled &&
              UnifiedSourceRegistry.instance.contains(work.id)) {
            return UnifiedWorkCard(
              key: ValueKey('unified_${work.id}'),
              work: work,
              crossAxisCount: crossAxisCount,
              isListLayout: layoutType == LayoutType.list,
            );
          }
          if (useHomeArtworkCards) {
            return HomeArtworkWorkCard(
              key: ValueKey('home_${work.id}'),
              work: work,
              crossAxisCount: crossAxisCount,
              isListLayout: layoutType == LayoutType.list,
            );
          }
          return EnhancedWorkCard(
            key: ValueKey(work.id),
            work: work,
            crossAxisCount: crossAxisCount,
            isListLayout: layoutType == LayoutType.list,
          );
        },
        layout: isGrid
            ? VirtualizedCollectionLayout.masonry
            : VirtualizedCollectionLayout.list,
        masonryCrossAxisCount: isGrid ? crossAxisCount : null,
        masonryCrossAxisSpacing: spacing,
        masonryMainAxisSpacing: spacing,
        padding: collectionPadding,
        isInitialLoading: isLoading && works.isEmpty,
        isRefreshing: isRefreshing,
        isLoadingMore: isLoadingMore,
        hasMore: hasMore,
        error: works.isEmpty ? error : null,
        loadMoreError: loadMoreError,
        onRefresh: onRefresh,
        onLoadMore: onLoadMore,
        pagination: pagination?.copyWith(
          padding: EdgeInsets.fromLTRB(
            resolvedPadding.left,
            spacing,
            resolvedPadding.right,
            24,
          ),
        ),
        onRetry: onRetry,
        onPrefetch: (items) {
          final normalItems = unifiedSourcesEnabled
              ? items
                  .where(
                    (work) =>
                        !UnifiedSourceRegistry.instance.contains(work.id),
                  )
                  .toList(growable: false)
              : items;
          if (normalItems.isNotEmpty) {
            prefetchWorkCovers(
              context,
              normalItems,
              host: auth.$1,
              token: auth.$2,
              crossAxisCount: crossAxisCount,
              isListCard: layoutType == LayoutType.list,
            );
          }
          onPrefetch?.call(items);
        },
        emptyBuilder: emptyBuilder,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
        endBuilder: endBuilder,
        showEndIndicator:
            pagination == null && showEndMessage && works.isNotEmpty,
        fillEmptyViewport: fillEmptyViewport,
        physics: physics,
        collectionTrailingBuilder:
            (onLoadMore != null && hasMore) || showInlineLoadingIndicator
                ? (context) => isGrid
                    ? const SizedBox(
                        height: 100,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                : null,
      );
    });
  }
}
