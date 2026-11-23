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
    tenderNo: 'GEM/2026/B/7845020',
    buyerDesignation: 'The Commandant',
    buyerOrg: 'Indian Army',
    company: 'Example Pvt Ltd',
    udyamRegistrationNo: 'UDYAM-MH-01-0012345',
    msmeCategory: 'Micro',
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
        home: MsmeTurnoverPage(store: s, tenderNo: tender),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  Future<void> fillAll(WidgetTester tester) async {
    await fill(tester, 'Tender / bid number', 'GEM/2026/B/7845020');
    await fill(tester, "Buyer's designation", 'The Commandant');
    await fill(tester, "Buyer's organisation", 'Indian Army');
    await fill(tester, 'Company name', 'Example Pvt Ltd');
    await fill(tester, 'Signatory name', 'Ravi Kumar');
    await fill(tester, 'Designation', 'Director');
    await fill(tester, 'Udyam Registration No.', 'UDYAM-MH-01-0012345');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildMsmeTurnoverDeclaration', () {
    test('no Subject block in document', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final subjectBlocks = blocks.where((b) {
        return b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text.contains('Subject'));
      }).toList();
      expect(subjectBlocks.length, 0);
    });

    test('subtitle contains "Prior Turnover and Prior Experience" and tenderNo', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(
        subtitle.plainText,
        contains('Para 11(a)'),
      );
      expect(
        subtitle.spans.any((s) => s.bold && s.text == 'GEM/2026/B/7845020'),
        isTrue,
      );
    });

    test('opening para contains "Prior Turnover and Prior Experience criteria"', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final para = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('Prior Turnover and Prior Experience criteria'),
      );
      expect(para.plainText, contains('Prior Turnover and Prior Experience criteria'));
    });

    test('boilerplate contains "Udyam Registration Certificate is enclosed"', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('Udyam Registration Certificate is enclosed'));
    });

    test('udyamRegistrationNo is bold in Udyam Registration No. line', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final udyamBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('Udyam Registration No.'),
      );
      expect(
        udyamBlock.spans.any((s) => s.bold && s.text == 'UDYAM-MH-01-0012345'),
        isTrue,
      );
    });

    test('"As an MSME, we may be exempted from the turnover/experience requirements" is NOT present', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(
        allText,
        isNot(contains('As an MSME, we may be exempted')),
      );
    });

    test('company name IS bold in the body', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final boldCompanySpans = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .expand((b) => b.spans)
          .where((s) => s.bold && s.text.contains('Example Pvt Ltd'))
          .toList();
      expect(boldCompanySpans, isNotEmpty);
    });

    test('no "Yours Sincerely" in document', () {
      final blocks = buildMsmeTurnoverDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join('\n');
      expect(allText, isNot(contains('Sincerely')));
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
    testWidgets('empty form — all 7 fields required', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('partial fill (5 of 6) still blocks generate', (tester) async {
      final s = await makeStore();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, "Buyer's designation", 'The Commandant');
      await fill(tester, "Buyer's organisation", 'Indian Army');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
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
            '{"profile":{"companyName":"Prefilled Co","signatoryName":"Jane Doe","signatoryDesignation":"CEO","udyamRegistrationNo":"UDYAM-MH-01-9999999"}}',
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
          await tester.pumpWidget(
            MaterialApp(
              theme: saathiTheme(),
              home: MsmeTurnoverPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
