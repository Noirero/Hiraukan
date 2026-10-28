import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work.dart';
import '../providers/local_collections_provider.dart';

class LocalCollectionPicker {
  const LocalCollectionPicker._();

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    Work work,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CollectionPickerSheet(work: work),
    );
  }
}

class _CollectionPickerSheet extends ConsumerStatefulWidget {
  const _CollectionPickerSheet({required this.work});

  final Work work;

  @override
  ConsumerState<_CollectionPickerSheet> createState() =>
      _CollectionPickerSheetState();
}

class _CollectionPickerSheetState
    extends ConsumerState<_CollectionPickerSheet> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(localCollectionsProvider);
    final copy = _PickerCopy.of(context);
    final scheme = Theme.of(context).colorScheme;

    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.work.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _creating ? null : _createCollection,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(copy.newCollection),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.collections.isEmpty
                    ? _EmptyState(copy: copy, onCreate: _createCollection)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: state.collections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final collection = state.collections[index];
                          final checked = ref
                              .read(localCollectionsProvider.notifier)
                              .contains(collection.id, widget.work);
                          return CheckboxListTile(
                            value: checked,
                            secondary: const Icon(Icons.folder_outlined),
                            title: Text(collection.name),
                            subtitle: Text(copy.items(collection.works.length)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onChanged: (value) async {
                              final notifier =
                                  ref.read(localCollectionsProvider.notifier);
                              if (value == true) {
                                await notifier.addWork(
                                  collection.id,
                                  widget.work,
                                );
                              } else {
                                await notifier.removeWork(
                                  collection.id,
                                  widget.work,
                                );
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _createCollection() async {
    final copy = _PickerCopy.of(context);
    final controller = TextEditingController();
    setState(() => _creating = true);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(copy.createTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: copy.nameHint),
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
      if (name == null || !mounted) return;

      try {
        final collection =
            await ref.read(localCollectionsProvider.notifier).create(name);
        if (!mounted) return;
        await ref
            .read(localCollectionsProvider.notifier)
            .addWork(collection.id, widget.work);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _creating = false);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.copy, required this.onCreate});

  final _PickerCopy copy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.create_new_folder_outlined,
              size: 52,
              color: scheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              copy.emptyTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              copy.emptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(copy.newCollection),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerCopy {
  const _PickerCopy({
    required this.title,
    required this.newCollection,
    required this.createTitle,
    required this.nameHint,
    required this.cancel,
    required this.create,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.items,
  });

  final String title;
  final String newCollection;
  final String createTitle;
  final String nameHint;
  final String cancel;
  final String create;
  final String emptyTitle;
  final String emptySubtitle;
  final String Function(int) items;

  static _PickerCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return _PickerCopy(
        title: 'Simpan ke Koleksi',
        newCollection: 'Koleksi baru',
        createTitle: 'Buat koleksi lokal',
        nameHint: 'Contoh: Sleep, Favorit, Dengarkan nanti',
        cancel: 'Batal',
        create: 'Buat',
        emptyTitle: 'Belum ada koleksi lokal',
        emptySubtitle:
            'Koleksi tersimpan di Hiraukan dan tidak bergantung pada akun atau server.',
        items: (count) => '$count karya',
      );
    }
    return _PickerCopy(
      title: 'Save to Collection',
      newCollection: 'New collection',
      createTitle: 'Create local collection',
      nameHint: 'For example: Sleep, Favorites, Listen Later',
      cancel: 'Cancel',
      create: 'Create',
      emptyTitle: 'No local collections yet',
      emptySubtitle:
          'Collections live in Hiraukan and do not depend on an account or server.',
      items: (count) => '$count works',
    );
  }
}
