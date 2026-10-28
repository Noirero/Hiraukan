import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kikoeru_flutter/src/models/work.dart';
import 'package:kikoeru_flutter/src/services/local_work_mark_service.dart';
import 'package:kikoeru_flutter/src/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = LocalWorkMarkService.instance;
  late Directory tempDirectory;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDirectory = await Directory.systemTemp.createTemp('hiraukan_marks_test_');
    Hive.init(tempDirectory.path);
    await StorageService.init();
  });

  setUp(() async {
    await service.save(const []);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('canonical source id is stable across provider mirrors', () {
    const first = Work(
      id: -10,
      title: 'First',
      sourceId: 'rj012345',
      sourceUrl: 'https://source-a.example/work/1',
    );
    const second = Work(
      id: 12345,
      title: 'Second',
      sourceId: 'RJ012345',
      sourceUrl: 'https://source-b.example/work/2',
    );

    expect(service.identityFor(first), service.identityFor(second));
    expect(service.identityFor(first), 'source:RJ012345');
  });

  test('favorite and personal rating share one local mark', () async {
    const work = Work(
      id: -42,
      title: 'External work',
      sourceUrl: 'https://example.invalid/work/42?token=secret',
    );

    var marks = await service.setFavorite(const [], work, true);
    marks = await service.setRating(marks, work, 4);

    expect(marks, hasLength(1));
    expect(marks.single.isFavorite, isTrue);
    expect(marks.single.rating, 4);
    expect(marks.single.key, 'id:-42');
    expect(marks.single.key, isNot(contains('token')));

    final restored = await service.load();
    expect(restored, hasLength(1));
    expect(restored.single.work.title, 'External work');
    expect(restored.single.rating, 4);
  });

  test('clearing the final local state removes the mark', () async {
    const work = Work(id: 77, title: 'Work');

    var marks = await service.setFavorite(const [], work, true);
    marks = await service.setRating(marks, work, 5);
    marks = await service.setFavorite(marks, work, false);

    expect(marks.single.isFavorite, isFalse);
    expect(marks.single.rating, 5);

    marks = await service.setRating(marks, work, null);
    expect(marks, isEmpty);
    expect(await service.load(), isEmpty);
  });

  test('rejects ratings outside 1 to 5', () async {
    const work = Work(id: 1, title: 'Work');

    await expectLater(
      service.setRating(const [], work, 0),
      throwsArgumentError,
    );
    await expectLater(
      service.setRating(const [], work, 6),
      throwsArgumentError,
    );
  });
}
