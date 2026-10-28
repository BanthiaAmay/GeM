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
    products: [
      MrpProductEntry(
        productName: 'Office Chair',
        brandName: 'ErgoMax',
        modelNo: 'EC-200',
        mrp: '15000',
        imageBytes: imageBytes,
      ),
    ],
    date: DateTime(2026, 10, 11),
  );

  MrpDeclarationInput makeTwoProductInput() => MrpDeclarationInput(
    products: [
      const MrpProductEntry(
        productName: 'Office Chair',
        brandName: 'ErgoMax',
        modelNo: 'EC-200',
        mrp: '15000',
      ),
      const MrpProductEntry(
        productName: 'Standing Desk',
        brandName: 'StandUp',
        modelNo: 'SD-400',
        mrp: '25000',
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
    await fill(tester, 'Product name', 'Office Chair');
    await fill(tester, 'Brand name', 'ErgoMax');
    await fill(tester, 'Model / Item No.', 'EC-200');
    await fill(tester, 'MRP (₹)', '15000');
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildMrpDeclarationLetter', () {
    test('titleUnderlined block present', () {
      final blocks = buildMrpDeclarationLetter(makeInput());
      expect(
        blocks.any((b) => b.kind == LetterBlockKind.titleUnderlined),
        isTrue,
      );
    });

    test('title contains "DECLARATION OF MAXIMUM RETAIL PRICE (MRP)"', () {
      final blocks = buildMrpDeclarationLetter(makeInput());
      final title = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.titleUnderlined,
      );
      expect(title.plainText, contains('DECLARATION OF MAXIMUM RETAIL PRICE'));
    });

    test('productTable block has correct headers', () {
      final blocks = buildMrpDeclarationLetter(makeInput());
      final table = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.productTable,
      );
      expect(table.tableHeaders, contains('Product Name'));
      expect(table.tableHeaders, contains('Brand'));
      expect(table.tableHeaders, contains('Model No.'));
      expect(table.tableHeaders!.any((h) => h.contains('MRP')), isTrue);
    });

    test('productTable row contains product values', () {
      final blocks = buildMrpDeclarationLetter(makeInput());
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
      final blocks = buildMrpDeclarationLetter(makeInput());
      expect(
        blocks.any((b) => b.kind == LetterBlockKind.productImage),
        isFalse,
      );
    });

    test('productImage block present when imageBytes provided', () {
      final fakeImage = Uint8List.fromList([1, 2, 3]);
      final blocks = buildMrpDeclarationLetter(
        makeInput(imageBytes: fakeImage),
      );
      final imgBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.productImage,
      );
      expect(imgBlock.imageBytes, equals(fakeImage));
    });

    test('declaration item 1: MRP as printed on product', () {
      final blocks = buildMrpDeclarationLetter(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(
        allText,
        contains('Maximum Retail Price as printed on the product'),
      );
    });

    test('declaration item 2: price quoted does not exceed MRP', () {
      final blocks = buildMrpDeclarationLetter(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('does not exceed'));
    });

    test('declaration item 3: misrepresentation → disqualification', () {
      final blocks = buildMrpDeclarationLetter(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('misrepresentation'));
      expect(allText, contains('disqualification'));
    });

    test('"We undertake" responsibility block present', () {
      final blocks = buildMrpDeclarationLetter(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, contains('We undertake'));
    });

    test('"Authorization Signatory" in signature block', () {
      final blocks = buildMrpDeclarationLetter(makeInput());
      final sigBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.signature,
      );
      expect(sigBlock.plainText, contains('Authorization Signatory'));
    });

    test('two products: two productTable blocks', () {
      final blocks = buildMrpDeclarationLetter(makeTwoProductInput());
      final tables = blocks
          .where((b) => b.kind == LetterBlockKind.productTable)
          .toList();
      expect(tables.length, 2);
      expect(tables[0].tableRows!.first, contains('Office Chair'));
      expect(tables[1].tableRows!.first, contains('Standing Desk'));
    });

    test('single product with image: 21 blocks', () {
      final fakeImage = Uint8List.fromList([
        0xFF,
        0xD8,
        0xFF,
      ]); // fake JPEG header
      final blocks = buildMrpDeclarationLetter(
        makeInput(imageBytes: fakeImage),
      );
      expect(blocks.length, 21);
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
      // No profile saves for MRP
      expect(s.profile.containsKey('companyName'), isFalse);

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

    testWidgets('no profile fields saved after generate', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await fillCard1(tester);
      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      expect(s.profile.isEmpty, isTrue);
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
