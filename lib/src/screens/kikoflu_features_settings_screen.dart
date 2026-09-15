import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

import '../services/ai_transcription_service.dart';
import '../services/audio_conversion_service.dart';
import '../services/hi_res_audio_service.dart';
import '../services/kikoflu_feature_coordinator.dart';
import '../services/kikoflu_feature_settings.dart';
import '../services/kikoflu_notification_service.dart';

class KikoFluFeaturesSettingsScreen extends StatefulWidget {
  const KikoFluFeaturesSettingsScreen({super.key});

  @override
  State<KikoFluFeaturesSettingsScreen> createState() =>
      _KikoFluFeaturesSettingsScreenState();
}

class _KikoFluFeaturesSettingsScreenState
    extends State<KikoFluFeaturesSettingsScreen> {
  final _settings = KikoFluFeatureSettings.instance;
  bool _busy = false;
  double? _modelProgress;
  String? _status;

  void _refresh() => setState(() {});

  WhisperModel get _selectedModel => AiTranscriptionService.instance
      .modelFromName(_settings.whisperModel);

  Future<void> _downloadModel() async {
    setState(() {
      _busy = true;
      _modelProgress = 0;
      _status = 'Downloading ${_selectedModel.name} model…';
    });
    try {
      await AiTranscriptionService.instance.downloadModel(
        _selectedModel,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _modelProgress = total > 0 ? received / total : null;
            _status = total > 0
                ? 'Model ${(received / 1048576).toStringAsFixed(0)} / ${(total / 1048576).toStringAsFixed(0)} MB'
                : 'Model ${(received / 1048576).toStringAsFixed(0)} MB';
          });
        },
      );
      if (mounted) setState(() => _status = 'Whisper model ready.');
    } catch (error) {
      if (mounted) setState(() => _status = 'Model download failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runBatchTranscription() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (!mounted || path == null) return;

    final installed = await AiTranscriptionService.instance
        .isModelInstalled(_selectedModel);
    if (!installed) {
      setState(() => _status = 'Download the selected Whisper model first.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Scanning audio files…';
    });
    final result = await AiTranscriptionService.instance.transcribeDirectory(
      Directory(path),
      model: _selectedModel,
      threads: _settings.whisperThreads,
      skipExisting: true,
      onProgress: (done, total, file) {
        if (!mounted) return;
        setState(() => _status =
            'Transcribing $done/$total — ${File(file).uri.pathSegments.last}');
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status =
          'Batch complete: ${result.completed} created, ${result.skipped} skipped, ${result.failed} failed.';
    });
  }

  Future<void> _testFcm() async {
    setState(() {
      _busy = true;
      _status = 'Checking Firebase configuration…';
    });
    final token = await KikoFluNotificationService.instance.getFcmToken();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = token == null
          ? 'FCM is not configured for this Hiraukan build.'
          : 'FCM is configured and ready.';
    });
  }

  Future<void> _probeHiRes() async {
    setState(() {
      _busy = true;
      _status = 'Checking Hi-Res output…';
    });
    final caps = await HiResAudioService.instance.capabilities();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = caps.supported
          ? 'Hi-Res: ${caps.deviceName ?? 'device'} — ${caps.sampleRates.join('/')} Hz, ${caps.bitDepths.join('/')} bit.'
          : 'Native Hi-Res bridge is unavailable; normal playback remains active.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Audio & AI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'KikoFlu-derived features are opt-in. Existing Hiraukan sources, downloads and playback remain the default path.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.multitrack_audio_rounded),
                  title: const Text('Crossfade'),
                  subtitle: Text('${_settings.crossfadeMs} ms between tracks'),
                  value: _settings.crossfadeEnabled,
                  onChanged: (value) async {
                    await _settings.setCrossfadeEnabled(value);
                    _refresh();
                  },
                ),
                if (_settings.crossfadeEnabled)
                  Slider(
                    value: _settings.crossfadeMs.toDouble(),
                    min: 250,
                    max: 5000,
                    divisions: 19,
                    label: '${_settings.crossfadeMs} ms',
                    onChanged: (value) async {
                      await _settings.setCrossfadeMs(value.round());
                      _refresh();
                    },
                  ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.transform_rounded),
                  title: const Text('Auto-convert WAV after download'),
                  subtitle: const Text(
                    'Preserves download folder structure and metadata.',
                  ),
                  value: _settings.autoConvertWav,
                  onChanged: (value) async {
                    await _settings.setAutoConvertWav(value);
                    await KikoFluFeatureCoordinator.instance
                        .refreshDownloadWatcher();
                    _refresh();
                  },
                ),
                if (_settings.autoConvertWav)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _settings.conversionFormat,
                      decoration:
                          const InputDecoration(labelText: 'Target format'),
                      items: WavConversionFormat.values
                          .where((format) =>
                              format != WavConversionFormat.none &&
                              AudioConversionService.instance
                                  .isSupported(format))
                          .map((format) => DropdownMenuItem(
                                value: format.value,
                                child: Text(format.displayName),
                              ))
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        await _settings.setConversionFormat(value);
                        _refresh();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.graphic_eq_rounded),
                  title: const Text('On-device AI transcription'),
                  subtitle: const Text(
                    'Whisper models are downloaded separately, not bundled in the APK.',
                  ),
                  value: _settings.aiTranscriptionEnabled,
                  onChanged: (value) async {
                    await _settings.setAiTranscriptionEnabled(value);
                    _refresh();
                  },
                ),
                if (_settings.aiTranscriptionEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _settings.whisperModel,
                      decoration:
                          const InputDecoration(labelText: 'Whisper model'),
                      items: const [
                        'tiny',
                        'base',
                        'small',
                        'medium',
                        'large',
                        'largeV3Turbo'
                      ]
                          .map((name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ))
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        await _settings.setWhisperModel(value);
                        _refresh();
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: const Text('Download selected model'),
                    subtitle: _modelProgress == null
                        ? null
                        : LinearProgressIndicator(value: _modelProgress),
                    enabled: !_busy,
                    onTap: _downloadModel,
                  ),
                  ListTile(
                    leading: const Icon(Icons.library_music_rounded),
                    title: const Text('Batch transcribe folder'),
                    subtitle: const Text(
                      'Existing .lrc files are skipped; subtitle files are never scanned as audio.',
                    ),
                    enabled: !_busy,
                    onTap: _runBatchTranscription,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary:
                      const Icon(Icons.notifications_active_outlined),
                  title: const Text('Task notifications'),
                  value: _settings.notificationsEnabled,
                  onChanged: (value) async {
                    await _settings.setNotificationsEnabled(value);
                    _refresh();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_outlined),
                  title: const Text('FCM push notifications'),
                  subtitle: const Text(
                    'Requires Hiraukan-owned Firebase configuration; KikoFlu credentials are not copied.',
                  ),
                  value: _settings.fcmEnabled,
                  onChanged: (value) async {
                    await _settings.setFcmEnabled(value);
                    await KikoFluNotificationService.instance
                        .setFcmEnabled(value);
                    if (value) await _testFcm();
                    _refresh();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.high_quality_rounded),
                  title: const Text('Hi-Res output'),
                  subtitle: const Text(
                    'Falls back safely to normal playback when native support is unavailable.',
                  ),
                  value: _settings.hiResEnabled,
                  onChanged: (value) async {
                    await _settings.setHiResEnabled(value);
                    await HiResAudioService.instance.setEnabled(value);
                    _refresh();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.usb_rounded),
                  title: const Text('Check Hi-Res / DAC capabilities'),
                  enabled: !_busy,
                  onTap: _probeHiRes,
                ),
              ],
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
}
