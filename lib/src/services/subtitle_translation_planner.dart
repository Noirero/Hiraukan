import '../models/lyric.dart';

class SubtitleTranslationPlanner {
  const SubtitleTranslationPlanner._();

  /// Pick the next untranslated subtitle index.
  ///
  /// Priority is:
  /// 1. current playback segment
  /// 2. the next 12 segments
  /// 3. the previous 4 nearby segments
  /// 4. remaining segments by distance, with future segments slightly favored
  static int pickNextIndex({
    required Set<int> pending,
    required List<LyricLine> lyrics,
    required Duration playbackPosition,
  }) {
    if (pending.isEmpty) {
      throw StateError('No pending subtitle segments');
    }
    if (pending.length == 1) return pending.first;

    var currentIndex = 0;
    for (var i = 0; i < lyrics.length; i++) {
      if (playbackPosition >= lyrics[i].startTime) {
        currentIndex = i;
      } else {
        break;
      }
    }

    int score(int index) {
      final delta = index - currentIndex;
      if (delta == 0) return 0;
      if (delta > 0 && delta <= 12) return delta;
      if (delta < 0 && -delta <= 4) return 20 + (-delta);
      return 100 + delta.abs() * 2 + (delta < 0 ? 1 : 0);
    }

    var best = pending.first;
    var bestScore = score(best);
    for (final index in pending.skip(1)) {
      final candidateScore = score(index);
      if (candidateScore < bestScore) {
        best = index;
        bestScore = candidateScore;
      }
    }
    return best;
  }
}
