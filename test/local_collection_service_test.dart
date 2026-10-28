import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/models/local_collection.dart';
import 'package:kikoeru_flutter/src/models/work.dart';
import 'package:kikoeru_flutter/src/services/local_collection_service.dart';

void main() {
  final service = LocalCollectionService.instance;
  final createdAt = DateTime.utc(2026, 1, 1);

  LocalCollection collectionWith(Work work) => LocalCollection(
        id: 'collection-1',
        name: 'Test',
        createdAt: createdAt,
        updatedAt: createdAt,
        works: <Work>[work],
      );

  test('canonical sourceId is the primary collection identity', () {
    const stored = Work(
      id: -1,
      title: 'Stored',
      sourceId: 'rj012345',
      sourceUrl: 'https://source.example/work/a',
    );
    const candidate = Work(
      id: 999,
      title: 'Candidate',
      sourceId: 'RJ012345',
      sourceUrl: 'https://other.example/work/b',
    );

    expect(service.contains(collectionWith(stored), candidate), isTrue);
  });

  test('sourceUrl is used when canonical sourceId is unavailable', () {
    const stored = Work(
      id: -10,
      title: 'Stored',
      sourceUrl: 'https://source.example/work/42',
    );
    const candidate = Work(
      id: 42,
      title: 'Candidate',
      sourceUrl: 'https://source.example/work/42',
    );

    expect(service.contains(collectionWith(stored), candidate), isTrue);
  });

  test('numeric work id is the final identity fallback', () {
    const stored = Work(id: 77, title: 'Stored');
    const candidate = Work(id: 77, title: 'Candidate');
    const other = Work(id: 78, title: 'Other');

    expect(service.contains(collectionWith(stored), candidate), isTrue);
    expect(service.contains(collectionWith(stored), other), isFalse);
  });
}
