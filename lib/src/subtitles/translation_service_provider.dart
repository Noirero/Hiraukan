import '../models/subtitle/subtitle_segment.dart';
import '../models/subtitle/timed_subtitle.dart';
import '../services/translation_service.dart';
import 'subtitle_translation_cache.dart';
import 'translation_provider.dart';

abstract class TranslationTextClient {
  Future<List<String>> translateBatch(
    List<String> texts, {
    String? sourceLanguage,
    required String targetLanguage,
  });
}

class LegacyTranslationServiceClient implements TranslationTextClient {
  final TranslationService service;

  LegacyTranslationServiceClient({TranslationService? service})
      : service = service ?? TranslationService();

  @override
  Future<List<String>> translateBatch(
    List<String> texts, {
    String? sourceLanguage,
    required String targetLanguage,
  }) {
    return service.translateBatch(
      texts,
      sourceLang: sourceLanguage,
      targetLang: targetLanguage,
      returnOriginalOnFailure: false,
    );
  }
}

/// Adapts the existing TranslationService/provider fallback chain to the new
/// subtitle TranslationProvider abstraction.
class TranslationServiceProvider implements TranslationProvider {
  final TranslationTextClient client;

  TranslationServiceProvider({TranslationTextClient? client})
      : client = client ?? LegacyTranslationServiceClient();

  @override
  Future<TimedSubtitle> translate(
    TimedSubtitle subtitle, {
    required String targetLanguage,
  }) async {
    final normalizedTarget =
        SubtitleTranslationCacheKey.normalizeLanguage(targetLanguage);
    final sourceLanguage =
        SubtitleTranslationCacheKey.normalizeLanguage(subtitle.language);
    final texts = subtitle.segments
        .map((segment) => segment.text)
        .toList(growable: false);

    final translations = await client.translateBatch(
      texts,
      sourceLanguage: sourceLanguage == 'und' ? null : sourceLanguage,
      targetLanguage: normalizedTarget,
    );

    if (translations.length != subtitle.segments.length) {
      throw StateError(
        'TranslationService returned ${translations.length} segments for '
        '${subtitle.segments.length} subtitle segments.',
      );
    }

    return TimedSubtitle(
      id: '${subtitle.id}:translation:$normalizedTarget:'
          '${SubtitleTranslationCacheKey.contentFingerprint(subtitle)}',
      source: subtitle.source,
      workId: subtitle.workId,
      trackId: subtitle.trackId,
      language: normalizedTarget,
      generatedBy: 'translation_service',
      segments: <SubtitleSegment>[
        for (var index = 0; index < subtitle.segments.length; index++)
          subtitle.segments[index].copyWith(text: translations[index]),
      ],
      isComplete: subtitle.isComplete,
      processedUntil: subtitle.processedUntil,
    );
  }
}
