import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_lock_service.dart';

/// A lifecycle-aware gate that can protect the entire Hiraukan UI without
/// changing navigation or source/provider state.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  final _pinController = TextEditingController();
  final _service = AppLockService.instance;

  bool _locked = false;
  bool _authenticating = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.revision.addListener(_handleServiceChanged);
    _locked = _service.isEnabled;

    if (_locked && _service.isBiometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_tryBiometric());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.revision.removeListener(_handleServiceChanged);
    _pinController.dispose();
    super.dispose();
  }

  void _handleServiceChanged() {
    if (!mounted) return;
    setState(() {
      if (!_service.isEnabled) {
        _locked = false;
        _errorText = null;
        _pinController.clear();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Biometric sheets can temporarily move the app through inactive/paused.
    // Those transitions must not immediately relock a successful unlock.
    if (_authenticating) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _service.notifyAppBackgrounded();
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _service.notifyAppForegrounded()) {
      setState(() {
        _locked = true;
        _errorText = null;
        _pinController.clear();
      });

      if (_service.isBiometricEnabled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_tryBiometric());
        });
      }
    }
  }

  Future<void> _tryBiometric() async {
    if (!_locked ||
        !_service.isEnabled ||
        !_service.isBiometricEnabled ||
        _authenticating) {
      return;
    }

    setState(() => _authenticating = true);
    final success = await _service.authenticateBiometric(
      reason: 'Unlock Hiraukan',
    );
    if (!mounted) return;

    setState(() {
      _authenticating = false;
      if (success) {
        _locked = false;
        _errorText = null;
        _pinController.clear();
      }
    });
  }

  void _unlockWithPin() {
    final pin = _pinController.text.trim();
    if (_service.verifyPin(pin)) {
      HapticFeedback.lightImpact();
      setState(() {
        _locked = false;
        _errorText = null;
        _pinController.clear();
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _errorText = 'PIN salah. Coba lagi.');
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.isEnabled || !_locked) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: true,
          child: ExcludeSemantics(child: widget.child),
        ),
        Material(
          color: colorScheme.surface,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 42,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Hiraukan terkunci',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Masukkan PIN untuk melanjutkan.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _pinController,
                        autofocus: !_service.isBiometricEnabled,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        decoration: InputDecoration(
                          labelText: 'PIN',
                          errorText: _errorText,
                          prefixIcon: const Icon(Icons.password_rounded),
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (_errorText != null) {
                            setState(() => _errorText = null);
                          }
                        },
                        onSubmitted: (_) => _unlockWithPin(),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _unlockWithPin,
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Buka kunci'),
                        ),
                      ),
                      if (_service.isBiometricEnabled) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _authenticating ? null : _tryBiometric,
                            icon: _authenticating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint_rounded),
                            label: Text(
                              _authenticating
                                  ? 'Memeriksa biometrik…'
                                  : 'Gunakan biometrik',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
