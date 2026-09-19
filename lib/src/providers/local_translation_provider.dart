import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/free_online_translation_engine.dart';
import '../services/translation_engine.dart';
import '../services/subtitle_translation_cache.dart';

final freeOnlineTranslationEngineProvider =
    Provider<TranslationEngine>((ref) {
  return FreeOnlineTranslationEngine.instance;
});

final translationDocumentCacheStatsProvider =
    FutureProvider<TranslationDocumentCacheStats>((ref) {
  return SubtitleTranslationCache.instance.stats();
});
