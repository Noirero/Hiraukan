import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kikoeru_flutter/src/providers/settings_provider.dart';
import 'package:kikoeru_flutter/src/providers/translation_quality_provider.dart';
import 'package:kikoeru_flutter/src/services/translation_glossary_service.dart';
import 'package:kikoeru_flutter/src/services/free_online_translation_engine.dart';

void main() {
  test('legacy translation preferences migrate without losing choices', () async {
    SharedPreferences.setMockInitialValues({
      'translation_source': 'local_ai',
      'local_translation_context_enabled': false,
      'local_translation_playback_priority_enabled': true,
      'local_translation_glossary_entries_v1':
          '[{"source":"先生","target":"Guru"}]',
      'local_translation_glossary_version_v1': 7,
    });

    final sourceNotifier = TranslationSourceNotifier();
    final qualityNotifier = TranslationQualityNotifier();
    await pumpEventQueue(times: 20);

    final prefs = await SharedPreferences.getInstance();
    expect(sourceNotifier.state, TranslationSource.freeOnline);
    expect(prefs.getString('translation_source'), 'free_online');

    expect(qualityNotifier.state.contextEnabled, isFalse);
    expect(qualityNotifier.state.playbackPriorityEnabled, isTrue);
    expect(
      prefs.getBool(TranslationQualityNotifier.contextKey),
      isFalse,
    );
    expect(
      prefs.getBool(TranslationQualityNotifier.playbackPriorityKey),
      isTrue,
    );
    expect(
      prefs.getBool(TranslationQualityNotifier.legacyContextKey),
      isNull,
    );

    final glossary = await TranslationGlossaryService.instance.load();
    expect(glossary.version, 7);
    expect(glossary.entries.single.source, '先生');
    expect(glossary.entries.single.target, 'Guru');
    expect(
      prefs.getString('online_translation_glossary_entries_v1'),
      isNotNull,
    );
    expect(
      prefs.getString('local_translation_glossary_entries_v1'),
      isNull,
    );

    sourceNotifier.dispose();
    qualityNotifier.dispose();
  });

  test('identical concurrent requests share one online call', () async {
    var calls = 0;
    final release = Completer<String>();
    final engine = FreeOnlineTranslationEngine.forTesting(
      client: (text, source, target) {
        calls++;
        return release.future;
      },
    );

    final first = engine.translate('おはよう');
    final second = engine.translate('おはよう');

    expect(calls, 1);
    release.complete('Selamat pagi');

    expect(await first, 'Selamat pagi');
    expect(await second, 'Selamat pagi');
    expect(calls, 1);
  });

  test('temporary failures retry with bounded attempts', () async {
    var calls = 0;
    final engine = FreeOnlineTranslationEngine.forTesting(
      client: (text, source, target) async {
        calls++;
        if (calls < 3) {
          throw StateError('temporary failure');
        }
        return 'Aku menyukaimu';
      },
      maxAttempts: 3,
      retryBaseDelay: Duration.zero,
    );

    expect(await engine.translate('好きだよ'), 'Aku menyukaimu');
    expect(calls, 3);
  });

  test('request timeout retries and then fails closed', () async {
    var calls = 0;
    final engine = FreeOnlineTranslationEngine.forTesting(
      client: (text, source, target) {
        calls++;
        return Completer<String>().future;
      },
      requestTimeout: const Duration(milliseconds: 5),
      maxAttempts: 2,
      retryBaseDelay: Duration.zero,
    );

    await expectLater(
      engine.translate('テスト'),
      throwsA(isA<TimeoutException>()),
    );
    expect(calls, 2);
  });

  test('failed request is removed from in-flight deduplication', () async {
    var calls = 0;
    final engine = FreeOnlineTranslationEngine.forTesting(
      client: (text, source, target) async {
        calls++;
        if (calls == 1) {
          throw StateError('first request fails');
        }
        return 'Berhasil';
      },
      maxAttempts: 1,
    );

    await expectLater(
      engine.translate('成功'),
      throwsA(isA<StateError>()),
    );
    expect(await engine.translate('成功'), 'Berhasil');
    expect(calls, 2);
  });
}
