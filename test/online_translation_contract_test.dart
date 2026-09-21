import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/ai_job_identity.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/providers/settings_provider.dart';
import 'package:kikoeru_flutter/src/services/free_online_translation_engine.dart';

void main() {
  test('free online provider still migrates the legacy preference', () {
    expect(TranslationSource.freeOnline.value, 'free_online');
    expect(
      TranslationSource.fromStoredValue('local_ai'),
      TranslationSource.freeOnline,
    );
    expect(
      TranslationSource.fromStoredValue('free_online'),
      TranslationSource.freeOnline,
    );
  });

  test('free online engine forwards selectable multilingual pairs', () async {
    final calls = <String>[];
    final engine = FreeOnlineTranslationEngine.forTesting(
      client: (text, source, target) async {
        calls.add('$source->$target:$text');
        return 'ok';
      },
    );

    expect(
      await engine.translate(
        '안녕하세요',
        sourceLanguage: 'ko',
        targetLanguage: 'en',
      ),
      'ok',
    );
    expect(
      await engine.translate(
        '你好',
        sourceLanguage: 'zh-cn',
        targetLanguage: 'ja',
      ),
      'ok',
    );
    expect(calls, ['ko->en:안녕하세요', 'zh-cn->ja:你好']);
  });

  test('free online engine has no local model lifecycle', () {
    final engine = FreeOnlineTranslationEngine.instance;
    expect(engine.id, 'google_web_no_key');
    expect(engine.displayName, contains('Gratis Online'));
  });

  test('Android APK does not bundle ML Kit translation runtime or bridge', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/meteor/kikoeruflutter/MainActivity.kt',
    ).readAsStringSync();

    expect(gradle, isNot(contains('com.google.mlkit:translate')));
    expect(activity, isNot(contains('LocalTranslationBridge')));
    expect(
      File(
        'android/app/src/main/kotlin/com/meteor/kikoeruflutter/LocalTranslationBridge.kt',
      ).existsSync(),
      isFalse,
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
}
