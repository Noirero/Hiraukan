import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/local_translation_provider.dart';
import '../services/local_translation_engine.dart';

class LocalAiTranslationSettingsScreen extends ConsumerWidget {
  const LocalAiTranslationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStatus = ref.watch(localTranslationModelProvider);

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
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Catatan: Local Lite adalah engine awal. Arsitektur Hiraukan '
                'tetap modular agar Local HQ atau engine lain dapat ditambahkan '
                'tanpa mengubah player dan sistem subtitle.',
              ),
            ),
          ),
        ],
      ),
    );
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
      secondaryLabel: 'Refresh',
      onSecondary: notifier.refresh,
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
