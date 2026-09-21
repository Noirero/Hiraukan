import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/lyric_provider.dart';
import '../providers/translation_glossary_provider.dart';
import '../providers/translation_provider.dart';
import '../providers/translation_quality_provider.dart';
import '../services/subtitle_language_settings.dart';
import '../services/subtitle_translation_cache.dart';
import 'translation_glossary_screen.dart';

class OnlineTranslationSettingsScreen extends ConsumerStatefulWidget {
  const OnlineTranslationSettingsScreen({super.key});

  @override
  ConsumerState<OnlineTranslationSettingsScreen> createState() =>
      _OnlineTranslationSettingsScreenState();
}

class _OnlineTranslationSettingsScreenState
    extends ConsumerState<OnlineTranslationSettingsScreen> {
  final _languages = SubtitleLanguageSettings.instance;

  Future<void> _setSourceLanguage(String code) async {
    await _languages.setSourceLanguage(code);
    ref.read(lyricControllerProvider.notifier).clearTranslation();
    if (mounted) setState(() {});
  }

  Future<void> _setTargetLanguage(String code) async {
    await _languages.setTargetLanguage(code);
    ref.read(lyricControllerProvider.notifier).clearTranslation();
    if (mounted) setState(() {});
  }

  Future<void> _editLanguageCode({
    required bool source,
  }) async {
    final current =
        source ? _languages.sourceLanguage : _languages.targetLanguage;
    final controller = TextEditingController(
      text: current == 'auto' ? '' : current,
    );

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          source ? 'Kode bahasa sumber' : 'Kode bahasa tujuan',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: source ? 'contoh: ko, ja, en, auto' : 'contoh: en, ja, id',
            helperText: 'Gunakan kode bahasa yang didukung layanan online.',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.trim().isEmpty) return;

    if (source) {
      await _setSourceLanguage(code);
    } else {
      await _setTargetLanguage(code);
    }
  }

  Future<void> _editAsrEngine() async {
    final controller = TextEditingController(
      text: _languages.asrEngine == 'auto' ? '' : _languages.asrEngine,
    );
    final engine = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Engine ASR online (fallback)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'auto atau ID engine dari gateway',
            helperText:
                'Kosongkan untuk membiarkan gateway memilih engine otomatis.',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (engine == null) return;
    await _languages.setAsrEngine(engine);
    if (mounted) setState(() {});
  }

  List<DropdownMenuItem<String>> _languageItems({
    required String current,
    required bool includeAuto,
  }) {
    final items = <DropdownMenuItem<String>>[];
    if (includeAuto) {
      items.add(
        const DropdownMenuItem(
          value: 'auto',
          child: Text('Auto Detect'),
        ),
      );
    }
    for (final language in SubtitleLanguageSettings.commonLanguages) {
      items.add(
        DropdownMenuItem(
          value: language.code,
          child: Text(language.label),
        ),
      );
    }
    final known = current == 'auto' ||
        SubtitleLanguageSettings.commonLanguages
            .any((language) => language.code == current);
    if (!known) {
      items.add(
        DropdownMenuItem(
          value: current,
          child: Text('Custom · $current'),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(freeOnlineTranslationEngineProvider);
    final cacheStats = ref.watch(translationDocumentCacheStatsProvider);
    final quality = ref.watch(translationQualityProvider);
    final glossary = ref.watch(translationGlossaryProvider);
    final sourceLanguage = _languages.sourceLanguage;
    final targetLanguage = _languages.targetLanguage;
    final asrEngine = _languages.asrEngine;

    return Scaffold(
      appBar: AppBar(title: const Text('Subtitle & Translate Online')),
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
                    '${SubtitleLanguageSettings.labelFor(sourceLanguage)} → '
                    '${SubtitleLanguageSettings.labelFor(targetLanguage)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ASR dan terjemahan diproses online. Hiraukan tidak '
                    'menanam atau mengunduh model bahasa ke APK.',
                  ),
                  const SizedBox(height: 8),
                  Text('Translate engine: ${engine.displayName}'),
                  const SizedBox(height: 4),
                  Text('ASR engine: $asrEngine'),
                  const SizedBox(height: 8),
                  const Text(
                    'Bahasa yang benar-benar dapat diproses mengikuti '
                    'kemampuan engine/gateway online yang dipilih.',
                  ),
                ],
              ),
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
                    'Bahasa pipeline',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('source-$sourceLanguage'),
                    initialValue: sourceLanguage,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Bahasa audio / subtitle sumber',
                      border: OutlineInputBorder(),
                    ),
                    items: _languageItems(
                      current: sourceLanguage,
                      includeAuto: true,
                    ),
                    onChanged: (value) {
                      if (value != null) _setSourceLanguage(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _editLanguageCode(source: true),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Kode bahasa lain'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('target-$targetLanguage'),
                    initialValue: targetLanguage,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Terjemahkan ke',
                      border: OutlineInputBorder(),
                    ),
                    items: _languageItems(
                      current: targetLanguage,
                      includeAuto: false,
                    ),
                    onChanged: (value) {
                      if (value != null) _setTargetLanguage(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _editLanguageCode(source: false),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Kode bahasa lain'),
                    ),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.graphic_eq_rounded),
                    title: const Text('Engine ASR online (fallback)'),
                    subtitle: Text(asrEngine),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _editAsrEngine,
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
                    'Mencoba baris sebelum/sesudah untuk membantu memahami '
                    'kalimat. Jika mapping berubah, otomatis kembali ke '
                    'terjemahan 1:1.',
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
                    'Jika subtitle sumber/lokal/cache tidak tersedia, Hiraukan '
                    'memakai Whisper lokal bila model sudah diunduh. ASR online '
                    'hanya menjadi fallback tambahan bila endpoint dikonfigurasi. '
                    'Auto Detect dapat dipakai atau bahasa sumber dipilih manual.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hasil ASR tetap bertimestamp, lalu diterjemahkan ke '
                    'bahasa tujuan yang dipilih. Gunakan ikon unduh di player '
                    'untuk menyimpan hasil terjemahan agar dapat dipakai offline.',
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
                child: Text('Statistik terjemahan offline tidak tersedia.'),
              ),
            ),
            data: (stats) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terjemahan offline',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${stats.documents} dokumen · ${_formatBytes(stats.bytes)}',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Setiap hasil disimpan bersama pasangan bahasa sumber '
                      'dan tujuan, sehingga satu track dapat memiliki beberapa '
                      'terjemahan offline.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: stats.documents == 0
                          ? null
                          : () async {
                              await SubtitleTranslationCache.instance
                                  .clearDownloaded();
                              ref.invalidate(
                                translationDocumentCacheStatsProvider,
                              );
                            },
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Hapus Terjemahan Offline'),
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
