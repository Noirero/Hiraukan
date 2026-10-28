import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_collection.dart';
import '../models/work.dart';
import '../providers/local_collections_provider.dart';
import '../sources/unified_source_registry.dart';
import '../widgets/privacy_blur_cover.dart';
import 'local_collection_add_work_screen.dart';
import 'unified_work_detail_screen.dart';
import 'work_detail_screen.dart';

class LocalCollectionsScreen extends ConsumerWidget {
  const LocalCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localCollectionsProvider);
    final copy = _Copy.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref, copy),
        icon: const Icon(Icons.add_rounded),
        label: Text(copy.create),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.collections.isEmpty
              ? _Empty(
                  icon: Icons.folder_copy_outlined,
                  title: copy.emptyTitle,
                  message: copy.emptySubtitle,
                  actionLabel: copy.create,
                  onAction: () => _create(context, ref, copy),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                  itemCount: state.collections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final collection = state.collections[index];
                    return _CollectionTile(
                      collection: collection,
                      copy: copy,
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => LocalCollectionDetailScreen(
                            collectionId: collection.id,
                          ),
                        ),
                      ),
                      onRename: () =>
                          _rename(context, ref, collection, copy),
                      onDelete: () =>
                          _delete(context, ref, collection, copy),
                    );
                  },
                ),
    );
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    _Copy copy,
  ) async {
    final name = await _nameDialog(context, copy.createTitle, copy);
    if (name == null || !context.mounted) return;
    try {
      final collection =
          await ref.read(localCollectionsProvider.notifier).create(name);
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LocalCollectionDetailScreen(
            collectionId: collection.id,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    LocalCollection collection,
    _Copy copy,
  ) async {
    final name = await _nameDialog(
      context,
      copy.renameTitle,
      copy,
      initialValue: collection.name,
    );
    if (name == null || !context.mounted) return;
    try {
      await ref
          .read(localCollectionsProvider.notifier)
          .rename(collection.id, name);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LocalCollection collection,
    _Copy copy,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.deleteTitle),
        content: Text(copy.deleteMessage(collection.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(localCollectionsProvider.notifier).delete(collection.id);
    }
  }

  Future<String?> _nameDialog(
    BuildContext context,
    String title,
    _Copy copy, {
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    controller.selection = TextSelection.collapsed(offset: initialValue.length);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
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
              child: Text(copy.save),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}

class LocalCollectionDetailScreen extends ConsumerWidget {
  const LocalCollectionDetailScreen({
    super.key,
    required this.collectionId,
  });

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localCollectionsProvider);
    final collection = state.collections
        .where((item) => item.id == collectionId)
        .firstOrNull;
    final copy = _Copy.of(context);

    if (collection == null) {
      return Scaffold(
        appBar: AppBar(title: Text(copy.title)),
        body: Center(child: Text(copy.notFound)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          IconButton(
            tooltip: copy.addWorks,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LocalCollectionAddWorkScreen(
                  collectionId: collection.id,
                ),
              ),
            ),
            icon: const Icon(Icons.playlist_add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LocalCollectionAddWorkScreen(
              collectionId: collection.id,
            ),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(copy.addWorks),
      ),
      body: collection.works.isEmpty
          ? _Empty(
              icon: Icons.library_add_outlined,
              title: copy.collectionEmptyTitle,
              message: copy.collectionEmpty,
              actionLabel: copy.addWorks,
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LocalCollectionAddWorkScreen(
                    collectionId: collection.id,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 112),
              itemCount: collection.works.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final work = collection.works[index];
                return _WorkTile(
                  work: work,
                  removeLabel: copy.remove,
                  onOpen: () => _openWork(context, work),
                  onRemove: () => ref
                      .read(localCollectionsProvider.notifier)
                      .removeWork(collection.id, work),
                );
              },
            ),
    );
  }

  void _openWork(BuildContext context, Work work) {
    if (_isUnifiedExternal(work)) {
      UnifiedSourceRegistry.instance.ensureFromWork(work);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UnifiedWorkDetailScreen(work: work),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WorkDetailScreen(work: work)),
    );
  }

  bool _isUnifiedExternal(Work work) {
    if (work.id < 0) return true;
    final source = work.sourceUrl?.trim();
    if (source == null || source.isEmpty) return false;
    final host = Uri.tryParse(source)?.host.toLowerCase() ?? '';
    return host.contains('hentaiasmr.moe') || host.contains('erovoice.us');
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.collection,
    required this.copy,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final LocalCollection collection;
  final _Copy copy;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.folder_rounded, color: scheme.primary),
        ),
        title: Text(
          collection.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(copy.items(collection.works.length)),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'rename') onRename();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'rename', child: Text(copy.rename)),
            PopupMenuItem(value: 'delete', child: Text(copy.delete)),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({
    required this.work,
    required this.onOpen,
    required this.onRemove,
    required this.removeLabel,
  });

  final Work work;
  final VoidCallback onOpen;
  final Future<void> Function() onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = work.images?.isNotEmpty == true ? work.images!.first : null;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 52,
            height: 52,
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
          [
            if (work.name?.trim().isNotEmpty == true) work.name!,
            if (work.displayId.trim().isNotEmpty) work.displayId,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: removeLabel,
          onPressed: onRemove,
          icon: const Icon(Icons.remove_circle_outline_rounded),
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

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: scheme.primary),
            const SizedBox(height: 14),
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
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Copy {
  const _Copy({
    required this.title,
    required this.create,
    required this.createTitle,
    required this.renameTitle,
    required this.rename,
    required this.deleteTitle,
    required this.delete,
    required this.deleteMessage,
    required this.cancel,
    required this.save,
    required this.nameHint,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.collectionEmptyTitle,
    required this.collectionEmpty,
    required this.notFound,
    required this.remove,
    required this.addWorks,
    required this.items,
  });

  final String title;
  final String create;
  final String createTitle;
  final String renameTitle;
  final String rename;
  final String deleteTitle;
  final String delete;
  final String Function(String) deleteMessage;
  final String cancel;
  final String save;
  final String nameHint;
  final String emptyTitle;
  final String emptySubtitle;
  final String collectionEmptyTitle;
  final String collectionEmpty;
  final String notFound;
  final String remove;
  final String addWorks;
  final String Function(int) items;

  static _Copy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return _Copy(
        title: 'Koleksi Lokal',
        create: 'Buat koleksi',
        createTitle: 'Buat koleksi lokal',
        renameTitle: 'Ubah nama koleksi',
        rename: 'Ubah nama',
        deleteTitle: 'Hapus koleksi?',
        delete: 'Hapus',
        deleteMessage: (name) =>
            'Koleksi “$name” akan dihapus. Karya dan file asli tidak ikut dihapus.',
        cancel: 'Batal',
        save: 'Simpan',
        nameHint: 'Contoh: Sleep, Favorit, Dengarkan nanti',
        emptyTitle: 'Buat ruang untuk karya pilihanmu',
        emptySubtitle:
            'Koleksi lokal tidak bergantung pada playlist server dan tetap mengikuti Hiraukan saat kamu berganti akun.',
        collectionEmptyTitle: 'Koleksi masih kosong',
        collectionEmpty:
            'Cari karya dari semua sumber aktif lalu tambahkan ke koleksi ini.',
        notFound: 'Koleksi tidak ditemukan.',
        remove: 'Hapus dari koleksi',
        addWorks: 'Tambah karya',
        items: (count) => '$count karya',
      );
    }
    return _Copy(
      title: 'Local Collections',
      create: 'Create collection',
      createTitle: 'Create local collection',
      renameTitle: 'Rename collection',
      rename: 'Rename',
      deleteTitle: 'Delete collection?',
      delete: 'Delete',
      deleteMessage: (name) =>
          '“$name” will be deleted. Original works and files are not removed.',
      cancel: 'Cancel',
      save: 'Save',
      nameHint: 'For example: Sleep, Favorites, Listen Later',
      emptyTitle: 'Make space for the works you care about',
      emptySubtitle:
          'Local collections do not depend on server playlists and remain available when you switch accounts.',
      collectionEmptyTitle: 'This collection is empty',
      collectionEmpty:
          'Search every enabled source and add works to this collection.',
      notFound: 'Collection not found.',
      remove: 'Remove from collection',
      addWorks: 'Add works',
      items: (count) => '$count works',
    );
  }
}
