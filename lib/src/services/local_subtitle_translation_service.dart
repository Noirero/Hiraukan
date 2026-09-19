import 'ai_heavy_job_queue.dart';
import 'local_translation_engine.dart';
import 'mlkit_local_translation_engine.dart';
import 'translation_glossary_service.dart';

class LocalSubtitleTranslationService {
  LocalSubtitleTranslationService({
    LocalTranslationEngine? engine,
  }) : _engine = engine ?? MlKitLocalTranslationEngine.instance;

  final LocalTranslationEngine _engine;

  Future<String> translateSegment({
    required List<String> sourceLines,
    required int index,
    required TranslationGlossarySnapshot glossary,
    bool contextEnabled = true,
  }) async {
    if (index < 0 || index >= sourceLines.length) {
      throw RangeError.index(index, sourceLines, 'index');
    }

    final source = sourceLines[index];
    if (source.trim().isEmpty || source == '♪ - ♪') return source;

    if (!contextEnabled || sourceLines.length == 1) {
      return _translateSingle(source, glossary);
    }

    final start = index > 0 ? index - 1 : index;
    final end = index + 1 < sourceLines.length ? index + 1 : index;
    final window = sourceLines.sublist(start, end + 1);
    final protected = _protectGlossary(window, glossary.entries);
    final joined = protected.lines.join('\n');

    try {
      final translated = await AiHeavyJobQueue.instance.run(
        () => _engine.translate(
          joined,
          sourceLanguage: 'ja',
          targetLanguage: 'id',
        ),
      );
      final translatedLines = translated.split('\n');
      final relativeIndex = index - start;

      if (translatedLines.length == protected.lines.length &&
          relativeIndex >= 0 &&
          relativeIndex < translatedLines.length) {
        final candidate = _restoreGlossary(
          translatedLines[relativeIndex],
          protected.replacements,
        ).trim();
        if (candidate.isNotEmpty) return candidate;
      }
    } on LocalTranslationModelNotInstalledException {
      rethrow;
    } catch (_) {
      // Context is a quality optimization only. Fall back to strict 1:1.
    }

    return _translateSingle(source, glossary);
  }

  Future<String> _translateSingle(
    String source,
    TranslationGlossarySnapshot glossary,
  ) async {
    final protected = _protectGlossary([source], glossary.entries);
    final translated = await AiHeavyJobQueue.instance.run(
      () => _engine.translate(
        protected.lines.first,
        sourceLanguage: 'ja',
        targetLanguage: 'id',
      ),
    );
    final restored =
        _restoreGlossary(translated, protected.replacements).trim();
    return restored.isEmpty ? source : restored;
  }

  _ProtectedGlossaryText _protectGlossary(
    List<String> sourceLines,
    List<TranslationGlossaryEntry> entries,
  ) {
    if (entries.isEmpty) {
      return _ProtectedGlossaryText(
        lines: List<String>.from(sourceLines),
        replacements: const {},
      );
    }

    final sorted = List<TranslationGlossaryEntry>.from(entries)
      ..sort((a, b) => b.source.length.compareTo(a.source.length));

    final replacements = <String, String>{};
    final lines = <String>[];
    var tokenCounter = 0;

    for (final original in sourceLines) {
      var text = original;
      for (final entry in sorted) {
        if (entry.source.isEmpty || !text.contains(entry.source)) continue;
        while (text.contains(entry.source)) {
          final token = 'ZXQGLOSS${tokenCounter++}ZXQ';
          text = text.replaceFirst(entry.source, token);
          replacements[token] = entry.target;
        }
      }
      lines.add(text);
    }

    return _ProtectedGlossaryText(
      lines: lines,
      replacements: replacements,
    );
  }

  String _restoreGlossary(
    String translated,
    Map<String, String> replacements,
  ) {
    var output = translated;
    for (final entry in replacements.entries) {
      output = output.replaceAll(entry.key, entry.value);
      final spaced = entry.key.split('').join(' ');
      output = output.replaceAll(spaced, entry.value);
    }
    return output;
  }
}

class _ProtectedGlossaryText {
  final List<String> lines;
  final Map<String, String> replacements;

  const _ProtectedGlossaryText({
    required this.lines,
    required this.replacements,
  });
}
