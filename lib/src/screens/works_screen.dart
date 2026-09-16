import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../models/sort_options.dart';
import '../providers/works_provider.dart';
import '../utils/l10n_extensions.dart';
import '../utils/scroll_optimization.dart';
import '../utils/subtitle_filter.dart';
import '../utils/system_ui_style.dart';
import '../utils/ui_tokens.dart';
import '../widgets/async_state_view.dart';
import '../widgets/download_fab.dart';
import '../widgets/floating_feed_toolbar.dart';
import '../widgets/home_source_filter_bar.dart';
import '../widgets/sort_dialog.dart';
import '../widgets/virtualized_sliver_collection.dart';
import '../widgets/works_grid_view.dart';
import '../utils/snackbar_util.dart';

class WorksScreen extends ConsumerStatefulWidget {
  const WorksScreen({super.key});

  @override
  ConsumerState<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends ConsumerState<WorksScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<String, double> _scrollPositions = <String, double>{};
  int _slideDirection = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final worksState = ref.read(worksProvider);
      if (!worksState.hasLoaded && !worksState.isLoading) {
        ref.read(worksProvider.notifier).loadWorks(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSortDialog(BuildContext context) {
    final state = ref.read(worksProvider);
    final isRecommendMode = state.displayMode == DisplayMode.popular ||
        state.displayMode == DisplayMode.recommended;

    if (isRecommendMode) {
      SnackBarUtil.showInfo(
        context,
        state.displayMode == DisplayMode.popular
            ? S.of(context).popularNoSort
            : S.of(context).recommendedNoSort,
      );
      return;
    }
    if (!state.canSortBrowse) {
      SnackBarUtil.showInfo(
        context,
        'Pengurutan tersedia untuk feed ASMR.one. Pilih ASMR.one untuk mengurutkan.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CommonSortDialog(
        currentOption: state.sortOption,
        currentDirection: state.sortDirection,
        availableOptions: SortOrder.values
            .where((option) => option != SortOrder.updatedAt)
            .toList(),
        onSort: (option, direction) {
          ref.read(worksProvider.notifier).setSortOption(option);
          ref.read(worksProvider.notifier).setSortDirection(direction);
        },
        autoClose: true,
      ),
    );
  }

  IconData _getLayoutIcon(LayoutType layoutType) {
    switch (layoutType) {
      case LayoutType.bigGrid:
        return Icons.grid_3x3;
      case LayoutType.smallGrid:
        return Icons.view_list;
      case LayoutType.list:
        return Icons.view_agenda;
    }
  }

  String _getLayoutTooltip(LayoutType layoutType) {
    switch (layoutType) {
      case LayoutType.bigGrid:
        return S.of(context).switchToSmallGrid;
      case LayoutType.smallGrid:
        return S.of(context).switchToList;
      case LayoutType.list:
        return S.of(context).switchToLargeGrid;
    }
  }

  IconData _getSubtitleFilterIcon(int subtitleFilter) {
    final mode = SubtitleFilterMode.fromValue(subtitleFilter);
    return mode == SubtitleFilterMode.withSubtitles
        ? Icons.closed_caption
        : Icons.closed_caption_disabled;
  }

  void _changeDisplayMode(DisplayMode mode) {
    ref.read(worksProvider.notifier).setDisplayMode(mode);
  }

  void _restoreScrollPosition(String feedKey) {
    final targetOffset = _scrollPositions[feedKey] ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      final safeMax = maxExtent.isFinite ? maxExtent : targetOffset;
      _scrollController.jumpTo(targetOffset.clamp(0.0, safeMax).toDouble());
    });
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity;
    if (velocity == null || velocity.abs() < 500) return;

    final worksState = ref.read(worksProvider);
    if (!worksState.curatedModesAvailable) return;

    if (velocity < 0) {
      if (worksState.displayMode == DisplayMode.all) {
        _changeDisplayMode(DisplayMode.popular);
      } else if (worksState.displayMode == DisplayMode.popular) {
        _changeDisplayMode(DisplayMode.recommended);
      }
    } else {
      if (worksState.displayMode == DisplayMode.recommended) {
        _changeDisplayMode(DisplayMode.popular);
      } else if (worksState.displayMode == DisplayMode.popular) {
        _changeDisplayMode(DisplayMode.all);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<WorksState>(
      worksProvider,
      (previous, next) {
        if (!mounted || previous == null) return;
        if (previous.activeFeedKey == next.activeFeedKey) return;

        if (_scrollController.hasClients) {
          _scrollPositions[previous.activeFeedKey] = _scrollController.offset;
        }

        final prevIndex = DisplayMode.values.indexOf(previous.displayMode);
        final nextIndex = DisplayMode.values.indexOf(next.displayMode);
        setState(() {
          _slideDirection = previous.displayMode == next.displayMode
              ? 0
              : (nextIndex >= prevIndex ? 1 : -1);
        });
        _restoreScrollPosition(next.activeFeedKey);
      },
    );

    final worksState = ref.watch(worksProvider);
    final isRecommendMode = worksState.displayMode == DisplayMode.popular ||
        worksState.displayMode == DisplayMode.recommended;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final horizontalPadding = FloatingToolbarLayout.horizontalPadding(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final headerTop = topPadding + 10;
    const headerHeight = 50.0;
    final toolbarTop = headerTop + headerHeight + 4;
    final contentTopPadding = toolbarTop + 56;
    final systemOverlayStyle =
        transparentSystemBarsForBrightness(theme.brightness);

    return AnnotatedRegion(
      value: systemOverlayStyle,
      child: Scaffold(
        floatingActionButton: const DownloadFab(),
        body: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scheme.primary.withValues(
                          alpha: isDark ? 0.085 : 0.045,
                        ),
                        scheme.surface.withValues(alpha: 0),
                        scheme.surface,
                      ],
                      stops: const [0, 0.34, 1],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                onHorizontalDragEnd: _handleSwipe,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    final direction = _slideDirection == 0
                        ? 0.0
                        : (_slideDirection > 0 ? 0.12 : -0.12);
                    final offsetAnimation = Tween<Offset>(
                      begin: Offset(direction, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(worksState.activeFeedKey),
                    child: _buildBody(
                      worksState,
                      horizontalPadding: horizontalPadding,
                      contentTopPadding: contentTopPadding,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ProgressiveTopScrim(height: toolbarTop + 52),
            ),
            Positioned(
              top: headerTop,
              left: horizontalPadding + 4,
              right: horizontalPadding + 4,
              height: headerHeight,
              child: _HiraukanHomeHeader(
                primary: scheme.primary,
                foreground: scheme.onSurface,
                secondary: scheme.onSurfaceVariant,
              ),
            ),
            Positioned(
              top: toolbarTop,
              left: horizontalPadding,
              right: horizontalPadding,
              child: FloatingFeedToolbar(
                collapseModesWhenNeeded: false,
                modeActions: _buildModeActions(context, worksState),
                toolActions: _buildToolActions(
                  context,
                  worksState,
                  isRecommendMode: isRecommendMode,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FloatingFeedModeAction> _buildModeActions(
    BuildContext context,
    WorksState worksState,
  ) {
    final actions = <FloatingFeedModeAction>[
      FloatingFeedModeAction(
        icon: Icons.grid_view,
        label: S.of(context).displayModeAll,
        isSelected: worksState.displayMode == DisplayMode.all,
        onPressed: () => _changeDisplayMode(DisplayMode.all),
      ),
    ];
    if (!worksState.curatedModesAvailable) return actions;

    actions.addAll([
      FloatingFeedModeAction(
        icon: Icons.local_fire_department,
        label: S.of(context).displayModePopular,
        isSelected: worksState.displayMode == DisplayMode.popular,
        onPressed: () => _changeDisplayMode(DisplayMode.popular),
      ),
      FloatingFeedModeAction(
        icon: Icons.auto_awesome,
        label: S.of(context).displayModeRecommended,
        isSelected: worksState.displayMode == DisplayMode.recommended,
        onPressed: () => _changeDisplayMode(DisplayMode.recommended),
      ),
    ]);
    return actions;
  }

  List<FloatingFeedToolAction> _buildToolActions(
    BuildContext context,
    WorksState worksState, {
    required bool isRecommendMode,
  }) {
    final subtitleMode =
        SubtitleFilterMode.fromValue(worksState.subtitleFilter);
    final sortEnabled = !isRecommendMode && worksState.canSortBrowse;
    return [
      FloatingFeedToolAction(
        icon: _getLayoutIcon(worksState.layoutType),
        tooltip: _getLayoutTooltip(worksState.layoutType),
        onPressed: () => ref.read(worksProvider.notifier).toggleLayoutType(),
      ),
      FloatingFeedToolAction(
        icon: _getSubtitleFilterIcon(worksState.subtitleFilter),
        tooltip: subtitleMode.localizedTooltip(context),
        isSelected: subtitleMode.isActive,
        onPressed: () =>
            ref.read(worksProvider.notifier).toggleSubtitleFilter(),
      ),
      FloatingFeedToolAction(
        icon: Icons.sort,
        tooltip: isRecommendMode
            ? S.of(context).recommendedNoSort
            : sortEnabled
                ? S.of(context).sort
                : 'Pengurutan hanya untuk feed ASMR.one',
        onPressed: sortEnabled ? () => _showSortDialog(context) : null,
      ),
    ];
  }

  Widget _buildBody(
    WorksState worksState, {
    required double horizontalPadding,
    required double contentTopPadding,
  }) {
    return _buildLayoutView(
      worksState,
      horizontalPadding: horizontalPadding,
      contentTopPadding: contentTopPadding,
    );
  }

  Widget _buildLayoutView(
    WorksState worksState, {
    required double horizontalPadding,
    required double contentTopPadding,
  }) {
    final notifier = ref.read(worksProvider.notifier);
    return WorksGridView(
      works: worksState.works,
      layoutType: worksState.layoutType,
      scrollController: _scrollController,
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        12,
        horizontalPadding,
        horizontalPadding,
      ),
      sliversBefore: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              contentTopPadding,
              horizontalPadding,
              8,
            ),
            child: const HomeSourceFilterBar(),
          ),
        ),
      ],
      unifiedSourcesEnabled: worksState.usesUnifiedBrowse,
      showUnifiedSourceFilterBar: false,
      physics: ScrollOptimization.physics,
      isLoading: worksState.isLoading,
      isRefreshing: worksState.isLoading && worksState.works.isNotEmpty,
      isLoadingMore: worksState.isLoadingMore,
      hasMore: worksState.hasMore,
      error: worksState.error,
      loadMoreError: worksState.loadMoreError,
      onLoadMore:
          worksState.displayMode == DisplayMode.all ? null : notifier.loadMore,
      onRetry: notifier.refresh,
      onRefresh: worksState.works.isEmpty ? null : notifier.refresh,
      pagination: worksState.displayMode == DisplayMode.all
          ? VirtualizedPagination(
              currentPage: worksState.currentPage,
              pageSize: worksState.pageSize,
              totalCount: worksState.totalCount,
              hasMore: worksState.hasMore,
              isLoading: worksState.isLoading || worksState.isRefreshing,
              onPreviousPage: notifier.previousPage,
              onNextPage: notifier.nextPage,
              onGoToPage: notifier.goToPage,
              nextPageOnOverscroll: true,
              scrollDuration: const Duration(milliseconds: 500),
              scrollCurve: Curves.easeInOut,
              extraBuilder: worksState.rawWorks.length > worksState.works.length
                  ? (context) => Text(
                        S.of(context).pageExcludedNWorks(
                              worksState.rawWorks.length -
                                  worksState.works.length,
                            ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      )
                  : null,
            )
          : null,
      showEndMessage:
          worksState.displayMode != DisplayMode.all && worksState.isLastPage,
      loadingBuilder: (context) => AsyncStateView(
        icon: const CircularProgressIndicator(),
        message: Text(S.of(context).loading),
        iconToTitleSpacing: UiSpacing.large,
      ),
      errorBuilder: (context, error, retry) => AsyncStateView(
        icon: Icon(
          Icons.error_outline,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          S.of(context).loadFailed,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        message: Text(
          error.toString(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        action: ElevatedButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: Text(S.of(context).retry),
        ),
      ),
      emptyBuilder: (context) => AsyncStateView(
        icon: Icon(
          worksState.safetyMode == AsmrSafetyMode.sfw
              ? Icons.eco_outlined
              : Icons.audiotrack,
          size: 64,
          color: Theme.of(context).colorScheme.outline,
        ),
        title: Text(
          S.of(context).noWorks,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        message: Text(
          worksState.safetyMode == AsmrSafetyMode.sfw
              ? 'Tidak ada karya dengan metadata SFW yang terverifikasi pada halaman ini.'
              : S.of(context).checkNetworkOrRetry,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ),
      endBuilder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  S.of(context).reachedEnd,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (worksState.rawWorks.length > worksState.works.length) ...[
              const SizedBox(height: 8),
              Text(
                S.of(context).excludedNWorks(
                      worksState.rawWorks.length - worksState.works.length,
                    ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HiraukanHomeHeader extends StatelessWidget {
  const _HiraukanHomeHeader({
    required this.primary,
    required this.foreground,
    required this.secondary,
  });

  final Color primary;
  final Color foreground;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary.withValues(alpha: 0.22)),
          ),
          child: Icon(Icons.graphic_eq_rounded, color: primary, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hiraukan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
              ),
              const SizedBox(height: 1),
              Text(
                'Lebih dari sekadar suara.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: secondary,
                      fontSize: 11.5,
                      letterSpacing: 0.15,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
