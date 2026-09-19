import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/translation_glossary_service.dart';

class TranslationGlossaryNotifier
    extends StateNotifier<AsyncValue<TranslationGlossarySnapshot>> {
  TranslationGlossaryNotifier() : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(TranslationGlossaryService.instance.load);
  }

  Future<void> replaceAll(List<TranslationGlossaryEntry> entries) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => TranslationGlossaryService.instance.replaceAll(entries),
    );
  }
}

final translationGlossaryProvider = StateNotifierProvider<
    TranslationGlossaryNotifier,
    AsyncValue<TranslationGlossarySnapshot>>((ref) {
  return TranslationGlossaryNotifier();
});
