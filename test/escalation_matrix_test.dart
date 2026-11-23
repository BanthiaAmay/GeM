import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/escalation_matrix_page.dart';
import 'package:gem/features/bid_docs/escalation_matrix_text.dart';
import 'package:gem/features/bid_docs/letter_model.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── helpers ────────────────────────────────────────────────────────────────

  const primary = EscalationContact(
    name: 'Ravi Kumar',
    designation: 'Director',
    email: 'ravi@example.com',
  );

  const secondary = EscalationContact(
    name: 'Priya Singh',
    designation: 'Manager',
    email: 'priya@example.com',
  );

  const tertiary = EscalationContact(
    name: 'Amit Gupta',
    designation: 'Executive',
    email: 'amit@example.com',
  );

  EscalationMatrixInput input({
    EscalationContact? sec,
    EscalationContact? ter,
  }) => EscalationMatrixInput(
    tenderNo: 'GEM/2026/B/7845020',
    primary: primary,
    secondary: sec,
    tertiary: ter,
    signatory: 'Ravi Kumar',
    designation: 'Director',
    company: 'Example Pvt Ltd',
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
        home: EscalationMatrixPage(store: s, tenderNo: tender),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  // ── Unit tests — letter builder ────────────────────────────────────────────

  group('buildEscalationMatrix', () {
    test('primary-only produces exactly one table row', () {
      final blocks = buildEscalationMatrix(input());
      final tableBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.productTable,
      );
      expect(tableBlock.tableRows?.length, 1);
      expect(tableBlock.tableRows?.first[0], '1 — Operational');
    });

    test('all three contacts produce three table rows', () {
      final blocks = buildEscalationMatrix(
        input(sec: secondary, ter: tertiary),
      );
      final tableBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.productTable,
      );
      expect(tableBlock.tableRows?.length, 3);
      expect(tableBlock.tableRows![0][0], '1 — Operational');
      expect(tableBlock.tableRows![1][0], '2 — Management');
      expect(tableBlock.tableRows![2][0], '3 — Senior/Legal');
    });

    test('secondary absent from table rows when not provided', () {
      final blocks = buildEscalationMatrix(input());
      final tableBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.productTable,
      );
      final tiers = tableBlock.tableRows?.map((r) => r[0]).join(' ') ?? '';
      expect(tiers, isNot(contains('2 — Management')));
      expect(tiers, isNot(contains('3 — Senior/Legal')));
    });

    test('tender number appears bold in subtitle block', () {
      final blocks = buildEscalationMatrix(input());
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      final boldSpans = subtitle.spans.where((s) => s.bold).toList();
      expect(boldSpans.any((s) => s.text == 'GEM/2026/B/7845020'), isTrue);
    });

    test('signatory name appears bold in signature block', () {
      final blocks = buildEscalationMatrix(input());
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

    test('secondary-only (no tertiary) produces two table rows', () {
      final blocks = buildEscalationMatrix(input(sec: secondary));
      final tableBlock = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.productTable,
      );
      expect(tableBlock.tableRows?.length, 2);
    });

    test('date is embedded bold in subtitle block (no standalone date block)', () {
      final blocks = buildEscalationMatrix(input());
      final subtitle = blocks.firstWhere(
        (b) => b.kind == LetterBlockKind.subtitle,
      );
      expect(subtitle.plainText, contains('Oct'));
      expect(subtitle.plainText, contains('2026'));
      expect(blocks.any((b) => b.kind == LetterBlockKind.date), isFalse);
    });
  });

  // ── Widget tests ───────────────────────────────────────────────────────────

  group('Tools hub — escalation matrix entry', () {
    testWidgets('registry has escalation-matrix entry with unique id', (
      tester,
    ) async {
      expect(kTools.any((t) => t.id == 'escalation-matrix'), isTrue);
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
    });

    testWidgets('tool card visible and routes to /tool-escalation', (
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
      expect(find.text('Escalation Matrix'), findsOneWidget);
      await tester.ensureVisible(find.text('Escalation Matrix'));
      await tester.tap(find.text('Escalation Matrix'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-escalation');
    });
  });

  group('EscalationMatrixPage', () {
    testWidgets('empty form validates — stays on Details', (tester) async {
      final s = await makeStore();
      await open(tester, s);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets(
      'generate requires tender, signatory, designation, company, primary three fields',
      (tester) async {
        final s = await makeStore();
        await open(tester, s, tender: 'GEM/2026/B/7845020');
        // Only primary name filled — should still fail (designation, email missing)
        final names = find.widgetWithText(TextFormField, 'Name');
        await tester.enterText(names.at(0), 'Ravi Kumar');
        await tester.tap(find.text('Generate letter'));
        await tester.pumpAndSettle();
        expect(find.text('Your letter'), findsNothing);
        expect(find.text('This is required'), findsWidgets);
      },
    );

    testWidgets(
      'partial secondary contact (email only) triggers validation for all three',
      (tester) async {
        final s = await makeStore();
        await open(tester, s, tender: 'GEM/2026/B/7845020');
        // Fill required header fields
        await fill(tester, 'Signatory name', 'Z');
        await fill(tester, 'Company name', 'Z Ltd');
        final designations = find.widgetWithText(TextFormField, 'Designation');
        await tester.enterText(designations.at(0), 'Owner');
        // Fill required primary fields
        final names = find.widgetWithText(TextFormField, 'Name');
        await tester.enterText(names.at(0), 'Ravi');
        await tester.enterText(designations.at(1), 'Director');
        final emails = find.widgetWithText(TextFormField, 'Email');
        await tester.enterText(emails.at(0), 'r@x.com');
        // Fill ONLY secondary email — should require the rest of secondary group
        await tester.enterText(emails.at(1), 'sec@x.com');
        await tester.tap(find.text('Generate letter'));
        await tester.pumpAndSettle();
        // Secondary name/designation should now be required
        expect(find.text('This is required'), findsWidgets);
        expect(find.text('Your letter'), findsNothing);
      },
    );

    testWidgets('generate → preview → confirm → print/share unlocked', (
      tester,
    ) async {
      final s = await makeStore();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, 'Signatory name', 'Z');
      await fill(tester, 'Company name', 'Z Ltd');
      final designations = find.widgetWithText(TextFormField, 'Designation');
      await tester.enterText(designations.at(0), 'Owner');
      final names = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(names.at(0), 'Ravi');
      await tester.enterText(designations.at(1), 'Director');
      final emails = find.widgetWithText(TextFormField, 'Email');
      await tester.enterText(emails.at(0), 'r@x.com');

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();

      expect(find.text('Your letter'), findsOneWidget);
      // Profile saved; tender number NOT saved
      expect(s.profile['companyName'], 'Z Ltd');
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

    testWidgets('changing a field after generate invalidates letter', (
      tester,
    ) async {
      final s = await makeStore();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, 'Signatory name', 'Z');
      await fill(tester, 'Company name', 'Z Ltd');
      final designations = find.widgetWithText(TextFormField, 'Designation');
      await tester.enterText(designations.at(0), 'Owner');
      final names = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(names.at(0), 'Ravi');
      await tester.enterText(designations.at(1), 'Director');
      final emails = find.widgetWithText(TextFormField, 'Email');
      await tester.enterText(emails.at(0), 'r@x.com');

      await tester.tap(find.text('Generate letter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await fill(tester, 'Company name', 'New Co Ltd');
      await tester.pumpAndSettle();
      expect(find.text('Generate letter'), findsOneWidget); // not "Update"
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
              home: EscalationMatrixPage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
