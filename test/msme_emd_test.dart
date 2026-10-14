import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/bid_docs/msme_emd_page.dart';
import 'package:gem/features/bid_docs/msme_emd_text.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  MsmeEmdInput makeInput() => MsmeEmdInput(
    recipientTitle: 'The Commandant',
    organization: 'Indian Army',
    organizationAddress: 'New Delhi, 110001',
    tenderNo: 'GEM/2026/B/7845020',
    company: 'Example Pvt Ltd',
    companyAddress: '123 MG Road, Mumbai',
    signatory: 'Ravi Kumar',
    designation: 'Director',
    udyamRegistrationNo: 'UDYAM-MH-01-0012345',
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
    await tester.pumpWidget(MaterialApp(
      theme: saathiTheme(),
      home: MsmeEmdPage(store: s, tenderNo: tender),
    ));
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
    await fill(tester, 'Udyam Registration No.', 'UDYAM-MH-01-0012345');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildMsmeEmdDeclaration', () {
    test('recipientTitle bold in recipient block', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
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

    test('"Subject:" span bold', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
      final subjectBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text.startsWith('Subject:')),
      );
      expect(
        subjectBlock.spans.any((s) => s.bold && s.text == 'Subject: '),
        isTrue,
      );
    });

    test('tender no. appears verbatim in subject line', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
      final subjectBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text == 'Subject: '),
      );
      expect(subjectBlock.plainText, contains('GEM/2026/B/7845020'));
    });

    test('organization appears in para 1 body (not just recipient block)', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
      // Para 1 (item 12) contains the organization in the body text
      final para1 = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('I am writing on behalf of'),
      );
      expect(para1.plainText, contains('Indian Army'));
    });

    test('udyamRegistrationNo is bold in MSME Registration Number line', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
      final udyamBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('MSME Registration Number'),
      );
      expect(
        udyamBlock.spans.any(
          (s) => s.bold && s.text == 'UDYAM-MH-01-0012345',
        ),
        isTrue,
      );
    });

    test('company name is NOT bold anywhere in the body', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
      final boldCompanySpans = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .expand((b) => b.spans)
          .where((s) => s.bold && s.text.contains('Example Pvt Ltd'))
          .toList();
      expect(boldCompanySpans, isEmpty);
    });

    test('closing is "Yours Sincerely" not "Sincerely"', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join('\n');
      expect(allText, contains('Yours Sincerely'));
      // Ensure plain "Sincerely" without "Yours" does not appear separately
      final lines = blocks.map((b) => b.plainText).toList();
      expect(lines.any((l) => l.trim() == 'Sincerely'), isFalse);
    });

    test('boilerplate contains "MSME Development Act, 2006"', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('Development Act, 2006'));
    });

    test('boilerplate contains "Earnest Money Deposit"', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('Earnest Money Deposit'));
    });

    test('boilerplate contains "MSME registration certificate"', () {
      final blocks = buildMsmeEmdDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('MSME registration certificate'));
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — msme-emd-exemption entry', () {
    testWidgets('registry has msme-emd-exemption entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'msme-emd-exemption'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-msme-emd', (
      tester,
    ) async {
      phone(tester, 390);
      final s = await makeStore();
      String? opened;
      await tester.pumpWidget(MaterialApp(
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
      ));
      await tester.pumpAndSettle();
      expect(find.text('MSME EMD Exemption'), findsOneWidget);
      await tester.ensureVisible(find.text('MSME EMD Exemption'));
      await tester.tap(find.text('MSME EMD Exemption'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-msme-emd');
    });
  });

  group('MsmeEmdPage', () {
    testWidgets('empty form — all 9 fields required', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('partial fill (8 of 9) still blocks generate', (tester) async {
      final s = await makeStore();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, 'Recipient title', 'The Commandant');
      await fill(tester, 'Organization', 'Indian Army');
      await fill(tester, 'Organization address', 'New Delhi');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Company address', '123 MG Road');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');
      // Udyam No. empty
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
      // Profile saved; tender/recipient/org NOT saved
      expect(s.profile['companyName'], 'Example Pvt Ltd');
      expect(s.profile['udyamRegistrationNo'], 'UDYAM-MH-01-0012345');
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

    testWidgets(
      'company / signatory / designation / udyamRegistrationNo prefilled from profile',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'saathi.v1.guest':
              '{"profile":{"companyName":"Prefilled Co","companyAddress":"99 Link Road","signatoryName":"Jane Doe","signatoryDesignation":"CEO","udyamRegistrationNo":"UDYAM-MH-01-9999999"}}',
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
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Udyam Registration No.'),
              )
              .controller
              ?.text,
          'UDYAM-MH-01-9999999',
        );
      },
    );

    testWidgets('renders without overflow in all 9 languages', (tester) async {
      final s = await makeStore();
      for (final w in [320.0, 390.0]) {
        for (final lang in supportedLanguages) {
          s.setLanguage(lang[0]);
          phone(tester, w);
          await tester.pumpWidget(MaterialApp(
            theme: saathiTheme(),
            home: MsmeEmdPage(store: s),
          ));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${lang[0]} @ $w',
          );
        }
      }
    });
  });
}
