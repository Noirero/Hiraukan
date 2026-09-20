import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:whisper_ggml_plus/whisper_ggml_plus.dart';

import '../services/ai_transcription_service.dart';
import '../services/audio_conversion_service.dart';
import '../services/floating_lyric_enhancement_service.dart';
import '../services/hi_res_audio_service.dart';
import '../services/kikoflu_feature_coordinator.dart';
import '../services/kikoflu_feature_settings.dart';
import '../services/kikoflu_notification_service.dart';
import '../services/speech_recognition_coordinator.dart';

class KikoFluFeaturesSettingsScreen extends StatefulWidget {
  const KikoFluFeaturesSettingsScreen({super.key});

  @override
  State<KikoFluFeaturesSettingsScreen> createState() =>
      _KikoFluFeaturesSettingsScreenState();
}

class _KikoFluFeaturesSettingsScreenState
    extends State<KikoFluFeaturesSettingsScreen> {
  static const _transcriptionNotificationId = 0x48495241;

  final _settings = KikoFluFeatureSettings.instance;
  final _floatingLyric = FloatingLyricEnhancementService.instance;
  bool _busy = false;
  double? _modelProgress;
  String? _status;

  void _refresh() => setState(() {});

  WhisperModel get _selectedModel => AiTranscriptionService.instance
      .modelFromName(_settings.whisperModel);

  String _profileLabel(String value) {
    return switch (value) {
      'fast' => SpeechRecognitionCoordinator.fastProfileApproved
          ? 'Fast · Whisper Tiny'
          : 'Fast · Whisper Tiny · menunggu benchmark',
      'highQuality' => SpeechRecognitionCoordinator.highQualityProfileApproved
          ? 'High Quality · Whisper Small'
          : 'High Quality · Whisper Small · menunggu benchmark',
      'compatibility' => 'Compatibility · model manual',
      _ => 'Auto · aman / Compatibility saat ini',
    };
  }

  String _transparencyModeLabel(int mode) {
    return switch (mode) {
      1 => 'Transparent',
      2 => 'Padded glass',
      _ => 'Normal',
    };
  }

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

    try {
      final result = await AiTranscriptionService.instance.transcribeDirectory(
        Directory(path),
        model: _selectedModel,
        threads: _settings.whisperThreads,
        skipExisting: true,
        onProgress: (done, total, file) {
          final fileName = File(file).uri.pathSegments.last;
          if (total > 0) {
            unawaited(KikoFluNotificationService.instance.showProgress(
              id: _transcriptionNotificationId,
              title: 'AI transcription',
              body: '$done/$total — $fileName',
              progress: done,
              maxProgress: total,
            ));
          }
          if (!mounted) return;
          setState(() => _status = 'Transcribing $done/$total — $fileName');
        },
      );

      final summary =
          '${result.completed} created, ${result.skipped} skipped, ${result.failed} failed.';
      await KikoFluNotificationService.instance.showMessage(
        id: _transcriptionNotificationId,
        title: 'AI transcription complete',
        body: summary,
      );
      if (!mounted) return;
      setState(() => _status = 'Batch complete: $summary');
    } catch (error) {
      await KikoFluNotificationService.instance.showMessage(
        id: _transcriptionNotificationId,
        title: 'AI transcription failed',
        body: '$error',
      );
      if (mounted) setState(() => _status = 'Batch failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                const ListTile(
                  leading: Icon(Icons.lyrics_outlined),
                  title: Text('Floating lyric enhancements'),
                  subtitle: Text(
                    'Adds KikoFlu-style controls without replacing Hiraukan floating lyrics.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.close_rounded),
                  title: const Text('Show close button'),
                  value: _floatingLyric.showCloseButton,
                  onChanged: (value) async {
                    await _floatingLyric.setShowCloseButton(value);
                    _refresh();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.blur_on_rounded),
                  title: const Text('Text shadow'),
                  value: _floatingLyric.shadowEnabled,
                  onChanged: (value) async {
                    await _floatingLyric.setShadowEnabled(value);
                    _refresh();
                  },
                ),
                if (_floatingLyric.shadowEnabled)
                  ListTile(
                    title: const Text('Shadow blur'),
                    subtitle: Slider(
                      value: _floatingLyric.shadowBlur.clamp(0.0, 24.0),
                      min: 0,
                      max: 24,
                      divisions: 24,
                      label: _floatingLyric.shadowBlur.toStringAsFixed(0),
                      onChanged: (value) async {
                        await _floatingLyric.setShadowBlur(value);
                        _refresh();
                      },
                    ),
                  ),
                ListTile(
                  title: const Text('Background style'),
                  trailing: DropdownButton<int>(
                    value: _floatingLyric.transparencyMode.clamp(0, 2),
                    items: List.generate(
                      3,
                      (mode) => DropdownMenuItem(
                        value: mode,
                        child: Text(_transparencyModeLabel(mode)),
                      ),
                    ),
                    onChanged: (value) async {
                      if (value == null) return;
                      await _floatingLyric.setTransparencyMode(value);
                      _refresh();
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Font weight'),
                  subtitle: Slider(
                    value: _floatingLyric.fontWeight.clamp(0, 8).toDouble(),
                    min: 0,
                    max: 8,
                    divisions: 8,
                    label: '${(_floatingLyric.fontWeight + 1) * 100}',
                    onChanged: (value) async {
                      await _floatingLyric.setFontWeight(value.round());
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: DropdownButtonFormField<String>(
                      initialValue: _settings.asrProfile,
                      decoration: const InputDecoration(
                        labelText: 'Profil ASR otomatis',
                        helperText:
                            'Fast/HQ tetap terkunci sampai benchmark Android/ASMR lulus.',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'auto',
                          child: Text(_profileLabel('auto')),
                        ),
                        DropdownMenuItem(
                          value: 'fast',
                          enabled:
                              SpeechRecognitionCoordinator.fastProfileApproved,
                          child: Text(_profileLabel('fast')),
                        ),
                        DropdownMenuItem(
                          value: 'highQuality',
                          enabled: SpeechRecognitionCoordinator
                              .highQualityProfileApproved,
                          child: Text(_profileLabel('highQuality')),
                        ),
                        DropdownMenuItem(
                          value: 'compatibility',
                          child: Text(_profileLabel('compatibility')),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        await _settings.setAsrProfile(value);
                        _refresh();
                      },
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.subtitles_outlined),
                    title: const Text('Auto subtitle Jepang → Indonesia'),
                    subtitle: const Text(
                      'Jika subtitle resmi tidak ada: Whisper membuat subtitle '
                      'Jepang, lalu Terjemahan Gratis Online menerjemahkannya '
                      'ke Indonesia. Model Whisper tetap diunduh terpisah.',
                    ),
                    value: _settings.autoAsrTranslateFallback,
                    onChanged: (value) async {
                      await _settings.setAutoAsrTranslateFallback(value);
                      _refresh();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _settings.whisperModel,
                      decoration: const InputDecoration(
                        labelText: 'Model Compatibility / batch manual',
                      ),
                      items: const [
                        'tiny',
                        'base',
                        'small',
                        'medium',
                        'large',
                        'largeV3Turbo',
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
                const SwitchListTile(
                  secondary: Icon(Icons.high_quality_rounded),
                  title: Text('Hi-Res output'),
                  subtitle: Text(
                    'Belum didukung di Android. Playback normal tetap digunakan.',
                  ),
                  value: false,
                  onChanged: null,
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
