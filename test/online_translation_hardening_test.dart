import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/free_online_translation_engine.dart';

void main() {
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
