import '../models/subtitle/timed_subtitle.dart';
import 'subtitle_request.dart';

abstract class CachedSubtitleProvider {
  Future<TimedSubtitle?> load(SubtitleRequest request);

  Future<void> save(SubtitleRequest request, TimedSubtitle subtitle);
}
