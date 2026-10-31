import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/bid_security_page.dart';
import 'package:gem/features/bid_docs/bid_security_text.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  BidSecurityInput makeInput() => BidSecurityInput(
    recipientTitle: 'The Commandant',
    organization: 'Indian Army',
    organizationAddress: 'New Delhi, 110001',
    tenderNo: 'GEM/2026/B/7845020',
    company: 'Example Pvt Ltd',
    companyAddress: '123 MG Road, Mumbai',
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
        home: BidSecurityPage(store: s, tenderNo: tender),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildBidSecurityDeclaration', () {
    test('recipient title appears bold in recipient block', () {
      final blocks = buildBidSecurityDeclaration(makeInput());
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

    test('"Subject:" span is bold', () {
      final blocks = buildBidSecurityDeclaration(makeInput());
      final subjectBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text.startsWith('Subject:')),
      );
      expect(
        subjectBlock.spans.any((s) => s.bold && s.text.startsWith('Subject:')),
        isTrue,
      );
    });

    test('tender no. appears verbatim in subject line', () {
      final blocks = buildBidSecurityDeclaration(makeInput());
      final subjectBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text.startsWith('Subject:')),
      );
      expect(subjectBlock.plainText, contains('GEM/2026/B/7845020'));
    });

    test('company name is bold in closing "Duly authorized…" line', () {
      final blocks = buildBidSecurityDeclaration(makeInput());
      final authBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('Duly authorized'),
      );
      expect(
        authBlock.spans.any((s) => s.bold && s.text == 'Example Pvt Ltd'),
        isTrue,
      );
    });

    test('company name does NOT appear bold elsewhere in the body', () {
      final blocks = buildBidSecurityDeclaration(makeInput());
      final boldCompanyBlocks = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .where(
            (b) => b.spans.any((s) => s.bold && s.text == 'Example Pvt Ltd'),
          )
          .toList();
      // Only the "Duly authorized" closing line should have bold company name
      expect(boldCompanyBlocks.length, 1);
      expect(boldCompanyBlocks.first.plainText, contains('Duly authorized'));
    });

    test('boilerplate contains "six months"', () {
      final blocks = buildBidSecurityDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('six months'));
    });

    test('boilerplate contains "Bid Securing Declaration shall cease"', () {
      final blocks = buildBidSecurityDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('Bid Securing Declaration shall cease'));
    });

    test('boilerplate contains "thirty days"', () {
      final blocks = buildBidSecurityDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('thirty days'));
    });

    test('date uses abbreviated month format', () {
      final blocks = buildBidSecurityDeclaration(makeInput());
      final dateBlock = blocks.first;
      expect(dateBlock.kind, LetterBlockKind.date);
      expect(dateBlock.plainText, contains('Oct'));
      expect(dateBlock.plainText, contains('2026'));
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — bid-security entry', () {
    testWidgets('registry has bid-security entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'bid-security'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-bid-security', (
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
      expect(find.text('Bid Security Declaration'), findsOneWidget);
      await tester.ensureVisible(find.text('Bid Security Declaration'));
      await tester.tap(find.text('Bid Security Declaration'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-bid-security');
    });
  });

  group('BidSecurityPage', () {
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
      // Fill 7 of 8 — missing Designation
      await fill(tester, 'Recipient title', 'The Commandant');
      await fill(tester, 'Organization', 'Indian Army');
      await fill(tester, 'Organization address', 'New Delhi');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Company address', '123 MG Road');
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
      await fill(tester, 'Recipient title', 'The Commandant');
      await fill(tester, 'Organization', 'Indian Army');
      await fill(tester, 'Organization address', 'New Delhi, 110001');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Company address', '123 MG Road, Mumbai');
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
      await fill(tester, 'Recipient title', 'The Commandant');
      await fill(tester, 'Organization', 'Indian Army');
      await fill(tester, 'Organization address', 'New Delhi, 110001');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Company address', '123 MG Road, Mumbai');
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

    testWidgets('company name / signatory / designation prefilled from profile', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'saathi.v1.guest':
            '{"profile":{"companyName":"Prefilled Co","companyAddress":"99 Link Road","signatoryName":"Jane Doe","signatoryDesignation":"CEO"}}',
      });
      final s = AppStore(await SharedPreferences.getInstance());
      await open(tester, s);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Company name'),
            )
            .controller
            ?.text,
        'Prefilled Co',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Signatory name'),
            )
            .controller
            ?.text,
        'Jane Doe',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Designation'),
            )
            .controller
            ?.text,
        'CEO',
      );
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
              home: BidSecurityPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
