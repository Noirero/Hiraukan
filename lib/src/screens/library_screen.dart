import 'package:flutter/material.dart';

import 'local_collections_screen.dart';
import 'my_screen.dart';

/// Product-level Library shell.
///
/// The mature MyScreen tab implementation remains intact underneath. This
/// wrapper gives the library a stable product identity and a first-class entry
/// to Hiraukan-owned local collections without duplicating the existing tabs.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = _LibraryCopy.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: copy.localCollections,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LocalCollectionsScreen(),
              ),
            ),
            icon: const Icon(Icons.folder_copy_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: const MyScreen(),
      ),
    );
  }
}

class _LibraryCopy {
  const _LibraryCopy({required this.title, required this.localCollections});

  final String title;
  final String localCollections;

  static _LibraryCopy of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'id' => const _LibraryCopy(
          title: 'Koleksi',
          localCollections: 'Koleksi lokal',
        ),
      'ja' => const _LibraryCopy(
          title: 'ライブラリ',
          localCollections: 'ローカルコレクション',
        ),
      'zh' => _LibraryCopy(
          title: locale.scriptCode == 'Hant' ? '資料庫' : '资料库',
          localCollections: locale.scriptCode == 'Hant' ? '本機收藏' : '本地收藏',
        ),
      'ru' => const _LibraryCopy(
          title: 'Медиатека',
          localCollections: 'Локальные коллекции',
        ),
      _ => const _LibraryCopy(
          title: 'Library',
          localCollections: 'Local collections',
        ),
    };
  }
}
