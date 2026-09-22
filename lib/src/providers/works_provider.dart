import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';

import '../extensions/audio_extension_provider.dart';
import '../models/work.dart';
import '../models/sort_options.dart';
import '../services/kikoeru_api_service.dart' hide kikoeruApiServiceProvider;
import '../services/log_service.dart';
import '../sources/unified_source_models.dart';
import '../sources/unified_source_provider.dart';
import '../utils/paged_collection.dart';
import '../utils/persistent_enum_preference.dart';
import '../utils/subtitle_filter.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'subtitle_library_provider.dart';

final _log = LogService.instance;

enum DisplayMode {
  all('all', '全部作品'),
  popular('popular', '热门推荐'),
  recommended('recommended', '推荐');

  const DisplayMode(this.value, this.label);
  final String value;
  final String label;
}

enum LayoutType {
  list,
  smallGrid,
  bigGrid,
}

enum HomeSourceFilter {
  all,
  asmrOne,
  hentaiAsmr,
  japaneseAsmr,
  asmr18,
  eroVoice,
  asmrHentaiNet,
}

extension HomeSourceFilterX on HomeSourceFilter {
  String get label => switch (this) {
        HomeSourceFilter.all => 'Semua Sumber',
        HomeSourceFilter.asmrOne => 'ASMR.one',
        HomeSourceFilter.hentaiAsmr => 'HentaiASMR',
        HomeSourceFilter.japaneseAsmr => 'JapaneseASMR',
        HomeSourceFilter.asmr18 => 'ASMR+18',
        HomeSourceFilter.eroVoice => 'EroVoice',
        HomeSourceFilter.asmrHentaiNet => 'ASMR Hentai',
      };

  UnifiedSourceKind? get unifiedSource => switch (this) {
        HomeSourceFilter.all => null,
        HomeSourceFilter.asmrOne => UnifiedSourceKind.asmrOne,
        HomeSourceFilter.hentaiAsmr => UnifiedSourceKind.hentaiAsmr,
        HomeSourceFilter.japaneseAsmr => UnifiedSourceKind.japaneseAsmr,
        HomeSourceFilter.asmr18 => UnifiedSourceKind.asmr18,
        HomeSourceFilter.eroVoice => UnifiedSourceKind.eroVoice,
        HomeSourceFilter.asmrHentaiNet => UnifiedSourceKind.asmrHentaiNet,
      };

  String? get extensionId => switch (this) {
        HomeSourceFilter.all => null,
        HomeSourceFilter.asmrOne => 'miyorare.audio.asmr_one',
        HomeSourceFilter.hentaiAsmr => 'miyorare.audio.hentai_asmr',
        HomeSourceFilter.japaneseAsmr => 'miyorare.audio.japanese_asmr',
        HomeSourceFilter.asmr18 => 'miyorare.audio.asmr18',
        HomeSourceFilter.eroVoice => 'miyorare.audio.ero_voice',
        HomeSourceFilter.asmrHentaiNet => 'miyorare.audio.asmr_hentai_net',
      };

  bool isAvailableIn(Set<String> enabledExtensionIds) =>
      extensionId == null || enabledExtensionIds.contains(extensionId);

  bool get supportsCuratedModes =>
      this == HomeSourceFilter.all || this == HomeSourceFilter.asmrOne;
}

List<HomeSourceFilter> availableHomeSourceFilters(
  Set<String> enabledExtensionIds,
) {
  return HomeSourceFilter.values
      .where((source) => source.isAvailableIn(enabledExtensionIds))
      .toList(growable: false);
}

class WorksModeSnapshot extends Equatable {
  static const _noValue = Object();

  final List<Work> works;
  final List<Work> rawWorks;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool hasLoaded;
  final String? error;
  final String? loadMoreError;
  final int currentPage;
  final int totalCount;
  final bool hasMore;
  final bool isLastPage;

  const WorksModeSnapshot({
    this.works = const [],
    this.rawWorks = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasLoaded = false,
    this.error,
    this.loadMoreError,
    this.currentPage = 1,
    this.totalCount = 0,
    this.hasMore = true,
    this.isLastPage = false,
  });

  WorksModeSnapshot copyWith({
    List<Work>? works,
    List<Work>? rawWorks,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasLoaded,
    Object? error = _noValue,
    Object? loadMoreError = _noValue,
    int? currentPage,
    int? totalCount,
    bool? hasMore,
    bool? isLastPage,
  }) {
    return WorksModeSnapshot(
      works: works ?? this.works,
      rawWorks: rawWorks ?? this.rawWorks,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      error: error == _noValue ? this.error : error as String?,
      loadMoreError: loadMoreError == _noValue
          ? this.loadMoreError
          : loadMoreError as String?,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLastPage: isLastPage ?? this.isLastPage,
    );
  }

