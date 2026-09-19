import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/ai_job_identity.dart';
import 'package:kikoeru_flutter/src/models/audio_track.dart';
import 'package:kikoeru_flutter/src/providers/settings_provider.dart';
import 'package:kikoeru_flutter/src/services/free_online_translation_engine.dart';

void main() {
  test('free online provider keeps legacy preference value and Indonesian target',
      () {
    // Keep the persisted value so existing Beta users migrate automatically
    // from the former Local AI option to the new free-online option.
    expect(TranslationSource.freeOnline.value, 'local_ai');
    expect(TranslationTargetLanguage.indonesian.value, 'id');
    expect(
      TranslationTargetLanguage.indonesian.resolveLocale(
        const Locale('en'),
      ).languageCode,
      'id',
    );
  });

  test('free online engine requires no local model manager', () async {
    final engine = FreeOnlineTranslationEngine.instance;
    expect(engine.id, 'google_web_no_key');
    expect(engine.displayName, contains('Gratis Online'));

    final status = await engine.getModelStatus();
    expect(status.isReady, isTrue);
    expect(status.message, contains('tidak membutuhkan model lokal'));
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
