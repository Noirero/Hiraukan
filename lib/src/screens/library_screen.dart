import 'package:flutter/material.dart';

import 'listening_moments_screen.dart';
import 'local_collections_screen.dart';
import 'my_screen.dart';

/// Product-level Library shell.
///
/// The mature MyScreen tab implementation remains intact underneath. Hiraukan-
/// owned library features live as explicit actions without duplicating those tabs.
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
            tooltip: copy.moments,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ListeningMomentsScreen(),
              ),
            ),
            icon: const Icon(Icons.bookmarks_outlined),
          ),
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
  const _LibraryCopy({
    required this.title,
    required this.localCollections,
    required this.moments,
  });

  final String title;
  final String localCollections;
  final String moments;

  static _LibraryCopy of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'id' => const _LibraryCopy(
          title: 'Koleksi',
          localCollections: 'Koleksi lokal',
          moments: 'Moments',
        ),
      'ja' => const _LibraryCopy(
          title: 'ライブラリ',
          localCollections: 'ローカルコレクション',
          moments: 'モーメント',
        ),
      'zh' => _LibraryCopy(
          title: locale.scriptCode == 'Hant' ? '資料庫' : '资料库',
          localCollections: locale.scriptCode == 'Hant' ? '本機收藏' : '本地收藏',
          moments: locale.scriptCode == 'Hant' ? '時間標記' : '时间标记',
        ),
      'ru' => const _LibraryCopy(
          title: 'Медиатека',
          localCollections: 'Локальные коллекции',
          moments: 'Моменты',
        ),
      _ => const _LibraryCopy(
          title: 'Library',
          localCollections: 'Local collections',
          moments: 'Moments',
        ),
    };
  }
}
