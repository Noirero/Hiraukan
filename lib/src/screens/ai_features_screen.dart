import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_transcription_service.dart';
import '../services/kikoflu_feature_settings.dart';
import '../services/subtitle_language_settings.dart';

class AiFeaturesScreen extends StatefulWidget {
  const AiFeaturesScreen({super.key});

  @override
  State<AiFeaturesScreen> createState() => _AiFeaturesScreenState();
}

class _AiFeaturesScreenState extends State<AiFeaturesScreen> {
  final _settings = KikoFluFeatureSettings.instance;
  final _languages = SubtitleLanguageSettings.instance;
  final _service = AiTranscriptionService.instance;

  bool _checking = true;
  bool _busy = false;
  bool _installed = false;
  int? _installedSize;
  double? _progress;
  String? _status;

  LocalAiModelConfig get _config => modelConfigFor(_settings.whisperModel);

  @override
  void initState() {
    super.initState();
    _refreshModel();
  }

  Future<void> _refreshModel() async {
    final config = _config;
    final installed = await _service.isModelConfigInstalled(config);
    final size = await _service.modelConfigSize(config);
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _installedSize = size;
      _checking = false;
    });
  }

  Future<void> _selectModel(String? name) async {
    if (name == null || name == _settings.whisperModel) return;
    await _settings.setWhisperModel(name);
    if (!mounted) return;
    setState(() {
      _checking = true;
      _progress = null;
      _status = null;
    });
    await _refreshModel();
  }

  Future<void> _downloadModel() async {
    final config = _config;
    setState(() {
      _busy = true;
      _progress = 0;
      _status = 'Mengunduh ${config.displayName}…';
    });
    try {
      await _service.downloadModelConfig(
        config,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? received / total : null;
            _status = total > 0
                ? '${_formatBytes(received)} / ${_formatBytes(total)}'
                : _formatBytes(received);
          });
        },
      );
      await _settings.setAiTranscriptionEnabled(true);
      if (!mounted) return;
      setState(() => _status = 'Model siap digunakan untuk subtitle lokal.');
      await _refreshModel();
    } catch (error) {
      if (mounted) setState(() => _status = 'Download gagal: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBrowser() async {
    final launched = await launchUrl(
      _config.downloadUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      setState(() => _status = 'Browser tidak dapat dibuka.');
    }
  }

  Future<void> _importModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['bin'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;

    setState(() {
      _busy = true;
      _status = 'Mengimpor model…';
    });
    try {
      await _service.importModelConfigFromFile(
        sourceFilePath: path,
        config: _config,
      );
      await _settings.setAiTranscriptionEnabled(true);
      await _refreshModel();
      if (mounted) setState(() => _status = 'Model berhasil diimpor.');
    } catch (error) {
      if (mounted) setState(() => _status = 'Import gagal: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteModel() async {
    await _service.deleteModelConfig(_config);
    await _settings.setAiTranscriptionEnabled(false);
    await _refreshModel();
    if (mounted) {
      setState(() {
        _progress = null;
        _status =
            'Model ${_config.displayName} dihapus. Subtitle ASR yang sudah dibuat tetap dapat dipakai dari cache.';
      });
    }
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
    final theme = Theme.of(context);
    final config = _config;
    final sourceLanguage = _languages.sourceLanguage;
    final targetLanguage = _languages.targetLanguage;

    return Scaffold(
      appBar: AppBar(title: const Text('Fitur AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    child: Icon(
                      Icons.auto_awesome,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fitur AI',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Transkripsi lokal dan pembuatan subtitle bertimestamp. '
                          'Model tidak ditanam di APK dan hanya aktif setelah diunduh.',
                        ),
                      ],
                    ),
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
                  const Text(
                    'AI Model',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: config.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final item in localAiModelConfigs)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            '${item.recommended ? '★ ' : ''}'
                            '${item.displayName}'
                            '${item.recommended ? ' (Recommended)' : ''}'
                            '${item.badge == null ? '' : ' · ${item.badge}'} '
                            '${item.sizeLabel}',
                          ),
                        ),
                    ],
                    onChanged: _busy ? null : _selectModel,
                  ),
                  const SizedBox(height: 16),
                  _specRow('Size', config.sizeLabel),
                  _specRow(
                    'Speed',
                    List.filled(config.speedRating, '⚡').join(),
                  ),
                  _specRow(
                    'Accuracy',
                    List.filled(config.accuracyRating, '★').join() +
                        List.filled(5 - config.accuracyRating, '☆').join(),
                  ),
                  _specRow('Min RAM', config.minRam),
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
                  const Row(
                    children: [
                      Icon(Icons.table_chart_outlined, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Model Comparison',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Base direkomendasikan untuk keseimbangan ukuran, kecepatan, dan akurasi. '
                    'Model besar membutuhkan RAM dan waktu proses lebih tinggi.',
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Model')),
                        DataColumn(label: Text('Size')),
                        DataColumn(label: Text('Speed')),
                        DataColumn(label: Text('RAM')),
                      ],
                      rows: [
                        for (final item in localAiModelConfigs)
                          DataRow(
                            selected: item.id == config.id,
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (item.recommended)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: Icon(
                                          Icons.star_rounded,
                                          size: 16,
                                        ),
                                      ),
                                    Text(item.displayName),
                                  ],
                                ),
                              ),
                              DataCell(Text(item.sizeLabel)),
                              DataCell(
                                Text(
                                  List.filled(item.speedRating, '⚡').join(),
                                ),
                              ),
                              DataCell(Text(item.minRam)),
                            ],
                          ),
                      ],
                    ),
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
                children: [
                  _infoRow(
                    Icons.inventory_2_outlined,
                    'Fitur AI',
                    _checking
                        ? 'Memeriksa…'
                        : _installed
                            ? 'Model terpasang'
                            : 'Paket AI belum terinstal',
                  ),
                  _infoRow(
                    Icons.model_training_outlined,
                    'Model',
                    config.recommended
                        ? '${config.displayName} (Recommended)'
                        : config.badge == null
                            ? config.displayName
                            : '${config.displayName} · ${config.badge}',
                  ),
                  if (_installedSize != null)
                    _infoRow(
                      Icons.storage_outlined,
                      'Ukuran terpasang',
                      _formatBytes(_installedSize!),
                    ),
                  const Divider(height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gunakan Whisper Lokal'),
                    subtitle: Text(
                      _installed
                          ? 'Suara → teks diproses di perangkat tanpa biaya server.'
                          : 'Unduh atau import model terlebih dahulu.',
                    ),
                    value: _settings.aiTranscriptionEnabled && _installed,
                    onChanged: _installed
                        ? (value) async {
                            await _settings.setAiTranscriptionEnabled(value);
                            if (mounted) setState(() {});
                          }
                        : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Otomatis buat subtitle jika tidak ada'),
                    subtitle: const Text(
                      'Subtitle sumber/lokal/cache tetap diprioritaskan. '
                      'Whisper hanya dipakai ketika tidak ada subtitle.',
                    ),
                    value: _settings.autoAsrTranslateFallback,
                    onChanged: (value) async {
                      await _settings.setAutoAsrTranslateFallback(value);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_progress != null && _busy)
                    LinearProgressIndicator(value: _progress),
                  if (_progress != null && _busy)
                    const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : _installed
                              ? _deleteModel
                              : _downloadModel,
                      icon: Icon(
                        _installed
                            ? Icons.delete_outline
                            : Icons.download_rounded,
                      ),
                      label: Text(
                        _installed ? 'Hapus Model' : 'Unduh Model',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _openBrowser,
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Via Browser'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _importModel,
                          icon: const Icon(Icons.file_open_outlined),
                          label: const Text('Import File'),
                        ),
                      ),
                    ],
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
                  const Text(
                    'Bahasa subtitle',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: sourceLanguage,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Bahasa audio / sumber',
                      border: OutlineInputBorder(),
                    ),
                    items: _languageItems(
                      current: sourceLanguage,
                      includeAuto: true,
                    ),
                    onChanged: (value) async {
                      if (value == null) return;
                      await _languages.setSourceLanguage(value);
                      if (mounted) setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
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
                    onChanged: (value) async {
                      if (value == null) return;
                      await _languages.setTargetLanguage(value);
                      if (mounted) setState(() {});
                    },
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
                  const Text(
                    'Transcription Speed',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('CPU Threads'),
                      const Spacer(),
                      Text('${_settings.whisperThreads} threads'),
                    ],
                  ),
                  Slider(
                    value: _settings.whisperThreads.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    label: '${_settings.whisperThreads}',
                    onChanged: (value) async {
                      await _settings.setWhisperThreads(value.round());
                      if (mounted) setState(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mode Cepat'),
                    subtitle: const Text(
                      'Memakai optimasi speed-up Whisper. Lebih cepat muncul, '
                      'dengan sedikit kompromi akurasi pada audio yang sulit.',
                    ),
                    value: _settings.whisperSpeedUp,
                    onChanged: (value) async {
                      await _settings.setWhisperSpeedUp(value);
                      if (mounted) setState(() {});
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Word-Level Timestamps'),
                    subtitle: const Text(
                      'OFF lebih cepat. ON membuat segmentasi lebih detail.',
                    ),
                    value: _settings.whisperSplitOnWord,
                    onChanged: (value) async {
                      await _settings.setWhisperSplitOnWord(value);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Alur: subtitle sumber/lokal/cache dicoba lebih dulu. Jika tidak '
                'ada dan model ini sudah diunduh, Whisper lokal membuat subtitle '
                'bertimestamp. Setelah itu translate berjalan online ke bahasa '
                'tujuan. Hasil terjemahan dapat diunduh dan dipakai offline.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KiB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
  }
}
