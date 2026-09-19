import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/translation_glossary_provider.dart';
import '../services/translation_glossary_service.dart';

class TranslationGlossaryScreen extends ConsumerWidget {
  const TranslationGlossaryScreen({super.key});

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref, {
    TranslationGlossaryEntry? existing,
  }) async {
    final sourceController = TextEditingController(text: existing?.source ?? '');
    final targetController = TextEditingController(text: existing?.target ?? '');

    final entry = await showDialog<TranslationGlossaryEntry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Tambah istilah' : 'Edit istilah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sourceController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Jepang / istilah asli',
                hintText: 'Contoh: お兄ちゃん',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              decoration: const InputDecoration(
                labelText: 'Indonesia / istilah tujuan',
                hintText: 'Contoh: Kakak',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final source = sourceController.text.trim();
              final target = targetController.text.trim();
              if (source.isEmpty || target.isEmpty) return;
              Navigator.of(dialogContext).pop(
                TranslationGlossaryEntry(
                  source: source,
                  target: target,
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    sourceController.dispose();
    targetController.dispose();
    if (entry == null || !context.mounted) return;

    await ref.read(translationGlossaryProvider.notifier).upsert(
          entry,
          previousSource: existing?.source,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGlossary = ref.watch(translationGlossaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Glosarium AI Translate'),
        actions: [
          IconButton(
            tooltip: 'Tambah istilah',
            onPressed: () => _editEntry(context, ref),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: asyncGlossary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal membuka glosarium: $error'),
          ),
        ),
        data: (snapshot) {
          if (snapshot.entries.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada istilah khusus',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tambahkan nama karakter, panggilan, honorific, atau istilah '
                  'ASMR yang ingin dipertahankan konsisten saat Jepang '
                  'diterjemahkan ke Indonesia.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _editEntry(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah istilah'),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.entries.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == snapshot.entries.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Hapus semua istilah?'),
                          content: const Text(
                            'Cache terjemahan lama tidak akan dipakai lagi '
                            'karena fingerprint glosarium berubah.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Batal'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Hapus semua'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(translationGlossaryProvider.notifier)
                            .clear();
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Hapus semua glosarium'),
                  ),
                );
              }

              final entry = snapshot.entries[index];
              return Card(
                child: ListTile(
                  title: Text(entry.source),
                  subtitle: Text(entry.target),
                  leading: const Icon(Icons.translate),
                  onTap: () => _editEntry(
                    context,
                    ref,
                    existing: entry,
                  ),
                  trailing: IconButton(
                    tooltip: 'Hapus',
                    onPressed: () => ref
                        .read(translationGlossaryProvider.notifier)
                        .remove(entry.source),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
