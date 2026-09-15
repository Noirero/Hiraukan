import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/history_record.dart';
import '../models/download_task.dart';
import '../models/audio_tap_playlist_mode.dart';
import '../providers/auth_provider.dart';
import '../providers/audio_provider.dart';
import '../providers/history_provider.dart';
import '../services/audio_player_service.dart';
import '../services/download_service.dart';
import '../services/cache_service.dart';
import '../services/log_service.dart';
import '../services/audio_file_url_resolver.dart';
import '../services/audio_track_queue_builder.dart';
import '../screens/work_detail_screen.dart';
import '../screens/unified_work_detail_screen.dart';
import '../services/storage_service.dart';
import '../sources/unified_source_preferences.dart';
import '../sources/unified_source_provider.dart';
import '../sources/unified_source_registry.dart';
import '../utils/string_utils.dart';
import '../utils/work_cover_prefetch.dart';
import '../providers/lyric_provider.dart';
import '../providers/work_card_display_provider.dart';
import '../utils/age_rating.dart';
import '../../l10n/app_localizations.dart';
import 'privacy_blur_cover.dart';
import 'age_rating_chip.dart';
import 'confirmation_dialog.dart';

final _log = LogService.instance;

class HistoryWorkCard extends ConsumerWidget {
  final HistoryRecord record;
  final VoidCallback? onTap;

