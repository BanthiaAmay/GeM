import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/main.dart';
import 'package:gem/data/app_store.dart';

void main() {
  Future<AppStore> setup(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(SaathiApp(store: s));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return s;
  }

  tearDown(() {});
  testWidgets('mobile home and Hindi have no overflow', (tester) async {
    await setup(tester, const Size(390, 844));
    expect(
      find.text('Your business.\nA new buyer: the\ngovernment.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('हिंदी'));
    await tester.pumpAndSettle();
    expect(find.text('आपका व्यवसाय।\nनया खरीदार:\nसरकार।'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('desktop tool navigation and validation work', (tester) async {
    await setup(tester, const Size(1440, 1000));
    await tester.tap(find.text('Can I sell on GeM?'));
    await tester.pumpAndSettle();
    expect(find.text('Can your business sell on GeM?'), findsOneWidget);
    final submit = find.text('Check my eligibility');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid non-negative number'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets(
    'every destination renders on a narrow screen in both languages',
    (tester) async {
      final s = await setup(tester, const Size(360, 800));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      for (final hi in [false, true]) {
        if (s.hi != hi) s.changeLanguage();
        for (final page in [
          'learn',
          'tools',
          'eligibility',
          'revenue',
          'pricing',
          'roi',
          'tracker',
          'report',
          'register',
          'account',
          'support',
          'about',
        ]) {
          nav.pushNamed('/$page');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$page hi=$hi');
          nav.pop();
          await tester.pumpAndSettle();
        }
      }
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'complete calculator journey updates report and tracker immediately',
    (tester) async {
      final s = await setup(tester, const Size(390, 844));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.pushNamed('/eligibility');
      await tester.pumpAndSettle();
      final numeric = find.byType(TextFormField);
      await tester.enterText(numeric.at(0), '100');
      await tester.enterText(numeric.at(1), '10');
      final check = find.text('Check my eligibility');
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(s.completed, contains('eligibility'));
      expect(find.text('Partial — a few details to resolve'), findsOneWidget);
      expect(tester.takeException(), isNull);
      nav.pop();
      await tester.pumpAndSettle();
      for (final page in ['revenue', 'pricing', 'roi']) {
        nav.pushNamed('/$page');
        await tester.pumpAndSettle();
        final calc = find.text('Calculate my result');
        await tester.ensureVisible(calc);
        await tester.tap(calc);
        await tester.pumpAndSettle();
        expect(s.completed, contains(page));
        expect(tester.takeException(), isNull, reason: '$page result');
        nav.pop();
        await tester.pumpAndSettle();
      }
      nav.pushNamed('/report');
      await tester.pumpAndSettle();
      expect(find.text('Copy report'), findsOneWidget);
      expect(tester.takeException(), isNull);
      nav.pop();
      await tester.pumpAndSettle();
      nav.pushNamed('/tracker');
      await tester.pumpAndSettle();
      expect(find.text('0 of 9 steps resolved'), findsOneWidget);
      final first = find.byType(Checkbox).first;
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.text('1 of 9 steps resolved'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
