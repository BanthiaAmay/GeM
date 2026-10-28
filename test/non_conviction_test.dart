import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/bid_docs/non_conviction_page.dart';
import 'package:gem/features/bid_docs/non_conviction_text.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  NonConvictionInput makeInput() => NonConvictionInput(
    company: 'Example Pvt Ltd',
    companyAddress: '123 MG Road, Mumbai',
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

  Future<void> open(WidgetTester tester, AppStore s) async {
    phone(tester, 390);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: NonConvictionPage(store: s),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildNonConvictionCertificate', () {
    test('company name appears bold in first body paragraph', () {
      final blocks = buildNonConvictionCertificate(makeInput());
      final boldTexts = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .expand((b) => b.spans)
          .where((s) => s.bold)
          .map((s) => s.text)
          .toList();
      expect(boldTexts, contains('Example Pvt Ltd'));
    });

    test('signatory name appears bold in body and signature blocks', () {
      final blocks = buildNonConvictionCertificate(makeInput());
      final boldTexts = blocks
          .expand((b) => b.spans)
          .where((s) => s.bold)
          .map((s) => s.text)
          .toList();
      expect(boldTexts, contains('Ravi Kumar'));
    });

    test('designation appears bold in first body paragraph', () {
      final blocks = buildNonConvictionCertificate(makeInput());
      final boldTexts = blocks
          .where((b) => b.kind == LetterBlockKind.body)
          .expand((b) => b.spans)
          .where((s) => s.bold)
          .map((s) => s.text)
          .toList();
      expect(boldTexts, contains('Director'));
    });

    test('exactly one Subject block with bold "Subject:" span', () {
      final blocks = buildNonConvictionCertificate(makeInput());
      final subjectBlocks = blocks.where((b) {
        return b.kind == LetterBlockKind.body &&
            b.spans.any((s) => s.bold && s.text.contains('Subject'));
      }).toList();
      expect(subjectBlocks.length, 1);
    });

    test('letter body does NOT contain any tender/bid number reference', () {
      final blocks = buildNonConvictionCertificate(makeInput());
      final allText = blocks.map((b) => b.plainText).join(' ').toLowerCase();
      expect(allText, isNot(contains('gem/')));
      expect(allText, isNot(contains('tender no')));
      expect(allText, isNot(contains('bid no')));
    });

    test('signatory name appears bold in signature block', () {
      final blocks = buildNonConvictionCertificate(makeInput());
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

    test('date uses abbreviated month format (Oct, not October)', () {
      final blocks = buildNonConvictionCertificate(makeInput());
      final dateBlock = blocks.first;
      expect(dateBlock.kind, LetterBlockKind.date);
      expect(dateBlock.plainText, contains('Oct'));
      expect(dateBlock.plainText, contains('2026'));
      expect(dateBlock.plainText, isNot(contains('October')));
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — non-conviction entry', () {
    testWidgets('registry has non-conviction entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'non-conviction'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-non-conviction', (
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
      expect(find.text('Non-Conviction Certificate'), findsOneWidget);
      await tester.ensureVisible(find.text('Non-Conviction Certificate'));
      await tester.tap(find.text('Non-Conviction Certificate'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-non-conviction');
    });
  });

  group('NonConvictionPage', () {
    testWidgets('empty form validates — stays on Details', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('generate blocked until all 4 fields filled', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      // Fill only 3 of 4 required fields — missing Designation
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Company address', '123 MG Road, Mumbai');
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
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Company address', '123 MG Road, Mumbai');
      await fill(tester, 'Signatory name', 'Ravi Kumar');
      await fill(tester, 'Designation', 'Director');

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      expect(find.text('Your letter'), findsOneWidget);
      // Profile saved
      expect(s.profile['companyName'], 'Example Pvt Ltd');
      // No tender number saved
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
      await open(tester, s);
      await fill(tester, 'Company name', 'Example Pvt Ltd');
      await fill(tester, 'Company address', '123 MG Road, Mumbai');
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
              home: NonConvictionPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
