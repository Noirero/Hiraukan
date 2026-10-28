import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kikoeru_flutter/src/widgets/work_detail/work_download_actions_button.dart';

void main() {
  testWidgets('groups offline and selective download actions in one menu',
      (tester) async {
    var offlineCalls = 0;
    var chooseCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              WorkDownloadActionsButton(
                isBusy: false,
                onMakeAvailableOffline: () => offlineCalls++,
                onChooseFiles: () => chooseCalls++,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('Download & offline'), findsOneWidget);
    expect(find.byIcon(Icons.download_for_offline_outlined), findsNothing);

    await tester.tap(find.byTooltip('Download & offline'));
    await tester.pumpAndSettle();

    expect(find.text('Make available offline'), findsOneWidget);
    expect(find.text('Choose files to download'), findsOneWidget);

    await tester.tap(find.text('Make available offline'));
    await tester.pumpAndSettle();
    expect(offlineCalls, 1);
    expect(chooseCalls, 0);

    await tester.tap(find.byTooltip('Download & offline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose files to download'));
    await tester.pumpAndSettle();

    expect(offlineCalls, 1);
    expect(chooseCalls, 1);
  });

  testWidgets('busy state disables the grouped download menu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              WorkDownloadActionsButton(
                isBusy: true,
                onMakeAvailableOffline: () {},
                onChooseFiles: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final menu = tester.widget<PopupMenuButton<WorkDownloadAction>>(
      find.byType(PopupMenuButton<WorkDownloadAction>),
    );
    expect(menu.enabled, isFalse);
  });
}
