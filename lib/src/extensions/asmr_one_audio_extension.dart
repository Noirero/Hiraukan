import '../models/work.dart';
import '../services/kikoeru_api_service.dart';
import '../sources/asmr_one_source_adapter.dart';
import '../sources/source_adapter.dart';
import '../sources/source_html_parser.dart';
import '../sources/unified_source_models.dart';
import 'audio_extension.dart';
import 'audio_extension_manifest.dart';

class AsmrOneAudioExtension implements AudioExtension {
  final UnifiedSourceAdapter _adapter;
  final String Function() _host;
  final String Function() _token;

  AsmrOneAudioExtension({
    required KikoeruApiService api,
    required String Function() host,
    required String Function() token,
  })  : _adapter = AsmrOneSourceAdapter(api),
        _host = host,
        _token = token;

  AsmrOneAudioExtension.withAdapter({
    required UnifiedSourceAdapter adapter,
    required String Function() host,
    required String Function() token,
  })  : _adapter = adapter,
        _host = host,
        _token = token;

  @override
  AudioExtensionManifest get manifest => const AudioExtensionManifest(
        id: 'miyorare.audio.asmr_one',
        name: 'ASMR.one',
        version: '1.0.0',
        auth: AudioExtensionAuthRequirement.optional,
        capabilities: {
          AudioExtensionCapability.catalog,
          AudioExtensionCapability.search,
          AudioExtensionCapability.detail,
          AudioExtensionCapability.playback,
          AudioExtensionCapability.download,
          AudioExtensionCapability.subtitles,
        },
        languages: ['ja'],
        homepage: 'https://www.asmr.one',
      );

  @override
  Future<AudioExtensionPage> browse({
    required int page,
    required int pageSize,
  }) async {
    return _pageFromSource(
      await _adapter.search(keyword: '', page: page, pageSize: pageSize),
    );
  }

  @override
  Future<AudioExtensionPage> search({
    required String keyword,
    required int page,
    required int pageSize,
  }) async {
    return _pageFromSource(
      await _adapter.search(
        keyword: keyword,
        page: page,
        pageSize: pageSize,
      ),
    );
  }

  @override
  Future<AudioExtensionWork> getDetail(String workId) async {
    final detail = await _adapter.loadDetail(_ref(workId));
    return _workFromSource(detail, localId: workId);
  }

  @override
  Future<List<AudioExtensionTrack>> getTracks(String workId) async {
    final files = await _adapter.loadTracks(_ref(workId));
    return _flattenTrackEntries(files)
        .map(
          (entry) => AudioExtensionTrack(
            id: entry.id,
            title: entry.title,
            durationSeconds: entry.durationSeconds,
            subtitleUrl: entry.subtitleUrl,
            metadata: {
              if (entry.hash != null) 'hash': entry.hash!,
              if (entry.rawUrl != null) 'rawUrl': entry.rawUrl!,
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
    final files = await _adapter.loadTracks(_ref(workId));
    _AsmrTrackEntry? selected;
    for (final entry in _flattenTrackEntries(files)) {
      if (entry.id == trackId) {
        selected = entry;
        break;
      }
    }
    if (selected == null) {
      throw StateError('Track not found: $trackId');
    }

    final resolved = _resolveUrl(selected);
    final uri = Uri.tryParse(resolved);
    if (uri == null || !uri.hasScheme) {
      throw StateError('ASMR.one returned an invalid playback URL');
    }

    return AudioPlaybackRequest(
      uri: uri,
      kind: uri.path.toLowerCase().endsWith('.m3u8')
          ? AudioPlaybackKind.hls
          : AudioPlaybackKind.direct,
      headers: const {},
    );
  }

  @override
  Future<AudioExtensionHealth> checkHealth() async {
    return switch (await _adapter.checkHealth()) {
      UnifiedSourceHealth.healthy => AudioExtensionHealth.healthy,
      UnifiedSourceHealth.degraded => AudioExtensionHealth.degraded,
      UnifiedSourceHealth.broken => AudioExtensionHealth.broken,
      UnifiedSourceHealth.unknown => AudioExtensionHealth.unknown,
    };
  }

  AudioExtensionPage _pageFromSource(SourceSearchPage source) {
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

  UnifiedSourceRef _ref(String workId) {
    return UnifiedSourceRef(
      source: UnifiedSourceKind.asmrOne,
      localId: workId,
      detailUrl: 'https://www.asmr.one/work/$workId',
    );
  }

  List<_AsmrTrackEntry> _flattenTrackEntries(List<dynamic> files) {
    final result = <_AsmrTrackEntry>[];
    var fallbackIndex = 0;

    void visit(List<dynamic> values) {
      for (final raw in values) {
        if (raw is! Map) continue;
        final file = Map<String, dynamic>.from(raw);
        final children = file['children'];
        if (children is List) visit(children);

        final type = file['type']?.toString().toLowerCase();
        if (type == 'folder') continue;

        final title =
            file['title']?.toString() ?? file['name']?.toString() ?? '';
        if (!_looksAudio(type, title)) continue;

        final hash = file['hash']?.toString();
        final rawUrl = file['mediaStreamUrl']?.toString() ??
            file['mediaDownloadUrl']?.toString() ??
            file['url']?.toString();
        final id = hash ?? 'index:$fallbackIndex:$title';
        fallbackIndex++;

        final duration = file['duration'];
        final subtitleUrl = file['subtitleUrl']?.toString() ??
            file['lyricUrl']?.toString();

        result.add(
          _AsmrTrackEntry(
            id: id,
            title: title.isEmpty ? 'Track $fallbackIndex' : title,
            hash: hash,
            rawUrl: rawUrl,
            durationSeconds: duration is num ? duration.round() : null,
            subtitleUrl: subtitleUrl,
          ),
        );
      }
    }

    visit(files);
    return result;
  }

  bool _looksAudio(String? type, String title) {
    if (type == 'audio') return true;
    final lower = title.toLowerCase();
    return lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.opus') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.wma') ||
        lower.endsWith('.m4b');
  }

  String _resolveUrl(_AsmrTrackEntry entry) {
    final host = _normalizedHost();
    var url = entry.rawUrl?.trim();

    if ((url == null || url.isEmpty) &&
        entry.hash != null &&
        entry.hash!.isNotEmpty) {
      url = '$host/api/media/stream/' + entry.hash!;
    }
    if (url == null || url.isEmpty) {
      throw StateError('Track has no playable URL');
    }
    if (url.startsWith('/')) {
      url = '$host$url';
    }

    final token = _token().trim();
    if (token.isNotEmpty && !url.contains('token=')) {
      url = url.contains('?') ? '$url&token=$token' : '$url?token=$token';
    }
    return url;
  }

  String _normalizedHost() {
    final value = _host().trim();
    if (value.isEmpty) return KikoeruApiService.remoteHost;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    }
    return 'https://$value';
  }
}

class _AsmrTrackEntry {
  final String id;
  final String title;
  final String? hash;
  final String? rawUrl;
  final int? durationSeconds;
  final String? subtitleUrl;

  const _AsmrTrackEntry({
    required this.id,
    required this.title,
    this.hash,
    this.rawUrl,
    this.durationSeconds,
    this.subtitleUrl,
  });
}
