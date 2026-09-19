import 'dart:math' as math;
import 'dart:typed_data';

class ReazonAudioChunk {
  final int startSample;
  final int endSample;

  const ReazonAudioChunk({
    required this.startSample,
    required this.endSample,
  });

  int get sampleCount => endSample - startSample;
}

/// Plans non-overlapping ReazonSpeech inference clips around quiet boundaries.
///
/// ReazonSpeech K2 v2 documents an approximately 30 second input limit. We
/// target 20 second clips, search a small window around that target for a local
/// low-energy boundary, and enforce a 28 second hard cap. This avoids the
/// duplicate-text problem of naive overlap while reducing cuts through speech.
class ReazonChunkPlanner {
  const ReazonChunkPlanner._();

  static const int targetSeconds = 20;
  static const int hardMaxSeconds = 28;
  static const int minimumChunkSeconds = 12;
  static const int searchRadiusSeconds = 4;
  static const int energyWindowMilliseconds = 120;
  static const int energyStepMilliseconds = 40;
  static const double distancePenaltyWeight = 0.12;

  static List<ReazonAudioChunk> plan({
    required Float32List samples,
    required int sampleRate,
  }) {
    if (samples.isEmpty || sampleRate <= 0) return const [];

    final targetSamples = targetSeconds * sampleRate;
    final hardMaxSamples = hardMaxSeconds * sampleRate;
    final minimumSamples = minimumChunkSeconds * sampleRate;
    final searchRadiusSamples = searchRadiusSeconds * sampleRate;

    final chunks = <ReazonAudioChunk>[];
    var start = 0;

    while (start < samples.length) {
      final remaining = samples.length - start;
      if (remaining <= hardMaxSamples) {
        chunks.add(
          ReazonAudioChunk(
            startSample: start,
            endSample: samples.length,
          ),
        );
        break;
      }

      final ideal = start + targetSamples;
      final hardEnd = math.min(start + hardMaxSamples, samples.length);
      final earliest = math.min(start + minimumSamples, hardEnd);
      final searchStart = math.max(earliest, ideal - searchRadiusSamples);
      final searchEnd = math.min(hardEnd, ideal + searchRadiusSamples);

      var boundary = ideal.clamp(earliest, hardEnd).toInt();
      if (searchEnd > searchStart) {
        boundary = _bestQuietBoundary(
          samples: samples,
          sampleRate: sampleRate,
          ideal: ideal,
          searchStart: searchStart,
          searchEnd: searchEnd,
        );
      }

      if (boundary <= start || boundary > hardEnd) {
        boundary = hardEnd;
      }

      chunks.add(
        ReazonAudioChunk(
          startSample: start,
          endSample: boundary,
        ),
      );
      start = boundary;
    }

    return List<ReazonAudioChunk>.unmodifiable(chunks);
  }

  static int _bestQuietBoundary({
    required Float32List samples,
    required int sampleRate,
    required int ideal,
    required int searchStart,
    required int searchEnd,
  }) {
    final halfWindow = math.max(
      1,
      (sampleRate * energyWindowMilliseconds / 2000).round(),
    );
    final step = math.max(
      1,
      (sampleRate * energyStepMilliseconds / 1000).round(),
    );

    final candidates = <_BoundaryEnergy>[];
    for (var position = searchStart;
        position <= searchEnd;
        position += step) {
      candidates.add(
        _BoundaryEnergy(
          position: position,
          energy: _meanAbsoluteEnergy(
            samples,
            position - halfWindow,
            position + halfWindow,
          ),
        ),
      );
    }

    if (candidates.isEmpty || candidates.last.position != searchEnd) {
      candidates.add(
        _BoundaryEnergy(
          position: searchEnd,
          energy: _meanAbsoluteEnergy(
            samples,
            searchEnd - halfWindow,
            searchEnd + halfWindow,
          ),
        ),
      );
    }

    final sortedEnergy = candidates.map((item) => item.energy).toList()
      ..sort();
    final medianEnergy = sortedEnergy[sortedEnergy.length ~/ 2];
    final normalization = math.max(medianEnergy, 1e-8);
    final radius = math.max(1, searchEnd - searchStart);

    var best = candidates.first;
    var bestScore = double.infinity;

    for (final candidate in candidates) {
      final normalizedEnergy = candidate.energy / normalization;
      final distancePenalty =
          (candidate.position - ideal).abs() / radius * distancePenaltyWeight;
      final score = normalizedEnergy + distancePenalty;

      if (score < bestScore ||
          (score == bestScore &&
              (candidate.position - ideal).abs() <
                  (best.position - ideal).abs())) {
        best = candidate;
        bestScore = score;
      }
    }

    return best.position;
  }

  static double _meanAbsoluteEnergy(
    Float32List samples,
    int start,
    int end,
  ) {
    final boundedStart = start.clamp(0, samples.length).toInt();
    final boundedEnd = end.clamp(boundedStart, samples.length).toInt();
    if (boundedEnd <= boundedStart) return double.infinity;

    var sum = 0.0;
    for (var i = boundedStart; i < boundedEnd; i++) {
      sum += samples[i].abs();
    }
    return sum / (boundedEnd - boundedStart);
  }
}

class _BoundaryEnergy {
  final int position;
  final double energy;

  const _BoundaryEnergy({
    required this.position,
    required this.energy,
  });
}
