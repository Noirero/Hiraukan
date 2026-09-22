import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/works_provider.dart';

void main() {
  test('disabled audio extensions are removed from Home source choices', () {
    const enabled = <String>{
      'miyorare.audio.hentai_asmr',
      'miyorare.audio.ero_voice',
    };

    final choices = availableHomeSourceFilters(enabled);

    expect(choices, contains(HomeSourceFilter.all));
    expect(choices, isNot(contains(HomeSourceFilter.asmrOne)));
    expect(choices, contains(HomeSourceFilter.hentaiAsmr));
    expect(choices, contains(HomeSourceFilter.eroVoice));
  });

  test('source filters map to their audio extension ids', () {
    expect(
      HomeSourceFilter.asmrOne.extensionId,
      'miyorare.audio.asmr_one',
    );
    expect(
      HomeSourceFilter.hentaiAsmr.extensionId,
      'miyorare.audio.hentai_asmr',
    );
    expect(
      HomeSourceFilter.eroVoice.extensionId,
      'miyorare.audio.ero_voice',
    );
    expect(HomeSourceFilter.all.extensionId, isNull);
  });
}
