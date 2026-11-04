import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/models.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_docs/mii_certificate_page.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/features/tools_hub/tool_card.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  Future<AppStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore(await SharedPreferences.getInstance());
  }

  void phone(WidgetTester t, double w) {
    t.view.physicalSize = Size(w, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  Widget hub(AppStore s, {void Function(String?)? onRoute}) => MaterialApp(
    theme: saathiTheme(),
    onGenerateRoute: (settings) {
      onRoute?.call(settings.name);
      return MaterialPageRoute(builder: (_) => const SizedBox());
    },
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ToolsHub(store: s),
      ),
    ),
  );

  group('Tools hub', () {
    test('every registry entry has a unique id and route', () {
      expect(kTools.map((t) => t.id).toSet().length, kTools.length);
      expect(kTools.map((t) => t.route).toSet().length, kTools.length);
      expect(kTools.any((t) => t.id == 'mii-certificate'), isTrue);
    });

    testWidgets('shows the MII box and opens its route', (tester) async {
      phone(tester, 390);
      final s = await store();
      String? opened;
      await tester.pumpWidget(hub(s, onRoute: (r) => opened = r));
      expect(find.text('Make in India certificate'), findsOneWidget);
      await tester.tap(find.text('Make in India certificate'));
      await tester.pumpAndSettle();
      expect(opened, '/tool-mii');
    });

    testWidgets('fits the narrowest phones in every language', (tester) async {
      final s = await store();
      for (final w in [320.0, 360.0, 390.0]) {
        phone(tester, w);
        for (final lang in supportedLanguages) {
          s.setLanguage(lang[0]);
          await tester.pumpWidget(hub(s));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });

  group('MII certificate page', () {
    Future<void> open(WidgetTester tester, AppStore s, {String? tender}) async {
      phone(tester, 390);
      await tester.pumpWidget(
        MaterialApp(
          theme: saathiTheme(),
          home: MiiCertificatePage(store: s, tenderNo: tender),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> fill(WidgetTester tester, String label, String text) async {
      await tester.enterText(find.widgetWithText(TextFormField, label), text);
    }

    testWidgets('Preview with an empty form validates and stays on Details', (
      tester,
    ) async {
      final s = await store();
      await open(tester, s);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('This is required'), findsWidgets);
      expect(find.text('Your letter'), findsNothing);
    });

    testWidgets('below 20% local content is rejected', (tester) async {
      final s = await store();
      await open(tester, s);
      await fill(tester, 'Local content (%)', '10');
      await tester.tap(find.text('Generate certificate'));
      await tester.pumpAndSettle();
      expect(
        find.text('Below 20% you do not qualify as a local supplier'),
        findsOneWidget,
      );
    });

    testWidgets('generate -> preview -> confirm unlocks print', (tester) async {
      final s = await store();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, 'Local content (%)', '100');
      await fill(tester, 'Company name', 'Z');
      await fill(tester, 'Where the local value addition is done', 'India');
      await fill(tester, 'Signatory name', 'Z');
      await fill(tester, 'Designation', 'Owner');
      await tester.tap(find.text('Generate certificate'));
      await tester.pumpAndSettle();

      expect(find.text('Your letter'), findsOneWidget);
      expect(
        find.textContaining('Local Content : 100%', findRichText: true),
        findsOneWidget,
      );
      // Remembered for next time, tender number is not.
      expect(s.profile['companyName'], 'Z');
      expect(s.profile.containsKey('tenderNo'), isFalse);

      AppButton printButton() => tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Print / Save as PDF'),
      );
      expect(printButton().onPressed, isNull); // gated

      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(printButton().onPressed, isNotNull);
    });

    testWidgets('changing an input discards the letter and the confirmation', (
      tester,
    ) async {
      final s = await store();
      await open(tester, s, tender: 'GEM/2026/B/7845020');
      await fill(tester, 'Local content (%)', '60');
      await fill(tester, 'Company name', 'Z');
      await fill(tester, 'Where the local value addition is done', 'India');
      await fill(tester, 'Signatory name', 'Z');
      await fill(tester, 'Designation', 'Owner');
      await tester.tap(find.text('Generate certificate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await fill(tester, 'Company name', 'Z Pvt Ltd');
      await tester.pumpAndSettle();
      expect(find.text('Generate certificate'), findsOneWidget); // not "Update"
    });

    testWidgets('fits narrow phones in every language', (tester) async {
      final s = await store();
      for (final w in [320.0, 360.0]) {
        for (final lang in supportedLanguages) {
          s.setLanguage(lang[0]);
          phone(tester, w);
          await tester.pumpWidget(
            MaterialApp(
              theme: saathiTheme(),
              home: MiiCertificatePage(store: s),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '${lang[0]} @ $w');
        }
      }
    });
  });
}
