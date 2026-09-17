import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/settings_provider.dart';

void main() {
  test('Indonesian is an official translation target', () {
    expect(
      TranslationTargetLanguage.values,
      contains(TranslationTargetLanguage.indonesian),
    );
    expect(TranslationTargetLanguage.indonesian.value, 'id');
    expect(
      TranslationTargetLanguage.fromValue('id'),
      TranslationTargetLanguage.indonesian,
    );
    expect(
      TranslationTargetLanguage.indonesian.resolveLocale(const Locale('ja')),
      const Locale('id'),
    );
  });
}
