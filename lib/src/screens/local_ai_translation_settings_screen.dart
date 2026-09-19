import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/local_translation_provider.dart';
import '../providers/local_translation_quality_provider.dart';
import '../providers/translation_glossary_provider.dart';
import '../services/local_translation_engine.dart';
import '../services/subtitle_translation_cache.dart';
import 'translation_glossary_screen.dart';

class LocalAiTranslationSettingsScreen extends ConsumerWidget {
  const LocalAiTranslationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStatus = ref.watch(localTranslationModelProvider);
    final cacheStats = ref.watch(translationDocumentCacheStatsProvider);
    final quality = ref.watch(localTranslationQualityProvider);
    final glossary = ref.watch(translationGlossaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Translate Lokal')),
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
                    'Local Lite · Jepang → Indonesia',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gratis, tanpa API key. Setelah model diunduh, terjemahan '
                    'berjalan di perangkat dan dapat digunakan offline.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Model bahasa tidak disertakan di APK. Storage bertambah '
                    'hanya setelah Anda memilih Download Model.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          asyncStatus.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ModelCard(
              status: 'Gagal membaca status model',
              details: error.toString(),
              primaryLabel: 'Coba lagi',
              onPrimary: () =>
                  ref.read(localTranslationModelProvider.notifier).refresh(),
            ),
            data: (status) => _buildStatusCard(context, ref, status),
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
                      .read(localTranslationQualityProvider.notifier)
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
                      .read(localTranslationQualityProvider.notifier)
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
                      '${stats.documents} dokumen · '
                      '${_formatBytes(stats.bytes)}',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cache tetap dapat dipakai setelah model AI dihapus. '
                      'Hapus cache hanya jika Anda ingin mengosongkan hasil '
                      'terjemahan yang sudah dibuat.',
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
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Catatan: Local Lite adalah engine awal. Arsitektur Hiraukan '
                'tetap modular agar Local HQ atau engine lain dapat ditambahkan '
                'tanpa mengubah player dan sistem subtitle. Model bahasa '
                'dikelola oleh runtime ML Kit dan tidak dibundel ke APK.',
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

  Widget _buildStatusCard(
    BuildContext context,
    WidgetRef ref,
    LocalTranslationModelStatus status,
  ) {
    final notifier = ref.read(localTranslationModelProvider.notifier);
    final label = switch (status.state) {
      LocalModelState.notInstalled => 'Belum diunduh',
      LocalModelState.downloading => 'Sedang mengunduh',
      LocalModelState.verifying => 'Memverifikasi',
      LocalModelState.ready => 'Siap digunakan',
      LocalModelState.updateAvailable => 'Pembaruan tersedia',
      LocalModelState.corrupt => 'Model rusak',
      LocalModelState.incompatible => 'Model tidak kompatibel',
      LocalModelState.failed => 'Gagal',
    };

    if (status.isReady) {
      return _ModelCard(
        status: label,
        details:
            'Engine: ${status.engineId} ${status.engineVersion}\n'
            'Model Jepang: siap\nModel Indonesia: siap',
        primaryLabel: 'Periksa ulang',
        onPrimary: notifier.refresh,
        secondaryLabel: 'Hapus Model',
        onSecondary: notifier.delete,
      );
    }

    if (status.state == LocalModelState.downloading ||
        status.state == LocalModelState.verifying) {
      return _ModelCard(
        status: label,
        details: 'Jangan tutup paksa aplikasi selama pemasangan model.',
      );
    }

    return _ModelCard(
      status: label,
      details: status.message ??
          'Download model Jepang dan Indonesia saat Anda siap menggunakan '
              'AI Translate Lokal.',
      primaryLabel: 'Download Model (Wi-Fi)',
      onPrimary: () => notifier.download(wifiOnly: true),
      secondaryLabel: 'Download via jaringan apa pun',
      onSecondary: () => notifier.download(wifiOnly: false),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.status,
    required this.details,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String status;
  final String details;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(details),
            if (primaryLabel != null || secondaryLabel != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (primaryLabel != null)
                    FilledButton.icon(
                      onPressed: onPrimary,
                      icon: const Icon(Icons.download),
                      label: Text(primaryLabel!),
                    ),
                  if (secondaryLabel != null)
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
