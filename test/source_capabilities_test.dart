import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';

void main() {
  test('ASMR.one and HentaiASMR are playback-capable', () {
    expect(UnifiedSourceKind.asmrOne.capabilities.playback, isTrue);
    expect(UnifiedSourceKind.hentaiAsmr.capabilities.playback, isTrue);
  });

  test('EroVoice remains catalog/detail/download without playback', () {
    final capabilities = UnifiedSourceKind.eroVoice.capabilities;

    expect(capabilities.catalog, isTrue);
    expect(capabilities.detail, isTrue);
    expect(capabilities.download, isTrue);
    expect(capabilities.playback, isFalse);
  });
}
