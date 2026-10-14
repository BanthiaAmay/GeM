// Minimal reproduction: no intermediate pumps (exactly matches failing test's fill())
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/mii_certificate_page.dart';
import 'package:gem/features/scroll_hint.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  testWidgets('no intermediate pumps (matches original test)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(MaterialApp(
      theme: saathiTheme(),
      home: MiiCertificatePage(store: s, tenderNo: 'GEM/2026/B/7845020'),
    ));
    await tester.pumpAndSettle();

    await fill(tester, 'Local content (%)', '100');
    await fill(tester, 'Company name', 'Z');
    await fill(tester, 'Where the local value addition is done', 'India');
    await fill(tester, 'Signatory name', 'Z');
    await fill(tester, 'Designation', 'Owner');
    await tester.tap(find.text('Generate certificate'));
    await tester.pumpAndSettle();

    expect(find.text('Your letter'), findsOneWidget);
  });
}
