import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';

import '../models/work.dart';
import '../services/kikoeru_api_service.dart' hide kikoeruApiServiceProvider;
import '../providers/works_provider.dart';
import '../models/sort_options.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';
import 'subtitle_library_provider.dart';
import '../utils/subtitle_filter.dart';
import '../utils/paged_collection.dart';
import '../utils/persistent_enum_preference.dart';
import '../sources/unified_source_models.dart';
import '../sources/unified_source_preferences.dart';
import '../sources/unified_source_provider.dart';

enum SearchLayoutType {
  list,
  smallGrid,
  bigGrid,
}

extension SearchLayoutTypeExtension on SearchLayoutType {
  LayoutType toWorksLayoutType() {
    switch (this) {
      case SearchLayoutType.list:
        return LayoutType.list;
      case SearchLayoutType.smallGrid:
        return LayoutType.smallGrid;
      case SearchLayoutType.bigGrid:
        return LayoutType.bigGrid;
    }
  }
}

class SearchResultState extends Equatable {
  final List<Work> works;
  final List<Work> rawWorks;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final String? error;
  final String? loadMoreError;
  final int currentPage;
  final int totalCount;
  final bool hasMore;
  final SearchLayoutType layoutType;
  final SortOrder sortOption;
  final SortDirection sortDirection;
  final int subtitleFilter;
  final int basePageSize;
  final String keyword;
  final Map<String, dynamic>? searchParams;
  final Set<UnifiedSourceKind> enabledSources;
  final Map<UnifiedSourceKind, UnifiedSourceHealth> sourceHealth;

  int get pageSize => SubtitleFilterMode.fromValue(subtitleFilter).isActive
      ? basePageSize * 2
      : basePageSize;

  const SearchResultState({
    this.works = const [],
    this.rawWorks = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.currentPage = 1,
    this.totalCount = 0,
    this.hasMore = true,
    this.layoutType = SearchLayoutType.bigGrid,
    this.sortOption = SortOrder.release,
    this.sortDirection = SortDirection.desc,
    this.subtitleFilter = 0,
    this.basePageSize = 40,
    this.keyword = '',
    this.searchParams,
    this.enabledSources = const {
      UnifiedSourceKind.asmrOne,
      UnifiedSourceKind.hentaiAsmr,
      UnifiedSourceKind.eroVoice,
    },
    this.sourceHealth = const {},
  });

  SearchResultState copyWith({
    List<Work>? works,
    List<Work>? rawWorks,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    String? error,
    String? loadMoreError,
    int? currentPage,
    int? totalCount,
    bool? hasMore,
    SearchLayoutType? layoutType,
    SortOrder? sortOption,
    SortDirection? sortDirection,
    int? subtitleFilter,
    int? basePageSize,
    String? keyword,
    Map<String, dynamic>? searchParams,
    Set<UnifiedSourceKind>? enabledSources,
    Map<UnifiedSourceKind, UnifiedSourceHealth>? sourceHealth,
  }) {
    return SearchResultState(
      works: works ?? this.works,
      rawWorks: rawWorks ?? this.rawWorks,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      loadMoreError: loadMoreError,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      layoutType: layoutType ?? this.layoutType,
      sortOption: sortOption ?? this.sortOption,
      sortDirection: sortDirection ?? this.sortDirection,
      subtitleFilter: subtitleFilter ?? this.subtitleFilter,
      basePageSize: basePageSize ?? this.basePageSize,
      keyword: keyword ?? this.keyword,
      searchParams: searchParams ?? this.searchParams,
      enabledSources: enabledSources ?? this.enabledSources,
      sourceHealth: sourceHealth ?? this.sourceHealth,
    );
  }

  @override
  List<Object?> get props => [
        works,
        rawWorks,
        isLoading,
        isRefreshing,
        isLoadingMore,
        error,
        loadMoreError,
        currentPage,
        totalCount,
        hasMore,
        layoutType,
        sortOption,
        sortDirection,
        subtitleFilter,
        basePageSize,
        keyword,
        searchParams,
        enabledSources,
        sourceHealth,
      ];
}

class SearchResultNotifier extends StateNotifier<SearchResultState> {
  static const String layoutPreferenceKey = 'search_result_layout_type';

  final KikoeruApiService _apiService;
  final Ref _ref;
  final PagedRequestGate _requestGate = PagedRequestGate();
  final _layoutPreference = PersistentEnumPreference<SearchLayoutType>(
    key: layoutPreferenceKey,
    values: SearchLayoutType.values,
    fallback: SearchLayoutType.bigGrid,
  );

