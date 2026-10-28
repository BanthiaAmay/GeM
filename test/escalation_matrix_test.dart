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
    position: 'Director',
    email: 'ravi@example.com',
    phone: '9876543210',
  );

  const secondary = EscalationContact(
    name: 'Priya Singh',
    position: 'Manager',
    email: 'priya@example.com',
    phone: '9876543211',
  );

  const tertiary = EscalationContact(
    name: 'Amit Gupta',
    position: 'Executive',
    email: 'amit@example.com',
    phone: '9876543212',
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
    test('primary-only produces exactly one numbered section', () {
      final blocks = buildEscalationMatrix(input());
      final headings = blocks
          .where((b) => b.kind == LetterBlockKind.heading)
          .map((b) => b.plainText)
          .toList();
      expect(headings.length, 1);
      expect(headings.first, contains('1.'));
      expect(headings.first, contains('Primary Contact'));
    });

    test('all three contacts produce three numbered sections', () {
      final blocks = buildEscalationMatrix(
        input(sec: secondary, ter: tertiary),
      );
      final headings = blocks
          .where((b) => b.kind == LetterBlockKind.heading)
          .map((b) => b.plainText)
          .toList();
      expect(headings.length, 3);
      expect(headings[0], contains('1.'));
      expect(headings[1], contains('2.'));
      expect(headings[2], contains('3.'));
    });

    test('secondary absent from output when not provided', () {
      final blocks = buildEscalationMatrix(input());
      final allText = blocks.map((b) => b.plainText).join(' ');
      expect(allText, isNot(contains('Secondary Contact')));
      expect(allText, isNot(contains('Additional Contact')));
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

    test('secondary-only (no tertiary) produces two sections', () {
      final blocks = buildEscalationMatrix(input(sec: secondary));
      final headings = blocks
          .where((b) => b.kind == LetterBlockKind.heading)
          .toList();
      expect(headings.length, 2);
    });

    test('date is formatted as month-name format', () {
      final blocks = buildEscalationMatrix(input());
      final dateBlock = blocks.first;
      expect(dateBlock.kind, LetterBlockKind.date);
      expect(dateBlock.plainText, contains('October'));
      expect(dateBlock.plainText, contains('2026'));
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
      'generate requires tender, signatory, designation, company, primary four fields',
      (tester) async {
        final s = await makeStore();
        await open(tester, s, tender: 'GEM/2026/B/7845020');
        // Only primary name filled — should still fail (position, email, phone missing)
        final names = find.widgetWithText(TextFormField, 'Name');
        await tester.enterText(names.at(0), 'Ravi Kumar');
        await tester.tap(find.text('Generate letter'));
        await tester.pumpAndSettle();
        expect(find.text('Your letter'), findsNothing);
        expect(find.text('This is required'), findsWidgets);
      },
    );

    testWidgets(
      'partial secondary contact (email only) triggers validation for all four',
      (tester) async {
        final s = await makeStore();
        await open(tester, s, tender: 'GEM/2026/B/7845020');
        // Fill required header fields
        await fill(tester, 'Signatory name', 'Z');
        await fill(tester, 'Designation', 'Owner');
        await fill(tester, 'Company name', 'Z Ltd');
        // Fill required primary fields
        final names = find.widgetWithText(TextFormField, 'Name');
        await tester.enterText(names.at(0), 'Ravi');
        final positions = find.widgetWithText(TextFormField, 'Position');
        await tester.enterText(positions.at(0), 'Director');
        final emails = find.widgetWithText(TextFormField, 'Email');
        await tester.enterText(emails.at(0), 'r@x.com');
        final phones = find.widgetWithText(TextFormField, 'Phone');
        await tester.enterText(phones.at(0), '9876543210');
        // Fill ONLY secondary email — should require the rest of secondary group
        await tester.enterText(emails.at(1), 'sec@x.com');
        await tester.tap(find.text('Generate letter'));
        await tester.pumpAndSettle();
        // Secondary name/position/phone should now be required
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
      await fill(tester, 'Designation', 'Owner');
      await fill(tester, 'Company name', 'Z Ltd');
      final names = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(names.at(0), 'Ravi');
      final positions = find.widgetWithText(TextFormField, 'Position');
      await tester.enterText(positions.at(0), 'Director');
      final emails = find.widgetWithText(TextFormField, 'Email');
      await tester.enterText(emails.at(0), 'r@x.com');
      final phones = find.widgetWithText(TextFormField, 'Phone');
      await tester.enterText(phones.at(0), '9876543210');

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
      await fill(tester, 'Designation', 'Owner');
      await fill(tester, 'Company name', 'Z Ltd');
      final names = find.widgetWithText(TextFormField, 'Name');
      await tester.enterText(names.at(0), 'Ravi');
      final positions = find.widgetWithText(TextFormField, 'Position');
      await tester.enterText(positions.at(0), 'Director');
      final emails = find.widgetWithText(TextFormField, 'Email');
      await tester.enterText(emails.at(0), 'r@x.com');
      final phones = find.widgetWithText(TextFormField, 'Phone');
      await tester.enterText(phones.at(0), '9876543210');

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
