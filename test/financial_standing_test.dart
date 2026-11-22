import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/financial_standing_page.dart';
import 'package:gem/features/bid_docs/financial_standing_text.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  FinancialStandingInput makeInput() => FinancialStandingInput(
    tenderNo: 'GEM/2026/B/7845020',
    buyerDesignation: 'The Commandant',
    buyerOrg: 'Indian Army',
    company: 'Example Pvt Ltd',
    turnover2223: '1,00,00,000',
    turnover2324: '1,20,00,000',
    turnover2425: '1,50,00,000',
    netWorthYear: '2024',
    signatory: 'Ravi Kumar',
    designation: 'Director',
    date: DateTime(2026, 10, 10),
  );

  Future<AppStore> makeStore() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore(await SharedPreferences.getInstance());
  }

  void phone(WidgetTester t, double w) {
    t.view.physicalSize = Size(w, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  Future<void> open(WidgetTester tester, AppStore s, {String? tender}) async {
    phone(tester, 390);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: FinancialStandingPage(store: s, tenderNo: tender),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildFinancialStandingUndertaking', () {
    test('company name appears bold in first body paragraph', () {
      final blocks = buildFinancialStandingUndertaking(makeInput());
      final bodyBold = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .expand((b) => b.spans)
          .where((s) => s.bold)
          .map((s) => s.text)
          .toList();
      expect(bodyBold, contains('Example Pvt Ltd'));
    });

    test('company name bold in exactly one body block (opening para)', () {
      final blocks = buildFinancialStandingUndertaking(makeInput());
      final allBoldBodies = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .where(
            (b) => b.spans.any((s) => s.bold && s.text == 'Example Pvt Ltd'),
          )
          .toList();
      expect(allBoldBodies.length, 1);
      expect(allBoldBodies.first.plainText, contains('declare:'));
    });

    test('tenderNo present in subtitle block', () {
      final blocks = buildFinancialStandingUndertaking(makeInput());
      final subtitleBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(subtitleBlock.plainText, contains('GEM/2026/B/7845020'));
    });

    test('recipient title appears bold in recipient block', () {
      final blocks = buildFinancialStandingUndertaking(makeInput());
      final recipientBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text == 'The Commandant'),
      );
      expect(
        recipientBlock.spans.any((s) => s.bold && s.text == 'The Commandant'),
        isTrue,
      );
    });

    test('date uses abbreviated month format in subtitle', () {
      final blocks = buildFinancialStandingUndertaking(makeInput());
      final subtitleBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(subtitleBlock.plainText, contains('Oct'));
      expect(subtitleBlock.plainText, contains('2026'));
    });

    test('no "Dear Sir/Ma\'am" in new document format', () {
      final blocks = buildFinancialStandingUndertaking(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, isNot(contains('Dear Sir')));
    });

    test('boilerplate contains "Insolvency and Bankruptcy Code"', () {
      final blocks = buildFinancialStandingUndertaking(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('Insolvency and Bankruptcy Code'));
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — financial-standing entry', () {
    testWidgets('registry has financial-standing entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'financial-standing'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-financial-standing', (
      tester,
    ) async {
      phone(tester, 390);
      final s = await makeStore();
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: saathiTheme(),
          onGenerateRoute: (settings) {
            opened = settings.name;
            return MaterialPageRoute(builder: (_) => const SizedBox());
          },
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ToolsHub(store: s),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Financial Standing Undertaking'), findsOneWidget);
      await tester.ensureVisible(find.text('Financial Standing Undertaking'));
      await tester.tap(find.text('Financial Standing Undertaking'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-financial-standing');
    });
  });

  group('FinancialStandingPage', () {
    testWidgets('empty form validates — stays on Details', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('all 8 fields required — partial fill still blocks generate', (
      tester,
    ) async {
      final s = await makeStore();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      // Fill 7 of 10 — missing Designation
      await fill(tester, 'Buyer\'s designation', 'The Commandant');
      await fill(tester, 'Buyer\'s organisation', 'Indian Army');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Turnover FY 2022–23 (₹)', '1,00,00,000');
      await fill(tester, 'Turnover FY 2023–24 (₹)', '1,20,00,000');
      await fill(tester, 'Turnover FY 2024–25 (₹)', '1,50,00,000');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      // Designation empty
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('Your letter'), findsNothing);
      expect(find.text('This is required'), findsWidgets);
    });

    testWidgets('generate → preview → confirm → print/share unlocked', (
      tester,
    ) async {
      final s = await makeStore();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, 'Buyer\'s designation', 'The Commandant');
      await fill(tester, 'Buyer\'s organisation', 'Indian Army');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Turnover FY 2022–23 (₹)', '1,00,00,000');
      await fill(tester, 'Turnover FY 2023–24 (₹)', '1,20,00,000');
      await fill(tester, 'Turnover FY 2024–25 (₹)', '1,50,00,000');
      await fill(tester, 'Net worth year', '2024');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      expect(find.text('Your letter'), findsOneWidget);
      // Profile saved; tender number NOT saved
      expect(s.profile['companyName'], 'Example Pvt Ltd');
      expect(s.profile.containsKey('tenderNo'), isFalse);

      AppButton printBtn() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Print / Save as PDF'),
      );
      expect(printBtn().onPressed, isNull);

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(printBtn().onPressed, isNotNull);
    });

    testWidgets('editing a field after generate invalidates letter', (
      tester,
    ) async {
      final s = await makeStore();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, 'Buyer\'s designation', 'The Commandant');
      await fill(tester, 'Buyer\'s organisation', 'Indian Army');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Turnover FY 2022–23 (₹)', '1,00,00,000');
      await fill(tester, 'Turnover FY 2023–24 (₹)', '1,20,00,000');
      await fill(tester, 'Turnover FY 2024–25 (₹)', '1,50,00,000');
      await fill(tester, 'Net worth year', '2024');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await fill(tester, 'Company name', 'New Co Ltd');
      await tester.pumpAndSettle();
      expect(find.text('Generate letter'), findsOneWidget);
    });

    testWidgets('renders without overflow in all 9 languages', (tester) async {
      final s = await makeStore();
      for (final w in [320.0, 390.0]) {
        for (final lang in supportedLanguages) {
          s.setLanguage(lang[0]);
          phone(tester, w);
          await tester.pumpWidget(
            MaterialApp(
              theme: saathiTheme(),
              home: FinancialStandingPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
