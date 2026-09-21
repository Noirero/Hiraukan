import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/translation_glossary_provider.dart';
import '../providers/translation_provider.dart';
import '../providers/translation_quality_provider.dart';
import '../services/subtitle_translation_cache.dart';
import 'translation_glossary_screen.dart';

class OnlineTranslationSettingsScreen extends ConsumerWidget {
  const OnlineTranslationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(freeOnlineTranslationEngineProvider);
    final cacheStats = ref.watch(translationDocumentCacheStatsProvider);
    final quality = ref.watch(translationQualityProvider);
    final glossary = ref.watch(translationGlossaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Terjemahan Gratis Online')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jepang → Indonesia',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gratis dan tidak memerlukan API key/token pengguna, akun, '
                    'atau download model. Terjemahan membutuhkan koneksi internet.',
                  ),
                  const SizedBox(height: 8),
                  Text('Engine: ${engine.displayName}'),
                  const SizedBox(height: 8),
                  const Text(
                    'Jika layanan online tidak dapat dijangkau, playback dan '
                    'subtitle Jepang tetap berjalan normal.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.forum_outlined),
                  title: const Text('Gunakan konteks baris sekitar'),
                  subtitle: const Text(
                    'Mencoba baris sebelum/sesudah untuk memahami kalimat '
                    'Jepang yang menghilangkan subjek. Jika mapping berubah, '
                    'otomatis kembali ke terjemahan 1:1.',
                  ),
                  value: quality.contextEnabled,
                  onChanged: (value) => ref
                      .read(translationQualityProvider.notifier)
                      .setContextEnabled(value),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.play_circle_outline),
                  title: const Text('Prioritaskan posisi playback'),
                  subtitle: const Text(
                    'Terjemahkan subtitle dekat posisi yang sedang diputar '
                    'atau setelah seek lebih dahulu.',
                  ),
                  value: quality.playbackPriorityEnabled,
                  onChanged: (value) => ref
                      .read(translationQualityProvider.notifier)
                      .setPlaybackPriorityEnabled(value),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Glossary / istilah khusus'),
                  subtitle: Text(
                    glossary.when(
                      data: (value) =>
                          '${value.entries.length} istilah · versi ${value.version}',
                      loading: () => 'Memuat...',
                      error: (_, __) => 'Tidak tersedia',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TranslationGlossaryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio tanpa subtitle',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fallback subtitle memakai ASR online Jepang. Jalur ini '
                    'tidak memasukkan atau mengunduh model Whisper ke perangkat. '
                    'Audio dikirim ke gateway ASR yang dikonfigurasi pada build, '
                    'lalu hasil teks Jepang bertimestamp diterjemahkan online '
                    'ke Indonesia.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Setelah terjemahan selesai, gunakan ikon unduh di player '
                    'untuk menyimpan hasil subtitle agar dapat dipakai saat offline.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          cacheStats.when(
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            ),
            error: (_, __) => const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Statistik cache terjemahan tidak tersedia.'),
              ),
            ),
            data: (stats) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cache subtitle Indonesia',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.documents} dokumen · ${_formatBytes(stats.bytes)}',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bagian ini berisi terjemahan yang secara eksplisit diunduh '
                      'untuk dipakai kembali saat offline.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: stats.documents == 0
                          ? null
                          : () async {
                              await SubtitleTranslationCache.instance.clear();
                              ref.invalidate(
                                translationDocumentCacheStatsProvider,
                              );
                            },
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Hapus Cache Terjemahan'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kib = bytes / 1024;
    if (kib < 1024) return '${kib.toStringAsFixed(1)} KiB';
    final mib = kib / 1024;
    return '${mib.toStringAsFixed(1)} MiB';
  }
}
