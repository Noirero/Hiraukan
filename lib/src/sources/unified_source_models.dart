import 'package:equatable/equatable.dart';

import '../models/work.dart';

enum UnifiedSourceKind {
  asmrOne,
  hentaiAsmr,
  eroVoice,
}

enum UnifiedSourceCapability {
  metadata,
  playback,
  download,
}

extension UnifiedSourceKindX on UnifiedSourceKind {
  String get id => switch (this) {
        UnifiedSourceKind.asmrOne => 'asmr_one',
        UnifiedSourceKind.hentaiAsmr => 'hentai_asmr',
        UnifiedSourceKind.eroVoice => 'ero_voice',
      };

  String get label => switch (this) {
        UnifiedSourceKind.asmrOne => 'ASMR.one',
        UnifiedSourceKind.hentaiAsmr => 'HentaiASMR',
        UnifiedSourceKind.eroVoice => 'EroVoice',
      };

  int get priority => switch (this) {
        UnifiedSourceKind.asmrOne => 0,
        UnifiedSourceKind.hentaiAsmr => 1,
        UnifiedSourceKind.eroVoice => 2,
      };

  Set<UnifiedSourceCapability> get capabilities => switch (this) {
        UnifiedSourceKind.asmrOne => const {
            UnifiedSourceCapability.metadata,
            UnifiedSourceCapability.playback,
            UnifiedSourceCapability.download,
          },
        UnifiedSourceKind.hentaiAsmr => const {
            UnifiedSourceCapability.metadata,
            UnifiedSourceCapability.playback,
            UnifiedSourceCapability.download,
          },
        UnifiedSourceKind.eroVoice => const {
            UnifiedSourceCapability.metadata,
            UnifiedSourceCapability.download,
          },
      };

  bool get canLoadMetadata =>
      capabilities.contains(UnifiedSourceCapability.metadata);

  bool get canPlay => capabilities.contains(UnifiedSourceCapability.playback);

  bool get canDownload =>
      capabilities.contains(UnifiedSourceCapability.download);

  bool get isDownloadOnly => canDownload && !canPlay;
}

enum UnifiedSourceHealth {
  healthy,
  degraded,
  broken,
  unknown,
}

class UnifiedSourceRef extends Equatable {
  final UnifiedSourceKind source;
  final String localId;
  final String? canonicalId;
  final String detailUrl;
  final String? coverUrl;
  final String? title;
  final String? circle;
  final int? durationSeconds;

  const UnifiedSourceRef({
    required this.source,
    required this.localId,
    required this.detailUrl,
    this.canonicalId,
    this.coverUrl,
    this.title,
    this.circle,
    this.durationSeconds,
  });

  UnifiedSourceRef copyWith({
    String? canonicalId,
    String? detailUrl,
    String? coverUrl,
    String? title,
    String? circle,
    int? durationSeconds,
  }) {
    return UnifiedSourceRef(
      source: source,
      localId: localId,
      canonicalId: canonicalId ?? this.canonicalId,
      detailUrl: detailUrl ?? this.detailUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      title: title ?? this.title,
      circle: circle ?? this.circle,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  @override
  List<Object?> get props => [
        source,
        localId,
        canonicalId,
        detailUrl,
        coverUrl,
        title,
        circle,
        durationSeconds,
      ];
}

class SourceWorkCandidate {
  final Work work;
  final UnifiedSourceRef ref;

  const SourceWorkCandidate({required this.work, required this.ref});
}

class SourceSearchPage {
  final List<SourceWorkCandidate> items;
  final int totalCount;
  final bool hasMore;

  const SourceSearchPage({
    required this.items,
    required this.totalCount,
    required this.hasMore,
  });
}

class UnifiedWorkBundle {
  final Work work;
  final String canonicalKey;
  final List<UnifiedSourceRef> sources;

  const UnifiedWorkBundle({
    required this.work,
    required this.canonicalKey,
    required this.sources,
  });

  String? get coverUrl {
    for (final source in sources) {
      final value = source.coverUrl?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Kept for existing callers that care about any mirrored source.
  bool get hasFallback => sources.length > 1;

  List<UnifiedSourceRef> get playableSources => sources
      .where((ref) => ref.source.canPlay)
      .toList(growable: false);

  List<UnifiedSourceRef> get downloadSources => sources
      .where((ref) => ref.source.canDownload)
      .toList(growable: false);

  List<UnifiedSourceRef> get downloadOnlySources => sources
      .where((ref) => ref.source.isDownloadOnly)
      .toList(growable: false);

  bool get canPlay => playableSources.isNotEmpty;

  bool get canDownload => downloadSources.isNotEmpty;

  bool get hasPlaybackFallback => playableSources.length > 1;

  bool hasSource(UnifiedSourceKind source) =>
      sources.any((ref) => ref.source == source);
}

class UnifiedSearchPage {
  final List<Work> works;
  final int totalCount;
  final bool hasMore;
  final Map<UnifiedSourceKind, UnifiedSourceHealth> health;

  const UnifiedSearchPage({
    required this.works,
    required this.totalCount,
    required this.hasMore,
    required this.health,
  });
}

class ResolvedSourceTracks {
  final UnifiedSourceRef source;
  final List<dynamic> files;
  final bool usedFallback;

  const ResolvedSourceTracks({
    required this.source,
    required this.files,
    required this.usedFallback,
  });
}

class ResolvedSourceDownloads {
  final UnifiedSourceRef source;
  final List<dynamic> files;

  const ResolvedSourceDownloads({
    required this.source,
    required this.files,
  });
}