  SearchResultNotifier(this._apiService, this._ref, {int initialPageSize = 20})
      : super(SearchResultState(basePageSize: initialPageSize)) {
    unawaited(_loadLayoutPreference());
    unawaited(_loadSourcePreferences());
  }

  Future<void> _loadLayoutPreference() async {
    final layoutType = await _layoutPreference.load();
    if (!mounted || layoutType == null || layoutType == state.layoutType) return;
    state = state.copyWith(
      layoutType: layoutType,
      error: state.error,
      loadMoreError: state.loadMoreError,
    );
  }

  Future<void> _loadSourcePreferences() async {
    final enabled = await UnifiedSourcePreferences.loadEnabledSources();
    if (!mounted ||
        (enabled.length == state.enabledSources.length &&
            enabled.containsAll(state.enabledSources))) {
      return;
    }
    state = state.copyWith(enabledSources: enabled);
    if (state.keyword.trim().isNotEmpty &&
        state.searchParams == null &&
        _supportsFederatedSearch(state.keyword)) {
      await loadResults(targetPage: 1, supersede: true);
    }
  }

  Future<void> initializeSearch({
    required String keyword,
    Map<String, dynamic>? searchParams,
  }) async {
    state = state.copyWith(
      keyword: keyword,
      searchParams: searchParams,
      currentPage: 1,
      works: [],
      rawWorks: [],
    );
    await loadResults(targetPage: 1, supersede: true);
  }

  void updatePageSize(int newSize) {
    if (state.basePageSize == newSize) return;
    state = state.copyWith(basePageSize: newSize);
    if (state.keyword.isNotEmpty || state.searchParams != null) refresh();
  }

