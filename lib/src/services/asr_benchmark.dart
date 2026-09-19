import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/ai_job_identity.dart';
import 'speech_recognition_engine.dart';

enum AsrBenchmarkCategory {
  cleanSpeech,
  softWhisper,
  closeMic,
  binaural,
  breathHeavy,
  longSilence,
  informalJapanese,
  multiCharacter,
}

class AsrBenchmarkCase {
  final String id;
  final AsrBenchmarkCategory category;
  final String audioPath;
  final String referenceText;
  final int durationMs;

  const AsrBenchmarkCase({
    required this.id,
    required this.category,
    required this.audioPath,
    required this.referenceText,
    required this.durationMs,
  });

  factory AsrBenchmarkCase.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category']?.toString() ?? '';
    final category = AsrBenchmarkCategory.values.firstWhere(
      (value) => value.name == categoryName,
      orElse: () => throw FormatException(
        'Unknown ASR benchmark category: $categoryName',
      ),
    );
    final durationMs = (json['durationMs'] as num?)?.toInt() ?? 0;
    if (durationMs <= 0) {
      throw const FormatException('durationMs must be greater than zero');
    }

    return AsrBenchmarkCase(
      id: json['id']?.toString() ?? '',
      category: category,
      audioPath: json['audioPath']?.toString() ?? '',
      referenceText: json['referenceText']?.toString() ?? '',
      durationMs: durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.name,
        'audioPath': audioPath,
        'referenceText': referenceText,
        'durationMs': durationMs,
      };
}

class AsrBenchmarkMeasurement {
  final String caseId;
  final AsrBenchmarkCategory category;
  final String engineId;
  final String engineVersion;
  final String hypothesisText;
  final double characterErrorRate;
  final int latencyMs;
  final double realTimeFactor;
  final int rssBeforeBytes;
  final int rssAfterBytes;
  final int? processPeakRssBeforeBytes;
  final int? processPeakRssAfterBytes;

  const AsrBenchmarkMeasurement({
    required this.caseId,
    required this.category,
    required this.engineId,
    required this.engineVersion,
    required this.hypothesisText,
    required this.characterErrorRate,
    required this.latencyMs,
    required this.realTimeFactor,
    required this.rssBeforeBytes,
    required this.rssAfterBytes,
    this.processPeakRssBeforeBytes,
    this.processPeakRssAfterBytes,
  });

  Map<String, dynamic> toJson() => {
        'caseId': caseId,
        'category': category.name,
        'engineId': engineId,
        'engineVersion': engineVersion,
        'hypothesisText': hypothesisText,
        'characterErrorRate': characterErrorRate,
        'latencyMs': latencyMs,
        'realTimeFactor': realTimeFactor,
        'rssBeforeBytes': rssBeforeBytes,
        'rssAfterBytes': rssAfterBytes,
        'processPeakRssBeforeBytes': processPeakRssBeforeBytes,
        'processPeakRssAfterBytes': processPeakRssAfterBytes,
      };
}

class AsrBenchmarkSummary {
  final String engineId;
  final String engineVersion;
  final List<AsrBenchmarkMeasurement> measurements;

  const AsrBenchmarkSummary({
    required this.engineId,
    required this.engineVersion,
    required this.measurements,
  });

  double get meanCharacterErrorRate {
    if (measurements.isEmpty) return double.nan;
    return measurements
            .map((item) => item.characterErrorRate)
            .reduce((a, b) => a + b) /
        measurements.length;
  }

  double get meanRealTimeFactor {
    if (measurements.isEmpty) return double.nan;
    return measurements
            .map((item) => item.realTimeFactor)
            .reduce((a, b) => a + b) /
        measurements.length;
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'engineId': engineId,
        'engineVersion': engineVersion,
        'meanCharacterErrorRate': meanCharacterErrorRate,
        'meanRealTimeFactor': meanRealTimeFactor,
        'measurements': measurements.map((item) => item.toJson()).toList(),
      };
}

class AsrBenchmarkEvaluator {
  const AsrBenchmarkEvaluator._();

  static String normalizeForJapaneseCer(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      if (_ignoredCharacters.contains(char) ||
          RegExp(r'\s', unicode: true).hasMatch(char)) {
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  static double characterErrorRate(String reference, String hypothesis) {
    final ref = normalizeForJapaneseCer(reference).runes.toList(growable: false);
    final hyp =
        normalizeForJapaneseCer(hypothesis).runes.toList(growable: false);
    if (ref.isEmpty) return hyp.isEmpty ? 0 : 1;

    final distance = _editDistance(ref, hyp);
    return distance / ref.length;
  }

  static int _editDistance(List<int> a, List<int> b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
        final insertion = current[j - 1] + 1;
        final deletion = previous[j] + 1;
        current[j] = _min3(substitution, insertion, deletion);
      }
      previous = current;
    }
    return previous.last;
  }

  static int _min3(int a, int b, int c) {
    var value = a < b ? a : b;
    if (c < value) value = c;
    return value;
  }

