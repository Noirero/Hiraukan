import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/asr_benchmark.dart';
import '../services/asr_benchmark_lab_service.dart';
import '../services/ai_transcription_service.dart';

class AsrBenchmarkLabScreen extends StatefulWidget {
  const AsrBenchmarkLabScreen({super.key});

  @override
  State<AsrBenchmarkLabScreen> createState() => _AsrBenchmarkLabScreenState();
}

class _AsrBenchmarkLabScreenState extends State<AsrBenchmarkLabScreen> {
  String? _folderPath;
  String? _status;
  String? _error;
  AsrBenchmarkLabResult? _result;
  bool _running = false;
  Map<String, bool>? _modelReady;

  @override
  void initState() {
    super.initState();
    _refreshModels();
  }

  Future<void> _refreshModels() async {
    final service = AiTranscriptionService.instance;
    final result = <String, bool>{};
    for (final name in const ['base', 'tiny', 'small']) {
      final model = service.modelFromName(name);
      result[name] = await service.isModelInstalled(model);
    }
    if (!mounted) return;
    setState(() => _modelReady = result);
  }

  Future<void> _pickFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Pilih folder corpus ASR benchmark',
    );
    if (path == null || !mounted) return;

    setState(() {
      _folderPath = path;
      _status = null;
      _error = null;
      _result = null;
    });
  }

  Future<void> _run() async {
    final folder = _folderPath;
    if (folder == null) {
      setState(() => _error = 'Pilih folder benchmark terlebih dahulu.');
      return;
    }

    final manifest = File('$folder${Platform.pathSeparator}manifest.json');
    if (!await manifest.exists()) {
      setState(() {
        _error = 'manifest.json tidak ditemukan di folder yang dipilih.';
      });
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _result = null;
      _status = 'Menyiapkan benchmark…';
    });

    try {
      final result = await const AsrBenchmarkLabService().run(
        manifest: manifest,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _status = status);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _status = 'Benchmark selesai.';
      });
    } on AsrBenchmarkModelsMissingException catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            'Model Whisper belum lengkap: ${error.modelNames.join(', ')}. '
            'Download model secara manual dari pengaturan ASR.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Benchmark gagal: $error');
    } finally {
      if (mounted) {
        setState(() => _running = false);
        await _refreshModels();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final modelReady = _modelReady;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ASR Benchmark Lab'),
      ),
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
                    'Benchmark-only',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Membandingkan Whisper Base (Compatibility), Tiny (Fast), '
                    'dan Small (High Quality) pada corpus Jepang/ASMR yang sama. '
                    'Hasil benchmark tidak mengaktifkan Fast atau High Quality '
                    'secara otomatis.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Folder harus memiliki manifest.json. audioPath pada '
                    'manifest boleh berupa path relatif terhadap folder tersebut.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                _modelTile(
                  'Whisper Base · Compatibility',
                  modelReady?['base'],
                ),
                const Divider(height: 1),
                _modelTile(
                  'Whisper Tiny · Fast candidate',
                  modelReady?['tiny'],
                ),
                const Divider(height: 1),
                _modelTile(
                  'Whisper Small · HQ candidate',
                  modelReady?['small'],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined),
                  title: const Text('Pilih folder benchmark'),
                  subtitle: Text(
                    _folderPath ?? 'Belum ada folder dipilih',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  enabled: !_running,
                  onTap: _pickFolder,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: _running
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.science_outlined),
                  title: const Text('Jalankan benchmark'),
                  subtitle: Text(
                    _status ??
                        'Menjalankan Base → Tiny → Small secara serial.',
                  ),
                  enabled: !_running,
                  onTap: _running ? null : _run,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            _resultCard(context, _result!),
          ],
        ],
      ),
    );
  }

  Widget _modelTile(String title, bool? ready) {
    return ListTile(
      leading: Icon(
        ready == null
            ? Icons.hourglass_empty
            : ready
                ? Icons.check_circle_outline
                : Icons.download_for_offline_outlined,
      ),
      title: Text(title),
      subtitle: Text(
        ready == null
            ? 'Memeriksa model…'
            : ready
                ? 'Model siap'
                : 'Belum diunduh',
      ),
    );
  }

  Widget _resultCard(
    BuildContext context,
    AsrBenchmarkLabResult result,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hasil benchmark',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _summaryRow('Compatibility · Base', result.compatibility),
            _summaryRow('Fast · Tiny', result.fast),
            _summaryRow('High Quality · Small', result.highQuality),
            const Divider(height: 24),
            _gateRow('Fast gate', result.fastGate),
            const SizedBox(height: 6),
            _gateRow('High Quality gate', result.highQualityGate),
            const SizedBox(height: 12),
            Text(
              'Laporan: ${result.reportPath}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final report = await File(result.reportPath).readAsString();
                await Clipboard.setData(
                  ClipboardData(text: report),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Laporan JSON disalin.'),
                  ),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Salin laporan JSON'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, AsrBenchmarkSummary summary) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        '$label · CER ${summary.meanCharacterErrorRate.toStringAsFixed(3)} · '
        'RTF ${summary.meanRealTimeFactor.toStringAsFixed(3)}',
      ),
    );
  }

  Widget _gateRow(String label, AsrBenchmarkGateResult gate) {
    final details = gate.reasons.isEmpty
        ? 'tidak ada pelanggaran gate'
        : gate.reasons.join(' · ');
    return Text(
      '$label: ${gate.state.name.toUpperCase()} · $details',
    );
  }
}
