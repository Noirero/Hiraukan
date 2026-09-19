import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/free_online_translation_engine.dart';
import '../services/local_translation_engine.dart';
import '../services/subtitle_translation_cache.dart';

final freeOnlineTranslationEngineProvider =
    Provider<LocalTranslationEngine>((ref) {
  return FreeOnlineTranslationEngine.instance;
});

final translationDocumentCacheStatsProvider =
    FutureProvider<TranslationDocumentCacheStats>((ref) {
  return SubtitleTranslationCache.instance.stats();
});
