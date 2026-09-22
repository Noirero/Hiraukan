import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/miyorare_audio_catalog_service.dart';

void main() {
  test('accepts an audio catalog bound by a sealed release lock', () {
    final catalog = utf8.encode('{"schemaVersion":1}');
    final tag = 'miyorare-sources-v1.2.3';
    final lock = utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'kind': 'MIYORARE_SOURCE_PACK_RELEASE_LOCK',
        'immutable': true,
        'sealedBeforePublish': true,
        'tag': tag,
        'assets': [
          {
            'name': MiyorareAudioCatalogService.catalogAssetName,
            'size': catalog.length,
            'sha256': sha256.convert(catalog).toString(),
          },
        ],
      }),
    );
    final checksum = utf8.encode(
      sha256.convert(lock).toString() +
          '  ' +
          MiyorareAudioCatalogService.releaseLockAssetName +
          '\n',
    );

    expect(
      () => MiyorareAudioCatalogService.verifyReleaseLock(
        releaseTag: tag,
        catalogBytes: catalog,
        lockBytes: lock,
        lockChecksumBytes: checksum,
      ),
      returnsNormally,
    );
  });

  test('rejects catalog bytes changed after release sealing', () {
    final original = utf8.encode('{"schemaVersion":1}');
    final tampered = utf8.encode('{"schemaVersion":2}');
    final tag = 'miyorare-sources-v1.2.3';
    final lock = utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'kind': 'MIYORARE_SOURCE_PACK_RELEASE_LOCK',
        'immutable': true,
        'sealedBeforePublish': true,
        'tag': tag,
        'assets': [
          {
            'name': MiyorareAudioCatalogService.catalogAssetName,
            'size': original.length,
            'sha256': sha256.convert(original).toString(),
          },
        ],
      }),
    );
    final checksum = utf8.encode(
      sha256.convert(lock).toString() +
          '  ' +
          MiyorareAudioCatalogService.releaseLockAssetName +
          '\n',
    );

    expect(
      () => MiyorareAudioCatalogService.verifyReleaseLock(
        releaseTag: tag,
        catalogBytes: tampered,
        lockBytes: lock,
        lockChecksumBytes: checksum,
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects an unsealed release lock', () {
    final catalog = utf8.encode('{"schemaVersion":1}');
    final tag = 'miyorare-sources-v1.2.3';
    final lock = utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'kind': 'MIYORARE_SOURCE_PACK_RELEASE_LOCK',
        'immutable': true,
        'sealedBeforePublish': false,
        'tag': tag,
        'assets': [
          {
            'name': MiyorareAudioCatalogService.catalogAssetName,
            'size': catalog.length,
            'sha256': sha256.convert(catalog).toString(),
          },
        ],
      }),
    );
    final checksum = utf8.encode(
      sha256.convert(lock).toString() +
          '  ' +
          MiyorareAudioCatalogService.releaseLockAssetName +
          '\n',
    );

    expect(
      () => MiyorareAudioCatalogService.verifyReleaseLock(
        releaseTag: tag,
        catalogBytes: catalog,
        lockBytes: lock,
        lockChecksumBytes: checksum,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
