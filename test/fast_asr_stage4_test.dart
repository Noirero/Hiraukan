import 'package:flutter_test/flutter_test.dart';

import 'package:kikoeru_flutter/src/services/reazon_fast_model_service.dart';
import 'package:kikoeru_flutter/src/services/reazon_timestamp_segmenter.dart';
import 'package:kikoeru_flutter/src/services/speech_recognition_coordinator.dart';
import 'package:kikoeru_flutter/src/services/speech_recognition_engine.dart';

void main() {
  test('Fast ASR stays below the documented ReazonSpeech clip limit', () {
    expect(
      ReazonTimestampSegmenter.recommendedChunkSeconds,
      lessThan(ReazonTimestampSegmenter.modelMaxClipSeconds),
    );
    expect(ReazonTimestampSegmenter.recommendedChunkSeconds, 20);
    expect(ReazonTimestampSegmenter.modelMaxClipSeconds, 30);
  });

  test('pinned Fast ASR weights keep the reviewed footprint', () {
    expect(ReazonFastModelService.modelId, 'reazonspeech-k2-v2-fast');
    expect(
      ReazonFastModelService.modelRevision,
      'a454b3fe1e63f4189ae3994248aeb3d31b6682f4',
    );
    expect(ReazonFastModelService.expectedWeightBytes, 169134945);
  });

  test('Fast model manifest distinguishes update from incompatibility', () {
    expect(
      ReazonFastModelService.classifyManifest(
        schemaVersion: ReazonFastModelService.manifestSchemaVersion,
        installedModelId: ReazonFastModelService.modelId,
        installedRevision: ReazonFastModelService.modelRevision,
        installedRuntime: ReazonFastModelService.runtimeId,
      ),
      FastAsrManifestCompatibility.compatible,
    );

    expect(
      ReazonFastModelService.classifyManifest(
        schemaVersion: ReazonFastModelService.manifestSchemaVersion,
        installedModelId: ReazonFastModelService.modelId,
        installedRevision: 'older-revision',
        installedRuntime: ReazonFastModelService.runtimeId,
      ),
      FastAsrManifestCompatibility.updateAvailable,
    );

    expect(
      ReazonFastModelService.classifyManifest(
        schemaVersion: ReazonFastModelService.manifestSchemaVersion,
        installedModelId: ReazonFastModelService.modelId,
        installedRevision: ReazonFastModelService.modelRevision,
        installedRuntime: 'unsupported-runtime',
      ),
      FastAsrManifestCompatibility.incompatible,
    );
  });

  test('token timestamps split subtitle around a meaningful silence gap', () {
    final spans = ReazonTimestampSegmenter.segment(
      tokens: const ['お', 'は', 'よ', 'う', '好', 'き'],
      timestamps: const [0.1, 0.3, 0.5, 0.7, 2.2, 2.4],
      chunkStart: const Duration(seconds: 10),
      chunkEnd: const Duration(seconds: 30),
      fallbackText: 'おはよう好き',
    );

    expect(spans, hasLength(2));
    expect(spans[0].text, 'おはよう');
    expect(spans[0].start, const Duration(milliseconds: 10100));
    expect(spans[0].end, const Duration(milliseconds: 12200));
    expect(spans[1].text, '好き');
    expect(spans[1].start, const Duration(milliseconds: 12200));
    expect(spans[1].end, const Duration(milliseconds: 13200));
  });

  test('invalid token timestamp shape safely falls back to one chunk', () {
    final spans = ReazonTimestampSegmenter.segment(
      tokens: const ['私', 'は'],
      timestamps: const [0.2],
      chunkStart: const Duration(seconds: 5),
      chunkEnd: const Duration(seconds: 15),
      fallbackText: '私は',
    );

    expect(spans, hasLength(1));
    expect(spans.single.text, '私は');
    expect(spans.single.start, const Duration(seconds: 5));
    expect(spans.single.end, const Duration(seconds: 15));
  });

  test('profile parsing is stable and unknown values stay compatibility-safe', () {
    final coordinator = SpeechRecognitionCoordinator.instance;

    expect(
      coordinator.profileFromName('fast'),
      SpeechRecognitionProfile.fast,
    );
    expect(
      coordinator.profileFromName('highQuality'),
      SpeechRecognitionProfile.highQuality,
    );
    expect(
      coordinator.profileFromName('unknown-future-profile'),
      SpeechRecognitionProfile.compatibility,
    );
  });

  test('High Quality profile remains unavailable until benchmarked', () async {
    await expectLater(
      SpeechRecognitionCoordinator.instance.resolveEngine(
        SpeechRecognitionProfile.highQuality,
      ),
      throwsA(isA<SpeechRecognitionProfileUnavailableException>()),
    );
  });
}