  @override
  List<Object?> get props => [
        works,
        rawWorks,
        isLoading,
        isRefreshing,
        isLoadingMore,
        hasLoaded,
        error,
        loadMoreError,
        currentPage,
        totalCount,
        hasMore,
        isLastPage,
      ];
}

class WorksState extends Equatable {
  final LayoutType layoutType;
  final SortOrder sortOption;
  final SortDirection sortDirection;
  final DisplayMode displayMode;
  final HomeSourceFilter sourceFilter;
  final Map<UnifiedSourceKind, UnifiedSourceHealth> sourceHealth;
  final int subtitleFilter;
  final int basePageSize;
  final Map<String, WorksModeSnapshot> modeStates;

  const WorksState({
    this.layoutType = LayoutType.bigGrid,
    this.sortOption = SortOrder.release,
    this.sortDirection = SortDirection.desc,
    this.displayMode = DisplayMode.all,
    this.sourceFilter = HomeSourceFilter.all,
    this.sourceHealth = const {},
    this.subtitleFilter = 0,
    this.basePageSize = 40,
    Map<String, WorksModeSnapshot>? modeStates,
  }) : modeStates = modeStates ?? const {};

  int get pageSize => SubtitleFilterMode.fromValue(subtitleFilter).isActive
      ? basePageSize * 2
      : basePageSize;

  String get activeFeedKey => '${displayMode.name}|${sourceFilter.name}';

  WorksModeSnapshot get _currentModeState =>
      modeStates[activeFeedKey] ?? const WorksModeSnapshot();

  List<Work> get works => _currentModeState.works;
  List<Work> get rawWorks => _currentModeState.rawWorks;
  bool get isLoading => _currentModeState.isLoading;
  bool get isRefreshing => _currentModeState.isRefreshing;
  bool get isLoadingMore => _currentModeState.isLoadingMore;
  bool get hasLoaded => _currentModeState.hasLoaded;
  String? get error => _currentModeState.error;
  String? get loadMoreError => _currentModeState.loadMoreError;
  int get currentPage => _currentModeState.currentPage;
  int get totalCount => _currentModeState.totalCount;
  bool get hasMore => _currentModeState.hasMore;
  bool get isLastPage => _currentModeState.isLastPage;

  bool get curatedModesAvailable => sourceFilter.supportsCuratedModes;

  bool get usesUnifiedBrowse =>
      displayMode == DisplayMode.all && sourceFilter != HomeSourceFilter.asmrOne;

  bool get canSortBrowse => displayMode == DisplayMode.all && !usesUnifiedBrowse;

  WorksState copyWith({
    LayoutType? layoutType,
    SortOrder? sortOption,
    SortDirection? sortDirection,
    DisplayMode? displayMode,
    HomeSourceFilter? sourceFilter,
    Map<UnifiedSourceKind, UnifiedSourceHealth>? sourceHealth,
    int? subtitleFilter,
    int? basePageSize,
    Map<String, WorksModeSnapshot>? modeStates,
  }) {
    return WorksState(
      layoutType: layoutType ?? this.layoutType,
      sortOption: sortOption ?? this.sortOption,
      sortDirection: sortDirection ?? this.sortDirection,
      displayMode: displayMode ?? this.displayMode,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      sourceHealth: sourceHealth ?? this.sourceHealth,
      subtitleFilter: subtitleFilter ?? this.subtitleFilter,
      basePageSize: basePageSize ?? this.basePageSize,
      modeStates: modeStates ?? this.modeStates,
    );
  }

  @override
  List<Object?> get props => [
        layoutType,
        sortOption,
        sortDirection,
        displayMode,
        sourceFilter,
        sourceHealth,
        subtitleFilter,
        basePageSize,
        modeStates,
      ];
}

class WorksNotifier extends StateNotifier<WorksState> {
  static const String layoutPreferenceKey = 'works_layout_type';
  static const String sourcePreferenceKey = 'home_unified_source_filter';

