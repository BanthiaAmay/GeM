import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/bid_docs/oem_authorization_page.dart';
import 'package:gem/features/bid_docs/oem_authorization_text.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  OemAuthorizationInput makeInput() => OemAuthorizationInput(
    template: OemAuthorizationTemplate.template1,
    recipientTitle: 'The Commandant',
    organization: 'Indian Army',
    organizationAddress: 'New Delhi, 110001',
    tenderNo: 'GEM/2026/B/7845020',
    resellerName: 'XYZ Pvt. Ltd',
    resellerAddress: 'Pune, 411001',
    company: 'Example OEM Pvt Ltd',
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
    await tester.pumpWidget(MaterialApp(
      theme: saathiTheme(),
      home: OemAuthorizationPage(store: s, tenderNo: tender),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  Future<void> fillAll(WidgetTester tester) async {
    await fill(tester, 'Tender No', 'GEM/2026/B/7845020');
    await fill(tester, 'Recipient title', 'The Commandant');
    await fill(tester, 'Organization', 'Indian Army');
    await fill(tester, 'Organization address', 'New Delhi, 110001');
    await fill(tester, 'Reseller name', 'XYZ Pvt. Ltd');
    await fill(tester, 'Reseller address', 'Pune, 411001');
    await fill(tester, 'Company name', 'Example OEM Pvt Ltd');
    await fill(tester, 'Company address', '123 MG Road, Mumbai');
    await fill(tester, 'Signatory name', 'Ravi Kumar');
    await fill(tester, 'Designation', 'Director');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildOemAuthorization', () {
    test('recipientTitle bold in recipient block', () {
      final blocks = buildOemAuthorization(makeInput());
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

    test('"Subject:" bold; value is "Authorization Letter" (no tender no)', () {
      final blocks = buildOemAuthorization(makeInput());
      final subjectBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text == 'Subject: '),
      );
      expect(subjectBlock.plainText, contains('Authorization Letter'));
      expect(subjectBlock.plainText, isNot(contains('GEM/')));
    });

    test('"GeM Bid No:" bold on its own line; tenderNo value follows', () {
      final blocks = buildOemAuthorization(makeInput());
      final bidNoBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text == 'GeM Bid No: '),
      );
      expect(bidNoBlock.plainText, contains('GEM/2026/B/7845020'));
    });

    test('para 1: company, companyAddress, M/s+resellerName, resellerAddress all bold', () {
      final blocks = buildOemAuthorization(makeInput());
      final para1 = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('would like to inform you'),
      );
      expect(
        para1.spans.any((s) => s.bold && s.text == 'Example OEM Pvt Ltd'),
        isTrue,
        reason: 'company should be bold',
      );
      expect(
        para1.spans.any((s) => s.bold && s.text == '123 MG Road, Mumbai'),
        isTrue,
        reason: 'companyAddress should be bold',
      );
      expect(
        para1.spans.any((s) => s.bold && s.text == 'M/s XYZ Pvt. Ltd'),
        isTrue,
        reason: '"M/s " prefix + resellerName should be bold',
      );
      expect(
        para1.spans.any((s) => s.bold && s.text == 'Pune, 411001'),
        isTrue,
        reason: 'resellerAddress should be bold',
      );
    });

    test('closing line: company bold in "on behalf of Z."', () {
      final blocks = buildOemAuthorization(makeInput());
      final closingBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('Duly authorized'),
      );
      expect(
        closingBlock.spans.any((s) => s.bold && s.text == 'Example OEM Pvt Ltd'),
        isTrue,
      );
    });

    test('no "Sincerely" in output', () {
      final blocks = buildOemAuthorization(makeInput());
      final lines = blocks.map((b) => b.plainText.trim()).toList();
      expect(
        lines.any((l) => l == 'Sincerely' || l == 'Sincerely,' || l == 'Yours Sincerely'),
        isFalse,
      );
    });

    test('boilerplate contains "quote rates, collect supply orders"', () {
      final blocks = buildOemAuthorization(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('quote rates, collect supply orders'));
    });

    test('boilerplate contains "valid till the validity of the above mentioned GeM Bid"', () {
      final blocks = buildOemAuthorization(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(
        allText,
        contains('valid till the validity of the above mentioned GeM Bid'),
      );
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — oem-authorization entry', () {
    testWidgets('registry has oem-authorization entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'oem-authorization'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-oem-authorization', (
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
      expect(find.text('OEM Authorization Certificate'), findsOneWidget);
      await tester.ensureVisible(find.text('OEM Authorization Certificate'));
      await tester.tap(find.text('OEM Authorization Certificate'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-oem-authorization');
    });
  });

  group('OemAuthorizationPage', () {
    testWidgets('all 10 text fields required; generate disabled until all filled', (
      tester,
    ) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('template dropdown defaults to Template 1', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      expect(find.text('Template 1'), findsOneWidget);
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
      expect(s.profile['companyName'], 'Example OEM Pvt Ltd');
      // Tender no and recipient must NOT be saved to profile
      expect(s.profile.containsKey('tenderNo'), isFalse);
      expect(s.profile.containsKey('recipientTitle'), isFalse);

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
      await fill(tester, 'Company name', 'New OEM Co Ltd');
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
    });

    testWidgets('reseller name and address NOT prefilled from profile', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'saathi.v1.guest':
            '{"profile":{"companyName":"Prefilled Co","signatoryName":"Jane Doe"}}',
      });
      final s = AppStore(await SharedPreferences.getInstance());
      await open(tester, s);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Reseller name'),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Reseller address'),
            )
            .controller
            ?.text,
        isEmpty,
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
            home: OemAuthorizationPage(store: s),
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
