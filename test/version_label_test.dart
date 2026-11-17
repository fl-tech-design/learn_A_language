import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_a_language/widgets/version_label.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets('VersionLabel zeigt Version, aber keine Build-Nummer',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'learn_a_language',
      packageName: 'learn_a_language',
      version: '1.4.1',
      buildNumber: '8',
      buildSignature: '',
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VersionLabel())),
    );
    await tester.pumpAndSettle();

    expect(find.text('v1.4.1'), findsOneWidget);
    expect(find.textContaining('+8'), findsNothing);
  });
}
