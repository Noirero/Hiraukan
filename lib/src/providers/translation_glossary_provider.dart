import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/translation_glossary_service.dart';

class TranslationGlossaryNotifier
    extends StateNotifier<AsyncValue<TranslationGlossarySnapshot>> {
  TranslationGlossaryNotifier(this._service)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final TranslationGlossaryService _service;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.snapshot);
  }

  Future<void> upsert(
    TranslationGlossaryEntry entry, {
    String? previousSource,
  }) async {
    state = await AsyncValue.guard(
      () => _service.upsert(entry, previousSource: previousSource),
    );
  }

  Future<void> remove(String source) async {
    state = await AsyncValue.guard(() => _service.remove(source));
  }

  Future<void> clear() async {
    state = await AsyncValue.guard(_service.clear);
  }
}

final translationGlossaryProvider = StateNotifierProvider<
    TranslationGlossaryNotifier,
    AsyncValue<TranslationGlossarySnapshot>>((ref) {
  return TranslationGlossaryNotifier(TranslationGlossaryService.instance);
});
