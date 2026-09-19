import 'dart:async';

/// Serializes heavy on-device AI work so playback keeps priority and Android
/// devices do not run ASR and local translation inference concurrently by
/// default.
class AiHeavyJobQueue {
  AiHeavyJobQueue._();

  static final AiHeavyJobQueue instance = AiHeavyJobQueue._();

  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() job) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await job());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
