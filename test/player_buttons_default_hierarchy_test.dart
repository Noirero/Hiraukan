import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/player_buttons_provider.dart';

void main() {
  test('mobile defaults keep listening essentials visible', () {
    expect(
      PlayerButtonsConfig.defaultMobile.getVisibleButtons(false),
      const [
        PlayerButtonType.speed,
        PlayerButtonType.sleepTimer,
        PlayerButtonType.seekBackward,
        PlayerButtonType.seekForward,
      ],
    );
    expect(
      PlayerButtonsConfig.defaultMobile.getMoreButtons(false),
      containsAll(<PlayerButtonType>[
        PlayerButtonType.floatingLyric,
        PlayerButtonType.mark,
        PlayerButtonType.repeat,
        PlayerButtonType.subtitleAdjustment,
        PlayerButtonType.detail,
      ]),
    );
  });

  test('desktop defaults keep volume in the quick row', () {
    expect(
      PlayerButtonsConfig.defaultDesktop.getVisibleButtons(true),
      const [
        PlayerButtonType.speed,
        PlayerButtonType.sleepTimer,
        PlayerButtonType.volume,
        PlayerButtonType.seekBackward,
        PlayerButtonType.seekForward,
      ],
    );
  });
}
