import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/gem_check_page.dart';
import 'package:gem/features/onboarding_flow_1.dart';
import 'package:gem/features/onboarding_flow_2.dart';
import 'package:gem/features/onboarding_flow_3.dart';
import 'package:gem/features/onboarding_flow_4.dart';
import 'package:gem/features/scroll_hint.dart';

// Every onboarding screen shows the artwork from the design mockups
// (screen illustrations + per-option line icons), and the name / business
// name screens write what the user types onto their illustration.
void main() {
  ScrollMoreHint.debugDisableBounce = true;

  Future<AppStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore(await SharedPreferences.getInstance());
  }

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(theme: saathiTheme(), home: page));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  int artImages(WidgetTester tester) => tester
      .widgetList<Image>(find.byType(Image))
      .where((i) {
        final p = i.image;
        final name = p is AssetImage
            ? p.assetName
            : p is ExactAssetImage
            ? p.assetName
            : '';
        return name.startsWith('assets/illustrations/') ||
            name.startsWith('assets/icons/');
      })
      .length;

  testWidgets('every onboarding screen loads its mockup artwork', (tester) async {
    final s = await store();
    // screen -> minimum number of mockup images it must show
    final pages = <String, (Widget, int)>{
      'name': (FlowFullNamePage(store: s), 1),
      'phone': (FlowPhonePage(store: s), 1),
      'otp': (FlowOtpPage(store: s), 1),
      'location': (FlowLocationPage(store: s), 1),
      'bizname': (FlowBusinessNamePage(store: s), 1),
      'bizform': (FlowBusinessFormPage(store: s), 4),
      'sector': (FlowSectorPage(store: s), 6),
      'role': (FlowRolePage(store: s), 6),
      'authorised': (FlowAuthorisedPage(store: s), 4),
      'privacy': (FlowPrivacyPage(store: s), 1),
      'records': (FlowRecordsPage(store: s), 5),
      'pan': (FlowPanPage(store: s), 4),
      'checklist': (FlowChecklistPage(store: s), 5),
      'video': (FlowVideoPage(store: s), 4),
      'redirect': (FlowRedirectPage(store: s), 4),
      'gemcheck': (GemCheckPage(store: s), 3),
    };
    for (final e in pages.entries) {
      await show(tester, e.value.$1);
      expect(tester.takeException(), isNull, reason: e.key);
      expect(
        artImages(tester),
        greaterThanOrEqualTo(e.value.$2),
        reason: '${e.key} should show its mockup artwork',
      );
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('name and business name are written onto their illustration', (
    tester,
  ) async {
    final s = await store();
    await show(tester, FlowFullNamePage(store: s));
    await tester.enterText(find.byType(TextField), 'Vijay Kumar');
    await tester.pumpAndSettle();
    // once in the field, once handwritten on the card
    expect(find.text('Vijay Kumar'), findsNWidgets(2));

    await show(tester, FlowBusinessNamePage(store: s));
    await tester.enterText(find.byType(TextField), 'Asha Textiles');
    await tester.pumpAndSettle();
    expect(find.text('Asha Textiles'), findsNWidgets(2));
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
