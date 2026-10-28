import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/audio_extension_provider.dart';
import '../models/work.dart';
import '../sources/unified_source_models.dart';
import '../sources/unified_source_provider.dart';
import '../sources/unified_source_registry.dart';
import '../widgets/privacy_blur_cover.dart';
import 'search_screen.dart';
import 'unified_work_detail_screen.dart';

/// Primary search experience for Hiraukan.
///
/// Search is intentionally source-agnostic by default. The previous Kikoeru
/// query-builder remains available as Advanced Search for users who need its
/// tag/circle/VA syntax and server-specific filters.
class UnifiedSearchScreen extends ConsumerStatefulWidget {
  const UnifiedSearchScreen({super.key});

  @override
  ConsumerState<UnifiedSearchScreen> createState() =>
      _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends ConsumerState<UnifiedSearchScreen> {
  static const int _pageSize = 40;

  final TextEditingController _controller = TextEditingController();
  final Set<UnifiedSourceKind> _selectedSources = <UnifiedSourceKind>{};

  List<Work> _results = const [];
  Map<UnifiedSourceKind, UnifiedSourceHealth> _health = const {};
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  String? _lastKeyword;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search({bool append = false}) async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    if (_loading || _loadingMore) return;

    final nextPage = append ? _page + 1 : 1;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
        _results = const [];
        _health = const {};
      }
    });

    try {
      final page = await ref.read(unifiedSourceServiceProvider).search(
            keyword: keyword,
            page: nextPage,
            pageSize: _pageSize,
            enabledSources:
                _selectedSources.isEmpty ? null : Set.of(_selectedSources),
          );
      if (!mounted) return;

      final combined = append
          ? _deduplicate(<Work>[..._results, ...page.works])
          : page.works;
      setState(() {
        _results = combined;
        _health = page.health;
        _page = nextPage;
        _hasMore = page.hasMore;
        _lastKeyword = keyword;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  List<Work> _deduplicate(List<Work> works) {
    final seen = <String>{};
    final result = <Work>[];
    for (final work in works) {
      final key = work.sourceId?.trim().toUpperCase();
      final identity = key != null && key.isNotEmpty ? key : '${work.id}';
      if (seen.add(identity)) result.add(work);
    }
    return result;
  }

  void _toggleSource(UnifiedSourceKind source) {
    setState(() {
      if (!_selectedSources.add(source)) {
        _selectedSources.remove(source);
      }
    });
    if (_lastKeyword != null) {
      _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _SearchCopy.of(context);
    final installState = ref.watch(audioExtensionInstallProvider);
    final availableSources = UnifiedSourceKind.values
        .where((source) => installState.installedIds.contains(source.extensionId))
        .toList(growable: false);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        scrolledUnderElevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SearchScreen(),
              ),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(copy.advanced),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    autofocus: false,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: copy.hint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: copy.search,
                        onPressed: _loading ? null : _search,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          copy.sources,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      if (_selectedSources.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(_selectedSources.clear);
                            if (_lastKeyword != null) _search();
                          },
                          child: Text(copy.allSources),
                        ),
                    ],
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final source in availableSources)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: _selectedSources.contains(source),
                              label: Text(source.label),
                              avatar: _healthDot(source),
                              onSelected: (_) => _toggleSource(source),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
          Expanded(child: _buildBody(copy)),
        ],
      ),
    );
  }

  Widget? _healthDot(UnifiedSourceKind source) {
    final health = _health[source];
    if (health == null || health == UnifiedSourceHealth.unknown) return null;

    final color = switch (health) {
      UnifiedSourceHealth.healthy => Colors.green,
      UnifiedSourceHealth.degraded => Colors.orange,
      UnifiedSourceHealth.broken => Colors.red,
      UnifiedSourceHealth.unknown => Colors.grey,
    };
    return Icon(Icons.circle, size: 9, color: color);
  }

  Widget _buildBody(_SearchCopy copy) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _results.isEmpty) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: copy.failed,
        message: _error!,
        actionLabel: copy.retry,
        onAction: _search,
      );
    }

    if (_lastKeyword == null) {
      return _MessageState(
        icon: Icons.travel_explore_rounded,
        title: copy.emptyTitle,
        message: copy.emptyMessage,
      );
    }

    if (_results.isEmpty) {
      return _MessageState(
        icon: Icons.search_off_rounded,
        title: copy.noResults,
        message: copy.noResultsMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: _results.length + (_hasMore || _loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : FilledButton.tonalIcon(
                      onPressed: () => _search(append: true),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: Text(copy.loadMore),
                    ),
            ),
          );
        }
        return _UnifiedSearchResultTile(work: _results[index]);
      },
    );
  }
}

