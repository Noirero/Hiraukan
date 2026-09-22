import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hiraukan startup is not gated by global authentication', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final authProviderSource =
        File('lib/src/providers/auth_provider.dart').readAsStringSync();

    expect(
      mainSource,
      isNot(contains('return const LoginScreen();')),
      reason: 'Login must remain optional; startup should open MainScreen.',
    );
    expect(
      mainSource,
      contains('return const MainScreen();'),
      reason: 'Hiraukan should have an anonymous main-screen startup path.',
    );
    expect(
      authProviderSource,
      contains("service.init('', KikoeruApiService.remoteHost);"),
      reason: 'Anonymous startup must initialize a usable default source host.',
    );
  });
}
