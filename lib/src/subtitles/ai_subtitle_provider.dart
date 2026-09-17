import '../models/subtitle/timed_subtitle.dart';
import 'subtitle_request.dart';

abstract class AiSubtitleProvider {
  Future<TimedSubtitle?> generate(SubtitleRequest request);
}
