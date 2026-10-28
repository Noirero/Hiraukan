import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/player_buttons_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persisted mobile order remains authoritative after default changes',
      () async {
    const savedOrder = <PlayerButtonType>[
      PlayerButtonType.detail,
      PlayerButtonType.repeat,
      PlayerButtonType.speed,
      PlayerButtonType.seekBackward,
      PlayerButtonType.seekForward,
      PlayerButtonType.sleepTimer,
      PlayerButtonType.mark,
      PlayerButtonType.subtitleAdjustment,
      PlayerButtonType.floatingLyric,
    ];
    SharedPreferences.setMockInitialValues({
      'player_buttons_config': savedOrder.map((item) => item.key).join(','),
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(playerButtonsConfigMobileProvider);

    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(
      container.read(playerButtonsConfigMobileProvider).buttonOrder,
      savedOrder,
    );
  });
}
