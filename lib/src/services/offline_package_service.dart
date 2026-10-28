import '../models/download_task.dart';
import '../models/work.dart';
import 'download_file_path_service.dart';
import 'download_service.dart';

class OfflinePackageResult {
  const OfflinePackageResult({
    required this.queued,
    required this.alreadyAvailable,
    required this.unavailable,
  });

  final int queued;
  final int alreadyAvailable;
  final int unavailable;

  bool get nothingToDo => queued == 0;
}

/// Bulk-download orchestration for a complete work.
///
/// This does not create a second offline format. Every file is queued through
/// [DownloadService], so metadata, cover persistence, cache reuse, queue limits,
/// pause/resume and the existing offline-work UI remain the source of truth.
class OfflinePackageService {
  OfflinePackageService._();

  static final OfflinePackageService instance = OfflinePackageService._();

  Future<OfflinePackageResult> makeAvailableOffline({
    required Work work,
    required String host,
    required String token,
    required String coverUrl,
  }) async {
    final annotatedMetadata = _annotatedMetadata(work);
    final annotatedChildren =
        annotatedMetadata['children'] as List<dynamic>? ?? const <dynamic>[];
    final localPathsByHash =
        DownloadFilePathService.localRelativePathsByHash(annotatedChildren);
    final candidates = _collectFiles(work.children ?? const <AudioFile>[]);
    final downloadService = DownloadService.instance;
    final existingTasks = await downloadService.getWorkTasks(work.id);
    final queuedHashes = existingTasks
        .where((task) =>
            task.hash != null &&
            (task.status == DownloadStatus.pending ||
                task.status == DownloadStatus.downloading ||
                task.status == DownloadStatus.paused ||
                task.status == DownloadStatus.completed))
        .map((task) => task.hash!)
        .toSet();

    var queued = 0;
    var alreadyAvailable = 0;
    var unavailable = 0;

    for (final candidate in candidates) {
      final file = candidate.file;
      final hash = file.hash?.trim();
      if (hash == null || hash.isEmpty) {
        unavailable++;
        continue;
      }

      final downloadedPath =
          await downloadService.getDownloadedFilePath(work.id, hash);
      if (downloadedPath != null || queuedHashes.contains(hash)) {
        alreadyAvailable++;
        continue;
      }

      final downloadUrl = _downloadUrl(
        file: file,
        host: host,
        token: token,
      );
      if (downloadUrl.isEmpty) {
        unavailable++;
        continue;
      }

      final fullFileName = candidate.relativePath.isEmpty
          ? file.title
          : '${candidate.relativePath}/${file.title}';
      final localFileName = localPathsByHash[hash];

      await downloadService.addTask(
        workId: work.id,
        workTitle: work.title,
        fileName: localFileName ?? fullFileName,
        downloadUrl: downloadUrl,
        hash: hash,
        totalBytes: file.size,
        workMetadata: annotatedMetadata,
        coverUrl: coverUrl,
      );
      queuedHashes.add(hash);
      queued++;
    }

    return OfflinePackageResult(
      queued: queued,
      alreadyAvailable: alreadyAvailable,
      unavailable: unavailable,
    );
  }

  Map<String, dynamic> _annotatedMetadata(Work work) {
    final metadata = Map<String, dynamic>.from(work.toJson());
    final children = metadata['children'];
    if (children is List) {
      final annotated = DownloadFilePathService.annotateFileTreeWithLocalPaths(
        List<dynamic>.from(children),
      );
      if (annotated.isNotEmpty) metadata['children'] = annotated;
    }
    return metadata;
  }

  List<_OfflineFileCandidate> _collectFiles(List<AudioFile> items) {
    final result = <_OfflineFileCandidate>[];

    void visit(List<AudioFile> children, String parentPath) {
      for (final item in children) {
        if (item.type == 'file') {
          result.add(
            _OfflineFileCandidate(file: item, relativePath: parentPath),
          );
          continue;
        }
        final nested = item.children;
        if (nested == null || nested.isEmpty) continue;
        final folderPath = parentPath.isEmpty
            ? item.title
            : '$parentPath/${item.title}';
        visit(nested, folderPath);
      }
    }

    visit(items, '');
    return result;
  }

  String _downloadUrl({
    required AudioFile file,
    required String host,
    required String token,
  }) {
    var downloadUrl = file.mediaDownloadUrl?.trim() ?? '';
    final normalizedHost = _normalizedHost(host);

    if (downloadUrl.isNotEmpty) {
      if (downloadUrl.startsWith('/') && normalizedHost.isNotEmpty) {
        downloadUrl = '$normalizedHost$downloadUrl';
      }
      if (token.isNotEmpty && !downloadUrl.contains('token=')) {
        downloadUrl += downloadUrl.contains('?') ? '&token=$token' : '?token=$token';
      }
      return downloadUrl;
    }

    final hash = file.hash?.trim();
    if (normalizedHost.isEmpty || hash == null || hash.isEmpty) return '';
    final encodedTitle = Uri.encodeComponent(file.title);
    final tokenQuery = token.isEmpty ? '' : '?token=$token';
    return '$normalizedHost/api/media/download/$hash/$encodedTitle$tokenQuery';
  }

  String _normalizedHost(String host) {
    final trimmed = host.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final local = trimmed.contains('localhost') ||
        trimmed.startsWith('127.0.0.1') ||
        trimmed.startsWith('192.168.');
    return '${local ? 'http' : 'https'}://$trimmed';
  }
}

class _OfflineFileCandidate {
  const _OfflineFileCandidate({
    required this.file,
    required this.relativePath,
  });

  final AudioFile file;
  final String relativePath;
}
