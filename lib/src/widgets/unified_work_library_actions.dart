import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work.dart';
import '../providers/local_collections_provider.dart';
import '../providers/local_work_marks_provider.dart';

/// Hiraukan-owned library actions shared by unified/external sources.
///
/// These actions are deliberately local. Provider-specific mutations (for
/// example ASMR.one server ratings/bookmarks) remain in their provider-native
/// flow and are never implied by this widget.
class UnifiedWorkLibraryActions extends ConsumerWidget {
  const UnifiedWorkLibraryActions({
    super.key,
    required this.work,
  });

  final Work work;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final copy = _Copy.of(context);
    final markState = ref.watch(localWorkMarksProvider);
    final mark = ref.read(localWorkMarksProvider.notifier).markFor(work);
    final collections = ref.watch(localCollectionsProvider).collections;
    final collectionNotifier = ref.read(localCollectionsProvider.notifier);
    final memberships = collections
        .where((item) => collectionNotifier.contains(item.id, work))
        .length;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow.withValues(alpha: 0.86),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.48),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 19, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    copy.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (markState.isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              copy.subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                mark?.isFavorite == true
                    ? FilledButton.tonalIcon(
                        onPressed: markState.isLoading
                            ? null
                            : () => ref
                                .read(localWorkMarksProvider.notifier)
                                .setFavorite(work, false),
                        icon: const Icon(Icons.favorite_rounded),
                        label: Text(copy.favorited),
                      )
                    : OutlinedButton.icon(
                        onPressed: markState.isLoading
                            ? null
                            : () => ref
                                .read(localWorkMarksProvider.notifier)
                                .setFavorite(work, true),
                        icon: const Icon(Icons.favorite_border_rounded),
                        label: Text(copy.favorite),
                      ),
                OutlinedButton.icon(
                  onPressed: markState.isLoading
                      ? null
                      : () => _showRating(context, ref, copy),
                  icon: Icon(
                    mark?.rating == null
                        ? Icons.star_border_rounded
                        : Icons.star_rounded,
                  ),
                  label: Text(
                    mark?.rating == null
                        ? copy.rating
                        : copy.ratingValue(mark!.rating!),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showCollections(context, ref, copy),
                  icon: const Icon(Icons.folder_copy_outlined),
                  label: Text(
                    memberships == 0
                        ? copy.collections
                        : copy.collectionCount(memberships),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRating(
    BuildContext context,
    WidgetRef ref,
    _Copy copy,
  ) async {
    final current = ref.read(localWorkMarksProvider.notifier).markFor(work)?.rating;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.ratingTitle,
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                copy.ratingHint,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  return IconButton.filledTonal(
                    tooltip: '$rating/5',
                    onPressed: () async {
                      await ref
                          .read(localWorkMarksProvider.notifier)
                          .setRating(work, rating);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    icon: Icon(
                      rating <= (current ?? 0)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                    ),
                  );
                }),
              ),
              if (current != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () async {
                    await ref
                        .read(localWorkMarksProvider.notifier)
                        .setRating(work, null);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  icon: const Icon(Icons.clear_rounded),
                  label: Text(copy.clearRating),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCollections(
    BuildContext context,
    WidgetRef ref,
    _Copy copy,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer(
        builder: (context, sheetRef, _) {
          final state = sheetRef.watch(localCollectionsProvider);
          final notifier = sheetRef.read(localCollectionsProvider.notifier);
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              copy.collectionsTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _createCollection(
                              sheetContext,
                              sheetRef,
                              copy,
                            ),
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: Text(copy.createCollection),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (state.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.collections.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 18, 8, 24),
                        child: Text(copy.noCollections),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: state.collections.length,
                          itemBuilder: (context, index) {
                            final collection = state.collections[index];
                            final selected = notifier.contains(collection.id, work);
                            return CheckboxListTile(
                              value: selected,
                              secondary: const Icon(Icons.folder_outlined),
                              title: Text(collection.name),
                              subtitle: Text(copy.items(collection.works.length)),
                              onChanged: (value) async {
                                if (value == true) {
                                  await notifier.addWork(collection.id, work);
                                } else {
                                  await notifier.removeWork(collection.id, work);
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createCollection(
    BuildContext context,
    WidgetRef ref,
    _Copy copy,
  ) async {
    final controller = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(copy.createCollection),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            decoration: InputDecoration(hintText: copy.collectionName),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) {
              final normalized = value.trim();
              if (normalized.isNotEmpty) {
                Navigator.pop(dialogContext, normalized);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(copy.cancel),
            ),
            FilledButton(
              onPressed: () {
                final normalized = controller.text.trim();
                if (normalized.isNotEmpty) {
                  Navigator.pop(dialogContext, normalized);
                }
              },
              child: Text(copy.create),
            ),
          ],
        ),
      );
      if (name == null || !context.mounted) return;
      final notifier = ref.read(localCollectionsProvider.notifier);
      final collection = await notifier.create(name);
      await notifier.addWork(collection.id, work);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      controller.dispose();
    }
  }
}

class _Copy {
  const _Copy({required this.isId});

  final bool isId;

  static _Copy of(BuildContext context) => _Copy(
        isId: Localizations.localeOf(context).languageCode == 'id',
      );

  String get title => isId ? 'Simpan di Hiraukan' : 'Save in Hiraukan';
  String get subtitle => isId
      ? 'Favorit, rating, dan koleksi ini lokal. Sumber asli tidak diubah.'
      : 'Favorites, ratings, and collections are local. The provider is not changed.';
  String get favorite => isId ? 'Favorit' : 'Favorite';
  String get favorited => isId ? 'Difavoritkan' : 'Favorited';
  String get rating => isId ? 'Beri rating' : 'Rate';
  String ratingValue(int value) => isId ? 'Rating $value/5' : '$value/5 rating';
  String get ratingTitle => isId ? 'Rating pribadi' : 'Personal rating';
  String get ratingHint => isId
      ? 'Disimpan hanya di perangkat Hiraukan, bukan dikirim ke situs sumber.'
      : 'Stored only in Hiraukan, not submitted to the source website.';
  String get clearRating => isId ? 'Hapus rating' : 'Clear rating';
  String get collections => isId ? 'Koleksi' : 'Collections';
  String collectionCount(int value) =>
      isId ? '$value koleksi' : '$value collection${value == 1 ? '' : 's'}';
  String get collectionsTitle => isId ? 'Tambahkan ke koleksi' : 'Add to collections';
  String get createCollection => isId ? 'Buat' : 'Create';
  String get noCollections => isId
      ? 'Belum ada koleksi lokal. Buat koleksi untuk mengelompokkan karya ini.'
      : 'No local collections yet. Create one to group this work.';
  String get collectionName => isId ? 'Nama koleksi' : 'Collection name';
  String get cancel => isId ? 'Batal' : 'Cancel';
  String get create => isId ? 'Buat' : 'Create';
  String items(int value) => isId ? '$value karya' : '$value works';
}
