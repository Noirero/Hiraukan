import 'package:flutter/material.dart';

enum WorkDownloadAction {
  makeAvailableOffline,
  chooseFiles,
}

class WorkDownloadActionsButton extends StatelessWidget {
  const WorkDownloadActionsButton({
    super.key,
    required this.isBusy,
    required this.onMakeAvailableOffline,
    required this.onChooseFiles,
  });

  final bool isBusy;
  final VoidCallback onMakeAvailableOffline;
  final VoidCallback onChooseFiles;

  @override
  Widget build(BuildContext context) {
    final copy = _DownloadActionCopy.of(context);

    return PopupMenuButton<WorkDownloadAction>(
      enabled: !isBusy,
      tooltip: copy.tooltip,
      icon: isBusy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined),
      onSelected: (action) {
        switch (action) {
          case WorkDownloadAction.makeAvailableOffline:
            onMakeAvailableOffline();
            return;
          case WorkDownloadAction.chooseFiles:
            onChooseFiles();
            return;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: WorkDownloadAction.makeAvailableOffline,
          child: Row(
            children: [
              const Icon(Icons.download_for_offline_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(copy.makeAvailableOffline)),
            ],
          ),
        ),
        PopupMenuItem(
          value: WorkDownloadAction.chooseFiles,
          child: Row(
            children: [
              const Icon(Icons.download_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(copy.chooseFiles)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DownloadActionCopy {
  const _DownloadActionCopy({
    required this.tooltip,
    required this.makeAvailableOffline,
    required this.chooseFiles,
  });

  final String tooltip;
  final String makeAvailableOffline;
  final String chooseFiles;

  static _DownloadActionCopy of(BuildContext context) {
    return switch (Localizations.localeOf(context).languageCode) {
      'id' => const _DownloadActionCopy(
          tooltip: 'Unduhan & offline',
          makeAvailableOffline: 'Jadikan tersedia offline',
          chooseFiles: 'Pilih file untuk diunduh',
        ),
      _ => const _DownloadActionCopy(
          tooltip: 'Download & offline',
          makeAvailableOffline: 'Make available offline',
          chooseFiles: 'Choose files to download',
        ),
    };
  }
}
