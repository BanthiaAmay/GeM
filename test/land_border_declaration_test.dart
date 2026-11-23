import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/land_border_declaration_page.dart';
import 'package:gem/features/bid_docs/land_border_declaration_text.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  LandBorderDeclarationInput makeInput() => LandBorderDeclarationInput(
    tenderNo: 'GEM/2026/B/7845020',
    company: 'Example Pvt Ltd',
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

  Future<void> open(WidgetTester tester, AppStore s) async {
    phone(tester, 390);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: LandBorderDeclarationPage(store: s),
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
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildLandBorderDeclaration', () {
    test('title is "DECLARATION — COMPLIANCE WITH LAND BORDER RESTRICTION"', () {
      final blocks = buildLandBorderDeclaration(makeInput());
      final titleBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.title,
      );
      expect(
        titleBlock.plainText,
        'DECLARATION — COMPLIANCE WITH LAND BORDER RESTRICTION',
      );
    });

    test('subtitle contains "GFR Rule 144(xi)" and "23.02.2023"', () {
      final blocks = buildLandBorderDeclaration(makeInput());
      final subtitles = blocks
          .where((b) => b.kind == LetterBlockKind.subtitle)
          .map((b) => b.plainText)
          .join(' ');
      expect(subtitles, contains('GFR Rule 144(xi)'));
      expect(subtitles, contains('23.02.2023'));
    });

    test('tenderNo present in subtitle block', () {
      final blocks = buildLandBorderDeclaration(makeInput());
      final subtitleWithBidNo = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.subtitle &&
            b.plainText.contains('GEM/2026/B/7845020'),
      );
      expect(subtitleWithBidNo.plainText, contains('GEM/2026/B/7845020'));
    });

    test('company name bold in opening para ("We, X, … declare:")', () {
      final blocks = buildLandBorderDeclaration(makeInput());
      final para = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body && b.plainText.contains('declare:'),
      );
      expect(
        para.spans.any((s) => s.bold && s.text == 'Example Pvt Ltd'),
        isTrue,
      );
    });

    test('numbered clauses 1–5 each in separate body blocks', () {
      final blocks = buildLandBorderDeclaration(makeInput());
      final bodyTexts = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .map((b) => b.plainText)
          .toList();
      expect(bodyTexts.any((t) => t.startsWith('1.')), isTrue);
      expect(bodyTexts.any((t) => t.startsWith('2.')), isTrue);
      expect(bodyTexts.any((t) => t.startsWith('3.')), isTrue);
      expect(bodyTexts.any((t) => t.startsWith('4.')), isTrue);
      expect(bodyTexts.any((t) => t.startsWith('5.')), isTrue);
    });

    test('boilerplate contains "land border with India"', () {
      final blocks = buildLandBorderDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('land border with India'));
    });

    test('no "Sincerely" in new document format', () {
      final blocks = buildLandBorderDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, isNot(contains('Sincerely')));
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — land-border-declaration entry', () {
    testWidgets('registry has land-border-declaration entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'land-border-declaration'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets(
      'tool card visible and routes to /tool-land-border-declaration',
      (tester) async {
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
        expect(find.text('Land Border Declaration'), findsOneWidget);
        await tester.ensureVisible(find.text('Land Border Declaration'));
        await tester.tap(find.text('Land Border Declaration'));
        await tester.pumpAndSettle();
        expect(opened, '/tool-land-border-declaration');
      },
    );
  });

  group('LandBorderDeclarationPage', () {
    testWidgets(
      'all 4 text fields required; generate disabled until all filled',
      (tester) async {
        final s = await makeStore();
        await open(tester, s);
        await tester.tap(find.text('Generate letter'));
        await tester.pumpAndSettle();
        expect(find.text('This is required'), findsWidgets);
        expect(find.text('Your letter'), findsNothing);
      },
    );

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
      expect(s.profile['signatoryName'], 'Ravi Kumar');

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
              home: LandBorderDeclarationPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
