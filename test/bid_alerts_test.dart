import 'support/authenticated_journey_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/keywords.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/alerts_page.dart';
import 'package:gem/features/bid_feed.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/onboarding_flow_2.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePush implements PushBridge {
  FakePush({this.allow = true});
  final bool allow;
  int enables = 0;
  @override
  bool get supported => true;
  @override
  Future<bool> enable() async {
    enables++;
    return allow;
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> detach() async {}
  @override
  String? takeLaunchRoute() => null;
}

class AlertsStore extends AuthenticatedJourneyStore {
  AlertsStore(super.prefs);
  final inAppSaves = <bool>[];
  @override
  Future<void> loadAlerts() async {}
  @override
  Future<void> setInAppAlerts(bool enabled) async {
    inAppSaves.add(enabled);
    alertPreferences = {...alertPreferences, 'in_app_enabled': enabled};
  }
}

void main() {
  ScrollMoreHint.debugDisableBounce = true;
  late AlertsStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AlertsStore(await SharedPreferences.getInstance());
  });

  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        routes: {'/flow-role': (_) => const Scaffold(body: Text('Role'))},
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('keyword field adds, de-duplicates, removes and limits', (
    tester,
  ) async {
    var values = <String>[];
    await show(
      tester,
      Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => AppKeywordField(
            values: values,
            onChanged: (v) => setState(() => values = v),
            suggestions: const ['Furniture', 'Paint'],
            label: 'Products',
            hint: 'e.g. chairs',
            addLabel: 'Add',
            removeLabel: 'Remove {keyword}',
            suggestionsLabel: 'Popular',
            limitMessage: 'Limit reached',
            max: 3,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'chairs, Tables,  ');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(values, ['chairs', 'Tables']);
    await tester.enterText(find.byType(TextField), 'CHAIRS');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(values, ['chairs', 'Tables']);
    await tester.tap(find.text('Furniture'));
    await tester.pumpAndSettle();
    expect(values, ['chairs', 'Tables', 'Furniture']);
    expect(find.text('Limit reached'), findsOneWidget);
    expect(find.text('Paint'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Remove Tables'));
    await tester.pumpAndSettle();
    expect(values, ['chairs', 'Furniture']);
  });

  Future<void> pick(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  // The category list loads from a bundled file: let it finish.
  Future<void> showPicker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        routes: {'/flow-role': (_) => const Scaffold(body: Text('Role'))},
        home: FlowProductsPage(store: store),
      ),
    );
    // A spinner shows until the file is read, so pump rather than settle.
    for (var i = 0; i < 100 && find.byType(TextField).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('industry then GeM category becomes the alert keyword', (
    tester,
  ) async {
    final push = FakePush();
    store.push = push;
    await showPicker(tester);
    expect(find.text('What industry does your business operate in?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Agriculture');
    await tester.pumpAndSettle();
    await pick(tester, 'Agriculture, Food & Livestock');
    expect(find.text('Which category best describes what you supply?'), findsOneWidget);
    expect(find.text('Showing categories for: Agriculture, Food & Livestock'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Grain Storage');
    await tester.pumpAndSettle();
    await pick(tester, 'Grain Storage Bin');
    await pick(tester, 'Continue');
    expect(store.gemIndustry, 'Agriculture, Food & Livestock');
    expect(store.gemCategoryName, 'Grain Storage Bin');
    expect(store.bidKeywords, ['Grain Storage Bin']);
    expect(push.enables, 1);
    expect(find.text('Role'), findsOneWidget);
  });

  testWidgets('a category not in the list can be typed under Others', (
    tester,
  ) async {
    await showPicker(tester);
    await tester.enterText(find.byType(TextField).first, 'Furniture');
    await tester.pumpAndSettle();
    await pick(tester, 'Furniture & Household Supplies');
    await pick(tester, 'Others');
    await tester.enterText(find.byType(TextField).last, 'Bamboo benches');
    await tester.pumpAndSettle();
    await pick(tester, 'Continue');
    expect(store.gemCategoryName, 'Bamboo benches');
    expect(store.bidKeywords, ['Bamboo benches']);
  });

  test('answers turn into balanced, capped keywords', () {
    final all = {for (final g in kSupplyGroups) g.id: g.keywords.toSet()};
    final words = keywordsFromAnswers(all);
    expect(words.length, 10);
    expect(words.take(3), ['Furniture', 'Stationery', 'Computer']);
    expect(answersFor(['cctv', 'Rice']), {
      'it': {'CCTV'},
      'food': {'Rice'},
    });
  });

  test('keywords are inferred from what the seller already told us', () {
    expect(inferKeywords({'businessName': 'Asha Textiles'}), [
      'Uniform',
      'Bedsheet',
      'Towel',
    ]);
    expect(
      inferKeywords({'businessName': 'Green Environment Pvt Ltd'}),
      isEmpty,
    );
    expect(inferKeywords({'sector': 'agriculture'}), ['Seeds', 'Fertilizer']);
    expect(
      inferKeywords({'sectorOther': 'computer repair and printing'}).first,
      'Computer',
    );
  });

  testWidgets('the step speaks the seller’s language', (tester) async {
    store.setLanguage('ta');
    await showPicker(tester);
    expect(find.text('உங்கள் தொழில் எந்தத் துறையில் இயங்குகிறது?'), findsOneWidget);
    expect(find.text('துறைகளைத் தேடுங்கள்…'), findsOneWidget);
  });

  testWidgets('bid feed opens on matches and explains empty states', (
    tester,
  ) async {
    await show(tester, Scaffold(body: BidFeed(store: store)));
    expect(find.text('No bids yet'), findsOneWidget);

    // A chosen GeM category opens the feed on "For you".
    store.setProfile('gemIndustry', 'Agriculture, Food & Livestock');
    store.setProfile('gemCategoryName', 'Grain Storage Bin');
    await show(
      tester,
      Scaffold(
        body: BidFeed(key: UniqueKey(), store: store),
      ),
    );
    expect(find.text('No matching open bids yet'), findsOneWidget);
  });

  testWidgets('turning app alerts on asks permission and explains a refusal', (
    tester,
  ) async {
    final push = FakePush(allow: false);
    store.push = push;
    store.alertPreferences = {'in_app_enabled': false, 'keywords': []};
    await show(tester, AlertsPage(store: store));
    // The first switch on the page is "App Notifications".
    expect(find.text('App Notifications'), findsOneWidget);
    final toggle = find.byType(Switch).first;
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(store.inAppSaves, [true]);
    expect(push.enables, 1);
    expect(
      find.textContaining('Allow them in your phone settings'),
      findsOneWidget,
    );
  });
}
