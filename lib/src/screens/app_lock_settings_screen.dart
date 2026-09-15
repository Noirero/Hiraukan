import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_lock_service.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  final _service = AppLockService.instance;

  bool _enabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _loadingBiometric = true;
  int _timeoutMinutes = 5;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadBiometricAvailability();
  }

  void _reload() {
    _enabled = _service.isEnabled;
    _biometricEnabled = _service.isBiometricEnabled;
    _timeoutMinutes = _service.autoLockTimeoutMinutes;
  }

  Future<void> _loadBiometricAvailability() async {
    final available = await _service.canUseBiometric();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _loadingBiometric = false;
    });
  }

  Future<String?> _showPinSetupDialog({
    String title = 'Atur PIN App Lock',
  }) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final pin = pinController.text.trim();
              final confirmation = confirmController.text.trim();

              if (pin.length < 4 || pin.length > 8) {
                setDialogState(() {
                  errorText = 'PIN harus terdiri dari 4-8 digit.';
                });
                return;
              }
              if (!RegExp(r'^\d+$').hasMatch(pin)) {
                setDialogState(() {
                  errorText = 'PIN hanya boleh berisi angka.';
                });
                return;
              }
              if (pin != confirmation) {
                setDialogState(() {
                  errorText = 'Konfirmasi PIN tidak sama.';
                });
                return;
              }

              Navigator.of(dialogContext).pop(pin);
            }

            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pinController,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'PIN baru',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Ulangi PIN',
                      errorText: errorText,
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();
    return result;
  }

  Future<String?> _showPinVerificationDialog({
    String title = 'Konfirmasi PIN',
  }) async {
    final controller = TextEditingController();
    String? errorText;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submit() {
              final pin = controller.text.trim();
              if (_service.verifyPin(pin)) {
                Navigator.of(dialogContext).pop(pin);
              } else {
                setDialogState(() => errorText = 'PIN salah.');
              }
            }

            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: InputDecoration(
                  labelText: 'PIN',
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.password_rounded),
                ),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Konfirmasi'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _enableLock() async {
    final pin = await _showPinSetupDialog();
    if (!mounted || pin == null) return;

    await _service.enable(pin: pin);
    if (!mounted) return;
    setState(_reload);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App Lock aktif. Hiraukan akan terkunci pada pembukaan berikutnya atau setelah timeout.'),
      ),
    );
  }

  Future<void> _disableLock() async {
    var authenticated = false;

    if (_biometricEnabled && _biometricAvailable) {
      authenticated = await _service.authenticateBiometric(
        reason: 'Confirm disabling Hiraukan App Lock',
      );
      if (!mounted) return;
    }

    if (!authenticated) {
      final pin = await _showPinVerificationDialog(
        title: 'Nonaktifkan App Lock',
      );
      authenticated = pin != null;
    }

    if (!authenticated || !mounted) return;

    await _service.disable();
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _changePin() async {
    final current = await _showPinVerificationDialog(
      title: 'Verifikasi PIN saat ini',
    );
    if (!mounted || current == null) return;

    final next = await _showPinSetupDialog(title: 'Ganti PIN App Lock');
    if (!mounted || next == null) return;

    await _service.setPin(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN App Lock diperbarui.')),
    );
  }

  Future<void> _setBiometric(bool value) async {
    if (!value) {
      await _service.setBiometricEnabled(false);
      if (!mounted) return;
      setState(_reload);
      return;
    }

    if (!_biometricAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrik tidak tersedia atau belum didaftarkan di perangkat.'),
        ),
      );
      return;
    }

    final success = await _service.authenticateBiometric(
      reason: 'Enable biometric unlock for Hiraukan',
    );
    if (!mounted || !success) return;

    await _service.setBiometricEnabled(true);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _setTimeout(int? value) async {
    if (value == null) return;
    await _service.setAutoLockTimeout(value);
    if (!mounted) return;
    setState(_reload);
  }

  String _timeoutLabel(int value) {
    return switch (value) {
      -1 => 'Jangan kunci otomatis',
      0 => 'Segera setelah keluar aplikasi',
      1 => 'Setelah 1 menit',
      5 => 'Setelah 5 menit',
      15 => 'Setelah 15 menit',
      30 => 'Setelah 30 menit',
      _ => 'Setelah $value menit',
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('App Lock')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: colorScheme.primary,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Lindungi Hiraukan dengan PIN dan biometrik perangkat. '
                      'App Lock bekerja lokal dan tidak mengubah akun, sumber, download, atau library.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    _enabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                  ),
                  title: const Text('Aktifkan App Lock'),
                  subtitle: Text(
                    _enabled
                        ? 'Perlindungan aktif'
                        : 'PIN diperlukan untuk mengaktifkan perlindungan',
                  ),
                  value: _enabled,
                  onChanged: (value) {
                    if (value) {
                      _enableLock();
                    } else {
                      _disableLock();
                    }
                  },
                ),
                if (_enabled) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint_rounded),
                    title: const Text('Buka dengan biometrik'),
                    subtitle: Text(
                      _loadingBiometric
                          ? 'Memeriksa perangkat…'
                          : _biometricAvailable
                              ? 'Gunakan sidik jari/biometrik perangkat; PIN tetap menjadi cadangan'
                              : 'Biometrik tidak tersedia pada perangkat ini',
                    ),
                    value: _biometricEnabled,
                    onChanged: _loadingBiometric ? null : _setBiometric,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: const Text('Ganti PIN'),
                    subtitle: const Text('Verifikasi PIN lama sebelum membuat PIN baru'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _changePin,
                  ),
                ],
              ],
            ),
          ),
          if (_enabled) ...[
            const SizedBox(height: 16),
            Card(
              color: colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.timer_outlined),
                      title: Text('Kunci otomatis'),
                      subtitle: Text('Tentukan kapan Hiraukan terkunci setelah berada di latar belakang.'),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: _timeoutMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Waktu auto-lock',
                        border: OutlineInputBorder(),
                      ),
                      items: const [-1, 0, 1, 5, 15, 30]
                          .map(
                            (value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text(_timeoutLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: _setTimeout,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
