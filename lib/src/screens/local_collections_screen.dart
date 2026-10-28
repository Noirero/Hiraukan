import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/local_collection.dart';
import '../models/work.dart';
import '../providers/auth_provider.dart';
import '../providers/local_collections_provider.dart';
import '../screens/unified_work_detail_screen.dart';
import '../screens/work_detail_screen.dart';
import '../sources/unified_source_registry.dart';
import '../utils/work_cover_prefetch.dart';
import '../widgets/privacy_blur_cover.dart';

class LocalCollectionsScreen extends ConsumerWidget {
  const LocalCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localCollectionsProvider);
    final copy = _CollectionsCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        actions: [
          IconButton(
            tooltip: copy.create,
            onPressed: () => _create(context, ref, copy),
            icon: const Icon(Icons.create_new_folder_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref, copy),
        icon: const Icon(Icons.add_rounded),
        label: Text(copy.create),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.collections.isEmpty
              ? _CollectionsEmpty(copy: copy, onCreate: () => _create(context, ref, copy))
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
                      onRename: () => _rename(context, ref, collection, copy),
                      onDelete: () => _delete(context, ref, collection, copy),
                    );
                  },
                ),
    );
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    _CollectionsCopy copy,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    LocalCollection collection,
    _CollectionsCopy copy,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    LocalCollection collection,
    _CollectionsCopy copy,
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
    if (confirmed != true || !context.mounted) return;
    await ref.read(localCollectionsProvider.notifier).delete(collection.id);
  }

  Future<String?> _nameDialog(
    BuildContext context,
    String title,
    _CollectionsCopy copy, {
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
              if (normalized.isNotEmpty) Navigator.pop(dialogContext, normalized);
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
                if (normalized.isNotEmpty) Navigator.pop(dialogContext, normalized);
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
  const LocalCollectionDetailScreen({super.key, required this.collectionId});

  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localCollectionsProvider);
    final collection = state.collections
        .where((item) => item.id == collectionId)
        .firstOrNull;
    final copy = _CollectionsCopy.of(context);

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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                copy.items(collection.works.length),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: collection.works.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  copy.collectionEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
              itemCount: collection.works.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final work = collection.works[index];
                return _WorkTile(
                  work: work,
                  onOpen: () => _openWork(context, ref, work),
                  onRemove: () async {
                    await ref
                        .read(localCollectionsProvider.notifier)
                        .removeWork(collection.id, work);
                  },
                  removeLabel: copy.remove,
                );
              },
            ),
    );
  }

  void _openWork(BuildContext context, WidgetRef ref, Work work) {
    final external = _isUnifiedExternalWork(work);
    if (external) {
      UnifiedSourceRegistry.instance.ensureFromWork(work);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UnifiedWorkDetailScreen(work: work),
        ),
      );
      return;
    }

    final auth = ref.read(authProvider);
    final host = auth.host ?? '';
    final token = auth.token ?? '';
    final coverProvider = host.isEmpty
        ? null
        : createWorkCoverImageProvider(
            work: work,
            host: host,
            token: token,
          );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkDetailScreen(
          work: work,
          initialCoverImageProvider: coverProvider,
        ),
      ),
    );
  }

  bool _isUnifiedExternalWork(Work work) {
    if (work.id < 0) return true;
    final rawUrl = work.sourceUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return false;
    final host = Uri.tryParse(rawUrl)?.host.toLowerCase() ?? '';
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
  final _CollectionsCopy copy;
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
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.32)),
      ),
      clipBehavior: Clip.antiAlias,
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
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
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
  final VoidCallback onRemove;
  final String removeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final directCover = work.images?.isNotEmpty == true ? work.images!.first : null;
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
            child: PrivacyBlurCover(child: _Cover(url: directCover)),
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

class _CollectionsEmpty extends StatelessWidget {
  const _CollectionsEmpty({required this.copy, required this.onCreate});

  final _CollectionsCopy copy;
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
            Icon(Icons.folder_copy_outlined, size: 60, color: scheme.primary),
            const SizedBox(height: 14),
            Text(
              copy.emptyTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              copy.emptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(copy.create),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionsCopy {
  const _CollectionsCopy({
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
    required this.collectionEmpty,
    required this.notFound,
    required this.remove,
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
  final String collectionEmpty;
  final String notFound;
  final String remove;
  final String Function(int) items;

  static _CollectionsCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return _CollectionsCopy(
        title: 'Koleksi Lokal',
        create: 'Buat koleksi',
        createTitle: 'Buat koleksi lokal',
        renameTitle: 'Ubah nama koleksi',
        rename: 'Ubah nama',
        deleteTitle: 'Hapus koleksi?',
        delete: 'Hapus',
        deleteMessage: (name) => 'Koleksi “$name” akan dihapus. Karya dan file asli tidak ikut dihapus.',
        cancel: 'Batal',
        save: 'Simpan',
        nameHint: 'Contoh: Sleep, Favorit, Dengarkan nanti',
        emptyTitle: 'Buat ruang untuk karya pilihanmu',
        emptySubtitle:
            'Koleksi lokal tidak bergantung pada playlist server dan tetap mengikuti Hiraukan saat kamu berganti akun.',
        collectionEmpty:
            'Koleksi ini masih kosong. Buka detail karya lalu pilih “Simpan ke Koleksi”.',
        notFound: 'Koleksi tidak ditemukan.',
        remove: 'Hapus dari koleksi',
        items: (count) => '$count karya',
      );
    }
    return _CollectionsCopy(
      title: 'Local Collections',
      create: 'Create collection',
      createTitle: 'Create local collection',
      renameTitle: 'Rename collection',
      rename: 'Rename',
      deleteTitle: 'Delete collection?',
      delete: 'Delete',
      deleteMessage: (name) => '“$name” will be deleted. Original works and files are not removed.',
      cancel: 'Cancel',
      save: 'Save',
      nameHint: 'For example: Sleep, Favorites, Listen Later',
      emptyTitle: 'Make space for the works you care about',
      emptySubtitle:
          'Local collections do not depend on server playlists and remain available when you switch accounts.',
      collectionEmpty:
          'This collection is empty. Open a work and choose “Save to Collection”.',
      notFound: 'Collection not found.',
      remove: 'Remove from collection',
      items: (count) => '$count works',
    );
  }
}