  final KikoeruApiService _apiService;
  final Ref _ref;
  final _layoutPreference = PersistentEnumPreference<LayoutType>(
    key: layoutPreferenceKey,
    values: LayoutType.values,
    fallback: LayoutType.bigGrid,
  );
  final _sourcePreference = PersistentEnumPreference<HomeSourceFilter>(
    key: sourcePreferenceKey,
    values: HomeSourceFilter.values,
    fallback: HomeSourceFilter.all,
  );
  final Map<String, PagedRequestGate> _requestGates = {};
  int _catalogGeneration = 0;

  WorksNotifier(
    this._apiService,
    this._ref, {
    int initialPageSize = 40,
    SortOrder initialSortOption = SortOrder.release,
    SortDirection initialSortDirection = SortDirection.desc,
  }) : super(WorksState(
          basePageSize: initialPageSize,
          sortOption: initialSortOption,
          sortDirection: initialSortDirection,
        )) {
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    final values = await Future.wait<Object?>([
      _layoutPreference.load(),
      _sourcePreference.load(),
    ]);
    if (!mounted) return;

    final layout = values[0] as LayoutType? ?? LayoutType.bigGrid;
    final loadedSource =
        values[1] as HomeSourceFilter? ?? HomeSourceFilter.all;
    final enabledExtensionIds = _ref
        .read(audioExtensionRegistryProvider)
        .extensions
        .map((extension) => extension.manifest.id)
        .toSet();
    final source = loadedSource.isAvailableIn(enabledExtensionIds)
        ? loadedSource
        : HomeSourceFilter.all;

    final oldKey = state.activeFeedKey;
    state = state.copyWith(
      layoutType: layout,
      sourceFilter: source,
      displayMode: source.supportsCuratedModes
          ? state.displayMode
          : DisplayMode.all,
    );
    if (state.activeFeedKey != oldKey && !state.hasLoaded && !state.isLoading) {
      unawaited(loadWorks(targetPage: 1, supersede: true));
    }
  }

  PagedRequestGate _requestGateFor(String feedKey) =>
      _requestGates.putIfAbsent(feedKey, PagedRequestGate.new);

  WorksModeSnapshot _getFeedState(String feedKey) =>
      state.modeStates[feedKey] ?? const WorksModeSnapshot();

  void _updateFeedState(
    String feedKey,
    WorksModeSnapshot Function(WorksModeSnapshot current) updater,
  ) {
    final updatedStates =
        Map<String, WorksModeSnapshot>.from(state.modeStates);
    updatedStates[feedKey] = updater(_getFeedState(feedKey));
    state = state.copyWith(modeStates: updatedStates);
  }

  void _updateActiveFeedState(
    WorksModeSnapshot Function(WorksModeSnapshot current) updater,
  ) {
    _updateFeedState(state.activeFeedKey, updater);
  }

  void updatePageSize(int newSize) {
    if (state.basePageSize == newSize) return;
    state = state.copyWith(basePageSize: newSize, modeStates: const {});
    _requestGates.clear();
    _catalogGeneration++;
    unawaited(loadWorks(targetPage: 1, supersede: true));
  }

  Set<UnifiedSourceKind> _enabledUnifiedSources(HomeSourceFilter source) {
    if (source.unifiedSource case final selected?) return {selected};
    return UnifiedSourceKind.values.toSet();
  }

  bool _usesUnifiedBrowse(DisplayMode mode, HomeSourceFilter source) {
    return mode == DisplayMode.all && source != HomeSourceFilter.asmrOne;
  }

