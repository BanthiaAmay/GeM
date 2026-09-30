import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/main.dart';

// The "GeM bidding" mini-section (turnover, turnover history, past-order
// experience, and — only on the "Yes" branch — the optional order-detail
// screen) sits between "Your business" and "Get ready". This test walks
// both the "No" and "Yes" branches all the way to the next section and
// checks what gets saved.
void main() {
  ScrollMoreHint.debugDisableBounce = true;

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<AppStore> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(SaathiApp(store: s, ready: s.initialize()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tap(tester, find.text('Get started'));
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Continue'));
    return s;
  }

  Future<void> reachTurnover(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'Vijay Kumar');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Continue'));
    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Send demo code'));
    await tap(tester, find.text('Use demo code'));
    await tap(tester, find.text('Choose state'));
    await tap(tester, find.text('Andhra Pradesh').last);
    await tester.enterText(find.byType(TextField).last, 'Pune');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Continue'));
    await tester.enterText(find.byType(TextField).first, 'Asha Textiles');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Proprietorship'));
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Manufacturing'));
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Owner / Proprietor'));
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Yes'));
    await tap(tester, find.text('Continue'));
    expect(
      find.text('What’s your business’s annual turnover (latest FY)?'),
      findsOneWidget,
    );
  }

  testWidgets('the "No" experience branch skips straight to privacy', (
    tester,
  ) async {
    final s = await boot(tester);
    await reachTurnover(tester);

    await tap(tester, find.text('Under ₹10 lakh'));
    await tap(tester, find.text('Continue'));

    expect(
      find.text('And the two years before that, roughly?'),
      findsOneWidget,
    );
    await tap(tester, find.text('Same as latest FY').at(0));
    await tap(tester, find.text('Same as latest FY').at(1));
    await tap(tester, find.text('Continue'));

    expect(
      find.text('Have you supplied similar orders before?'),
      findsOneWidget,
    );
    await tap(tester, find.text('No'));
    await tap(tester, find.text('Continue'));

    // Straight to the very next existing screen — no detour, no fake
    // destination, and no lingering "Skip" affordance anywhere.
    expect(find.text('Your information stays yours'), findsOneWidget);
    expect(s.profile['turnoverLatest'], 'under10L');
    expect(s.profile['pastOrderExperience'], 'no');
    expect(s.profile['pastOrderCount'], isNull);
    expect(find.text('Skip'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the "Yes" experience branch reaches the optional detail screen and saves it',
    (tester) async {
      final s = await boot(tester);
      await reachTurnover(tester);

      await tap(tester, find.text('₹1.5 crore–₹5 crore'));
      await tap(tester, find.text('Continue'));

      // Leave both prior years on their own explicit bands (not "same"),
      // to prove the picker path saves independently of the toggle path.
      // Each picker is its own bottom sheet, opened via its "Choose a
      // range" hint, so it must be opened before its option is tappable.
      await tap(tester, find.text('Choose a range').at(0));
      await tap(tester, find.text('Under ₹10 lakh'));
      await tap(tester, find.text('Choose a range').at(0));
      await tap(tester, find.text('₹40 lakh–₹1.5 crore'));
      await tap(tester, find.text('Continue'));

      await tap(tester, find.text('Yes'));
      await tap(tester, find.text('Continue'));

      // The optional detail screen — reachable only from "Yes".
      expect(
        find.text('Roughly how many, and what total value?'),
        findsOneWidget,
      );
      expect(find.text('Skip'), findsNothing);

      // Its own primary action must work with nothing entered at all —
      // both fields are optional and there is no separate Skip control.
      await tap(tester, find.text('Save and finish'));
      expect(find.text('Your information stays yours'), findsOneWidget);
      expect(s.profile['pastOrderExperience'], 'yes');
      expect(s.profile['pastOrderCount'], isNull);
      expect(s.profile['pastOrderValueRange'], isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the optional detail screen saves what is actually entered', (
    tester,
  ) async {
    await boot(tester);
    await reachTurnover(tester);
    await tap(tester, find.text('Under ₹10 lakh'));
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Same as latest FY').at(0));
    await tap(tester, find.text('Same as latest FY').at(1));
    await tap(tester, find.text('Continue'));
    await tap(tester, find.text('Yes'));
    await tap(tester, find.text('Continue'));

    await tester.enterText(find.byType(TextField).first, '5');
    await tester.pumpAndSettle();
    await tap(tester, find.text('Choose a range'));
    await tap(tester, find.text('₹10 lakh–₹40 lakh').last);
    await tap(tester, find.text('Save and finish'));

    expect(find.text('Your information stays yours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
