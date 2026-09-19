import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';

void main() {
  test('ASMR.one and HentaiASMR are playback-capable', () {
    expect(UnifiedSourceKind.asmrOne.canPlay, isTrue);
    expect(UnifiedSourceKind.hentaiAsmr.canPlay, isTrue);
  });

  test('EroVoice remains metadata/download without playback', () {
    expect(UnifiedSourceKind.eroVoice.canLoadMetadata, isTrue);
    expect(UnifiedSourceKind.eroVoice.canDownload, isTrue);
    expect(UnifiedSourceKind.eroVoice.canPlay, isFalse);
    expect(UnifiedSourceKind.eroVoice.isDownloadOnly, isTrue);
  });
}
