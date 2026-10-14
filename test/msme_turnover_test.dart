import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/bid_docs/msme_turnover_page.dart';
import 'package:gem/features/bid_docs/msme_turnover_text.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  MsmeTurnoverInput makeInput() => MsmeTurnoverInput(
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
      home: MsmeTurnoverPage(store: s, tenderNo: tender),
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

  group('buildMsmeTurnoverDeclaration', () {
    test('subject line contains "Turnover/Experience" not "EMD"', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final subjectBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text == 'Subject: '),
      );
      expect(subjectBlock.plainText, contains('Turnover/Experience'));
      expect(subjectBlock.plainText, isNot(contains('EMD')));
    });

    test('para 2 contains "Turnover and Experience for MSMEs" not "EMD"', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final para2 = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('Development Act, 2006'),
      );
      expect(para2.plainText, contains('Turnover and Experience for MSMEs'));
      expect(para2.plainText, isNot(contains('EMD')));
    });

    test('para 3 contains "[Micro/Small/Medium] Enterprise" and "MSMED Act"', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final para3 = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('[Micro/Small/Medium] Enterprise'),
      );
      expect(para3.plainText, contains('MSMED Act'));
    });

    test('udyamRegistrationNo bold in MSME Registration Number line', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
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

    test('"As an MSME, we may be exempted from the turnover/experience requirements" present', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(
        allText,
        contains(
          'As an MSME, we may be exempted from the turnover/experience requirements',
        ),
      );
    });

    test('NO "Furthermore, we confirm that our MSME registration is valid" paragraph', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, isNot(contains('Furthermore, we confirm')));
    });

    test('company name NOT bold anywhere in the body', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final boldCompanySpans = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .expand((b) => b.spans)
          .where((s) => s.bold && s.text.contains('Example Pvt Ltd'))
          .toList();
      expect(boldCompanySpans, isEmpty);
    });

    test('closing is "Yours Sincerely"', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join('\n');
      expect(allText, contains('Yours Sincerely'));
      final lines = blocks.map((b) => b.plainText).toList();
      expect(lines.any((l) => l.trim() == 'Sincerely'), isFalse);
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — msme-turnover-exemption entry', () {
    testWidgets('registry has msme-turnover-exemption entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'msme-turnover-exemption'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-msme-turnover', (
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
      expect(find.text('MSME Turnover/Experience Exemption'), findsOneWidget);
      await tester.ensureVisible(
        find.text('MSME Turnover/Experience Exemption'),
      );
      await tester.tap(find.text('MSME Turnover/Experience Exemption'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-msme-turnover');
    });
  });

  group('MsmeTurnoverPage', () {
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

    testWidgets('profile fields prefill on load', (tester) async {
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
              find.widgetWithText(TextFormField, 'Udyam Registration No.'),
            )
            .controller
            ?.text,
        'UDYAM-MH-01-9999999',
      );
    });

    testWidgets('renders without overflow in all 9 languages', (tester) async {
      final s = await makeStore();
      for (final w in [320.0, 390.0]) {
        for (final lang in supportedLanguages) {
          s.setLanguage(lang[0]);
          phone(tester, w);
          await tester.pumpWidget(MaterialApp(
            theme: saathiTheme(),
            home: MsmeTurnoverPage(store: s),
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
