import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/sources/unified_source_models.dart';

void main() {
  group('unified source capabilities', () {
    test('ASMR.one supports playback and download', () {
      expect(UnifiedSourceKind.asmrOne.canPlay, isTrue);
      expect(UnifiedSourceKind.asmrOne.canDownload, isTrue);
      expect(UnifiedSourceKind.asmrOne.isDownloadOnly, isFalse);
    });

    test('HentaiASMR supports playback and download', () {
      expect(UnifiedSourceKind.hentaiAsmr.canPlay, isTrue);
      expect(UnifiedSourceKind.hentaiAsmr.canDownload, isTrue);
      expect(UnifiedSourceKind.hentaiAsmr.isDownloadOnly, isFalse);
    });

    test('EroVoice is download-only and cannot enter playback fallback', () {
      expect(UnifiedSourceKind.eroVoice.canLoadMetadata, isTrue);
      expect(UnifiedSourceKind.eroVoice.canDownload, isTrue);
      expect(UnifiedSourceKind.eroVoice.canPlay, isFalse);
      expect(UnifiedSourceKind.eroVoice.isDownloadOnly, isTrue);
    });
  });
}
