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

  LowestPriceDeclarationInput makeInput() => LowestPriceDeclarationInput(
    template: LowestPriceTemplate.template1,
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
        home: LowestPriceDeclarationPage(store: s, tenderNo: tender),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  Future<void> fillAll(WidgetTester tester) async {
    await fill(tester, 'Recipient title', 'The Commandant');
    await fill(tester, 'Organization', 'Indian Army');
    await fill(tester, 'Organization address', 'New Delhi, 110001');
    await fill(tester, 'Tender / bid number', 'GEM/2026/B/7845020');
    await fill(tester, 'Company name', 'Example Pvt Ltd');
    await fill(tester, 'Company address', '123 MG Road, Mumbai');
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

    test('"Subject:" bold; value is "Declaration of Lowest Price Quoted"', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final subjectBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text == 'Subject: '),
      );
      expect(
        subjectBlock.plainText,
        contains('Declaration of Lowest Price Quoted'),
      );
    });

    test('"GeM Bid No:" bold; tenderNo value follows', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final bidNoBlock = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text == 'GeM Bid No: '),
      );
      expect(bidNoBlock.plainText, contains('GEM/2026/B/7845020'));
    });

    test('para 1: company bold AND companyAddress bold', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final para1 = blocks.firstWhere(
        (b) =>
            b.kind == LetterBlockKind.body &&
            b.plainText.contains('having our registered office at'),
      );
      expect(
        para1.spans.any((s) => s.bold && s.text == 'Example Pvt Ltd'),
        isTrue,
        reason: 'company should be bold',
      );
      expect(
        para1.spans.any((s) => s.bold && s.text == '123 MG Road, Mumbai'),
        isTrue,
        reason: 'companyAddress should be bold',
      );
    });

    test('"Duly authorized": company bold', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
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

    test('boilerplate contains "public sector undertaking (PSU)"', () {
      final blocks = buildLowestPriceDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('public sector undertaking (PSU)'));
    });

    test(
      'boilerplate contains "disqualification from the tendering process"',
      () {
        final blocks = buildLowestPriceDeclaration(makeInput());
        final allText = blocks.map((b) => b.plainText).join(' ');
        expect(
          allText,
          contains('disqualification from the tendering process'),
        );
      },
    );

    test(
      'items 13, 14, 15 are consecutive body blocks (no spacers between)',
      () {
        final blocks = buildLowestPriceDeclaration(makeInput());
        final para1Idx = blocks.indexWhere(
          (b) =>
              b.kind == LetterBlockKind.body &&
              b.plainText.contains('having our registered office at'),
        );
        expect(para1Idx, isNot(-1));
        // block at para1Idx+1 is item 14 (affirm)
        expect(blocks[para1Idx + 1].kind, LetterBlockKind.body);
        expect(blocks[para1Idx + 1].plainText, contains('We affirm'));
        // block at para1Idx+2 is item 15 (understand)
        expect(blocks[para1Idx + 2].kind, LetterBlockKind.body);
        expect(blocks[para1Idx + 2].plainText, contains('We understand'));
      },
    );
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