class _UnifiedSearchResultTile extends StatelessWidget {
  const _UnifiedSearchResultTile({required this.work});

  final Work work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bundle = UnifiedSourceRegistry.instance.bundleFor(work.id) ??
        UnifiedSourceRegistry.instance.ensureFromWork(work);
    final sourceLabels = bundle.sources
        .map((source) => source.source.label)
        .toSet()
        .join(' · ');
    final cover = bundle.coverUrl ??
        (work.images?.isNotEmpty == true ? work.images!.first : null);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => UnifiedWorkDetailScreen(work: work),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: PrivacyBlurCover(
                    child: _Cover(url: cover),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      work.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (work.name?.trim().isNotEmpty == true) work.name!,
                        work.displayId,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _SmallBadge(
                          icon: Icons.language_rounded,
                          label: sourceLabels.isEmpty ? 'Hiraukan' : sourceLabels,
                        ),
                        if (work.hasSubtitle == true)
                          const _SmallBadge(
                            icon: Icons.subtitles_outlined,
                            label: 'CC',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parsed = url == null ? null : Uri.tryParse(url!);
    if (parsed == null || !(parsed.isScheme('http') || parsed.isScheme('https'))) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.graphic_eq_rounded, color: scheme.primary, size: 30),
      );
    }

    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.graphic_eq_rounded, color: scheme.primary, size: 30),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.primary),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: scheme.primary),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchCopy {
  const _SearchCopy({
    required this.title,
    required this.advanced,
    required this.hint,
    required this.search,
    required this.sources,
    required this.allSources,
    required this.failed,
    required this.retry,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.noResults,
    required this.noResultsMessage,
    required this.loadMore,
  });

  final String title;
  final String advanced;
  final String hint;
  final String search;
  final String sources;
  final String allSources;
  final String failed;
  final String retry;
  final String emptyTitle;
  final String emptyMessage;
  final String noResults;
  final String noResultsMessage;
  final String loadMore;

  static _SearchCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return const _SearchCopy(
        title: 'Pencarian',
        advanced: 'Lanjutan',
        hint: 'Cari karya, circle, VA, tag, atau RJ…',
        search: 'Cari',
        sources: 'Sumber',
        allSources: 'Semua sumber',
        failed: 'Pencarian gagal',
        retry: 'Coba lagi',
        emptyTitle: 'Cari di semua sumber Hiraukan',
        emptyMessage:
            'Secara default Hiraukan mencari di semua sumber audio yang aktif dan menggabungkan hasilnya.',
        noResults: 'Tidak ada hasil',
        noResultsMessage: 'Coba kata kunci lain atau ubah filter sumber.',
        loadMore: 'Muat lebih banyak',
      );
    }

    return const _SearchCopy(
      title: 'Search',
      advanced: 'Advanced',
      hint: 'Search works, circles, voice actors, tags, or RJ…',
      search: 'Search',
      sources: 'Sources',
      allSources: 'All sources',
      failed: 'Search failed',
      retry: 'Retry',
      emptyTitle: 'Search across Hiraukan',
      emptyMessage:
          'Hiraukan searches every enabled audio source by default and merges the results into one view.',
      noResults: 'No results',
      noResultsMessage: 'Try another keyword or change the source filters.',
      loadMore: 'Load more',
    );
  }
}
