import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/bid_docs/mrp_declaration_page.dart';
import 'package:gem/features/bid_docs/mrp_declaration_text.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  MrpDeclarationInput makeInput({Uint8List? imageBytes}) => MrpDeclarationInput(
    tenderNo: 'GEM/2026/B/7845020',
    company: 'Example Pvt Ltd',
    signatory: 'Ravi Kumar',
    designation: 'Director',
    products: [
      const MrpProductRow(
        productName: 'Office Chair',
        makeBrand: 'ErgoMax',
        modelNo: 'EC-200',
        mrp: '15000',
        gemBidPrice: '14000',
        discountPercent: '7%',
      ),
    ],
    date: DateTime(2026, 10, 11),
  );

  MrpDeclarationInput makeTwoProductInput() => MrpDeclarationInput(
    tenderNo: 'GEM/2026/B/7845020',
    company: 'Example Pvt Ltd',
    signatory: 'Ravi Kumar',
    designation: 'Director',
    products: [
      const MrpProductRow(
        productName: 'Office Chair',
        makeBrand: 'ErgoMax',
        modelNo: 'EC-200',
        mrp: '15000',
        gemBidPrice: '14000',
        discountPercent: '7%',
      ),
      const MrpProductRow(
        productName: 'Standing Desk',
        makeBrand: 'StandUp',
        modelNo: 'SD-400',
        mrp: '25000',
        gemBidPrice: '23000',
        discountPercent: '8%',
      ),
    ],
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
        home: MrpDeclarationPage(store: s),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  Future<void> fillCard1(WidgetTester tester) async {
    await fill(tester, 'Tender / bid number', 'GEM/2026/B/7845020');
    await fill(tester, 'Company name', 'Example Pvt Ltd');
    await fill(tester, 'Signatory name', 'Ravi Kumar');
    await fill(tester, 'Designation', 'Director');
    await tester.ensureVisible(find.widgetWithText(TextFormField, 'Product name'));
    await fill(tester, 'Product name', 'Office Chair');
    await fill(tester, 'Make / Brand', 'ErgoMax');
    await fill(tester, 'Model / Item No.', 'EC-200');
    await fill(tester, 'MRP (₹)', '15000');
    await fill(tester, 'GeM Bid Price (₹)', '14000');
    await fill(tester, 'Discount %', '7%');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildMrpDeclaration', () {
    test('title block present', () {
      final blocks = buildMrpDeclaration(makeInput());
      expect(
        blocks.any((b) => b.kind == LetterBlockKind.title),
        isTrue,
      );
    });

    test('title contains "DECLARATION OF MAXIMUM RETAIL PRICE (MRP)"', () {
      final blocks = buildMrpDeclaration(makeInput());
      final title = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.title,
      );
      expect(title.plainText, contains('DECLARATION OF MAXIMUM RETAIL PRICE'));
    });

    test('productTable block has correct headers', () {
      final blocks = buildMrpDeclaration(makeInput());
      final table = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.productTable,
      );
      expect(table.tableHeaders, contains('Product Name'));
      expect(table.tableHeaders, contains('Make/Brand'));
      expect(table.tableHeaders, contains('Model No.'));
      expect(table.tableHeaders!.any((h) => h.contains('MRP')), isTrue);
    });

    test('productTable row contains product values', () {
      final blocks = buildMrpDeclaration(makeInput());
      final table = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.productTable,
      );
      final row = table.tableRows!.first;
      expect(row, contains('Office Chair'));
      expect(row, contains('ErgoMax'));
      expect(row, contains('EC-200'));
      expect(row, contains('15000'));
    });

    test('no productImage block when imageBytes is null', () {
      final blocks = buildMrpDeclaration(makeInput());
      expect(
        blocks.any((b) => b.kind == LetterBlockKind.productImage),
        isFalse,
      );
    });

    test('no productImage block even when imageBytes param passed', () {
      final fakeImage = Uint8List.fromList([1, 2, 3]);
      final blocks = buildMrpDeclaration(makeInput(imageBytes: fakeImage));
      expect(
        blocks.any((b) => b.kind == LetterBlockKind.productImage),
        isFalse,
      );
    });

    test('declaration item 1: MRP as printed on product/packaging', () {
      final blocks = buildMrpDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('MRP above is as printed on the product/packaging'));
      expect(allText, contains('Legal Metrology Act, 2009'));
    });

    test('declaration item 2: minimum 10% discount', () {
      final blocks = buildMrpDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('minimum 10% discount on the above MRP'));
      expect(allText, contains('GTC Clause 3(A)(xi)'));
    });

    test('declaration item 3: misrepresent MRP on GeM', () {
      final blocks = buildMrpDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('misrepresent MRP'));
      expect(allText, contains('GTC Clause 23.5(iv)'));
    });

    test('"We undertake" responsibility block present', () {
      final blocks = buildMrpDeclaration(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('We undertake'));
    });

    test('signatory name appears bold in signature block', () {
      final blocks = buildMrpDeclaration(makeInput());
      final sigBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.signature,
      );
      expect(sigBlock.spans.any((s) => s.bold && s.text == 'Ravi Kumar'), isTrue);
    });

    test('two products: one productTable block with two rows', () {
      final blocks = buildMrpDeclaration(makeTwoProductInput());
      final tables = blocks
          .where((b) => b.kind == LetterBlockKind.productTable)
          .toList();
      expect(tables.length, 1);
      expect(tables[0].tableRows![0], contains('Office Chair'));
      expect(tables[0].tableRows![1], contains('Standing Desk'));
    });

    test('single product: 18 blocks total', () {
      final fakeImage = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      final blocks = buildMrpDeclaration(makeInput(imageBytes: fakeImage));
      expect(blocks.length, 18);
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — mrp-declaration entry', () {
    testWidgets('registry has mrp-declaration entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'mrp-declaration'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-mrp-declaration', (
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
      expect(find.text('MRP Declaration Letter'), findsOneWidget);
      await tester.ensureVisible(find.text('MRP Declaration Letter'));
      await tester.tap(find.text('MRP Declaration Letter'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-mrp-declaration');
    });
  });

  group('MrpDeclarationPage', () {
    testWidgets(
      'all 4 product fields required; generate disabled until filled',
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
      await fillCard1(tester);

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

    testWidgets('add product button increases card count', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      expect(find.text('Product 1'), findsOneWidget);
      expect(find.text('Product 2'), findsNothing);

      await tester.ensureVisible(find.text('+ Add Product'));
      await tester.tap(find.text('+ Add Product'));
      await tester.pumpAndSettle();

      expect(find.text('Product 1'), findsOneWidget);
      expect(find.text('Product 2'), findsOneWidget);
    });

    testWidgets('remove button hidden for single product, visible with 2', (
      tester,
    ) async {
      final s = await makeStore();
      await open(tester, s);
      // With 1 card, no card-remove button
      expect(
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Remove product',
        ),
        findsNothing,
      );

      await tester.ensureVisible(find.text('+ Add Product'));
      await tester.tap(find.text('+ Add Product'));
      await tester.pumpAndSettle();
      // With 2 cards, remove buttons appear on each card
      expect(
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Remove product',
        ),
        findsWidgets,
      );
    });

    testWidgets('field edit clears preview', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await fillCard1(tester);

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await fill(tester, 'Product name', 'New Chair');
      await tester.pumpAndSettle();
      expect(find.text('Generate letter'), findsOneWidget);
    });

    testWidgets('profile fields (company, signatory, designation) saved after generate', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await fillCard1(tester);
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(s.profile['companyName'], 'Example Pvt Ltd');
      expect(s.profile['signatoryName'], 'Ravi Kumar');
      expect(s.profile['signatoryDesignation'], 'Director');
      expect(s.profile.containsKey('tenderNo'), isFalse);
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
              home: MrpDeclarationPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
