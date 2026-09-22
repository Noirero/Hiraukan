import '../models/work.dart';
import '../sources/source_adapter.dart';
import '../sources/source_html_parser.dart';
import '../sources/unified_source_models.dart';
import 'audio_extension.dart';
import 'audio_extension_manifest.dart';

typedef AudioExtensionRefBuilder = UnifiedSourceRef Function(String workId);

class AdapterBackedDirectAudioExtension implements AudioExtension {
  final UnifiedSourceAdapter adapter;
  final AudioExtensionManifest _manifest;
  final AudioExtensionRefBuilder refBuilder;
  final bool playbackEnabled;
  final Map<String, UnifiedSourceRef> _knownRefs = {};

  AdapterBackedDirectAudioExtension({
    required this.adapter,
    required AudioExtensionManifest manifest,
    required this.refBuilder,
    this.playbackEnabled = true,
  }) : _manifest = manifest;

  @override
  AudioExtensionManifest get manifest => _manifest;

  @override
  Future<AudioExtensionPage> browse({
    required int page,
    required int pageSize,
  }) async {
    return _pageFromSource(
      await adapter.search(keyword: '', page: page, pageSize: pageSize),
    );
  }

  @override
  Future<AudioExtensionPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    return _pageFromSource(
      await adapter.search(
        keyword: keyword,
        page: page,
        pageSize: pageSize,
      ),
    );
  }

  @override
  Future<AudioExtensionWork> getDetail(String workId) async {
    final detail = await adapter.loadDetail(_refFor(workId));
    return _workFromSource(detail, localId: workId);
  }

  @override
  Future<List<AudioExtensionTrack>> getTracks(String workId) async {
    final files = await adapter.loadTracks(_refFor(workId));
    return _flatten(files)
        .map(
          (entry) => AudioExtensionTrack(
            id: entry.id,
            title: entry.title,
            durationSeconds: entry.durationSeconds,
            subtitleUrl: entry.subtitleUrl,
            metadata: {
              if (entry.rawUrl != null) 'rawUrl': entry.rawUrl!,
              if (entry.hash != null) 'hash': entry.hash!,
            },
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<AudioPlaybackRequest> resolvePlayback({
    required String workId,
    required String trackId,
  }) async {
    if (!playbackEnabled) {
      throw UnsupportedError(
        manifest.name + ' does not expose direct playback in Hiraukan',
      );
    }

    final files = await adapter.loadTracks(_refFor(workId));
    _DirectTrackEntry? selected;
    for (final entry in _flatten(files)) {
      if (entry.id == trackId) {
        selected = entry;
        break;
      }
    }
    if (selected == null) {
      throw StateError('Track not found: $trackId');
    }

    final rawUrl = selected.rawUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      throw StateError('Track has no direct playback URL');
    }
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) {
      throw StateError('Source returned an invalid playback URL');
    }

    return AudioPlaybackRequest(
      uri: uri,
      kind: uri.path.toLowerCase().endsWith('.m3u8')
          ? AudioPlaybackKind.hls
          : AudioPlaybackKind.direct,
    );
  }

  @override
  Future<AudioExtensionHealth> checkHealth() async {
    return switch (await adapter.checkHealth()) {
      UnifiedSourceHealth.healthy => AudioExtensionHealth.healthy,
      UnifiedSourceHealth.degraded => AudioExtensionHealth.degraded,
      UnifiedSourceHealth.broken => AudioExtensionHealth.broken,
      UnifiedSourceHealth.unknown => AudioExtensionHealth.unknown,
    };
  }

  AudioExtensionPage _pageFromSource(SourceSearchPage source) {
    for (final candidate in source.items) {
      _knownRefs[candidate.ref.localId] = candidate.ref;
    }
    return AudioExtensionPage(
      items: source.items
          .map(
            (candidate) => _workFromSource(
              candidate.work,
              localId: candidate.ref.localId,
              detailUrl: candidate.ref.detailUrl,
              coverUrl: candidate.ref.coverUrl,
              canonicalId: candidate.ref.canonicalId,
            ),
          )
          .toList(growable: false),
      totalCount: source.totalCount,
      hasMore: source.hasMore,
    );
  }

  AudioExtensionWork _workFromSource(
    Work work, {
    required String localId,
    String? detailUrl,
    String? coverUrl,
    String? canonicalId,
  }) {
    var resolvedCover = coverUrl;
    if ((resolvedCover == null || resolvedCover.isEmpty) &&
        work.images?.isNotEmpty == true) {
      resolvedCover = work.images!.first;
    }
    return AudioExtensionWork(
      id: localId,
      title: work.title,
      canonicalId: canonicalId ??
          SourceHtmlParser.extractCanonicalId(work.sourceId ?? work.title),
      creator: work.name,
      coverUrl: resolvedCover,
      description: work.description,
      tags: work.tags?.map((tag) => tag.name).toList(growable: false) ??
          const [],
      durationSeconds: work.duration,
      detailUrl: detailUrl ?? work.sourceUrl,
    );
  }

  UnifiedSourceRef _refFor(String workId) {
    return _knownRefs[workId] ?? refBuilder(workId);
  }

  List<_DirectTrackEntry> _flatten(List<dynamic> files) {
    final result = <_DirectTrackEntry>[];
    var fallbackIndex = 0;

    void visit(List<dynamic> values) {
      for (final raw in values) {
        if (raw is! Map) continue;
        final file = Map<String, dynamic>.from(raw);
        final children = file['children'];
        if (children is List) visit(children);
        if (file['type']?.toString().toLowerCase() == 'folder') continue;

        final title =
            file['title']?.toString() ?? file['name']?.toString() ?? '';
        final rawUrl = file['mediaStreamUrl']?.toString() ??
            file['mediaDownloadUrl']?.toString() ??
            file['url']?.toString();
        final hash = file['hash']?.toString();
        if (rawUrl == null || rawUrl.isEmpty) continue;

        final type = file['type']?.toString().toLowerCase();
        if (!_looksAudio(type, title, rawUrl)) continue;

        final id = hash ?? 'index:$fallbackIndex:$title';
        fallbackIndex++;
        final duration = file['duration'];
        result.add(
          _DirectTrackEntry(
            id: id,
            title: title.isEmpty
                ? SourceHtmlParser.basenameFromUrl(rawUrl, fallbackIndex)
                : title,
            hash: hash,
            rawUrl: rawUrl,
            durationSeconds: duration is num ? duration.round() : null,
            subtitleUrl: file['subtitleUrl']?.toString() ??
                file['lyricUrl']?.toString(),
          ),
        );
      }
    }

    visit(files);
    return result;
  }

  bool _looksAudio(String? type, String title, String rawUrl) {
    if (type == 'audio') return true;
    final value = (title + ' ' + rawUrl).toLowerCase();
    return value.contains('.mp3') ||
        value.contains('.m4a') ||
        value.contains('.aac') ||
        value.contains('.ogg') ||
        value.contains('.opus') ||
        value.contains('.wav') ||
        value.contains('.flac') ||
        value.contains('.wma') ||
        value.contains('.m4b') ||
        value.contains('.m3u8');
  }
}

class _DirectTrackEntry {
  final String id;
  final String title;
  final String? hash;
  final String? rawUrl;
  final int? durationSeconds;
  final String? subtitleUrl;

  const _DirectTrackEntry({
    required this.id,
    required this.title,
    this.hash,
    this.rawUrl,
    this.durationSeconds,
    this.subtitleUrl,
  });
}
