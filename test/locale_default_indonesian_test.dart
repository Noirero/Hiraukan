import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Indonesian is the default locale when no preference exists', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final notifier = LocaleNotifier();

    await Future<void>.delayed(Duration.zero);

    expect(notifier.state?.languageCode, 'id');
    notifier.dispose();
  });

  test('explicit Follow System selection survives notifier recreation', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final first = LocaleNotifier();
    await Future<void>.delayed(Duration.zero);

    await first.setLocale(null);
    expect(first.state, isNull);
    first.dispose();

    final second = LocaleNotifier();
    await Future<void>.delayed(Duration.zero);

    expect(second.state, isNull);
    second.dispose();
  });
}
