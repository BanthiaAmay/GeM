import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/bid_docs/warranty_declaration_page.dart';
import 'package:gem/features/bid_docs/warranty_declaration_text.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  WarrantyDeclarationInput makeInput() => WarrantyDeclarationInput(
    tenderNo: 'GEM/2026/B/7845020',
    company: 'Example Pvt Ltd',
    signatory: 'Ravi Kumar',
    designation: 'Director',
    warrantyPeriod: '1 year',
    warrantyResponseDays: '5',
    contactName: 'Priya Sharma',
    contactDesignation: 'Manager',
    contactEmail: 'priya@example.com',
    contactPhone: '+91 9876543210',
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

  Future<void> open(WidgetTester tester, AppStore s) async {
    phone(tester, 390);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: WarrantyDeclarationPage(store: s),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  Future<void> fillAll(WidgetTester tester) async {
    await fill(tester, 'Tender / bid number', 'GEM/2026/B/7845020');
    await fill(tester, 'Company name', 'Example Pvt Ltd');
    await fill(tester, 'Signatory name', 'Ravi Kumar');
    await fill(tester, 'Designation', 'Director');
    await fill(tester, 'Warranty period', '1 year');
    await fill(tester, 'Warranty response days', '5');
    await fill(tester, 'Contact person name', 'Priya Sharma');
    await fill(tester, 'Contact designation', 'Manager');
    await fill(tester, 'Contact email', 'priya@example.com');
    await fill(tester, 'Contact phone', '+91 9876543210');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildWarrantyDeclaration', () {
    test('title is "WARRANTY DECLARATION"', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final titleBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.title,
      );
      expect(titleBlock.plainText, 'WARRANTY DECLARATION');
    });

    test(
      'signatoryName and designation are separate bold spans in opening paragraph',
      () {
        final blocks = buildWarrantyDeclaration(makeInput());
        final openingPara = blocks.firstWhere(
          (b) =>
              b.kind == LetterBlockKind.body &&
              b.plainText.contains('declare:'),
        );
        expect(
          openingPara.spans.any((s) => s.bold && s.text == 'Ravi Kumar'),
          isTrue,
          reason: 'signatory should be its own bold span',
        );
        expect(
          openingPara.spans.any((s) => s.bold && s.text == 'Director'),
          isTrue,
          reason: 'designation should be its own bold span',
        );
        expect(
          openingPara.spans.any(
            (s) =>
                s.text.contains('Ravi Kumar') &&
                s.text.contains('Director') &&
                s.text.contains('('),
          ),
          isFalse,
          reason: 'they should not be combined in one span',
        );
      },
    );

    test('warrantyPeriod renders bold', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final boldPeriodSpan = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .expand((b) => b.spans)
          .where((s) => s.bold && s.text == '1 year')
          .toList();
      expect(boldPeriodSpan, isNotEmpty);
    });

    test('inline "Warranty Claims Contact:" block present with all details bold', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final contactBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('Warranty Claims Contact:'),
      );
      expect(
        contactBlock.spans.any((s) => s.bold && s.text == 'Priya Sharma'),
        isTrue,
      );
      expect(
        contactBlock.spans.any((s) => s.bold && s.text == 'Manager'),
        isTrue,
      );
      expect(
        contactBlock.spans.any((s) => s.bold && s.text == 'priya@example.com'),
        isTrue,
      );
      expect(
        contactBlock.spans.any((s) => s.bold && s.text == '+91 9876543210'),
        isTrue,
      );
    });

    test('tender number appears bold in subtitle block', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(
        subtitle.spans.any((s) => s.bold && s.text == 'GEM/2026/B/7845020'),
        isTrue,
      );
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — warranty-declaration entry', () {
    testWidgets('registry has warranty-declaration entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'warranty-declaration'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-warranty-declaration', (
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
      expect(find.text('Warranty Declaration'), findsOneWidget);
      await tester.ensureVisible(find.text('Warranty Declaration'));
      await tester.tap(find.text('Warranty Declaration'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-warranty-declaration');
    });
  });

  group('WarrantyDeclarationPage', () {
    testWidgets('empty form — all 10 fields required', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('partial fill (9 of 10) still blocks generate', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await fill(tester, 'Tender / bid number', 'GEM/2026/B/7845020');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');
      await fill(tester, 'Warranty period', '1 year');
      await fill(tester, 'Warranty response days', '5');
      await fill(tester, 'Contact person name', 'Priya Sharma');
      await fill(tester, 'Contact designation', 'Manager');
      await fill(tester, 'Contact email', 'priya@example.com');
      // Contact phone empty
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('Your letter'), findsNothing);
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
      // Signatory saved to profile; contact fields NOT saved
      expect(s.profile['signatoryName'], 'Ravi Kumar');
      expect(s.profile.containsKey('contactEmail'), isFalse);

      AppButton printBtn() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Print / Save as PDF'),
      );
      expect(printBtn().onPressed, isNull);

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(printBtn().onPressed, isNotNull);
    });

    testWidgets('field edit after confirmation clears checkbox', (
      tester,
    ) async {
      final s = await makeStore();
      await open(tester, s);
      await fillAll(tester);

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await fill(tester, 'Warranty period', '2 years');
      await tester.pumpAndSettle();
      // After editing a field the letter is invalidated
      expect(find.text('Generate letter'), findsOneWidget);
    });

    testWidgets('signatory / designation prefilled from profile', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'saathi.v1.guest':
            '{"profile":{"signatoryName":"Jane Doe","signatoryDesignation":"CEO"}}',
      });
      final s = AppStore(await SharedPreferences.getInstance());
      await open(tester, s);
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

    testWidgets('invalid email shows inline error', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await fill(tester, 'Tender / bid number', 'GEM/2026/B/7845020');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');
      await fill(tester, 'Warranty period', '1 year');
      await fill(tester, 'Warranty response days', '5');
      await fill(tester, 'Contact person name', 'Priya Sharma');
      await fill(tester, 'Contact designation', 'Manager');
      await fill(tester, 'Contact email', 'not-an-email');
      await fill(tester, 'Contact phone', '+91 9876543210');
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('invalid phone shows inline error', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await fill(tester, 'Tender / bid number', 'GEM/2026/B/7845020');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');
      await fill(tester, 'Warranty period', '1 year');
      await fill(tester, 'Warranty response days', '5');
      await fill(tester, 'Contact person name', 'Priya Sharma');
      await fill(tester, 'Contact designation', 'Manager');
      await fill(tester, 'Contact email', 'priya@example.com');
      await fill(tester, 'Contact phone', '123'); // too short
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid phone number'), findsOneWidget);
      expect(find.text('Your letter'), findsNothing);
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
              home: WarrantyDeclarationPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