  const HistoryWorkCard({
    super.key,
    required this.record,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final host = authState.host ?? '';
    final token = authState.token ?? '';
    final work = record.work;
    final showAgeRating = ref.watch(workCardDisplayProvider).showAgeRating;
    final isUnifiedExternal = _isUnifiedExternalWork(work);
    final unifiedBundle = isUnifiedExternal
        ? (UnifiedSourceRegistry.instance.bundleFor(work.id) ??
            UnifiedSourceRegistry.instance.ensureFromWork(work))
        : null;

    final httpHeaders = isUnifiedExternal
        ? null
        : StorageService.serverCookieHeaders;
    final initialCoverImageProvider = isUnifiedExternal || host.isEmpty
        ? null
        : createWorkCoverImageProvider(
            work: work,
            host: host,
            token: token,
          );
    final directCover = isUnifiedExternal
        ? (unifiedBundle?.coverUrl ??
            (work.images?.isNotEmpty == true ? work.images!.first : null))
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => isUnifiedExternal
                  ? UnifiedWorkDetailScreen(work: work)
                  : WorkDetailScreen(
                      work: work,
                      initialCoverImageProvider: initialCoverImageProvider,
                    ),
            ),
          );
        },
        onLongPress: () {
          showCommonConfirmationDialog(
            context: context,
            title: S.of(context).deleteRecord,
            content: Text(S.of(context).deletePlayRecordConfirm(work.title)),
            confirmLabel: S.of(context).delete,
            variant: ConfirmationDialogVariant.danger,
          ).then((confirmed) {
            if (confirmed) {
              ref.read(historyProvider.notifier).remove(work.id);
            }
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'work_cover_${work.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: PrivacyBlurCover(
                        child: _HistoryCover(
                          work: work,
                          host: host,
                          token: token,
                          directCover: directCover,
                          httpHeaders: httpHeaders,
                          isUnifiedExternal: isUnifiedExternal,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (showAgeRating && AgeRatingFormatter.hasValue(work.age))
                    Positioned(
                      top: 8,
                      right: 8,
                      child: AgeRatingChip(age: work.age, compact: true),
                    ),
                  if (record.lastTrack != null)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _resumePlayback(context, ref),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Icon(
                              Icons.play_arrow,
                              size: 24,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (record.lastTrack != null)
                    Builder(
                      builder: (context) {
                        final lastTrack = record.lastTrack!;
                        final int? trackDurationMs =
                            lastTrack.duration?.inMilliseconds;
                        final double progressValue =
                            trackDurationMs != null && trackDurationMs > 0
                                ? (record.lastPositionMs / trackDurationMs)
                                    .clamp(0.0, 1.0)
                                : 0.0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lastTrack.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${formatDuration(Duration(milliseconds: record.lastPositionMs))} / ${formatDuration(lastTrack.duration ?? Duration.zero)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                if (record.playlistTotal > 0)
                                  Text(
                                    '${record.playlistIndex + 1} / ${record.playlistTotal}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: progressValue,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              color: Theme.of(context).colorScheme.primary,
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ],
                        );
                      },
                    )
                  else
                    Text(
                      S.of(context).notPlayedYet,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isUnifiedExternalWork(dynamic work) {
    if (work.id < 0) return true;
    final rawUrl = work.sourceUrl?.toString();
    if (rawUrl == null || rawUrl.isEmpty) return false;
    final host = Uri.tryParse(rawUrl)?.host.toLowerCase() ?? '';
    return host.contains('hentaiasmr.moe') || host.contains('erovoice.us');
  }

  Future<void> _resumePlayback(BuildContext context, WidgetRef ref) async {
    final work = record.work;
    if (_isUnifiedExternalWork(work)) {
      await _resumeUnifiedPlayback(context, ref);
      return;
    }

    final l10n = S.of(context);
    final authState = ref.read(authProvider);
    final host = authState.host ?? '';
    final token = authState.token ?? '';

    final apiService = ref.read(kikoeruApiServiceProvider);
    List<dynamic> allFiles = [];
    try {
      allFiles = await apiService.getWorkTracks(work.id);
      ref.read(fileListControllerProvider.notifier).updateFiles(
            allFiles,
            workId: work.id,
          );
    } catch (e) {
      _log.captureOutput('Failed to update file list: $e');

      try {
        final tasks = await DownloadService.instance.getWorkTasks(work.id);
        if (tasks.isNotEmpty) {
          final downloadedFiles = tasks
              .where((t) => t.status == DownloadStatus.completed)
              .map((t) => {
                    'title': t.fileName,
                    'name': t.fileName,
                    'hash': t.hash,
                    'type': 'file',
                  })
              .toList();

          if (downloadedFiles.isNotEmpty) {
            allFiles = downloadedFiles;
            ref.read(fileListControllerProvider.notifier).updateFiles(
                  allFiles,
                  workId: work.id,
                );
          }
        }
      } catch (e2) {
        _log.captureOutput('Failed to load downloaded files: $e2');
      }
    }

    if (allFiles.isEmpty) {
      if (record.lastTrack != null) {
        try {
          await AudioPlayerService.instance.updateQueue([record.lastTrack!]);
          await AudioPlayerService.instance
              .seek(Duration(milliseconds: record.lastPositionMs));
          await AudioPlayerService.instance.play();
          ref.read(miniPlayerVisibilityProvider.notifier).show();
          ref.read(historyProvider.notifier).addOrUpdate(work);
        } catch (e) {
          _log.captureOutput('Failed to resume playback: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.playbackFailed(e.toString()))),
            );
          }
        }
      }
      return;
    }

    List<dynamic> getSiblingAudioFiles(List<dynamic> files) {
      bool isTargetFile(dynamic file) {
        if (file['type'] == 'folder') return false;
        final fileHash = file['hash'];
        final fileName = file['title'] ?? file['name'];

        if (record.lastTrack!.hash != null &&
            fileHash == record.lastTrack!.hash) {
          return true;
        }
        return fileName == record.lastTrack!.title;
      }

      List<dynamic> extractAudioFiles(List<dynamic> list) {
        return list.where((file) {
          if (file['type'] == 'folder') return false;
          final name = file['title'] ?? file['name'] ?? '';
          final ext = name.split('.').last.toLowerCase();
          return ['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'].contains(ext);
        }).toList();
      }

      for (final file in files) {
        if (file['type'] == 'folder') {
          if (file['children'] != null) {
            final children = file['children'] as List<dynamic>;
            if (children.any(isTargetFile)) {
              return extractAudioFiles(children);
            }
            final result = getSiblingAudioFiles(children);
            if (result.isNotEmpty) return result;
          }
        } else if (isTargetFile(file)) {
          return extractAudioFiles(files);
        }
      }

      return [];
    }

    List<dynamic> audioFiles = getSiblingAudioFiles(allFiles);

    if (audioFiles.isEmpty) {
      List<dynamic> flattenAudioFiles(List<dynamic> files) {
        final List<dynamic> result = [];
        for (final file in files) {
          if (file['type'] == 'folder') {
            if (file['children'] != null) {
              result.addAll(flattenAudioFiles(file['children']));
            }
          } else {
            final name = file['title'] ?? file['name'] ?? '';
            final ext = name.split('.').last.toLowerCase();
            if (['mp3', 'wav', 'flac', 'm4a', 'aac', 'ogg'].contains(ext)) {
              result.add(file);
            }
          }
        }
        return result;
      }

      audioFiles = flattenAudioFiles(allFiles);
    }

    final downloadService = DownloadService.instance;

    String? coverUrl;
    if (host.isNotEmpty) {
      String normalizedUrl = host;
      if (!host.startsWith('http://') && !host.startsWith('https://')) {
        normalizedUrl = 'https://$host';
      }
      coverUrl = token.isNotEmpty
          ? '$normalizedUrl/api/cover/${work.id}?token=$token'
          : '$normalizedUrl/api/cover/${work.id}';
    }

    final audioUrlResolver = AudioFileUrlResolver(
      resolveDownloadedPath: downloadService.getDownloadedFilePath,
      downloadRootPath: () async {
        final downloadDir = await downloadService.getDownloadDirectory();
        return downloadDir.path;
      },
      resolveCachedAudioPath: CacheService.getCachedAudioFile,
    );
    final vaNames = work.vas?.map((va) => va.name).toList() ?? [];
    final artistInfo = vaNames.isNotEmpty ? vaNames.join(', ') : null;
    final queue = await const AudioTrackQueueBuilder().build(
      audioFiles: audioFiles,
      selectedFile:
          record.lastTrack ?? (audioFiles.isNotEmpty ? audioFiles.first : null),
      resolveUrl: (file) => audioUrlResolver.resolveOnline(
        file: file,
        workId: work.id,
        host: host,
        token: token,
        downloadedFiles: const {},
        fileRelativePaths: const {},
      ),
      workId: work.id,
      albumTitle: work.title,
      unknownTitle: l10n.unknown,
      artist: artistInfo,
      artworkUrl: coverUrl,
    );

    var tracks = queue.tracks;
    var index = queue.startIndex;

    if (tracks.isEmpty && record.lastTrack != null) {
      tracks = [record.lastTrack!];
      index = 0;
    }

    if (tracks.isNotEmpty) {
      try {
        await AudioPlayerService.instance
            .updateQueue(tracks, startIndex: index);
        await AudioPlayerService.instance
            .seek(Duration(milliseconds: record.lastPositionMs));
        await AudioPlayerService.instance.play();
        ref.read(miniPlayerVisibilityProvider.notifier).show();
        ref.read(historyProvider.notifier).addOrUpdate(work);
      } catch (e) {
        _log.captureOutput('Failed to resume playback: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.playbackFailed(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _resumeUnifiedPlayback(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final work = record.work;
    final authState = ref.read(authProvider);
    final host = authState.host ?? '';
    final token = authState.token ?? '';
    final l10n = S.of(context);

    try {
      final registry = UnifiedSourceRegistry.instance;
      registry.ensureFromWork(work);
      final preferred = await UnifiedSourcePreferences.loadPreferredSource();
      final service = ref.read(unifiedSourceServiceProvider);
      final resolved = await service.resolveTracks(
        work,
        preferredSource: preferred,
      );
      final tracks = service.buildAudioTracks(
        work: work,
        resolved: resolved,
        host: host,
        token: token,
      );
      if (tracks.isEmpty) {
        throw StateError('No playable tracks are available');
      }

      var index = 0;
      final lastTrack = record.lastTrack;
      if (lastTrack != null) {
        final found = tracks.indexWhere((track) {
          if (lastTrack.hash != null && track.hash == lastTrack.hash) {
            return true;
          }
          return track.title == lastTrack.title;
        });
        if (found >= 0) index = found;
      }

      final controller = ref.read(audioPlayerControllerProvider.notifier);
      await controller.playTracks(
        tracks,
        startIndex: index,
        work: work,
        playlistMode: AudioTapPlaylistMode.replaceQueue,
      );
      await controller.seek(
        Duration(milliseconds: record.lastPositionMs),
      );
    } catch (error) {
      _log.captureOutput('Failed to resume unified playback: $error');

      // Last-known URL is still a useful final fallback if the provider parser
      // is temporarily unavailable but the previously resolved media remains
      // reachable.
      final lastTrack = record.lastTrack;
      if (lastTrack != null) {
        try {
          await AudioPlayerService.instance.updateQueue([lastTrack]);
          await AudioPlayerService.instance
              .seek(Duration(milliseconds: record.lastPositionMs));
          await AudioPlayerService.instance.play();
          ref.read(miniPlayerVisibilityProvider.notifier).show();
          return;
        } catch (fallbackError) {
          _log.captureOutput(
            'Failed to resume unified last-known track: $fallbackError',
          );
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.playbackFailed(error.toString()))),
        );
      }
    }
  }
}

class _HistoryCover extends StatelessWidget {
  final dynamic work;
  final String host;
  final String token;
  final String? directCover;
  final Map<String, String>? httpHeaders;
  final bool isUnifiedExternal;

  const _HistoryCover({
    required this.work,
    required this.host,
    required this.token,
    required this.directCover,
    required this.httpHeaders,
    required this.isUnifiedExternal,
  });

  @override
  Widget build(BuildContext context) {
    final url = isUnifiedExternal
        ? directCover
        : work.getCoverImageUrl(host, token: token).toString();
    if (url == null || url.trim().isEmpty) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.graphic_eq, color: Colors.grey, size: 42),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: httpHeaders,
      cacheKey: isUnifiedExternal ? 'unified_history_${work.id}_$url' : 'work_cover_${work.id}',
      fit: BoxFit.cover,
      placeholder: (context, value) => Container(
        color: Colors.grey[200],
        child: const Center(child: Icon(Icons.image, color: Colors.grey)),
      ),
      errorWidget: (context, value, error) => Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
      ),
    );
  }
}
