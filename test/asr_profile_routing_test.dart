import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/ai_job_identity.dart';
import 'package:kikoeru_flutter/src/services/asr_subtitle_cache.dart';
import 'package:kikoeru_flutter/src/services/speech_recognition_coordinator.dart';
import 'package:kikoeru_flutter/src/services/speech_recognition_engine.dart';
import 'package:kikoeru_flutter/src/services/whisper_compatibility_engine.dart';
import 'package:kikoeru_flutter/src/services/whisper_fast_candidate_engine.dart';
import 'package:kikoeru_flutter/src/services/whisper_high_quality_candidate_engine.dart';

void main() {
  const track = TrackIdentity(
    trackId: 'track-a',
    sourceKey: 'asmr_one',
    sourceWorkId: 'RJ123',
    audioFingerprint: 'hash-a',
  );

  test('ASR cache identity separates engine, version and model', () {
    final cache = AsrSubtitleCache.instance;

    final compatBase = cache.cacheIdentity(
      track: track,
      engineId: 'whisper_existing',
      engineVersion: 'compat-v1',
      modelName: 'base',
    );
    final compatTiny = cache.cacheIdentity(
      track: track,
      engineId: 'whisper_existing',
      engineVersion: 'compat-v1',
      modelName: 'tiny',
    );
    final fastTiny = cache.cacheIdentity(
      track: track,
      engineId: 'whisper_tiny_fast_candidate',
      engineVersion: 'candidate-v1',
      modelName: 'tiny',
    );
    final hqSmall = cache.cacheIdentity(
      track: track,
      engineId: 'whisper_small_hq_candidate',
      engineVersion: 'candidate-v1',
      modelName: 'small',
    );

    expect(compatBase, isNot(compatTiny));
    expect(compatBase, isNot(fastTiny));
    expect(fastTiny, isNot(hqSmall));
    expect(
      compatBase,
      cache.cacheIdentity(
        track: track,
        engineId: 'whisper_existing',
        engineVersion: 'compat-v1',
        modelName: 'base',
      ),
    );
  });

  test('engine profiles declare deterministic model defaults', () {
    expect(const WhisperCompatibilityEngine().defaultModelName, 'base');
    expect(const WhisperFastCandidateEngine().defaultModelName, 'tiny');
    expect(
      const WhisperHighQualityCandidateEngine().defaultModelName,
      'small',
    );
  });

  test('automatic routing is downgrade-safe while experimental gates are shut',
      () async {
    final coordinator = SpeechRecognitionCoordinator.instance;

    expect(SpeechRecognitionCoordinator.fastProfileApproved, isFalse);
    expect(SpeechRecognitionCoordinator.highQualityProfileApproved, isFalse);

    final auto = await coordinator.resolveAutomaticEngine(
      SpeechRecognitionProfile.auto,
    );
    final staleFast = await coordinator.resolveAutomaticEngine(
      SpeechRecognitionProfile.fast,
    );
    final staleHq = await coordinator.resolveAutomaticEngine(
      SpeechRecognitionProfile.highQuality,
    );

    expect(auto.profile, SpeechRecognitionProfile.compatibility);
    expect(staleFast.profile, SpeechRecognitionProfile.compatibility);
    expect(staleHq.profile, SpeechRecognitionProfile.compatibility);
  });

  test('automatic subtitle fallback uses profile routing and dynamic cache IDs',
      () {
    final fallback = File(
      'lib/src/services/asr_subtitle_fallback_service.dart',
    ).readAsStringSync();

    expect(fallback, contains('resolveAutomaticEngine(profile)'));
    expect(fallback, contains('engineId: engine.id'));
    expect(fallback, contains('engineVersion: engine.version'));
    expect(fallback, contains('compatibilityModelName'));
  });

  test('profile UI keeps Fast and HQ tied to benchmark release gates', () {
    final settings = File(
      'lib/src/screens/kikoflu_features_settings_screen.dart',
    ).readAsStringSync();

    expect(settings, contains("value: 'auto'"));
    expect(settings, contains("value: 'fast'"));
    expect(settings, contains("value: 'highQuality'"));
    expect(settings, contains("value: 'compatibility'"));
    expect(
      settings,
      contains('SpeechRecognitionCoordinator.fastProfileApproved'),
    );
    expect(
      settings,
      contains('highQualityProfileApproved'),
    );
  });
}
