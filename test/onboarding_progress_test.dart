import 'support/authenticated_journey_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/main.dart';

// The onboarding header's "<Section> · <step> OF <total>" line is derived
// live from the current route (see _kOnboardingSteps / _stepInfoFor in
// onboarding_widgets.dart) — never a hardcoded string. This test walks the
// full 15-step "not yet on GeM" flow and checks that exact text at every
// step, including a backward pop across a section boundary and a
// mid-flow language switch.
void main() {
  ScrollMoreHint.debugDisableBounce = true;

  testWidgets(
    'progress heading tracks the real step/section/total, forward, back and localized',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final s = AuthenticatedJourneyStore(
        await SharedPreferences.getInstance(),
      );
      await tester.pumpWidget(SaathiApp(store: s, ready: s.initialize()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      // Default selection on the GeM check is "No" — the full 15-step flow.
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      Future<void> continueTap() async {
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }

      // One label line names both the section and the step.
      void expectHeading(String section, String stepOfTotal) {
        expect(stepOfTotal.startsWith(section.toUpperCase()), isTrue);
        expect(find.text(stepOfTotal), findsOneWidget);
      }

      // 1. Full name — Getting started, 1 of 4.
      expect(find.text('What is your full name?'), findsOneWidget);
      expectHeading('Getting started', 'GETTING STARTED · 1 OF 3');
      await tester.enterText(find.byType(TextField).first, 'Vijay Kumar');
      await tester.pumpAndSettle();
      await continueTap();

      // 2. Mobile number — Getting started, 2 of 4.
      expectHeading('Getting started', 'GETTING STARTED · 2 OF 3');
      await tester.enterText(find.byType(TextField).first, '9876543210');
      await tester.pumpAndSettle();
      await continueTap();

      // 4. Location — Getting started, 4 of 4.
      expect(find.text('Where is your business based?'), findsOneWidget);
      expectHeading('Getting started', 'GETTING STARTED · 3 OF 3');
      await tester.tap(find.text('Choose state'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Andhra Pradesh').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Pune');
      await tester.pumpAndSettle();
      await continueTap();

      // 5. Business name — Your business, 1 of 6 (Getting started complete
      // checkpoint fires and settles in between; pumpAndSettle waits it out).
      expect(find.text('What is your business called?'), findsOneWidget);
      expectHeading('Your business', 'YOUR BUSINESS · 1 OF 6');

      // Back across the section boundary: must revert to step 4/4 of
      // "Getting started", not stay stuck on "Your business".
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Where is your business based?'), findsOneWidget);
      expectHeading('Getting started', 'GETTING STARTED · 3 OF 3');

      // Forward again — this route was never disposed (maintainState),
      // so the state/district picked earlier are still filled in.
      await continueTap();
      expectHeading('Your business', 'YOUR BUSINESS · 1 OF 6');
      await tester.enterText(find.byType(TextField).first, 'Asha Textiles');
      await tester.pumpAndSettle();
      await continueTap();

      // 6. Business form — Your business, 2 of 6.
      expectHeading('Your business', 'YOUR BUSINESS · 2 OF 6');
      await tester.tap(find.text('Proprietorship'));
      await tester.pumpAndSettle();
      await continueTap();

      // 7. Sector — 3 of 6.
      expectHeading('Your business', 'YOUR BUSINESS · 3 OF 6');
      await tester.tap(find.text('Manufacturing'));
      await tester.pumpAndSettle();
      await continueTap();

      // 7a. What it supplies — 4 of 6. "Asha Textiles" pre-ticks textiles;
      // ticking Furniture adds all its words, one per group in turn.
      expect(find.text('What does your business supply?'), findsOneWidget);
      expectHeading('Your business', 'YOUR BUSINESS · 4 OF 6');
      await tester.ensureVisible(find.text('Furniture'));
      await tester.tap(find.text('Furniture'));
      await tester.pumpAndSettle();
      await continueTap();
      expect(s.bidKeywords, [
        'Furniture',
        'Uniform',
        'Office chair',
        'Bedsheet',
        'Table',
        'Towel',
        'Steel almirah',
      ]);

      // 8. Role — 5 of 6.
      expectHeading('Your business', 'YOUR BUSINESS · 5 OF 6');
      await tester.tap(find.text('Owner / Proprietor'));
      await tester.pumpAndSettle();
      await continueTap();

      // 9. Authorised person — 6 of 6 (last of the section).
      expectHeading('Your business', 'YOUR BUSINESS · 6 OF 6');
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      await continueTap();

      // 9a. Turnover — GeM bidding, 1 of 4 (new section after the checkpoint).
      expect(
        find.text('What’s your business’s annual turnover (latest FY)?'),
        findsOneWidget,
      );
      expectHeading('GeM bidding', 'GEM BIDDING · 1 OF 4');
      await tester.ensureVisible(find.text('₹10 lakh–₹40 lakh'));
      await tester.tap(find.text('₹10 lakh–₹40 lakh'));
      await tester.pumpAndSettle();
      await continueTap();

      // 9b. Turnover history — 2 of 4.
      expectHeading('GeM bidding', 'GEM BIDDING · 2 OF 4');
      await tester.ensureVisible(find.text('Same as latest FY').at(0));
      await tester.tap(find.text('Same as latest FY').at(0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Same as latest FY').at(1));
      await tester.tap(find.text('Same as latest FY').at(1));
      await tester.pumpAndSettle();
      await continueTap();

      // 9c. Experience ("No" branch) — 3 of 4; the "Yes" branch (which
      // reaches the real 4th screen) is covered by its own test.
      expectHeading('GeM bidding', 'GEM BIDDING · 3 OF 4');
      await tester.ensureVisible(find.text('No'));
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      await continueTap();

      // 10. Privacy — Get ready, 1 of 4 (new section after the checkpoint).
      expect(find.text('Your information stays yours'), findsOneWidget);
      expectHeading('Get ready', 'GET READY · 1 OF 4');
      await tester.ensureVisible(
        find.text('I understand this is a preparation guide.'),
      );
      await tester.tap(find.text('I understand this is a preparation guide.'));
      await tester.pumpAndSettle();
      await continueTap();

      // 11. Business documentation — 2 of 4.
      expectHeading('Get ready', 'GET READY · 2 OF 4');
      await tester.ensureVisible(find.text('Business PAN details'));
      await tester.tap(find.text('Business PAN details'));
      await tester.pumpAndSettle();
      await continueTap();

      // 12. PAN readiness — 3 of 4.
      expectHeading('Get ready', 'GET READY · 3 OF 4');
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      await continueTap();

      // 13. Readiness checklist — 4 of 4 (last of the section).
      expectHeading('Get ready', 'GET READY · 4 OF 4');
      await continueTap();

      // 14. Video guide — Next step, 1 of 2.
      expect(find.text('How to register your business on GeM'), findsOneWidget);
      expectHeading('Next step', 'NEXT STEP · 1 OF 2');
      await tester.ensureVisible(find.text('Continue without video'));
      await tester.tap(find.text('Continue without video'));
      await tester.pumpAndSettle();

      // 15. Redirect — Next step, 2 of 2 (final step).
      expect(find.text('You’re ready to register on GeM'), findsOneWidget);
      expectHeading('Next step', 'NEXT STEP · 2 OF 2');

      // Localization: the same route, in Hindi, without navigating.
      s.setLanguage('hi');
      await tester.pumpAndSettle();
      expect(find.text('अगला कदम · 2 में से 2'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
