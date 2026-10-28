import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/services/portable_backup_service.dart';

void main() {
  group('PortableBackupService.inspect', () {
    test('reports portable metadata counts', () {
      final raw = jsonEncode({
        'kind': PortableBackupService.kind,
        'schemaVersion': PortableBackupService.schemaVersion,
        'history': [
          {'work_id': 1},
          {'work_id': 2},
        ],
        'localCollections': [
          {'id': 'a'},
        ],
        'listeningMoments': [
          {'id': 'm1'},
          {'id': 'm2'},
          {'id': 'm3'},
        ],
      });

      final summary = PortableBackupService.instance.inspect(raw);
      expect(summary.historyCount, 2);
      expect(summary.collectionCount, 1);
      expect(summary.momentCount, 3);
    });

    test('rejects non-Hiraukan JSON', () {
      expect(
        () => PortableBackupService.instance.inspect(
          jsonEncode({'kind': 'other', 'schemaVersion': 1}),
        ),
        throwsFormatException,
      );
    });

    test('rejects unsupported schema versions', () {
      expect(
        () => PortableBackupService.instance.inspect(
          jsonEncode({
            'kind': PortableBackupService.kind,
            'schemaVersion': PortableBackupService.schemaVersion + 1,
          }),
        ),
        throwsFormatException,
      );
    });
  });
}
