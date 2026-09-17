import '../models/subtitle/timed_subtitle.dart';

abstract class TranslationProvider {
  Future<TimedSubtitle> translate(
    TimedSubtitle subtitle, {
    required String targetLanguage,
  });
}
