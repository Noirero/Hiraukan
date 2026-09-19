import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_translation_engine.dart';
import '../services/mlkit_local_translation_engine.dart';
import '../services/subtitle_translation_cache.dart';

class LocalTranslationModelNotifier
    extends StateNotifier<AsyncValue<LocalTranslationModelStatus>> {
  LocalTranslationModelNotifier(this._engine)
      : super(const AsyncValue.loading()) {
    refresh();
  }

  final LocalTranslationEngine _engine;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_engine.getModelStatus);
  }

  Future<void> download({bool wifiOnly = true}) async {
    state = AsyncValue.data(
      LocalTranslationModelStatus(
        state: LocalModelState.downloading,
        engineId: _engine.id,
        engineVersion: _engine.version,
        sourceModelInstalled: false,
        targetModelInstalled: false,
      ),
    );
    state = await AsyncValue.guard(
      () => _engine.downloadModels(wifiOnly: wifiOnly),
    );
  }

  Future<void> delete() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_engine.deleteModels);
  }
}

final localTranslationEngineProvider = Provider<LocalTranslationEngine>((ref) {
  return MlKitLocalTranslationEngine.instance;
});

final localTranslationModelProvider = StateNotifierProvider<
    LocalTranslationModelNotifier,
    AsyncValue<LocalTranslationModelStatus>>((ref) {
  return LocalTranslationModelNotifier(
    ref.watch(localTranslationEngineProvider),
  );
});


final translationDocumentCacheStatsProvider =
    FutureProvider<TranslationDocumentCacheStats>((ref) {
  return SubtitleTranslationCache.instance.stats();
});
