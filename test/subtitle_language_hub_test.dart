import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kikoeru_flutter/src/screens/subtitle_language_hub_screen.dart';
import 'package:kikoeru_flutter/src/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    hiveDirectory = await Directory.systemTemp.createTemp(
      'hiraukan_subtitle_language_hub_test_',
    );
    Hive.init(hiveDirectory.path);
    await StorageService.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  testWidgets('subtitle hub groups normal workflow before local AI',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('en'),
          home: SubtitleLanguageHubScreen(),
        ),
      ),
    );

    expect(find.text('Subtitles & Language'), findsOneWidget);
    expect(find.text('Subtitle Library'), findsOneWidget);
    expect(find.text('Player Subtitle Style'), findsOneWidget);
    expect(find.text('Online Language & Translation'), findsOneWidget);
    expect(find.text('Translation Glossary'), findsOneWidget);
    expect(find.text('LLM Provider'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Local Transcription (Whisper)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Local Transcription (Whisper)'), findsOneWidget);
    expect(
      find.textContaining('ASR benchmarks and technical experiments'),
      findsOneWidget,
    );
  });

  testWidgets('subtitle hub exposes Indonesian product copy', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('id'),
          home: SubtitleLanguageHubScreen(),
        ),
      ),
    );

    expect(find.text('Subtitle & Bahasa'), findsOneWidget);
    expect(find.text('Perpustakaan Subtitle'), findsOneWidget);
    expect(find.text('Bahasa & Terjemahan Online'), findsOneWidget);
  });
}
