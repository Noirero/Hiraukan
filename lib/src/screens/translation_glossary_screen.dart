import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/translation_glossary_provider.dart';
import '../services/translation_glossary_service.dart';

class TranslationGlossaryScreen extends ConsumerWidget {
  const TranslationGlossaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glossary = ref.watch(translationGlossaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Glossary AI Translate')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntry(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Istilah'),
      ),
      body: glossary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Gagal membaca glossary: $error'),
          ),
        ),
        data: (snapshot) {
          if (snapshot.entries.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada istilah khusus.\n\n'
                  'Tambahkan nama karakter, panggilan, honorific, nama tempat, '
                  'atau istilah yang ingin dipertahankan secara konsisten.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: snapshot.entries.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = snapshot.entries[index];
              return ListTile(
                leading: const Icon(Icons.translate),
                title: Text(entry.source),
                subtitle: Text(entry.target),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus',
                  onPressed: () async {
                    final next = List<TranslationGlossaryEntry>.from(
                      snapshot.entries,
                    )..removeAt(index);
                    await ref
                        .read(translationGlossaryProvider.notifier)
                        .replaceAll(next);
                  },
                ),
                onTap: () => _editEntry(
                  context,
                  ref,
                  snapshot,
                  index,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addEntry(BuildContext context, WidgetRef ref) async {
    final current = ref.read(translationGlossaryProvider).valueOrNull;
    if (current == null) return;

    final entry = await _showEntryDialog(context);
    if (entry == null) return;

    await ref
        .read(translationGlossaryProvider.notifier)
        .replaceAll([...current.entries, entry]);
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    TranslationGlossarySnapshot snapshot,
    int index,
  ) async {
    final entry = await _showEntryDialog(
      context,
      initial: snapshot.entries[index],
    );
    if (entry == null) return;

    final next = List<TranslationGlossaryEntry>.from(snapshot.entries);
    next[index] = entry;
    await ref.read(translationGlossaryProvider.notifier).replaceAll(next);
  }

  Future<TranslationGlossaryEntry?> _showEntryDialog(
    BuildContext context, {
    TranslationGlossaryEntry? initial,
  }) async {
    final sourceController = TextEditingController(text: initial?.source);
    final targetController = TextEditingController(text: initial?.target);

    final result = await showDialog<TranslationGlossaryEntry>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initial == null ? 'Tambah Istilah' : 'Edit Istilah'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sourceController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Teks Jepang',
                hintText: 'Contoh: お兄ちゃん',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              decoration: const InputDecoration(
                labelText: 'Hasil Indonesia',
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
    return result;
  }
}
