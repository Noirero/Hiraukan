import 'local_translation_engine.dart';
import 'free_online_translation_engine.dart';
import 'translation_glossary_service.dart';

class LocalSubtitleTranslationService {
  LocalSubtitleTranslationService({
    LocalTranslationEngine? engine,
  }) : _engine = engine ?? FreeOnlineTranslationEngine.instance;

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
      final translated = await _engine.translate(
          joined,
          sourceLanguage: 'ja',
          targetLanguage: 'id',
      );
      final translatedLines = translated.split('\n');
      final relativeIndex = index - start;

      if (translatedLines.length == protected.lines.length &&
          relativeIndex >= 0 &&
          relativeIndex < translatedLines.length) {
        final rawCandidate = translatedLines[relativeIndex];
        final expectedTokens = protected.tokensByLine[relativeIndex];
        if (_containsAllGlossaryTokens(rawCandidate, expectedTokens)) {
          final candidate = _restoreGlossary(
            rawCandidate,
            protected.replacements,
          ).trim();
          if (candidate.isNotEmpty && !candidate.contains('ZXQGLOSS')) {
            return candidate;
          }
        }
      }
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
    final translated = await _engine.translate(
        protected.lines.first,
        sourceLanguage: 'ja',
        targetLanguage: 'id',
      );
    final expectedTokens = protected.tokensByLine.first;
    if (!_containsAllGlossaryTokens(translated, expectedTokens)) {
      return _translateUnprotected(source);
    }

    final restored =
        _restoreGlossary(translated, protected.replacements).trim();
    if (restored.isEmpty || restored.contains('ZXQGLOSS')) {
      return _translateUnprotected(source);
    }
    return restored;
  }

  _ProtectedGlossaryText _protectGlossary(
    List<String> sourceLines,
    List<TranslationGlossaryEntry> entries,
  ) {
    if (entries.isEmpty) {
      return _ProtectedGlossaryText(
        lines: List<String>.from(sourceLines),
        replacements: const {},
        tokensByLine: [
          for (final _ in sourceLines) const <String>[],
        ],
      );
    }

    final sorted = List<TranslationGlossaryEntry>.from(entries)
      ..sort((a, b) => b.source.length.compareTo(a.source.length));

    final replacements = <String, String>{};
    final lines = <String>[];
    final tokensByLine = <List<String>>[];
    var tokenCounter = 0;

    for (final original in sourceLines) {
      var text = original;
      final lineTokens = <String>[];
      for (final entry in sorted) {
        if (entry.source.isEmpty || !text.contains(entry.source)) continue;
        while (text.contains(entry.source)) {
          final token = 'ZXQGLOSS${tokenCounter++}ZXQ';
          text = text.replaceFirst(entry.source, token);
          replacements[token] = entry.target;
          lineTokens.add(token);
        }
      }
      lines.add(text);
      tokensByLine.add(List.unmodifiable(lineTokens));
    }

    return _ProtectedGlossaryText(
      lines: lines,
      replacements: replacements,
      tokensByLine: List.unmodifiable(tokensByLine),
    );
  }

  Future<String> _translateUnprotected(String source) async {
    final translated = await _engine.translate(
        source,
        sourceLanguage: 'ja',
        targetLanguage: 'id',
      );
    final trimmed = translated.trim();
    return trimmed.isEmpty ? source : trimmed;
  }

  bool _containsAllGlossaryTokens(
    String translated,
    List<String> expectedTokens,
  ) {
    for (final token in expectedTokens) {
      if (translated.contains(token)) continue;
      final spaced = token.split('').join(' ');
      if (!translated.contains(spaced)) return false;
    }
    return true;
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
  final List<List<String>> tokensByLine;

  const _ProtectedGlossaryText({
    required this.lines,
    required this.replacements,
    required this.tokensByLine,
  });
}
