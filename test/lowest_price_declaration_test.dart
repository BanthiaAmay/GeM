import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/bid_docs/lowest_price_declaration_page.dart';
import 'package:gem/features/bid_docs/lowest_price_declaration_text.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  LowestPriceInput makeInput() => LowestPriceInput(
    tenderNo: 'GEM/2026/B/7845020',
    buyerDesignation: 'The Commandant',
    buyerOrg: 'Indian Army',
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

  Future<void> open(WidgetTester tester, AppStore s, {String? tender}) async {
    phone(tester, 390);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: LowestPriceDeclarationPage(store: s, tenderNo: tender),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  Future<void> fillAll(WidgetTester tester) async {
    await fill(tester, 'Buyer\'s designation', 'The Commandant');
    await fill(tester, 'Buyer\'s organisation', 'Indian Army');
    await fill(tester, 'Company name', 'Example Pvt Ltd');
    await fill(tester, 'Signatory name', 'Ravi Kumar');
    await fill(tester, 'Designation', 'Director');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildLowestPriceDeclaration', () {
    test('recipientTitle bold in recipient block', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
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

    test('tenderNo present in subtitle block', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(subtitle.plainText, contains('GEM/2026/B/7845020'));
    });

    test('title is "DECLARATION OF BEST PRICE AND PRICE PARITY"', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final title = blocks.firstWhere((b) => b.kind == LetterBlockKind.title);
      expect(title.plainText, 'DECLARATION OF BEST PRICE AND PRICE PARITY');
    });

    test('company bold in opening para ("We, Z, … declare:")', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final para = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body && b.plainText.contains('declare:'),
      );
      expect(
        para.spans.any((s) => s.bold && s.text == 'Example Pvt Ltd'),
        isTrue,
      );
    });

    test('boilerplate contains "minimum discount of 10%"', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('minimum discount of 10%'));
    });

    test('boilerplate contains "Competition Act, 2002"', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('Competition Act, 2002'));
    });

    test('no "Subject:" in any block', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, isNot(contains('Subject:')));
    });

    test('no "Sincerely" in output', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final lines = blocks.map((b) => b.plainText.trim()).toList();
      expect(
        lines.any(
          (l) =>
              l == 'Sincerely' || l == 'Sincerely,' || l == 'Yours Sincerely',
        ),
        isFalse,
      );
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — lowest-price-declaration entry', () {
    testWidgets('registry has lowest-price-declaration entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'lowest-price-declaration'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets(
      'tool card visible and routes to /tool-lowest-price-declaration',
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
        expect(find.text('Lowest Price Declaration'), findsOneWidget);
        await tester.ensureVisible(find.text('Lowest Price Declaration'));
        await tester.tap(find.text('Lowest Price Declaration'));
        await tester.pumpAndSettle();
        expect(opened, '/tool-lowest-price-declaration');
      },
    );
  });

  group('LowestPriceDeclarationPage', () {
    testWidgets(
      'all 8 text fields required; generate disabled until all filled',
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
              home: LowestPriceDeclarationPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
