import 'package:equatable/equatable.dart';

import '../models/subtitle/timed_subtitle.dart';

enum SubtitleDisplayMode {
  off,
  original,
  translated,
  bilingual,
}

enum SubtitleTranslationStatus {
  idle,
  translating,
  ready,
  unavailable,
}

/// Language codes used by the first-party subtitle translation experience.
abstract final class SubtitleTranslationTarget {
  static const String indonesian = 'id';
}

class SubtitlePresentationSegment extends Equatable {
  final Duration start;
  final Duration end;
  final String originalText;
  final String? translatedText;

  const SubtitlePresentationSegment({
    required this.start,
    required this.end,
    required this.originalText,
    this.translatedText,
  });

  @override
  List<Object?> get props => [start, end, originalText, translatedText];
}

/// A non-destructive subtitle representation for the player layer.
///
/// [original] always remains the source of truth. [translated] is optional and
/// never replaces or mutates the original subtitle.
class SubtitlePresentation extends Equatable {
  final SubtitleDisplayMode mode;
  final TimedSubtitle? original;
  final TimedSubtitle? translated;

  const SubtitlePresentation({
    required this.mode,
    this.original,
    this.translated,
  });

  bool get isVisible => mode != SubtitleDisplayMode.off && original != null;

  List<SubtitlePresentationSegment> get segments {
    final originalSubtitle = original;
    if (!isVisible || originalSubtitle == null) {
      return const <SubtitlePresentationSegment>[];
    }

    final translatedSegments = translated?.segments;
    return <SubtitlePresentationSegment>[
      for (var index = 0; index < originalSubtitle.segments.length; index++)
        SubtitlePresentationSegment(
          start: originalSubtitle.segments[index].start,
          end: originalSubtitle.segments[index].end,
          originalText: originalSubtitle.segments[index].text,
          translatedText: _translatedTextFor(
            index,
            translatedSegments,
          ),
        ),
    ];
  }

  String? _translatedTextFor(
    int index,
    List<dynamic>? translatedSegments,
  ) {
    if (mode == SubtitleDisplayMode.original || translatedSegments == null) {
      return null;
    }
    if (index >= translatedSegments.length) return null;
    return translatedSegments[index].text as String;
  }

  @override
  List<Object?> get props => [mode, original, translated];
}

enum SubtitleCcOption {
  off,
  sourceOriginal,
  automaticOriginal,
  automaticIndonesian,
  bilingual,
  settings,
}

class SubtitleCcOptionState extends Equatable {
  final SubtitleCcOption option;
  final String label;
  final bool available;
  final bool selected;
  final bool busy;
  final String? statusText;

  const SubtitleCcOptionState({
    required this.option,
    required this.label,
    required this.available,
    this.selected = false,
    this.busy = false,
    this.statusText,
  });

  @override
  List<Object?> get props => [
        option,
        label,
        available,
        selected,
        busy,
        statusText,
      ];
}
