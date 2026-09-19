class ReazonTimedTextSpan {
  final Duration start;
  final Duration end;
  final String text;

  const ReazonTimedTextSpan({
    required this.start,
    required this.end,
    required this.text,
  });
}

/// Converts token-level timestamps from sherpa-onnx into subtitle-friendly
/// spans while keeping every generated timestamp inside its source chunk.
///
/// ReazonSpeech K2 v2 documents an approximately 30 second input limit. The
/// engine intentionally feeds shorter chunks so model limits are never the
/// reason playback or transcription fails.
class ReazonTimestampSegmenter {
  const ReazonTimestampSegmenter._();

  static const int modelMaxClipSeconds = 30;
  static const int recommendedChunkSeconds = 20;

  static const double silenceGapSeconds = 1.0;
  static const double maxSegmentSeconds = 6.0;
  static const int maxCharacters = 32;
  static const double tailPaddingSeconds = 0.8;

  static List<ReazonTimedTextSpan> segment({
    required List<String> tokens,
    required List<double> timestamps,
    required Duration chunkStart,
    required Duration chunkEnd,
    required String fallbackText,
  }) {
    if (chunkEnd <= chunkStart) return const [];

    final fallback = fallbackText.trim();
    if (tokens.isEmpty || tokens.length != timestamps.length) {
      return _fallback(
        chunkStart: chunkStart,
        chunkEnd: chunkEnd,
        text: fallback,
      );
    }

    final chunkSeconds =
        (chunkEnd - chunkStart).inMicroseconds / Duration.microsecondsPerSecond;
    final points = <_TokenPoint>[];

    for (var i = 0; i < tokens.length; i++) {
      final timestamp = timestamps[i];
      if (!timestamp.isFinite ||
          timestamp < 0 ||
          timestamp > chunkSeconds + 0.5) {
        continue;
      }

      final token = _normalizeToken(tokens[i]);
      if (token.isEmpty || token == '<blk>') continue;
      points.add(_TokenPoint(text: token, seconds: timestamp));
    }

    if (points.isEmpty) {
      return _fallback(
        chunkStart: chunkStart,
        chunkEnd: chunkEnd,
        text: fallback,
      );
    }

    final result = <ReazonTimedTextSpan>[];
    var current = <_TokenPoint>[];

    void flush(double endSeconds) {
      if (current.isEmpty) return;

      final text = current.map((point) => point.text).join().trim();
      if (text.isEmpty) {
        current = <_TokenPoint>[];
        return;
      }

      final startSeconds = current.first.seconds;
      var boundedEndSeconds = endSeconds.clamp(
        startSeconds,
        chunkSeconds,
      );
      if (boundedEndSeconds <= startSeconds) {
        boundedEndSeconds =
            (startSeconds + 0.2).clamp(startSeconds, chunkSeconds);
      }

      final start = chunkStart +
          Duration(
            microseconds:
                (startSeconds * Duration.microsecondsPerSecond).round(),
          );
      final end = chunkStart +
          Duration(
            microseconds:
                (boundedEndSeconds * Duration.microsecondsPerSecond).round(),
          );

      if (end > start) {
        result.add(
          ReazonTimedTextSpan(
            start: start,
            end: end > chunkEnd ? chunkEnd : end,
            text: text,
          ),
        );
      }

      current = <_TokenPoint>[];
    }

    for (final point in points) {
      if (current.isNotEmpty) {
        final previous = current.last;
        final groupStart = current.first.seconds;
        final nextLength =
            current.fold<int>(0, (sum, item) => sum + item.text.length) +
                point.text.length;
        final currentText = current.map((item) => item.text).join();

        final shouldSplit = point.seconds - previous.seconds >= silenceGapSeconds ||
            point.seconds - groupStart >= maxSegmentSeconds ||
            nextLength > maxCharacters ||
            _endsSentence(currentText);

        if (shouldSplit) {
          flush(point.seconds);
        }
      }

      current.add(point);
    }

    final lastTimestamp = current.isEmpty ? 0.0 : current.last.seconds;
    flush(
      (lastTimestamp + tailPaddingSeconds).clamp(
        0.0,
        chunkSeconds,
      ),
    );

    if (result.isEmpty) {
      return _fallback(
        chunkStart: chunkStart,
        chunkEnd: chunkEnd,
        text: fallback,
      );
    }

    return List<ReazonTimedTextSpan>.unmodifiable(result);
  }

  static List<ReazonTimedTextSpan> _fallback({
    required Duration chunkStart,
    required Duration chunkEnd,
    required String text,
  }) {
    if (text.isEmpty) return const [];
    return [
      ReazonTimedTextSpan(
        start: chunkStart,
        end: chunkEnd,
        text: text,
      ),
    ];
  }

  static String _normalizeToken(String token) {
    return token.replaceAll('▁', ' ');
  }

  static bool _endsSentence(String text) {
    final trimmed = text.trimRight();
    if (trimmed.length < 6) return false;
    return trimmed.endsWith('。') ||
        trimmed.endsWith('！') ||
        trimmed.endsWith('？') ||
        trimmed.endsWith('!') ||
        trimmed.endsWith('?');
  }
}

class _TokenPoint {
  final String text;
  final double seconds;

  const _TokenPoint({
    required this.text,
    required this.seconds,
  });
}
