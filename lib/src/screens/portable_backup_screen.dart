import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/history_provider.dart';
import '../providers/listening_moments_provider.dart';
import '../providers/local_collections_provider.dart';
import '../services/portable_backup_service.dart';

class PortableBackupScreen extends ConsumerStatefulWidget {
  const PortableBackupScreen({super.key});

  @override
  ConsumerState<PortableBackupScreen> createState() =>
      _PortableBackupScreenState();
}

class _PortableBackupScreenState extends ConsumerState<PortableBackupScreen> {
  bool _busy = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final copy = _BackupCopy.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.36),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: scheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy.safeTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        copy.safeMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ActionCard(
            icon: Icons.file_upload_outlined,
            title: copy.exportTitle,
            subtitle: copy.exportSubtitle,
            buttonLabel: copy.exportButton,
            onPressed: _busy ? null : () => _export(copy),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.file_download_outlined,
            title: copy.importTitle,
            subtitle: copy.importSubtitle,
            buttonLabel: copy.importButton,
            onPressed: _busy ? null : () => _import(copy),
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
          if (_status != null) ...[
            const SizedBox(height: 18),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_status!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _export(_BackupCopy copy) async {
    setState(() {
      _busy = true;
      _status = copy.preparing;
    });
    try {
      final service = PortableBackupService.instance;
      final content = await service.exportJson();
      final summary = service.inspect(content);
      final fileName = _fileName();

      String? result;
      if (Platform.isIOS) {
        result = await FilePicker.platform.saveFile(
          dialogTitle: copy.exportTitle,
          fileName: fileName,
          bytes: Uint8List.fromList(utf8.encode(content)),
        );
      } else {
        result = await FilePicker.platform.saveFile(
          dialogTitle: copy.exportTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['json'],
        );
        if (result != null) {
          final path = result.toLowerCase().endsWith('.json')
              ? result
              : '$result.json';
          await File(path).writeAsString(content);
          result = path;
        }
      }

      if (!mounted) return;
      if (result == null) {
        setState(() => _status = null);
        return;
      }
      setState(() => _status = copy.exported(result!, summary));
    } catch (error) {
      if (mounted) setState(() => _status = copy.failed(error.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(_BackupCopy copy) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );
    final file = picked == null || picked.files.isEmpty
        ? null
        : picked.files.first;
    if (file == null || !mounted) return;

    setState(() {
      _busy = true;
      _status = copy.reading;
    });

    try {
      final raw = file.bytes != null
          ? utf8.decode(file.bytes!)
          : file.path != null
              ? await File(file.path!).readAsString()
              : throw const FormatException('Selected backup has no readable data');
      final service = PortableBackupService.instance;
      final preview = service.inspect(raw);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(copy.confirmTitle),
          content: Text(copy.confirmMessage(preview)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(copy.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(copy.importButton),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        setState(() => _status = null);
        return;
      }

      final imported = await service.importJson(raw);
      await Future.wait<void>([
        ref.read(localCollectionsProvider.notifier).load(),
        ref.read(listeningMomentsProvider.notifier).load(),
        ref.read(historyProvider.notifier).load(refresh: true, force: true),
      ]);
      if (!mounted) return;
      setState(() => _status = copy.imported(imported));
    } catch (error) {
      if (mounted) setState(() => _status = copy.failed(error.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fileName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'hiraukan-backup-${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupCopy {
  const _BackupCopy({
    required this.title,
    required this.safeTitle,
    required this.safeMessage,
    required this.exportTitle,
    required this.exportSubtitle,
    required this.exportButton,
    required this.importTitle,
    required this.importSubtitle,
    required this.importButton,
    required this.preparing,
    required this.reading,
    required this.confirmTitle,
    required this.cancel,
    required this.exported,
    required this.confirmMessage,
    required this.imported,
    required this.failed,
  });

  final String title;
  final String safeTitle;
  final String safeMessage;
  final String exportTitle;
  final String exportSubtitle;
  final String exportButton;
  final String importTitle;
  final String importSubtitle;
  final String importButton;
  final String preparing;
  final String reading;
  final String confirmTitle;
  final String cancel;
  final String Function(String, PortableBackupSummary) exported;
  final String Function(PortableBackupSummary) confirmMessage;
  final String Function(PortableBackupSummary) imported;
  final String Function(String) failed;

  static _BackupCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return _BackupCopy(
        title: 'Backup & Restore',
        safeTitle: 'Backup metadata yang aman',
        safeMessage:
            'File backup berisi history, Koleksi Lokal, dan Moments. Token akun, password, API key, audio, dan cache tidak diekspor.',
        exportTitle: 'Ekspor backup',
        exportSubtitle:
            'Simpan metadata library Hiraukan sebagai satu file JSON portable.',
        exportButton: 'Pilih lokasi & ekspor',
        importTitle: 'Impor backup',
        importSubtitle:
            'Data di-merge dengan library lokal. Item lain yang tidak ada di backup tetap dipertahankan.',
        importButton: 'Impor',
        preparing: 'Menyiapkan backup…',
        reading: 'Membaca backup…',
        confirmTitle: 'Impor data ini?',
        cancel: 'Batal',
        exported: (path, summary) =>
            'Backup tersimpan: $path\n${summary.historyCount} history · ${summary.collectionCount} koleksi · ${summary.momentCount} moments',
        confirmMessage: (summary) =>
            'Akan di-merge: ${summary.historyCount} history, ${summary.collectionCount} koleksi, dan ${summary.momentCount} moments. Data lokal lain tetap dipertahankan.',
        imported: (summary) =>
            'Import selesai: ${summary.historyCount} history · ${summary.collectionCount} koleksi · ${summary.momentCount} moments.',
        failed: (error) => 'Backup gagal: $error',
      );
    }
    return _BackupCopy(
      title: 'Backup & Restore',
      safeTitle: 'Credential-safe metadata backup',
      safeMessage:
          'Backups contain history, Local Collections, and Moments. Account tokens, passwords, API keys, audio, and caches are never exported.',
      exportTitle: 'Export backup',
      exportSubtitle:
          'Save Hiraukan library metadata as one portable JSON file.',
      exportButton: 'Choose location & export',
      importTitle: 'Import backup',
      importSubtitle:
          'Imported items are merged with your local library; unrelated local data stays intact.',
      importButton: 'Import',
      preparing: 'Preparing backup…',
      reading: 'Reading backup…',
      confirmTitle: 'Import this data?',
      cancel: 'Cancel',
      exported: (path, summary) =>
          'Backup saved: $path\n${summary.historyCount} history · ${summary.collectionCount} collections · ${summary.momentCount} moments',
      confirmMessage: (summary) =>
          'Merge ${summary.historyCount} history records, ${summary.collectionCount} collections, and ${summary.momentCount} moments? Unrelated local data remains.',
      imported: (summary) =>
          'Import complete: ${summary.historyCount} history · ${summary.collectionCount} collections · ${summary.momentCount} moments.',
      failed: (error) => 'Backup failed: $error',
    );
  }
}