  Future<void> loadWorks({
    bool refresh = false,
    int? targetPage,
    bool append = false,
    bool supersede = false,
  }) async {
    final mode = state.displayMode;
    final source = state.sourceFilter;
    final feedKey = state.activeFeedKey;
    final generation = _catalogGeneration;
    final modeState = _getFeedState(feedKey);
    final requestGate = _requestGateFor(feedKey);
    final requestToken = requestGate.begin(supersede: supersede);

    if (requestToken == null) {
      _log.captureOutput('[WorksProvider] Already loading $feedKey, skipping');
      return;
    }

    final previousPage = modeState.currentPage;
    final isAllMode = mode == DisplayMode.all;
    final page = targetPage ??
        (isAllMode ? previousPage : (refresh ? 1 : previousPage + 1));
    final shouldAppend = !isAllMode && page > 1;

    _updateFeedState(
      feedKey,
      (snapshot) => snapshot.copyWith(
        isLoading: true,
        isRefreshing: !append,
        isLoadingMore: append,
        error: null,
        loadMoreError: null,
      ),
    );

    try {
      final pageSize = state.pageSize;
      final sortOption = state.sortOption;
      final sortDirection = state.sortDirection;
      const serverSubtitleParam = 0;
      final unifiedBrowse = _usesUnifiedBrowse(mode, source);

      List<Work> incomingWorks;
      int totalCount;
      int currentPage = page;
      bool hasMore;
      late Map<UnifiedSourceKind, UnifiedSourceHealth> health;

      if (unifiedBrowse) {
        final result = await _ref.read(unifiedSourceServiceProvider).search(
              keyword: '',
              page: page,
              pageSize: pageSize,
              enabledSources: _enabledUnifiedSources(source),
            );
        incomingWorks = result.works;
        totalCount = result.totalCount;
        hasMore = result.hasMore;
        health = result.health;
      } else {
        Map<String, dynamic> response;
        if (mode == DisplayMode.popular) {
          response = await _apiService.getPopularWorks(
            page: page,
            pageSize: pageSize,
            subtitle: serverSubtitleParam,
          );
        } else if (mode == DisplayMode.recommended) {
          final currentUser = _ref.read(authProvider).currentUser;
          final recommenderUuid = currentUser?.recommenderUuid ??
              '766cc58d-7f1e-4958-9a93-913400f378dc';
          response = await _apiService.getRecommendedWorks(
            recommenderUuid: recommenderUuid,
            page: page,
            pageSize: pageSize,
            subtitle: serverSubtitleParam,
          );
        } else {
          response = await _apiService.getWorks(
            page: page,
            order: sortOption.value,
            sort: sortOption == SortOrder.nsfw ? 'asc' : sortDirection.value,
            subtitle: serverSubtitleParam,
            pageSize: pageSize,
          );
        }

        final worksData = response['works'] as List<dynamic>?;
        final pagination = response['pagination'] as Map<String, dynamic>?;
        if (worksData == null) throw Exception('No works data in response');
        incomingWorks = worksData
            .map((workJson) =>
                Work.fromJson(Map<String, dynamic>.from(workJson as Map)))
            .toList(growable: false);
        totalCount = (pagination?['totalCount'] as num?)?.toInt() ?? 0;
        currentPage =
            (pagination?['currentPage'] as num?)?.toInt() ?? page;
        hasMore = (currentPage * pageSize) < totalCount;
        health = Map<UnifiedSourceKind, UnifiedSourceHealth>.from(
          state.sourceHealth,
        )..[UnifiedSourceKind.asmrOne] = UnifiedSourceHealth.healthy;
      }

      if (generation != _catalogGeneration ||
          !requestGate.isCurrent(requestToken)) {
        return;
      }

      final latestModeState = _getFeedState(feedKey);
      final newRawWorks = mergePagedItems<Work, int>(
        existing: shouldAppend ? latestModeState.rawWorks : const [],
        incoming: incomingWorks,
        idOf: (work) => work.id,
        replace: !shouldAppend,
      );
      final blockedItems = _ref.read(blockedItemsProvider);
      final filteredWorks = _filterWorks(newRawWorks, blockedItems);

      var isLastPage = false;
      if (mode == DisplayMode.popular || mode == DisplayMode.recommended) {
        final currentTotal = filteredWorks.length;
        hasMore = incomingWorks.length >= pageSize &&
            currentTotal < 100 &&
            currentTotal < totalCount;
        isLastPage = !hasMore && filteredWorks.isNotEmpty;
      } else {
        isLastPage = !hasMore && filteredWorks.isNotEmpty;
      }

      _updateFeedState(
        feedKey,
        (snapshot) => snapshot.copyWith(
          works: filteredWorks,
          rawWorks: newRawWorks,
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          hasLoaded: true,
          currentPage: currentPage,
          totalCount: totalCount,
          hasMore: hasMore,
          isLastPage: isLastPage,
          error: null,
          loadMoreError: null,
        ),
      );
      if (state.activeFeedKey == feedKey) {
        state = state.copyWith(sourceHealth: health);
      }
    } catch (e) {
      if (generation != _catalogGeneration ||
          !requestGate.isCurrent(requestToken)) {
        return;
      }
      _log.captureOutput('Failed to load works for $feedKey: $e');
      final message = '加载失败: ${e.toString()}';
      _updateFeedState(
        feedKey,
        (snapshot) => snapshot.copyWith(
          isLoading: false,
          isRefreshing: false,
          isLoadingMore: false,
          error: append ? null : message,
          loadMoreError: append ? message : null,
        ),
      );
      if (state.activeFeedKey == feedKey &&
          !_usesUnifiedBrowse(mode, source)) {
        final health = Map<UnifiedSourceKind, UnifiedSourceHealth>.from(
          state.sourceHealth,
        )..[UnifiedSourceKind.asmrOne] = UnifiedSourceHealth.broken;
        state = state.copyWith(sourceHealth: health);
      }
    } finally {
      requestGate.complete(requestToken);
    }
  }

