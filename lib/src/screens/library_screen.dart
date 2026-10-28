import 'package:flutter/material.dart';

import 'listening_moments_screen.dart';
import 'local_collections_screen.dart';
import 'my_screen.dart';
import 'portable_backup_screen.dart';

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
          PopupMenuButton<String>(
            tooltip: copy.more,
            onSelected: (value) {
              final screen = switch (value) {
                'moments' => const ListeningMomentsScreen(),
                'collections' => const LocalCollectionsScreen(),
                'backup' => const PortableBackupScreen(),
                _ => null,
              };
              if (screen != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => screen),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'moments',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bookmarks_outlined),
                  title: Text(copy.moments),
                ),
              ),
              PopupMenuItem(
                value: 'collections',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_copy_outlined),
                  title: Text(copy.localCollections),
                ),
              ),
              PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(copy.backup),
                ),
              ),
            ],
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
    required this.backup,
    required this.more,
  });

  final String title;
  final String localCollections;
  final String moments;
  final String backup;
  final String more;

  static _LibraryCopy of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'id' => const _LibraryCopy(
          title: 'Koleksi',
          localCollections: 'Koleksi lokal',
          moments: 'Moments',
          backup: 'Backup & Restore',
          more: 'Opsi koleksi',
        ),
      'ja' => const _LibraryCopy(
          title: 'ライブラリ',
          localCollections: 'ローカルコレクション',
          moments: 'モーメント',
          backup: 'バックアップと復元',
          more: 'ライブラリメニュー',
        ),
      'zh' => _LibraryCopy(
          title: locale.scriptCode == 'Hant' ? '資料庫' : '资料库',
          localCollections: locale.scriptCode == 'Hant' ? '本機收藏' : '本地收藏',
          moments: locale.scriptCode == 'Hant' ? '時間標記' : '时间标记',
          backup: locale.scriptCode == 'Hant' ? '備份與還原' : '备份与恢复',
          more: locale.scriptCode == 'Hant' ? '資料庫選項' : '资料库选项',
        ),
      'ru' => const _LibraryCopy(
          title: 'Медиатека',
          localCollections: 'Локальные коллекции',
          moments: 'Моменты',
          backup: 'Резервная копия',
          more: 'Параметры медиатеки',
        ),
      _ => const _LibraryCopy(
          title: 'Library',
          localCollections: 'Local collections',
          moments: 'Moments',
          backup: 'Backup & Restore',
          more: 'Library options',
        ),
    };
  }
}
