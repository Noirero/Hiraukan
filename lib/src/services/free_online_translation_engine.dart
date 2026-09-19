import 'dart:async';

import 'package:translator/translator.dart';

import 'translation_engine.dart';

typedef FreeOnlineTranslateClient = Future<String> Function(
  String text,
  String sourceLanguage,
  String targetLanguage,
);

/// Online Japanese -> Indonesian translation without a user API credential.
///
/// The engine intentionally stays lightweight: no local model, no native AI
/// runtime, and no automatic fallback to paid/API providers.
class FreeOnlineTranslationEngine implements TranslationEngine {
  FreeOnlineTranslationEngine._()
      : _client = _defaultClient,
        requestTimeout = const Duration(seconds: 8),
        maxAttempts = 2,
        retryBaseDelay = const Duration(milliseconds: 300),
        failureCooldown = const Duration(seconds: 30);

  /// Test-only constructor that does not require real network access.
  FreeOnlineTranslationEngine.forTesting({
    required FreeOnlineTranslateClient client,
    this.requestTimeout = const Duration(milliseconds: 100),
    this.maxAttempts = 3,
    this.retryBaseDelay = Duration.zero,
    this.failureCooldown = Duration.zero,
  }) : _client = client;

  static final FreeOnlineTranslationEngine instance =
      FreeOnlineTranslationEngine._();

  final FreeOnlineTranslateClient _client;
  final Duration requestTimeout;
  final int maxAttempts;
  final Duration retryBaseDelay;
  final Duration failureCooldown;
  final Map<String, Future<String>> _inFlight = {};
  DateTime? _retryAfter;

  static final GoogleTranslator _translator = GoogleTranslator();

  static Future<String> _defaultClient(
    String text,
    String sourceLanguage,
    String targetLanguage,
  ) async {
    final result = await _translator.translate(
      text,
      from: sourceLanguage,
      to: targetLanguage,
    );
    return result.text;
  }

  @override
  String get id => 'google_web_no_key';

  @override
  String get version => 'translator-1.0.0-online-v2';

  @override
  String get displayName => 'Gratis Online';

  @override
  Future<String> translate(
    String text, {
    String sourceLanguage = 'ja',
    String targetLanguage = 'id',
  }) {
    if (text.trim().isEmpty) return Future.value(text);
    if (sourceLanguage != 'ja' || targetLanguage != 'id') {
      return Future.error(
        ArgumentError(
          'Free Online translation currently supports ja -> id only.',
        ),
      );
    }

    final retryAfter = _retryAfter;
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
      return Future.error(
        StateError(
          'Online translation is temporarily paused after a network failure.',
        ),
      );
    }

    final key = '$sourceLanguage|$targetLanguage|$text';
    final existing = _inFlight[key];
    if (existing != null) return existing;

    late Future<String> tracked;
    tracked = _translateWithRetry(
      text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    ).then((value) {
      _retryAfter = null;
      return value;
    }, onError: (Object error, StackTrace stackTrace) {
      if (failureCooldown > Duration.zero) {
        _retryAfter = DateTime.now().add(failureCooldown);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }).whenComplete(() {
      if (identical(_inFlight[key], tracked)) {
        _inFlight.remove(key);
      }
    });
    _inFlight[key] = tracked;
    return tracked;
  }

  Future<String> _translateWithRetry(
    String text, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final attempts = maxAttempts < 1 ? 1 : maxAttempts;
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final translated = await _client(
          text,
          sourceLanguage,
          targetLanguage,
        ).timeout(requestTimeout);

        final normalized = translated.trim();
        if (normalized.isEmpty) {
          throw StateError('Online translation returned an empty response.');
        }
        return normalized;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;

        if (attempt + 1 >= attempts) break;

        final multiplier = 1 << attempt;
        final delay = Duration(
          microseconds: retryBaseDelay.inMicroseconds * multiplier,
        );
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
      }
    }

    Error.throwWithStackTrace(
      lastError ?? StateError('Online translation failed.'),
      lastStackTrace ?? StackTrace.current,
    );
  }
}