  Future<void> refresh({bool resetPage = false}) async {
    await loadWorks(
      targetPage: resetPage ? 1 : state.currentPage,
      supersede: true,
    );
  }

  Future<void> loadMore() async {
    final modeState = _getFeedState(state.activeFeedKey);
    if (modeState.isLoading || !modeState.hasMore) return;
    await loadWorks(
      targetPage: modeState.currentPage + 1,
      append: true,
    );
  }

  Future<void> goToPage(int page) async {
    if (state.displayMode != DisplayMode.all || page < 1) return;
    final maxPage = (state.totalCount / state.pageSize).ceil();
    if (page > maxPage && maxPage > 0) return;
    await loadWorks(targetPage: page);
  }

  Future<void> nextPage() async {
    if (state.displayMode != DisplayMode.all ||
        !state.hasMore ||
        state.isLoading) {
      return;
    }
    await loadWorks(targetPage: state.currentPage + 1);
  }

  Future<void> previousPage() async {
    if (state.displayMode != DisplayMode.all ||
        state.currentPage <= 1 ||
        state.isLoading) {
      return;
    }
    await loadWorks(targetPage: state.currentPage - 1);
  }

  void setSortOption(SortOrder option) {
    if (state.sortOption == option) return;
    state = state.copyWith(sortOption: option);
    if (state.canSortBrowse) unawaited(refresh(resetPage: true));
  }

  void setSortDirection(SortDirection direction) {
    if (state.sortDirection == direction) return;
    state = state.copyWith(sortDirection: direction);
    if (state.canSortBrowse) unawaited(refresh(resetPage: true));
  }

  void toggleSortDirection() {
    setSortDirection(
      state.sortDirection == SortDirection.asc
          ? SortDirection.desc
          : SortDirection.asc,
    );
  }

  void setLayoutType(LayoutType layoutType) {
    if (state.layoutType == layoutType) return;
    state = state.copyWith(layoutType: layoutType);
    unawaited(_layoutPreference.save(layoutType));
  }

  void toggleLayoutType() {
    final newLayoutType = switch (state.layoutType) {
      LayoutType.bigGrid => LayoutType.smallGrid,
      LayoutType.smallGrid => LayoutType.list,
      LayoutType.list => LayoutType.bigGrid,
    };
    setLayoutType(newLayoutType);
  }

  void clearError() {
    _updateActiveFeedState((feedState) => feedState.copyWith(error: null));
  }

  void setDisplayMode(DisplayMode mode) {
    if (state.displayMode == mode) return;
    if (mode != DisplayMode.all && !state.curatedModesAvailable) return;
    state = state.copyWith(displayMode: mode);
    _loadCurrentFeedIfNeeded();
  }

  void setSourceFilter(HomeSourceFilter source) {
    if (state.sourceFilter == source) return;
    final displayMode = source.supportsCuratedModes
        ? state.displayMode
        : DisplayMode.all;
    state = state.copyWith(sourceFilter: source, displayMode: displayMode);
    unawaited(_sourcePreference.save(source));
    _loadCurrentFeedIfNeeded();
  }

  void _loadCurrentFeedIfNeeded() {
    final target = _getFeedState(state.activeFeedKey);
    if (!target.hasLoaded && !target.isLoading) {
      unawaited(loadWorks(targetPage: 1, supersede: true));
    }
  }

  bool get isSubtitleFilterActive =>
      SubtitleFilterMode.fromValue(state.subtitleFilter).isActive;

  void toggleSubtitleFilter() {
    final currentPage = state.currentPage;
    final oldFilterMode = SubtitleFilterMode.fromValue(state.subtitleFilter);
    final newFilterMode = oldFilterMode.next;
    var newPage = currentPage;
    if (oldFilterMode == SubtitleFilterMode.all && newFilterMode.isActive) {
      newPage = ((currentPage + 1) / 2).ceil();
    } else if (oldFilterMode.isActive &&
        newFilterMode == SubtitleFilterMode.all) {
      newPage = (currentPage * 2) - 1;
    }
    newPage = newPage.clamp(1, 9999);
    state = state.copyWith(subtitleFilter: newFilterMode.value);
    reapplyFilters();
    unawaited(loadWorks(targetPage: newPage, supersede: true));
  }

