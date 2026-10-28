import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/audio_extension_provider.dart';
import '../models/work.dart';
import '../providers/local_collections_provider.dart';
import '../sources/unified_source_models.dart';
import '../sources/unified_source_provider.dart';
import '../sources/unified_source_registry.dart';
import '../widgets/privacy_blur_cover.dart';

/// Adds works to a local collection through the existing unified-source search.
/// No collection-specific search backend or source registry is introduced.
class LocalCollectionAddWorkScreen extends ConsumerStatefulWidget {
  const LocalCollectionAddWorkScreen({
    super.key,
    required this.collectionId,
  });

  final String collectionId;

  @override
  ConsumerState<LocalCollectionAddWorkScreen> createState() =>
      _LocalCollectionAddWorkScreenState();
}

class _LocalCollectionAddWorkScreenState
    extends ConsumerState<LocalCollectionAddWorkScreen> {
  static const _pageSize = 40;

  final _controller = TextEditingController();
  final Set<UnifiedSourceKind> _selectedSources = <UnifiedSourceKind>{};
  List<Work> _results = const <Work>[];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;
  String? _keyword;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search({bool append = false}) async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty || _loading || _loadingMore) return;

    final nextPage = append ? _page + 1 : 1;
    setState(() {
      _error = null;
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _results = const <Work>[];
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
      setState(() {
        _results = append
            ? _deduplicate(<Work>[..._results, ...page.works])
            : page.works;
        _page = nextPage;
        _hasMore = page.hasMore;
        _keyword = keyword;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  List<Work> _deduplicate(List<Work> works) {
    final seen = <String>{};
    return works.where((work) {
      final sourceId = work.sourceId?.trim().toUpperCase();
      final key = sourceId != null && sourceId.isNotEmpty
          ? 'source:$sourceId'
          : work.sourceUrl?.trim().isNotEmpty == true
              ? 'url:${work.sourceUrl!.trim()}'
              : 'id:${work.id}';
      return seen.add(key);
    }).toList(growable: false);
  }

  void _toggleSource(UnifiedSourceKind source) {
    setState(() {
      if (!_selectedSources.add(source)) _selectedSources.remove(source);
    });
    if (_keyword != null) _search();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _AddCopy.of(context);
    final installState = ref.watch(audioExtensionInstallProvider);
    final collectionState = ref.watch(localCollectionsProvider);
    final collection = collectionState.collections
        .where((item) => item.id == widget.collectionId)
        .firstOrNull;
    final availableSources = UnifiedSourceKind.values
        .where((source) => installState.installedIds.contains(source.extensionId))
        .toList(growable: false);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(collection == null
            ? copy.title
            : copy.titleFor(collection.name)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
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
                if (availableSources.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final source in availableSources)
                          Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: FilterChip(
                              selected: _selectedSources.contains(source),
                              label: Text(source.label),
                              onSelected: (_) => _toggleSource(source),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(child: _buildResults(copy)),
        ],
      ),
    );
  }

  Widget _buildResults(_AddCopy copy) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _results.isEmpty) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: copy.failed,
        message: _error!,
      );
    }
    if (_keyword == null) {
      return _Message(
        icon: Icons.travel_explore_rounded,
        title: copy.startTitle,
        message: copy.startMessage,
      );
    }
    if (_results.isEmpty) {
      return _Message(
        icon: Icons.search_off_rounded,
        title: copy.noResults,
        message: copy.noResultsMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
      itemCount: _results.length + (_hasMore || _loadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : FilledButton.tonal(
                      onPressed: () => _search(append: true),
                      child: Text(copy.loadMore),
                    ),
            ),
          );
        }
        return _ResultTile(
          work: _results[index],
          collectionId: widget.collectionId,
          copy: copy,
        );
      },
    );
  }
}

class _ResultTile extends ConsumerWidget {
  const _ResultTile({
    required this.work,
    required this.collectionId,
    required this.copy,
  });

  final Work work;
  final String collectionId;
  final _AddCopy copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localCollectionsProvider);
    final notifier = ref.read(localCollectionsProvider.notifier);
    final collection = state.collections
        .where((item) => item.id == collectionId)
        .firstOrNull;
    final isAdded = collection != null && notifier.contains(collectionId, work);
    final bundle = UnifiedSourceRegistry.instance.bundleFor(work.id) ??
        UnifiedSourceRegistry.instance.ensureFromWork(work);
    final sourceLabel = (bundle?.sources ?? const <UnifiedSourceRef>[])
        .map((item) => item.source.label)
        .toSet()
        .join(' · ');
    final cover = bundle?.coverUrl ??
        (work.images?.isNotEmpty == true ? work.images!.first : null);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 54,
            height: 54,
            child: PrivacyBlurCover(child: _Cover(url: cover)),
          ),
        ),
        title: Text(
          work.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          sourceLabel.isEmpty ? work.displayId : '$sourceLabel · ${work.displayId}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton.filledTonal(
          tooltip: isAdded ? copy.remove : copy.add,
          onPressed: () async {
            if (isAdded) {
              await notifier.removeWork(collectionId, work);
            } else {
              await notifier.addWork(collectionId, work);
            }
          },
          icon: Icon(
            isAdded ? Icons.check_rounded : Icons.add_rounded,
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
    final uri = url == null ? null : Uri.tryParse(url!);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.graphic_eq_rounded, color: scheme.primary),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.graphic_eq_rounded, color: scheme.primary),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCopy {
  const _AddCopy({
    required this.title,
    required this.titleFor,
    required this.hint,
    required this.search,
    required this.failed,
    required this.startTitle,
    required this.startMessage,
    required this.noResults,
    required this.noResultsMessage,
    required this.loadMore,
    required this.add,
    required this.remove,
  });

  final String title;
  final String Function(String) titleFor;
  final String hint;
  final String search;
  final String failed;
  final String startTitle;
  final String startMessage;
  final String noResults;
  final String noResultsMessage;
  final String loadMore;
  final String add;
  final String remove;

  static _AddCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return _AddCopy(
        title: 'Tambah Karya',
        titleFor: (name) => 'Tambah ke $name',
        hint: 'Cari karya, circle, VA, tag, atau RJ…',
        search: 'Cari',
        failed: 'Pencarian gagal',
        startTitle: 'Cari di semua sumber aktif',
        startMessage:
            'Karya yang kamu pilih disimpan sebagai snapshot lokal di koleksi ini.',
        noResults: 'Tidak ada hasil',
        noResultsMessage: 'Coba kata kunci atau sumber lain.',
        loadMore: 'Muat lebih banyak',
        add: 'Tambahkan ke koleksi',
        remove: 'Hapus dari koleksi',
      );
    }
    return _AddCopy(
      title: 'Add Works',
      titleFor: (name) => 'Add to $name',
      hint: 'Search works, circles, voice actors, tags, or RJ…',
      search: 'Search',
      failed: 'Search failed',
      startTitle: 'Search every enabled source',
      startMessage:
          'Selected works are stored as local snapshots inside this collection.',
      noResults: 'No results',
      noResultsMessage: 'Try another keyword or source.',
      loadMore: 'Load more',
      add: 'Add to collection',
      remove: 'Remove from collection',
    );
  }
}
