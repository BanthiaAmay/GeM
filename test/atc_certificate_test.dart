import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/atc_certificate_page.dart';
import 'package:gem/features/bid_docs/atc_certificate_text.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  AtcCertificateInput makeInput() => AtcCertificateInput(
    recipientTitle: 'The Commandant',
    organization: 'Indian Army',
    organizationAddress: 'New Delhi, 110001',
    tenderNo: 'GEM/2026/B/7845020',
    company: 'Example Pvt Ltd',
    companyAddress: '123 MG Road, Mumbai',
    signatory: 'Ravi Kumar',
    designation: 'Director',
    date: DateTime(2026, 10, 11),
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
        home: AtcCertificatePage(store: s, tenderNo: tender),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  Future<void> fillAll(WidgetTester tester) async {
    await fill(tester, 'Tender / bid number', 'GEM/2026/B/7845020');
    await fill(tester, 'Recipient title', 'The Commandant');
    await fill(tester, 'Organization', 'Indian Army');
    await fill(tester, 'Organization address', 'New Delhi, 110001');
    await fill(tester, 'Company name', 'Example Pvt Ltd');
    await fill(tester, 'Company address', '123 MG Road, Mumbai');
    await fill(tester, 'Signatory name', 'Ravi Kumar');
    await fill(tester, 'Designation', 'Director');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildAtcCertificate', () {
    test('recipientTitle bold in recipient block', () {
      final blocks = buildAtcCertificate(makeInput());
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

    test('"Subject:" bold; value is "Acceptance of Terms and Conditions"', () {
      final blocks = buildAtcCertificate(makeInput());
      final subjectBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text == 'Subject: '),
      );
      expect(
        subjectBlock.plainText,
        contains('Acceptance of Terms and Conditions'),
      );
      // Subject line must NOT contain tender number
      expect(subjectBlock.plainText, isNot(contains('GEM/')));
    });

    test('"GeM Bid No:" bold on its own line; tenderNo value follows', () {
      final blocks = buildAtcCertificate(makeInput());
      final bidNoBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text == 'GeM Bid No: '),
      );
      expect(bidNoBlock.plainText, contains('GEM/2026/B/7845020'));
    });

    test('company name bold in para 1 ("We, Z, hereby…")', () {
      final blocks = buildAtcCertificate(makeInput());
      final para1 = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('hereby acknowledge'),
      );
      expect(
        para1.spans.any((s) => s.bold && s.text == 'Example Pvt Ltd'),
        isTrue,
      );
    });

    test('company name bold in closing line ("…on behalf of Z.")', () {
      final blocks = buildAtcCertificate(makeInput());
      final closingBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('Duly authorized'),
      );
      expect(
        closingBlock.spans.any((s) => s.bold && s.text == 'Example Pvt Ltd'),
        isTrue,
      );
    });

    test('company name bold in exactly two places', () {
      final blocks = buildAtcCertificate(makeInput());
      final boldCompanyBlocks = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .where(
            (b) => b.spans.any((s) => s.bold && s.text == 'Example Pvt Ltd'),
          )
          .toList();
      expect(boldCompanyBlocks.length, 2);
    });

    test('no "Sincerely" line in output', () {
      final blocks = buildAtcCertificate(makeInput());
      final lines = blocks.map((b) => b.plainText.trim()).toList();
      expect(
        lines.any((l) => l == 'Sincerely' || l == 'Yours Sincerely'),
        isFalse,
      );
    });

    test('boilerplate contains "integral part of the bidding process"', () {
      final blocks = buildAtcCertificate(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('integral part of the bidding process'));
    });

    test('boilerplate contains "disqualification or termination"', () {
      final blocks = buildAtcCertificate(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('disqualification or termination'));
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — atc-certificate entry', () {
    testWidgets('registry has atc-certificate entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'atc-certificate'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-atc-certificate', (
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
      expect(find.text('ATC Certificate'), findsOneWidget);
      await tester.ensureVisible(find.text('ATC Certificate'));
      await tester.tap(find.text('ATC Certificate'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-atc-certificate');
    });
  });

  group('AtcCertificatePage', () {
    testWidgets('empty form — all 8 fields required', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('partial fill (7 of 8) still blocks generate', (tester) async {
      final s = await makeStore();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
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
      await open(tester, s);
      await fillAll(tester);

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      expect(find.text('Your letter'), findsOneWidget);
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

    testWidgets('field edit clears confirmation', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await fillAll(tester);

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await fill(tester, 'Company name', 'New Co Ltd');
      await tester.pumpAndSettle();
      expect(find.text('Generate letter'), findsOneWidget);
    });

    testWidgets('profile fields prefill on load', (tester) async {
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
              home: AtcCertificatePage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
