import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kikoeru_flutter/src/services/mlkit_local_translation_engine.dart';
import 'package:kikoeru_flutter/src/services/translation_glossary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('glossary protects a Japanese term and restores Indonesian target',
      () async {
    final service = TranslationGlossaryService.instance;
    final snapshot = await service.replace(const [
      TranslationGlossaryEntry(
        source: 'お兄ちゃん',
        target: 'Kakak',
      ),
    ]);

    final protected = snapshot.protect('お兄ちゃん、大好き');
    expect(protected.text, isNot(contains('お兄ちゃん')));
    expect(protected.tokenTargets, isNotEmpty);

    final token = protected.tokenTargets.keys.single;
    expect(
      protected.restore('Aku sayang $token'),
      'Aku sayang Kakak',
    );
  });

  test('glossary fingerprint is deterministic and changes with terminology',
      () async {
    final service = TranslationGlossaryService.instance;

    final first = await service.replace(const [
      TranslationGlossaryEntry(source: '先生', target: 'Guru'),
      TranslationGlossaryEntry(source: '先輩', target: 'Senpai'),
    ]);
    final reordered = await service.replace(const [
      TranslationGlossaryEntry(source: '先輩', target: 'Senpai'),
      TranslationGlossaryEntry(source: '先生', target: 'Guru'),
    ]);
    final changed = await service.replace(const [
      TranslationGlossaryEntry(source: '先輩', target: 'Kakak kelas'),
      TranslationGlossaryEntry(source: '先生', target: 'Guru'),
    ]);

    expect(first.fingerprint, reordered.fingerprint);
    expect(changed.fingerprint, isNot(first.fingerprint));
  });

  test('duplicate Japanese glossary source keeps the latest target', () async {
    final service = TranslationGlossaryService.instance;
    final snapshot = await service.replace(const [
      TranslationGlossaryEntry(source: '耳かき', target: 'Membersihkan telinga'),
      TranslationGlossaryEntry(source: '耳かき', target: 'Korek telinga'),
    ]);

    expect(snapshot.entries, hasLength(1));
    expect(snapshot.entries.single.target, 'Korek telinga');
  });

  test('Local Lite truthfully reports no native context window support', () {
    final capabilities = MlKitLocalTranslationEngine.instance.capabilities;

    expect(capabilities.supportsNativeContextWindow, isFalse);
    expect(capabilities.supportsNativeGlossaryHints, isFalse);
    expect(capabilities.maxContextSegments, 0);
  });
}