  static const _ignoredCharacters = <String>{
    '。',
    '、',
    '！',
    '？',
    '!',
    '?',
    '.',
    ',',
    '・',
    '「',
    '」',
    '『',
    '』',
    '（',
    '）',
    '(',
    ')',
    '…',
    '〜',
    '~',
  };
}

class AsrBenchmarkRunner {
  const AsrBenchmarkRunner();

  Future<AsrBenchmarkMeasurement> runCase({
    required SpeechRecognitionEngine engine,
    required AsrBenchmarkCase benchmarkCase,
    int threads = 4,
  }) async {
    final audio = File(benchmarkCase.audioPath);
    if (!await audio.exists()) {
      throw FileSystemException(
        'Benchmark audio does not exist',
        benchmarkCase.audioPath,
      );
    }

    final identity = await _identityForFile(audio);
    final peakBefore = await _readLinuxProcessPeakRssBytes();
    final rssBefore = ProcessInfo.currentRss;
    final stopwatch = Stopwatch()..start();

    final subtitle = await engine.transcribe(
      SpeechRecognitionRequest(
        audioPath: benchmarkCase.audioPath,
        trackIdentity: identity,
        sourceLanguage: 'ja',
        threads: threads,
      ),
    );

    stopwatch.stop();
    final rssAfter = ProcessInfo.currentRss;
    final peakAfter = await _readLinuxProcessPeakRssBytes();
    final hypothesis = subtitle?.segments
            .map((segment) => segment.text.trim())
            .where((text) => text.isNotEmpty)
            .join() ??
        '';

    final latencyMs = stopwatch.elapsedMilliseconds;
    return AsrBenchmarkMeasurement(
      caseId: benchmarkCase.id,
      category: benchmarkCase.category,
      engineId: engine.id,
      engineVersion: engine.version,
      hypothesisText: hypothesis,
      characterErrorRate: AsrBenchmarkEvaluator.characterErrorRate(
        benchmarkCase.referenceText,
        hypothesis,
      ),
      latencyMs: latencyMs,
      realTimeFactor: latencyMs / benchmarkCase.durationMs,
      rssBeforeBytes: rssBefore,
      rssAfterBytes: rssAfter,
      processPeakRssBeforeBytes: peakBefore,
      processPeakRssAfterBytes: peakAfter,
    );
  }

  Future<AsrBenchmarkSummary> runAll({
    required SpeechRecognitionEngine engine,
    required List<AsrBenchmarkCase> cases,
    int threads = 4,
  }) async {
    final results = <AsrBenchmarkMeasurement>[];
    for (final benchmarkCase in cases) {
      results.add(
        await runCase(
          engine: engine,
          benchmarkCase: benchmarkCase,
          threads: threads,
        ),
      );
    }
    return AsrBenchmarkSummary(
      engineId: engine.id,
      engineVersion: engine.version,
      measurements: List.unmodifiable(results),
    );
  }

  Future<List<AsrBenchmarkCase>> loadManifest(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map || decoded['cases'] is! List) {
      throw const FormatException(
        'ASR benchmark manifest must contain a cases array',
      );
    }

    final cases = <AsrBenchmarkCase>[];
    for (final raw in decoded['cases'] as List) {
      if (raw is! Map) {
        throw const FormatException('Invalid ASR benchmark case');
      }
      final benchmarkCase =
          AsrBenchmarkCase.fromJson(Map<String, dynamic>.from(raw));
      if (benchmarkCase.id.trim().isEmpty ||
          benchmarkCase.audioPath.trim().isEmpty ||
          benchmarkCase.referenceText.trim().isEmpty) {
        throw const FormatException(
          'Benchmark id, audioPath and referenceText are required',
        );
      }
      cases.add(benchmarkCase);
    }
    return List.unmodifiable(cases);
  }

  Future<TrackIdentity> _identityForFile(File file) async {
    final stat = await file.stat();
    final normalizedPath = p.normalize(file.absolute.path);
    final fingerprint = sha256
        .convert(
          utf8.encode(
            '$normalizedPath|${stat.size}|${stat.modified.millisecondsSinceEpoch}',
          ),
        )
        .toString();

    return TrackIdentity(
      trackId: p.basenameWithoutExtension(file.path),
      sourceKey: 'benchmark',
      sourceWorkId: p.basename(file.parent.path),
      audioFingerprint: fingerprint,
    );
  }

  Future<int?> _readLinuxProcessPeakRssBytes() async {
    if (!(Platform.isAndroid || Platform.isLinux)) return null;
    try {
      final status = await File('/proc/self/status').readAsLines();
      final line = status.firstWhere(
        (value) => value.startsWith('VmHWM:'),
        orElse: () => '',
      );
      if (line.isEmpty) return null;
      final match = RegExp(r'VmHWM:\s+(\d+)\s+kB').firstMatch(line);
      if (match == null) return null;
      return int.parse(match.group(1)!) * 1024;
    } catch (_) {
      return null;
    }
  }
}
