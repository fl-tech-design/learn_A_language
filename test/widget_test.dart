import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/l10n/app_localizations.dart';
import 'package:learn_a_language/theme/app_theme.dart';
import 'package:learn_a_language/widgets/app_widgets.dart';
import 'package:learn_a_language/widgets/version_label.dart';

Widget _testBottom(BoxBottom bottom) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(children: [const Spacer(), bottom]),
      ),
    );

void main() {
  testWidgets('BoxBottom zeigt Settings- und Exit-Icon im Ticket-#63-Layout',
      (tester) async {
    await tester.pumpWidget(_testBottom(BoxBottom(
      onSettings: () {},
      onExit: () {},
    )));

    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.power_settings_new), findsOneWidget);
  });

  testWidgets('BoxBottom zeigt die App-Version in der Mitte', (tester) async {
    await tester.pumpWidget(_testBottom(BoxBottom(
      onSettings: () {},
      onExit: () {},
    )));

    await tester.pumpAndSettle();
    expect(find.byType(VersionLabel), findsOneWidget);
  });

  testWidgets('BoxBottom behält auch im Querformat die Mindesthöhe',
      (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testBottom(BoxBottom(
      onSettings: () {},
      onExit: () {},
    )));

    expect(tester.getSize(find.byType(BoxBottom)).height,
        greaterThanOrEqualTo(AppTheme.bottomBarMinHeight));
  });
}