  Future<void> loadResults({
    int? targetPage,
    bool append = false,
    bool supersede = false,
  }) async {
    final requestToken = _requestGate.begin(supersede: supersede);
    if (requestToken == null) return;

    final page = targetPage ?? state.currentPage;
    state = state.copyWith(
      isLoading: true,
      isRefreshing: !append,
      isLoadingMore: append,
      error: null,
      loadMoreError: null,
    );

    try {
      List<Work> pageWorks;
      int totalCount;
      bool hasMore;
      var health = state.sourceHealth;
      const serverSubtitleParam = 0;

      if (state.searchParams?.containsKey('vaId') == true) {
        final result = await _apiService.getWorksByVa(
          vaId: state.searchParams!['vaId'],
          page: page,
          pageSize: state.pageSize,
          order: state.sortOption.value,
          sort: state.sortDirection.value,
          subtitle: serverSubtitleParam,
        );
        pageWorks = _parseWorks(result['works']);
        totalCount = _totalCount(result, pageWorks.length);
        hasMore = _hasMoreFromTotal(page, totalCount);
      } else if (state.searchParams?.containsKey('tagId') == true) {
        final result = await _apiService.getWorksByTag(
          tagId: state.searchParams!['tagId'],
          page: page,
          pageSize: state.pageSize,
          order: state.sortOption.value,
          sort: state.sortDirection.value,
          subtitle: serverSubtitleParam,
        );
        pageWorks = _parseWorks(result['works']);
        totalCount = _totalCount(result, pageWorks.length);
        hasMore = _hasMoreFromTotal(page, totalCount);
      } else if (_supportsFederatedSearch(state.keyword)) {
        final result = await _ref.read(unifiedSourceServiceProvider).search(
              keyword: state.keyword,
              page: page,
              pageSize: state.pageSize,
              enabledSources: state.enabledSources,
            );
        pageWorks = result.works;
        totalCount = result.totalCount;
        hasMore = result.hasMore;
        health = result.health;
      } else {
        final result = await _apiService.searchWorks(
          keyword: state.keyword,
          page: page,
          pageSize: state.pageSize,
          order: state.sortOption.value,
          sort: state.sortDirection.value,
          subtitle: serverSubtitleParam,
        );
        pageWorks = _parseWorks(result['works']);
        totalCount = _totalCount(result, pageWorks.length);
        hasMore = _hasMoreFromTotal(page, totalCount);
      }

      if (!_requestGate.isCurrent(requestToken)) return;

      final rawWorks = mergePagedItems<Work, int>(
        existing: const [],
        incoming: pageWorks,
        idOf: (work) => work.id,
        replace: true,
      );
      final blockedItems = _ref.read(blockedItemsProvider);
      final filteredWorks = _filterWorks(rawWorks, blockedItems);

      state = state.copyWith(
        works: filteredWorks,
        rawWorks: rawWorks,
        currentPage: page,
        totalCount: totalCount,
        hasMore: hasMore,
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: null,
        loadMoreError: null,
        sourceHealth: health,
      );
    } catch (e) {
      if (!_requestGate.isCurrent(requestToken)) return;
      final message = e.toString();
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        error: append ? null : message,
        loadMoreError: append ? message : null,
      );
    } finally {
      _requestGate.complete(requestToken);
    }
  }

  List<Work> _parseWorks(Object? raw) {
    final list = raw is List ? raw : const [];
    return list.map((item) {
      if (item is Work) return item;
      return Work.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList(growable: false);
  }

  int _totalCount(Map<String, dynamic> result, int fallback) {
    final pagination = result['pagination'] as Map<String, dynamic>?;
    return (pagination?['totalCount'] as num?)?.toInt() ?? fallback;
  }

  bool _hasMoreFromTotal(int page, int totalCount) {
    final totalPages = totalCount > 0 ? (totalCount / state.pageSize).ceil() : 1;
    return page < totalPages;
  }

  bool _supportsFederatedSearch(String keyword) {
    final value = keyword.trim();
    if (value.isEmpty) return false;
    return !value.contains(r'$');
  }

  void setSourceEnabled(UnifiedSourceKind source, bool enabled) {
    final next = {...state.enabledSources};
    if (enabled) {
      next.add(source);
    } else if (next.length > 1) {
      next.remove(source);
    }
    if (next.length == state.enabledSources.length &&
        next.containsAll(state.enabledSources)) {
      return;
    }
    state = state.copyWith(
      enabledSources: next,
      currentPage: 1,
      works: [],
      rawWorks: [],
    );
    unawaited(UnifiedSourcePreferences.saveEnabledSources(next));
    unawaited(refresh());
  }

  void enableAllSources() {
    final all = UnifiedSourceKind.values.toSet();
    state = state.copyWith(
      enabledSources: all,
      currentPage: 1,
      works: [],
      rawWorks: [],
    );
    unawaited(UnifiedSourcePreferences.saveEnabledSources(all));
    unawaited(refresh());
  }

  void reapplyFilters() {
    final blockedItems = _ref.read(blockedItemsProvider);
    state = state.copyWith(works: _filterWorks(state.rawWorks, blockedItems));
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
    }).toList();
  }

  Future<void> goToPage(int page) async => loadResults(targetPage: page);

  Future<void> refresh() async =>
      loadResults(targetPage: state.currentPage, supersede: true);

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    await loadResults(targetPage: state.currentPage + 1);
  }

  void toggleLayoutType() {
    final nextLayout = switch (state.layoutType) {
      SearchLayoutType.bigGrid => SearchLayoutType.smallGrid,
      SearchLayoutType.smallGrid => SearchLayoutType.list,
      SearchLayoutType.list => SearchLayoutType.bigGrid,
    };
    state = state.copyWith(layoutType: nextLayout);
    unawaited(_layoutPreference.save(nextLayout));
  }

  bool get isSubtitleFilterActive =>
      SubtitleFilterMode.fromValue(state.subtitleFilter).isActive;

  void toggleSubtitleFilter() {
    final currentPage = state.currentPage;
    final oldFilterMode = SubtitleFilterMode.fromValue(state.subtitleFilter);
    final newFilterMode = oldFilterMode.next;
    final newFilter = newFilterMode.value;

    int newPage;
    if (oldFilterMode == SubtitleFilterMode.all && newFilterMode.isActive) {
      newPage = ((currentPage + 1) / 2).ceil();
    } else if (oldFilterMode.isActive &&
        newFilterMode == SubtitleFilterMode.all) {
      newPage = (currentPage * 2) - 1;
    } else {
      newPage = currentPage;
    }
    newPage = newPage.clamp(1, 9999);

    state = state.copyWith(
      subtitleFilter: newFilter,
      currentPage: newPage,
      works: [],
      rawWorks: [],
    );
    loadResults(targetPage: newPage, supersede: true);
  }

  void updateSort(SortOrder option, SortDirection direction) {
    state = state.copyWith(
      sortOption: option,
      sortDirection: direction,
      currentPage: 1,
      works: [],
      rawWorks: [],
    );
    refresh();
  }
}

final searchResultProvider =
    StateNotifierProvider<SearchResultNotifier, SearchResultState>((ref) {
  final apiService = ref.watch(kikoeruApiServiceProvider);
  final pageSize = ref.read(pageSizeProvider);
  final notifier = SearchResultNotifier(apiService, ref, initialPageSize: pageSize);

  ref.listen(pageSizeProvider, (previous, next) {
    if (previous != next) notifier.updatePageSize(next);
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
