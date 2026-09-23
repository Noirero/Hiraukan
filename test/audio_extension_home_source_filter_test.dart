import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/providers/works_provider.dart';
import 'package:kikoeru_flutter/src/sources/asmr18_source_adapter.dart';

void main() {
  test('ASMR+18 exposes independent catalog category filters', () {
    expect(
      Asmr18CatalogCategory.values.map((value) => value.id),
      <String>['all', 'boys', 'girls', 'allages'],
    );
    expect(Asmr18CatalogCategory.boys.label, 'Boys');
    expect(Asmr18CatalogCategory.girls.label, 'Girls');
  });


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
      HomeSourceFilter.japaneseAsmr.extensionId,
      'miyorare.audio.japanese_asmr',
    );
    expect(
      HomeSourceFilter.asmr18.extensionId,
      'miyorare.audio.asmr18',
    );
    expect(
      HomeSourceFilter.eroVoice.extensionId,
      'miyorare.audio.ero_voice',
    );
    expect(
      HomeSourceFilter.asmrHentaiNet.extensionId,
      'miyorare.audio.asmr_hentai_net',
    );
    expect(HomeSourceFilter.all.extensionId, isNull);
  });
}
