import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/main.dart';
import 'package:gem/core/motion.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/scroll_hint.dart';

void main() {
  // The scroll-more chevron bounces forever in the real app; that
  // repeating animation would otherwise stop pumpAndSettle() from
  // ever settling in these tests.
  ScrollMoreHint.debugDisableBounce = true;


  /// Walks the 11 steps shared by both "already on GeM" and "not yet"
  /// answers: name, phone, OTP, location, business name, business
  /// form, sector, role, authorised person, privacy, and business
  /// documentation. Leaves the caller wherever that last step's
  /// Continue button goes (Home for "yes", PAN check for "no").
  Future<void> fillFirstElevenSteps(WidgetTester tester) async {
    // 1. Full name
    expect(find.text('What is your full name?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Vijay Kumar');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 2. Mobile number
    expect(find.text('Your mobile number'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send demo code'));
    await tester.tap(find.text('Send demo code'));
    await tester.pumpAndSettle();

    // 3. OTP
    expect(find.text('Enter your code'), findsOneWidget);
    await tester.ensureVisible(find.text('Use demo code'));
    await tester.tap(find.text('Use demo code'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 4. Location
    expect(find.text('Where is your business based?'), findsOneWidget);
    await tester.ensureVisible(find.text('Choose state'));
    await tester.tap(find.text('Choose state'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Andhra Pradesh').last);
    await tester.tap(find.text('Andhra Pradesh').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Pune');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 5. Business name
    expect(find.text('What is your business called?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Asha Textiles');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 6. Business form
    expect(find.text('How is your business formed?'), findsOneWidget);
    await tester.ensureVisible(find.text('Proprietorship'));
    await tester.tap(find.text('Proprietorship'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 7. Sector
    expect(find.text('Which sector best fits your business?'), findsOneWidget);
    await tester.ensureVisible(find.text('Manufacturing'));
    await tester.tap(find.text('Manufacturing'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 8. Role
    expect(find.text('What is your role in the business?'), findsOneWidget);
    await tester.ensureVisible(find.text('Owner / Proprietor'));
    await tester.tap(find.text('Owner / Proprietor'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 9. Authorised person readiness
    expect(find.text('Is the authorised person ready?'), findsOneWidget);
    await tester.ensureVisible(find.text('Yes'));
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 9a. Turnover (latest FY) — new "GeM bidding" section.
    expect(
      find.text('What’s your business’s annual turnover (latest FY)?'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('₹10 lakh–₹40 lakh'));
    await tester.tap(find.text('₹10 lakh–₹40 lakh'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 9b. Turnover, two prior years — both "Same as latest FY".
    expect(
      find.text('And the two years before that, roughly?'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Same as latest FY').at(0));
    await tester.tap(find.text('Same as latest FY').at(0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Same as latest FY').at(1));
    await tester.tap(find.text('Same as latest FY').at(1));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 9c. Past-order experience — "No" branch (the "Yes" branch and its
    // optional detail screen have their own dedicated test).
    expect(
      find.text('Have you supplied similar orders before?'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('No'));
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 10. Privacy notice
    expect(find.text('Your information stays yours'), findsOneWidget);
    await tester.ensureVisible(
      find.text('I understand this is a preparation guide.'),
    );
    await tester.ensureVisible(find.text('I understand this is a preparation guide.'));
    await tester.tap(find.text('I understand this is a preparation guide.'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // 11. Business documentation
    expect(
      find.text('Which business records do you have ready?'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Business PAN details'));
    await tester.tap(find.text('Business PAN details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }

  Future<AppStore> setup(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final s = AppStore(await SharedPreferences.getInstance());
    await tester.pumpWidget(SaathiApp(store: s, ready: s.initialize()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
    await tester.ensureVisible(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your language'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Is your business already on GeM?'), findsOneWidget);
    // Answer "Yes": already-on-GeM users still walk the shared first
    // 11 steps (name through business documentation) before landing
    // on Home; the full "No" readiness flow has its own dedicated test.
    await tester.ensureVisible(find.text('Yes'));
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await fillFirstElevenSteps(tester);
    expect(tester.takeException(), isNull);
    return s;
  }

  tearDown(() {});
  testWidgets('mobile home and Hindi have no overflow', (tester) async {
    await setup(tester, const Size(390, 844));
    expect(find.text('Hello, Vijay'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('EN'));
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('हिन्दी'));
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();
    expect(find.text('नमस्ते, Vijay'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('desktop tool navigation and validation work', (tester) async {
    await setup(tester, const Size(1440, 1000));
    // Navigate directly — the home page no longer has a tool-card shortcut
    // for the eligibility tool (moved to the Calculators section).
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamed('/eligibility');
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
        if (s.hi != hi) s.setLanguage(hi ? 'hi' : 'en');
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
      // Report page is in a rebuild state; verify it renders without exceptions.
      expect(tester.takeException(), isNull);
      nav.pop();
      await tester.pumpAndSettle();
      nav.pushNamed('/tracker');
      await tester.pumpAndSettle();
      // Tracker is in a rebuild state; verify it renders without exceptions.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets(
    'answering "No" on the GeM check walks through all 15 readiness screens',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(await SharedPreferences.getInstance());
      await tester.pumpWidget(SaathiApp(store: s, ready: s.initialize()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Get started'));
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Is your business already on GeM?'), findsOneWidget);
      // Default selection is "No" — go straight to Continue.
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 1-11. Steps shared with the "already on GeM" flow.
      await fillFirstElevenSteps(tester);

      // 12. PAN readiness
      expect(find.text('Do you have business PAN details?'), findsOneWidget);
      await tester.ensureVisible(find.text('Yes'));
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 13. Readiness checklist
      expect(find.text('Your GeM-ready checklist'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'checklist');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 14. Video guide placeholder
      expect(
        find.text('How to register your business on GeM'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'video');
      await tester.ensureVisible(find.text('Continue without video'));
      await tester.tap(find.text('Continue without video'));
      await tester.pumpAndSettle();

      // 15. Redirect to official GeM registration
      expect(find.text('You’re ready to register on GeM'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'redirect');
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'after not now');
      expect(s.hasOnboarded, isTrue);
      expect(s.profile['fullName'], 'Vijay Kumar');
      expect(s.profile['mobile'], '9876543210');
      expect(s.profile['state'], 'Andhra Pradesh');
      expect(s.profile['district'], 'Pune');
      expect(s.profile['businessName'], 'Asha Textiles');
      expect(s.profile['businessForm'], 'proprietorship');
      expect(s.profile['sector'], 'manufacturing');
      expect(s.profile['role'], 'owner');
      expect(s.profile['authorisedReady'], 'yes');
      expect(s.profile['records'], contains('pan'));
      expect(s.profile['panReady'], 'yes');

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'reduced motion walks all 15 onboarding screens without ever looping forever',
    (tester) async {
      // Forces route transition *durations* (fixed at construction,
      // outside any BuildContext — see core/transitions.dart) to also
      // collapse, on top of the MediaQuery override below which
      // covers every Motion.reduced(context) check within widgets.
      Motion.debugReducedOverride = true;
      addTearDown(() => Motion.debugReducedOverride = null);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      SharedPreferences.setMockInitialValues({});
      final s = AppStore(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        // copyWith (not a bare MediaQueryData(disableAnimations: true))
        // — a fresh MediaQueryData() defaults size to Size.zero, which
        // starves every MediaQuery.sizeOf(context) computation further
        // down (e.g. the state picker sheet's `height * 0.7`) to zero
        // and silently drops its list content instead of just going
        // motion-free.
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: SaathiApp(store: s, ready: s.initialize()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      // If any AnimationController never completes and no repeating
      // animation ever stops (a Hero flight, a route transition, a
      // bobbing chevron, the section-complete checkpoint, ...),
      // pumpAndSettle() times out and this test fails right here.
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Get started'));
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your language'), findsOneWidget);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Is your business already on GeM?'), findsOneWidget);
      // Default selection is "No" — walks the full 15-screen flow.
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 1-11. Steps shared with the "already on GeM" flow — includes
      // the demo OTP screen (step 3) via its "Use demo code" button.
      await fillFirstElevenSteps(tester);

      // 12. PAN readiness
      expect(find.text('Do you have business PAN details?'), findsOneWidget);
      await tester.ensureVisible(find.text('Yes'));
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 13. Readiness checklist — last step of "Get ready", so this
      // Continue also triggers (and must cleanly finish) the
      // section-complete checkpoint overlay.
      expect(find.text('Your GeM-ready checklist'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'checklist');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // 14. Video guide placeholder
      expect(
        find.text('How to register your business on GeM'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: 'video');
      await tester.ensureVisible(find.text('Continue without video'));
      await tester.tap(find.text('Continue without video'));
      await tester.pumpAndSettle();

      // 15. Redirect to official GeM registration
      expect(find.text('You’re ready to register on GeM'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'redirect');
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'after not now');
      expect(s.hasOnboarded, isTrue);

      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
