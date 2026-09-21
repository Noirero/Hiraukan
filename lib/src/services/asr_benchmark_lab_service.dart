import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'asr_benchmark.dart';
import 'whisper_compatibility_engine.dart';
import 'whisper_fast_candidate_engine.dart';
import 'whisper_high_quality_candidate_engine.dart';

class AsrBenchmarkModelsMissingException implements Exception {
  final List<String> modelNames;

  const AsrBenchmarkModelsMissingException(this.modelNames);

  @override
  String toString() =>
      'Missing required Whisper models: ${modelNames.join(', ')}';
}

class AsrBenchmarkLabResult {
  final String manifestPath;
  final String reportPath;
  final AsrBenchmarkSummary compatibility;
  final AsrBenchmarkSummary fast;
  final AsrBenchmarkSummary highQuality;
  final AsrBenchmarkGateResult fastGate;
  final AsrBenchmarkGateResult highQualityGate;

  const AsrBenchmarkLabResult({
    required this.manifestPath,
    required this.reportPath,
    required this.compatibility,
    required this.fast,
    required this.highQuality,
    required this.fastGate,
    required this.highQualityGate,
  });

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'manifestPath': manifestPath,
        'compatibility': compatibility.toJson(),
        'fast': fast.toJson(),
        'highQuality': highQuality.toJson(),
        'fastGate': {
          'state': fastGate.state.name,
          'passed': fastGate.passed,
          'reasons': fastGate.reasons,
        },
        'highQualityGate': {
          'state': highQualityGate.state.name,
          'passed': highQualityGate.passed,
          'reasons': highQualityGate.reasons,
        },
      };
}

typedef AsrBenchmarkLabStatusCallback = void Function(String status);

class AsrBenchmarkLabService {
  const AsrBenchmarkLabService();

  Future<AsrBenchmarkLabResult> run({
    required File manifest,
    int threads = 4,
    AsrBenchmarkLabStatusCallback? onStatus,
  }) async {
    if (!await manifest.exists()) {
      throw FileSystemException(
        'Benchmark manifest does not exist',
        manifest.path,
      );
    }

    const compatibility = WhisperCompatibilityEngine();
    const fast = WhisperFastCandidateEngine();
    const highQuality = WhisperHighQualityCandidateEngine();

    final missing = <String>[];
    if (!await compatibility.isModelInstalled('base')) {
      missing.add('base');
    }
    if (!await fast.isModelInstalled(WhisperFastCandidateEngine.modelName)) {
      missing.add(WhisperFastCandidateEngine.modelName);
    }
    if (!await highQuality
        .isModelInstalled(WhisperHighQualityCandidateEngine.modelName)) {
      missing.add(WhisperHighQualityCandidateEngine.modelName);
    }
    if (missing.isNotEmpty) {
      throw AsrBenchmarkModelsMissingException(
        List<String>.unmodifiable(missing.toSet()),
      );
    }

    const runner = AsrBenchmarkRunner();
    onStatus?.call('Memuat manifest benchmark…');
    final cases = await runner.loadManifest(manifest);
    if (cases.isEmpty) {
      throw const FormatException('Benchmark manifest has no cases.');
    }

    String progress(
      String profile,
      int index,
      int total,
      AsrBenchmarkCase benchmarkCase,
    ) {
      return '$profile · ${index + 1}/$total · '
          '${benchmarkCase.category.name} · ${benchmarkCase.id}';
    }

    onStatus?.call('Menjalankan Compatibility · Whisper Base…');
    final compatibilitySummary = await runner.runAll(
      engine: compatibility,
      cases: cases,
      threads: threads,
      onCaseStarting: (index, total, benchmarkCase) {
        onStatus?.call(
          progress('Compatibility', index, total, benchmarkCase),
        );
      },
    );

    onStatus?.call('Menjalankan Fast candidate · Whisper Tiny…');
    final fastSummary = await runner.runAll(
      engine: fast,
      cases: cases,
      threads: threads,
      onCaseStarting: (index, total, benchmarkCase) {
        onStatus?.call(
          progress('Fast Tiny', index, total, benchmarkCase),
        );
      },
    );

    onStatus?.call('Menjalankan High Quality candidate · Whisper Small…');
    final highQualitySummary = await runner.runAll(
      engine: highQuality,
      cases: cases,
      threads: threads,
      onCaseStarting: (index, total, benchmarkCase) {
        onStatus?.call(
          progress('HQ Small', index, total, benchmarkCase),
        );
      },
    );

    final fastGate = AsrFastAcceptanceEvaluator.evaluate(
      candidate: fastSummary,
      compatibility: compatibilitySummary,
    );
    final highQualityGate = AsrHighQualityAcceptanceEvaluator.evaluate(
      candidate: highQualitySummary,
      compatibility: compatibilitySummary,
    );

    onStatus?.call('Menyimpan laporan benchmark…');
    final support = await getApplicationSupportDirectory();
    final reportDir = Directory(
      p.join(support.path, 'hiraukan_ai', 'benchmark_reports'),
    );
    if (!await reportDir.exists()) {
      await reportDir.create(recursive: true);
    }

    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final reportFile = File(
      p.join(reportDir.path, 'asr_benchmark_$timestamp.json'),
    );

    final partialResult = AsrBenchmarkLabResult(
      manifestPath: manifest.absolute.path,
      reportPath: reportFile.path,
      compatibility: compatibilitySummary,
      fast: fastSummary,
      highQuality: highQualitySummary,
      fastGate: fastGate,
      highQualityGate: highQualityGate,
    );

    await reportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(partialResult.toJson()),
      flush: true,
    );

    onStatus?.call('Benchmark selesai.');
    return partialResult;
  }
}
