import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';

void main() {
  test('ASMR.one and HentaiASMR are playback-capable', () {
    expect(UnifiedSourceKind.asmrOne.canPlay, isTrue);
    expect(UnifiedSourceKind.hentaiAsmr.canPlay, isTrue);
  });

  test('JapaneseASMR and ASMR+18 expose verified playback capabilities', () {
    expect(UnifiedSourceKind.japaneseAsmr.canPlay, isTrue);
    expect(UnifiedSourceKind.japaneseAsmr.canDownload, isTrue);
    expect(UnifiedSourceKind.asmr18.canPlay, isTrue);
    expect(UnifiedSourceKind.asmr18.canDownload, isFalse);
  });

  test('ASMR Hentai remains metadata-only until media URL is verified', () {
    expect(UnifiedSourceKind.asmrHentaiNet.canLoadMetadata, isTrue);
    expect(UnifiedSourceKind.asmrHentaiNet.canPlay, isFalse);
    expect(UnifiedSourceKind.asmrHentaiNet.canDownload, isFalse);
  });

  test('EroVoice remains metadata/download without playback', () {
    expect(UnifiedSourceKind.eroVoice.canLoadMetadata, isTrue);
    expect(UnifiedSourceKind.eroVoice.canDownload, isTrue);
    expect(UnifiedSourceKind.eroVoice.canPlay, isFalse);
    expect(UnifiedSourceKind.eroVoice.isDownloadOnly, isTrue);
  });
}
