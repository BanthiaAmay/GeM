import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/bid_docs/non_relation_page.dart';
import 'package:gem/features/bid_docs/non_relation_text.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  NonRelationInput makeInput() => NonRelationInput(
    tenderNo: 'GEM/2026/B/7845020',
    buyerDesignation: 'The Commandant',
    buyerOrg: 'Indian Army',
    company: 'Example Pvt Ltd',
    signatory: 'Ravi Kumar',
    designation: 'Director',
    date: DateTime(2026, 10, 9),
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
        home: NonRelationPage(store: s, tenderNo: tender),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildNonRelationUndertaking', () {
    test('company name appears bold in first body paragraph', () {
      final blocks = buildNonRelationUndertaking(makeInput());
      final bodyBlocks = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .toList();
      final boldTexts = bodyBlocks
          .expand((b) => b.spans)
          .where((s) => s.bold)
          .map((s) => s.text)
          .toList();
      expect(boldTexts, contains('Example Pvt Ltd'));
    });

    test('signatory name appears bold in first body paragraph', () {
      final blocks = buildNonRelationUndertaking(makeInput());
      final bodyBlocks = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .toList();
      final boldTexts = bodyBlocks
          .expand((b) => b.spans)
          .where((s) => s.bold)
          .map((s) => s.text)
          .toList();
      expect(boldTexts, contains('Ravi Kumar'));
    });

    test('designation appears bold in first body paragraph', () {
      final blocks = buildNonRelationUndertaking(makeInput());
      final bodyBlocks = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .toList();
      final boldTexts = bodyBlocks
          .expand((b) => b.spans)
          .where((s) => s.bold)
          .map((s) => s.text)
          .toList();
      expect(boldTexts, contains('Director'));
    });

    test('tender number appears bold in subtitle (not body) block', () {
      final blocks = buildNonRelationUndertaking(makeInput());
      // tenderNo is in subtitle only
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(
        subtitle.spans.any((s) => s.bold && s.text == 'GEM/2026/B/7845020'),
        isTrue,
      );
      // tenderNo should NOT appear in any body block
      final bodyText = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .map((b) => b.plainText)
          .join(' ');
      expect(bodyText, isNot(contains('GEM/2026/B/7845020')));
    });

    test('tender number text appears in subtitle block content', () {
      final blocks = buildNonRelationUndertaking(makeInput());
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(subtitle.plainText, contains('GEM/2026/B/7845020'));
    });

    test('no Subject block in document', () {
      final blocks = buildNonRelationUndertaking(makeInput());
      final subjectBlocks = blocks.where((b) {
        return b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text.contains('Subject'));
      }).toList();
      expect(subjectBlocks.length, 0);
    });

    test('signatory name appears bold in signature block', () {
      final blocks = buildNonRelationUndertaking(makeInput());
      final sigBlocks = blocks
          .where((b) => b.kind == LetterBlockKind.signature)
          .toList();
      expect(sigBlocks.isNotEmpty, isTrue);
      final boldText = sigBlocks
          .expand((b) => b.spans)
          .where((s) => s.bold)
          .map((s) => s.text)
          .join(' ');
      expect(boldText, contains('Ravi Kumar'));
    });

    test('date is embedded bold in subtitle block (no standalone date block)', () {
      final blocks = buildNonRelationUndertaking(makeInput());
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(subtitle.plainText, contains('Oct'));
      expect(subtitle.plainText, contains('2026'));
      expect(blocks.any((b) => b.kind == LetterBlockKind.date), isFalse);
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — non-relation entry', () {
    testWidgets('registry has non-relation entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'non-relation'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card routes to /tool-non-relation', (tester) async {
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
      expect(find.text('Conflict of Interest Declaration'), findsOneWidget);
      await tester.ensureVisible(find.text('Conflict of Interest Declaration'));
      await tester.tap(find.text('Conflict of Interest Declaration'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-non-relation');
    });
  });

  group('NonRelationPage', () {
    testWidgets('empty form validates — stays on Details', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('generate blocked until all 6 fields filled', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      // Fill only 5 of 6 required fields — missing Designation
      await fill(tester, 'Tender / bid number', 'GEM/2026/B/7845020');
      await fill(tester, "Buyer's designation", 'The Commandant');
      await fill(tester, "Buyer's organisation", 'Indian Army');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
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
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, "Buyer's designation", 'The Commandant');
      await fill(tester, "Buyer's organisation", 'Indian Army');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      expect(find.text('Your letter'), findsOneWidget);
      // Profile saved; tender number NOT saved
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

    testWidgets('editing a field after generate invalidates letter', (
      tester,
    ) async {
      final s = await makeStore();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, "Buyer's designation", 'The Commandant');
      await fill(tester, "Buyer's organisation", 'Indian Army');
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await fill(tester, 'Company name', 'New Co Ltd');
      await tester.pumpAndSettle();
      expect(find.text('Generate letter'), findsOneWidget);
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
              home: NonRelationPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