  void reapplyFilters() {
    final blockedItems = _ref.read(blockedItemsProvider);
    final updatedStates = state.modeStates.map((key, snapshot) {
      return MapEntry(
        key,
        snapshot.copyWith(works: _filterWorks(snapshot.rawWorks, blockedItems)),
      );
    });
    state = state.copyWith(modeStates: updatedStates);
  }

  List<Work> _filterWorks(List<Work> works, BlockedItemsState blockedItems) {
    final localSubtitleIds = _ref.read(subtitleLibraryProvider);
    final subtitleFilteredWorks = filterWorksBySubtitleMode(
      works,
      localSubtitleIds,
      state.subtitleFilter,
    );

    return subtitleFilteredWorks.where((work) {
      if (work.tags != null) {
        for (final tag in work.tags!) {
          if (blockedItems.tags.contains(tag.name)) return false;
        }
      }
      if (work.vas != null) {
        for (final va in work.vas!) {
          if (blockedItems.cvs.contains(va.name)) return false;
        }
      }
      if (work.name != null && blockedItems.circles.contains(work.name)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  void syncAudioExtensions(Set<String> enabledExtensionIds) {
    final previousSource = state.sourceFilter;
    final nextSource = previousSource.isAvailableIn(enabledExtensionIds)
        ? previousSource
        : HomeSourceFilter.all;
    final asmrOneEnabled =
        enabledExtensionIds.contains(HomeSourceFilter.asmrOne.extensionId);
    final nextDisplayMode =
        state.displayMode != DisplayMode.all && !asmrOneEnabled
            ? DisplayMode.all
            : (nextSource.supportsCuratedModes
                ? state.displayMode
                : DisplayMode.all);

    _catalogGeneration++;
    _requestGates.clear();
    state = state.copyWith(
      sourceFilter: nextSource,
      displayMode: nextDisplayMode,
      modeStates: const {},
      sourceHealth: const {},
    );

    if (nextSource != previousSource) {
      unawaited(_sourcePreference.save(nextSource));
    }
    unawaited(loadWorks(targetPage: 1, supersede: true));
  }

  void resetCatalogForUserChange() {
    _catalogGeneration++;
    _requestGates.clear();
    state = state.copyWith(modeStates: const {}, sourceHealth: const {});
    unawaited(loadWorks(targetPage: 1, supersede: true));
  }
}

final worksProvider = StateNotifierProvider<WorksNotifier, WorksState>((ref) {
  final apiService = ref.watch(kikoeruApiServiceProvider);
  final pageSize = ref.read(pageSizeProvider);
  final defaultSort = ref.read(defaultSortProvider);

  final notifier = WorksNotifier(
    apiService,
    ref,
    initialPageSize: pageSize,
    initialSortOption: defaultSort.order,
    initialSortDirection: defaultSort.direction,
  );

  ref.listen(pageSizeProvider, (previous, next) {
    if (previous != next) notifier.updatePageSize(next);
  });

  ref.listen(defaultSortProvider, (previous, next) {
    if (previous != next) {
      notifier.setSortOption(next.order);
      notifier.setSortDirection(next.direction);
    }
  });

  ref.listen(currentUserProvider, (previous, next) {
    final prevUser = previous;
    final nextUser = next;
    if (prevUser?.name != nextUser?.name || prevUser?.host != nextUser?.host) {
      _log.captureOutput('[WorksProvider] User changed, resetting works cache');
      notifier.resetCatalogForUserChange();
    }
  });

  ref.listen(audioExtensionRegistryProvider, (previous, next) {
    final previousIds = previous?.extensions
            .map((extension) => extension.manifest.id)
            .toSet() ??
        const <String>{};
    final nextIds =
        next.extensions.map((extension) => extension.manifest.id).toSet();
    final unchanged = previousIds.length == nextIds.length &&
        previousIds.containsAll(nextIds);
    if (!unchanged) {
      _log.captureOutput(
        '[WorksProvider] Audio extensions changed, resetting source catalog',
      );
      notifier.syncAudioExtensions(nextIds);
    }
  });

  ref.listen(blockedItemsProvider, (previous, next) {
    if (previous != next) notifier.reapplyFilters();
  });

  ref.listen(subtitleLibraryProvider, (previous, next) {
    if (previous != next && notifier.isSubtitleFilterActive) {
      notifier.reapplyFilters();
    }
  });

  return notifier;
});
