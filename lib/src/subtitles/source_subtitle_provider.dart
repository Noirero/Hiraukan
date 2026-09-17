import '../models/subtitle/timed_subtitle.dart';
import 'subtitle_request.dart';

abstract class SourceSubtitleProvider {
  Future<TimedSubtitle?> load(SubtitleRequest request);
}
