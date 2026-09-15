import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/audio_provider.dart';
import '../providers/settings_provider.dart';
import '../services/kikoflu_feature_coordinator.dart';
import '../services/screen_awake_service.dart';
import 'app_lock_gate.dart';

class ScreenAwakeObserver extends ConsumerStatefulWidget {
  const ScreenAwakeObserver({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<ScreenAwakeObserver> createState() =>
      _ScreenAwakeObserverState();
}

class _ScreenAwakeObserverState extends ConsumerState<ScreenAwakeObserver> {
  bool? _lastRequestedEnabled;

  @override
  void initState() {
    super.initState();
    // The coordinator only observes existing Hiraukan services. All imported
    // features remain opt-in and therefore add no source/provider startup work.
    unawaited(KikoFluFeatureCoordinator.instance.initialize());
  }

  @override
  void dispose() {
    ScreenAwakeService.setEnabled(false);
    unawaited(KikoFluFeatureCoordinator.instance.dispose());
    super.dispose();
  }

  void _apply(bool enabled) {
    if (_lastRequestedEnabled == enabled) return;
    _lastRequestedEnabled = enabled;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScreenAwakeService.setEnabled(enabled);
    });
  }

  @override
  Widget build(BuildContext context) {
    final keepAwake = ref.watch(keepScreenAwakeProvider);
    final hasTrack = ref.watch(currentTrackProvider).maybeWhen(
          data: (track) => track != null,
          orElse: () => false,
        );

    _apply(keepAwake && hasTrack);
    return AppLockGate(child: widget.child);
  }
}
