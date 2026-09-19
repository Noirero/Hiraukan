import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/ai_job_identity.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/providers/settings_provider.dart';
import 'package:kikoeru_flutter/src/services/local_translation_engine.dart';

void main() {
  test('Local AI provider is explicit and Indonesian target is available', () {
    expect(TranslationSource.localAi.value, 'local_ai');
    expect(TranslationTargetLanguage.indonesian.value, 'id');
    expect(
      TranslationTargetLanguage.indonesian.resolveLocale(
        const Locale('en'),
      ).languageCode,
      'id',
    );
  });

  test('track identity is stable across display-only track changes', () {
    const original = AudioTrack(
      id: 'track-1',
      title: 'Display title A',
      url: 'https://example.test/a.mp3',
      workId: 123,
      hash: 'audio-hash',
      sourceKey: 'asmr_one',
      sourceWorkId: 'RJ123456',
    );
    const renamed = AudioTrack(
      id: 'track-1',
      title: 'Display title B',
      url: 'https://cdn.example.test/a.mp3',
      workId: 123,
      hash: 'audio-hash',
      sourceKey: 'asmr_one',
      sourceWorkId: 'RJ123456',
    );

    expect(
      TrackIdentity.fromTrack(original),
      TrackIdentity.fromTrack(renamed),
    );
  });

  test('track identity changes when the audio fingerprint changes', () {
    const first = AudioTrack(
      id: 'track-1',
      title: 'Track',
      url: 'https://example.test/a.mp3',
      hash: 'hash-v1',
      sourceKey: 'asmr_one',
      sourceWorkId: 'RJ123456',
    );
    const second = AudioTrack(
      id: 'track-1',
      title: 'Track',
      url: 'https://example.test/a.mp3',
      hash: 'hash-v2',
      sourceKey: 'asmr_one',
      sourceWorkId: 'RJ123456',
    );

    expect(
      TrackIdentity.fromTrack(first),
      isNot(TrackIdentity.fromTrack(second)),
    );
  });

  test('model status is only ready when both language models are installed', () {
    const incomplete = LocalTranslationModelStatus(
      state: LocalModelState.ready,
      engineId: 'test',
      engineVersion: '1',
      sourceModelInstalled: true,
      targetModelInstalled: false,
    );
    const ready = LocalTranslationModelStatus(
      state: LocalModelState.ready,
      engineId: 'test',
      engineVersion: '1',
      sourceModelInstalled: true,
      targetModelInstalled: true,
    );

    expect(incomplete.isReady, isFalse);
    expect(ready.isReady, isTrue);
  });
}
