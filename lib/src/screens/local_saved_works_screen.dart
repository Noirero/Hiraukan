import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_work_mark.dart';
import '../providers/local_work_marks_provider.dart';
import '../sources/unified_source_registry.dart';
import '../utils/source_request_headers.dart';
import 'unified_work_detail_screen.dart';

class LocalSavedWorksScreen extends ConsumerWidget {
  const LocalSavedWorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = _Copy.of(context);
    final state = ref.watch(localWorkMarksProvider);
    final favorites = state.marks
        .where((item) => item.isFavorite)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : favorites.isEmpty
              ? _Empty(copy: copy)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 112),
                  itemCount: favorites.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, index) => _SavedTile(
                    mark: favorites[index],
                    copy: copy,
                    onOpen: () => _open(context, favorites[index]),
                    onRemove: () => ref
                        .read(localWorkMarksProvider.notifier)
                        .setFavorite(favorites[index].work, false),
                  ),
                ),
    );
  }

  void _open(BuildContext context, LocalWorkMark mark) {
    UnifiedSourceRegistry.instance.ensureFromWork(mark.work);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnifiedWorkDetailScreen(work: mark.work),
      ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({
    required this.mark,
    required this.copy,
    required this.onOpen,
    required this.onRemove,
  });

  final LocalWorkMark mark;
  final _Copy copy;
  final VoidCallback onOpen;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final work = mark.work;
    final scheme = Theme.of(context).colorScheme;
    final cover = work.images?.isNotEmpty == true ? work.images!.first : null;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: SizedBox(
            width: 54,
            height: 54,
            child: _Cover(url: cover),
          ),
        ),
        title: Text(
          work.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (work.name?.trim().isNotEmpty == true) work.name!.trim(),
            work.displayId,
            if (mark.rating != null) '★ ${mark.rating}/5',
          ].where((item) => item.isNotEmpty).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: copy.remove,
          onPressed: onRemove,
          icon: const Icon(Icons.favorite_rounded),
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return const _FallbackCover();
    return CachedNetworkImage(
      imageUrl: value,
      httpHeaders: sourceImageHeadersFor(value),
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => const _FallbackCover(),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.graphic_eq_rounded, color: scheme.primary),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.copy});

  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border_rounded, size: 58, color: scheme.primary),
            const SizedBox(height: 14),
            Text(
              copy.emptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              copy.emptyBody,
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

class _Copy {
  const _Copy({required this.isId});

  final bool isId;

  static _Copy of(BuildContext context) => _Copy(
        isId: Localizations.localeOf(context).languageCode == 'id',
      );

  String get title => isId ? 'Favorit Hiraukan' : 'Hiraukan Favorites';
  String get remove => isId ? 'Hapus dari favorit' : 'Remove from favorites';
  String get emptyTitle => isId ? 'Belum ada favorit lokal' : 'No local favorites yet';
  String get emptyBody => isId
      ? 'Favoritkan karya dari detail sumber mana pun untuk menyimpannya di sini.'
      : 'Favorite a work from any source detail to keep it here.';
}
