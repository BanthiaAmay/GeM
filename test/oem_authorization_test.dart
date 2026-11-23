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
    tenderNo: 'GEM/2026/B/7845020',
    buyerDesignation: 'The Commandant',
    buyerOrg: 'Indian Army',
    oemCompany: 'Example OEM Pvt Ltd',
    signatory: 'Ravi Kumar',
    designation: 'Director',
    resellerName: 'XYZ Pvt. Ltd',
    resellerAddress: 'Pune, 411001',
    productName: 'Office Chair',
    cmsQuadrant: 'Q3',
    date: DateTime(2026, 10, 4),
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
        home: OemAuthorizationPage(store: s, tenderNo: tender),
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
    await fill(tester, 'OEM company name', 'Example OEM Pvt Ltd');
    await fill(tester, 'Reseller / distributor name', 'XYZ Pvt. Ltd');
    await fill(tester, 'Reseller / distributor address', 'Pune, 411001');
    await fill(tester, 'Product name', 'Office Chair');
    await fill(tester, 'Signatory name', 'Ravi Kumar');
    await fill(tester, 'Designation', 'Director');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildOemAuthorizationCertificate', () {
    test('title is "OEM AUTHORIZATION CERTIFICATE"', () {
      final blocks = buildOemAuthorizationCertificate(makeInput());
      final titleBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.title,
      );
      expect(titleBlock.plainText, 'OEM AUTHORIZATION CERTIFICATE');
    });

    test('tenderNo appears bold in subtitle block', () {
      final blocks = buildOemAuthorizationCertificate(makeInput());
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(
        subtitle.spans.any((s) => s.bold && s.text == 'GEM/2026/B/7845020'),
        isTrue,
      );
    });

    test('date is embedded bold in subtitle block (no standalone date block)', () {
      final blocks = buildOemAuthorizationCertificate(makeInput());
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(subtitle.plainText, contains('Oct'));
      expect(subtitle.plainText, contains('2026'));
      expect(blocks.any((b) => b.kind == LetterBlockKind.date), isFalse);
    });

    test('buyerDesignation bold in recipient block', () {
      final blocks = buildOemAuthorizationCertificate(makeInput());
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

    test('no Subject block in document', () {
      final blocks = buildOemAuthorizationCertificate(makeInput());
      final subjectBlocks = blocks.where((b) {
        return b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text.contains('Subject'));
      }).toList();
      expect(subjectBlocks.length, 0);
    });

    test('authorization para contains "hereby authorize" and correct bold spans', () {
      final blocks = buildOemAuthorizationCertificate(makeInput());
      final authPara = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('hereby authorize'),
      );
      // oemCompany bold
      expect(
        authPara.spans.any((s) => s.bold && s.text == 'Example OEM Pvt Ltd'),
        isTrue,
      );
      // signatory bold
      expect(
        authPara.spans.any((s) => s.bold && s.text == 'Ravi Kumar'),
        isTrue,
      );
      // designation bold
      expect(
        authPara.spans.any((s) => s.bold && s.text == 'Director'),
        isTrue,
      );
      // 'M/s ' is a separate bold span
      expect(
        authPara.spans.any((s) => s.bold && s.text == 'M/s '),
        isTrue,
      );
      // resellerName bold
      expect(
        authPara.spans.any((s) => s.bold && s.text == 'XYZ Pvt. Ltd'),
        isTrue,
      );
      // resellerAddress bold
      expect(
        authPara.spans.any((s) => s.bold && s.text == 'Pune, 411001'),
        isTrue,
      );
    });

    test('boilerplate contains correct authorization scope', () {
      final blocks = buildOemAuthorizationCertificate(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(
        allText,
        contains('quote, bid, accept Supply Orders, supply, invoice, and collect payment'),
      );
    });

    test('validity note contains correct text', () {
      final blocks = buildOemAuthorizationCertificate(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(
        allText,
        contains(
          'sole and exclusive for this Bid, remains valid for the full duration of any resulting Supply Order',
        ),
      );
    });

    test('signature block contains oemCompany bold', () {
      final blocks = buildOemAuthorizationCertificate(makeInput());
      final sigBlocks = blocks
          .where((b) => b.kind == LetterBlockKind.signature)
          .toList();
      expect(sigBlocks.isNotEmpty, isTrue);
      final boldText = sigBlocks
          .expand((b) => b.spans)
          .where((s) => s.bold)
          .map((s) => s.text)
          .join(' ');
      expect(boldText, contains('Example OEM Pvt Ltd'));
      expect(boldText, contains('Ravi Kumar'));
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

    testWidgets('tool card routes to /tool-oem-authorization', (tester) async {
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
      expect(find.text('OEM Authorization Certificate'), findsOneWidget);
      await tester.ensureVisible(find.text('OEM Authorization Certificate'));
      await tester.tap(find.text('OEM Authorization Certificate'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-oem-authorization');
    });
  });

  group('OemAuthorizationPage', () {
    testWidgets('empty form — all 9 text fields required', (tester) async {
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
      await fill(tester, "Buyer's designation", 'The Commandant');
      await fill(tester, "Buyer's organisation", 'Indian Army');
      await fill(tester, 'OEM company name', 'Example OEM Pvt Ltd');
      await fill(tester, 'Reseller / distributor name', 'XYZ Pvt. Ltd');
      await fill(tester, 'Reseller / distributor address', 'Pune, 411001');
      await fill(tester, 'Product name', 'Office Chair');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      // Designation still empty
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
      // OEM company saved to profile; tender NOT saved
      expect(s.profile['companyName'], 'Example OEM Pvt Ltd');
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

    testWidgets('field edit after confirmation clears letter', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await fillAll(tester);

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await fill(tester, 'OEM company name', 'New OEM Ltd');
      await tester.pumpAndSettle();
      expect(find.text('Generate letter'), findsOneWidget);
    });

    testWidgets('OEM company name prefilled from profile', (tester) async {
      SharedPreferences.setMockInitialValues({
        'saathi.v1.guest':
            '{"profile":{"companyName":"Prefilled OEM Co","signatoryName":"Jane Doe","signatoryDesignation":"CEO"}}',
      });
      final s = AppStore(await SharedPreferences.getInstance());
      await open(tester, s);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'OEM company name'),
            )
            .controller
            ?.text,
        'Prefilled OEM Co',
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

    testWidgets('reseller fields are NOT prefilled from profile', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'saathi.v1.guest':
            '{"profile":{"companyName":"OEM Co","signatoryName":"Jane Doe","signatoryDesignation":"CEO"}}',
      });
      final s = AppStore(await SharedPreferences.getInstance());
      await open(tester, s);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Reseller / distributor name'),
            )
            .controller
            ?.text,
        '',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(
                TextFormField,
                'Reseller / distributor address',
              ),
            )
            .controller
            ?.text,
        '',
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
              home: OemAuthorizationPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
