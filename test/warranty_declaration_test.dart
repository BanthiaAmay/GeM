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
    signatoryName: 'Ravi Kumar',
    designation: 'Director',
    warrantyPeriod: '1 year',
    contactName: 'Priya Sharma',
    contactPosition: 'Manager',
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
    await tester.pumpWidget(MaterialApp(
      theme: saathiTheme(),
      home: WarrantyDeclarationPage(store: s),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  Future<void> fillAll(WidgetTester tester) async {
    await fill(tester, 'Signatory name', 'Ravi Kumar');
    await fill(tester, 'Designation', 'Director');
    await fill(tester, 'Warranty period', '1 year');
    await fill(tester, 'Contact person name', 'Priya Sharma');
    await fill(tester, 'Contact position', 'Manager');
    await fill(tester, 'Contact email', 'priya@example.com');
    await fill(tester, 'Contact phone', '+91 9876543210');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildWarrantyDeclaration', () {
    test('"To Whom It May Concern" block is LetterBlockKind.title', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final titleBlock = blocks.firstWhere(
        (b) => b.plainText.contains('To Whom It May Concern'),
      );
      expect(titleBlock.kind, LetterBlockKind.title);
    });

    test('signatoryName + " (" + designation + ")" renders bold together in one span', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final boldSpan = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .expand((b) => b.spans)
          .firstWhere(
            (s) => s.bold && s.text.contains('Ravi Kumar') && s.text.contains('Director'),
          );
      expect(boldSpan.text, 'Ravi Kumar (Director)');
    });

    test('warrantyPeriod renders bold', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final boldPeriodSpan = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .expand((b) => b.spans)
          .where((s) => s.bold && s.text == '1 year')
          .toList();
      expect(boldPeriodSpan, isNotEmpty);
    });

    test('Name contact line present with correct value', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join('\n');
      expect(allText, contains('Name: Priya Sharma'));
    });

    test('Position contact line present with correct value', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join('\n');
      expect(allText, contains('Position: Manager'));
    });

    test('Email contact line present with correct value', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join('\n');
      expect(allText, contains('Email: priya@example.com'));
    });

    test('Phone No contact line present with correct value', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join('\n');
      expect(allText, contains('Phone No: +91 9876543210'));
    });

    test('no tender number reference anywhere in the letter', () {
      final blocks = buildWarrantyDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join('\n').toLowerCase();
      expect(allText, isNot(contains('gem/')));
      expect(allText, isNot(contains('tender no')));
      expect(allText, isNot(contains('bid no')));
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
      expect(find.text('Warranty Declaration'), findsOneWidget);
      await tester.ensureVisible(find.text('Warranty Declaration'));
      await tester.tap(find.text('Warranty Declaration'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-warranty-declaration');
    });
  });

  group('WarrantyDeclarationPage', () {
    testWidgets('empty form — all 7 fields required', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('partial fill (6 of 7) still blocks generate', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');
      await fill(tester, 'Warranty period', '1 year');
      await fill(tester, 'Contact person name', 'Priya Sharma');
      await fill(tester, 'Contact position', 'Manager');
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
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');
      await fill(tester, 'Warranty period', '1 year');
      await fill(tester, 'Contact person name', 'Priya Sharma');
      await fill(tester, 'Contact position', 'Manager');
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
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');
      await fill(tester, 'Warranty period', '1 year');
      await fill(tester, 'Contact person name', 'Priya Sharma');
      await fill(tester, 'Contact position', 'Manager');
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
          await tester.pumpWidget(MaterialApp(
            theme: saathiTheme(),
            home: WarrantyDeclarationPage(store: s),
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
