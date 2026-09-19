import 'package:flutter/material.dart';

import '../services/reazon_fast_model_service.dart';

class FastAsrModelSettingsScreen extends StatefulWidget {
  const FastAsrModelSettingsScreen({super.key});

  @override
  State<FastAsrModelSettingsScreen> createState() =>
      _FastAsrModelSettingsScreenState();
}

class _FastAsrModelSettingsScreenState
    extends State<FastAsrModelSettingsScreen> {
  ReazonFastModelStatus? _status;
  bool _busy = false;
  double? _progress;
  String? _activeFile;
  String? _message;
  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await ReazonFastModelService.instance.status();
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _download() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _activeFile = null;
      _message = 'Menyiapkan download model Fast…';
      _cancelRequested = false;
    });

    try {
      final result = await ReazonFastModelService.instance.download(
        isCancelled: () => _cancelRequested,
        onProgress: (received, total, fileName) {
          if (!mounted) return;
          setState(() {
            _activeFile = fileName;
            _progress =
                total > 0 ? (received / total).clamp(0.0, 1.0) : null;
            _message = total > 0
                ? 'Fast ASR ${(received / 1048576).toStringAsFixed(0)} / '
                    '${(total / 1048576).toStringAsFixed(0)} MiB'
                : 'Mengunduh Fast ASR…';
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _status = result;
        _message = 'Model Fast siap digunakan.';
      });
    } on ReazonFastDownloadCancelledException {
      if (!mounted) return;
      setState(() => _message = 'Download model Fast dibatalkan.');
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Download model Fast gagal: $error');
      await _refresh();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
          _activeFile = null;
        });
      }
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ReazonFastModelService.instance.delete();
      if (!mounted) return;
      setState(() {
        _message = 'Model Fast dihapus. Subtitle yang sudah dibuat tidak ikut dihapus.';
      });
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stateLabel(FastAsrModelState state) => switch (state) {
        FastAsrModelState.notInstalled => 'Belum diunduh',
        FastAsrModelState.downloading => 'Sedang mengunduh',
        FastAsrModelState.verifying => 'Memverifikasi',
        FastAsrModelState.ready => 'Siap digunakan',
        FastAsrModelState.updateAvailable => 'Pembaruan model tersedia',
        FastAsrModelState.incompatible => 'Model tidak kompatibel',
        FastAsrModelState.corrupt => 'Model tidak lengkap / rusak',
        FastAsrModelState.failed => 'Gagal',
      };

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final mib = bytes / 1048576;
    return '${mib.toStringAsFixed(1)} MiB';
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;

    return Scaffold(
      appBar: AppBar(title: const Text('Fast ASR · Jepang')),
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
                    'ReazonSpeech K2 v2 · Fast',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Japanese speech recognition lokal melalui sherpa-onnx. '
                    'Model tidak disertakan dalam APK dan hanya memakai storage '
                    'setelah Anda memilih Download.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Audio asli tidak diubah. Hiraukan membuat salinan PCM '
                    'sementara 16 kHz dan memprosesnya dalam potongan aman.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: status == null
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _stateLabel(status.state),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Model weights: sekitar '
                          '${_formatBytes(ReazonFastModelService.expectedWeightBytes)} '
                          '+ tokens',
                        ),
                        if (status.installedBytes > 0)
                          Text(
                            'Terpasang: ${_formatBytes(status.installedBytes)}',
                          ),
                        if (status.message != null) ...[
                          const SizedBox(height: 6),
                          Text(status.message!),
                        ],
                        if (_progress != null) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: _progress),
                          const SizedBox(height: 6),
                          Text(
                            _activeFile == null
                                ? (_message ?? 'Mengunduh…')
                                : '${_message ?? 'Mengunduh…'}\n$_activeFile',
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!status.isReady)
                              FilledButton.icon(
                                onPressed: _busy ? null : _download,
                                icon: const Icon(Icons.download),
                                label: const Text('Download Fast Model'),
                              ),
                            if (_busy)
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _cancelRequested = true);
                                },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Batalkan'),
                              ),
                            if (status.installedBytes > 0 && !_busy)
                              OutlinedButton.icon(
                                onPressed: _delete,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Hapus Model'),
                              ),
                            if (!_busy)
                              TextButton(
                                onPressed: _refresh,
                                child: const Text('Periksa ulang'),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          if (_message != null && _progress == null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Integrity: file ONNX diverifikasi ukuran + SHA-256 sebelum '
                'diaktifkan. Instalasi memakai file sementara dan baru dianggap '
                'siap setelah seluruh komponen valid. License model: Apache-2.0.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
