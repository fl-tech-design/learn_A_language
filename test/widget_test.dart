import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learn_a_language/theme/app_theme.dart';
import 'package:learn_a_language/widgets/app_widgets.dart';

void main() {
  testWidgets('BoxBottom zeigt Settings- und Beenden-Beschriftung', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const Spacer(),
          BoxBottom(
            settingsText: 'Einstellungen',
            exitText: 'Beenden',
            onSettings: () {},
            onExit: () {},
          ),
        ]),
      ),
    ));

    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Beenden'), findsOneWidget);
  });

  testWidgets('BoxBottom behält auch im Querformat die Mindesthöhe', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          const Spacer(),
          BoxBottom(
            settingsText: 'Einstellungen',
            exitText: 'Beenden',
            onSettings: () {},
            onExit: () {},
          ),
        ]),
      ),
    ));

    final size = tester.getSize(find.byType(BoxBottom));
    expect(size.height, greaterThanOrEqualTo(AppTheme.bottomBarMinHeight));
  });
}

