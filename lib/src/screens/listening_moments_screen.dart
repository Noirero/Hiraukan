import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audio_track.dart';
import '../models/listening_moment.dart';
import '../providers/audio_provider.dart';
import '../providers/listening_moments_provider.dart';
import '../widgets/privacy_blur_cover.dart';

class ListeningMomentsScreen extends ConsumerWidget {
  const ListeningMomentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(listeningMomentsProvider);
    final currentTrack = ref.watch(currentTrackProvider).valueOrNull;
    final currentPosition =
        ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final copy = _MomentCopy.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      floatingActionButton: currentTrack == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _saveCurrent(
                context,
                ref,
                currentTrack,
                currentPosition,
                copy,
              ),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(copy.saveCurrent),
            ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.moments.isEmpty
              ? _Empty(copy: copy, hasCurrentTrack: currentTrack != null)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 112),
                  itemCount: state.moments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, index) => _MomentTile(
                    moment: state.moments[index],
                    copy: copy,
                  ),
                ),
    );
  }

  Future<void> _saveCurrent(
    BuildContext context,
    WidgetRef ref,
    AudioTrack track,
    Duration position,
    _MomentCopy copy,
  ) async {
    final note = await _noteDialog(
      context,
      title: copy.saveTitle,
      hint: copy.noteHint,
      confirm: copy.save,
    );
    if (note == null || !context.mounted) return;
    await ref.read(listeningMomentsProvider.notifier).add(
          track: track,
          position: position,
          note: note,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copy.saved(position))),
    );
  }

  static Future<String?> _noteDialog(
    BuildContext context, {
    required String title,
    required String hint,
    required String confirm,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    controller.selection = TextSelection.collapsed(offset: initialValue.length);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            maxLength: 240,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_MomentCopy.of(dialogContext).cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: Text(confirm),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}

class _MomentTile extends ConsumerWidget {
  const _MomentTile({required this.moment, required this.copy});

  final ListeningMoment moment;
  final _MomentCopy copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final artwork = moment.track.artworkUrl;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _play(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: PrivacyBlurCover(child: _Cover(url: artwork)),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      moment.track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(moment.position),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (moment.track.album?.trim().isNotEmpty == true) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              moment.track.album!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (moment.note.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        moment.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    final note = await ListeningMomentsScreen._noteDialog(
                      context,
                      title: copy.editTitle,
                      hint: copy.noteHint,
                      confirm: copy.save,
                      initialValue: moment.note,
                    );
                    if (note != null && context.mounted) {
                      await ref
                          .read(listeningMomentsProvider.notifier)
                          .updateNote(moment.id, note);
                    }
                  } else if (value == 'delete') {
                    await ref
                        .read(listeningMomentsProvider.notifier)
                        .delete(moment.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(copy.edit)),
                  PopupMenuItem(value: 'delete', child: Text(copy.delete)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    try {
      final controller = ref.read(audioPlayerControllerProvider.notifier);
      await controller.playTracks(<AudioTrack>[moment.track]);
      await controller.seekAndPersist(moment.position);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.playFailed(error.toString()))),
      );
    }
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uri = url == null ? null : Uri.tryParse(url!);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.graphic_eq_rounded, color: scheme.primary),
      );
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Icon(Icons.graphic_eq_rounded, color: scheme.primary),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.copy, required this.hasCurrentTrack});
  final _MomentCopy copy;
  final bool hasCurrentTrack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmarks_outlined, size: 58, color: scheme.primary),
            const SizedBox(height: 14),
            Text(
              copy.emptyTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              hasCurrentTrack ? copy.emptyPlaying : copy.emptyMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentCopy {
  const _MomentCopy({
    required this.title,
    required this.saveCurrent,
    required this.saveTitle,
    required this.noteHint,
    required this.save,
    required this.cancel,
    required this.saved,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyPlaying,
    required this.editTitle,
    required this.edit,
    required this.delete,
    required this.playFailed,
  });

  final String title;
  final String saveCurrent;
  final String saveTitle;
  final String noteHint;
  final String save;
  final String cancel;
  final String Function(Duration) saved;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyPlaying;
  final String editTitle;
  final String edit;
  final String delete;
  final String Function(String) playFailed;

  static _MomentCopy of(BuildContext context) {
    if (Localizations.localeOf(context).languageCode == 'id') {
      return _MomentCopy(
        title: 'Moments',
        saveCurrent: 'Simpan momen',
        saveTitle: 'Simpan posisi ini',
        noteHint: 'Catatan opsional tentang momen ini…',
        save: 'Simpan',
        cancel: 'Batal',
        saved: (position) =>
            'Momen tersimpan di ${_MomentTile._formatDuration(position)}',
        emptyTitle: 'Belum ada momen tersimpan',
        emptyMessage:
            'Putar audio, lalu simpan timestamp yang ingin kamu temukan lagi.',
        emptyPlaying:
            'Audio sedang aktif. Gunakan tombol “Simpan momen” di bawah.',
        editTitle: 'Edit catatan',
        edit: 'Edit catatan',
        delete: 'Hapus',
        playFailed: (error) => 'Tidak dapat membuka momen: $error',
      );
    }
    return _MomentCopy(
      title: 'Moments',
      saveCurrent: 'Save moment',
      saveTitle: 'Save this position',
      noteHint: 'Optional note about this moment…',
      save: 'Save',
      cancel: 'Cancel',
      saved: (position) =>
          'Moment saved at ${_MomentTile._formatDuration(position)}',
      emptyTitle: 'No saved moments yet',
      emptyMessage:
          'Play audio, then save a timestamp you want to find again.',
      emptyPlaying: 'Audio is active. Use “Save moment” below.',
      editTitle: 'Edit note',
      edit: 'Edit note',
      delete: 'Delete',
      playFailed: (error) => 'Could not open this moment: $error',
    );
  }
}
