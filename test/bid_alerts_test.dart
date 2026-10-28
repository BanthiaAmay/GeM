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
  @override
  Future<void> loadAlerts() async {}
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

  testWidgets('supply questions pre-tick from business details', (
    tester,
  ) async {
    final push = FakePush();
    store.push = push;
    store.setProfile('sector', 'services');
    store.setProfile('businessName', 'Shakti Security Agency');
    await show(tester, FlowProductsPage(store: store));
    expect(find.textContaining('We ticked a few'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // Nothing to type.
    // Only the inferred words are on, not every word of their groups.
    expect(find.text('Laptop'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(store.bidKeywords, ['CCTV', 'Security services']);
    expect(push.enables, 1);
    expect(find.text('Role'), findsOneWidget);
  });

  testWidgets('ticking a group adds its words; unticking a word drops it', (
    tester,
  ) async {
    store.setProfile('sector', 'other');
    await show(tester, FlowProductsPage(store: store));
    expect(find.text('Skip for now'), findsOneWidget);
    await tester.ensureVisible(find.text('Manpower & security'));
    await tester.tap(find.text('Manpower & security'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Security services'));
    await tester.tap(find.text('Security services'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(store.bidKeywords, ['Manpower']);
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
    await show(tester, FlowProductsPage(store: store));
    expect(find.text('உங்கள் தொழில் என்ன வழங்குகிறது?'), findsOneWidget);
    expect(find.text('மரச்சாமான்கள்'), findsOneWidget); // Furniture.
  });

  testWidgets('bid feed opens on matches and explains empty states', (
    tester,
  ) async {
    await show(tester, Scaffold(body: BidFeed(store: store)));
    expect(find.text('No bids yet'), findsOneWidget);

    store.setProfile('bidKeywords', ['Manpower']);
    await show(tester, Scaffold(body: BidFeed(key: UniqueKey(), store: store)));
    expect(find.text('No matching open bids yet'), findsOneWidget);
  });

  testWidgets('turning app alerts on asks permission and explains a refusal', (
    tester,
  ) async {
    final push = FakePush(allow: false);
    store.push = push;
    store.alertPreferences = {'in_app_enabled': false, 'keywords': []};
    await show(tester, AlertsPage(store: store));
    final toggle = find.text('App notifications for matching bids');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(push.enables, 1);
    expect(
      find.textContaining('Allow them in your phone settings'),
      findsOneWidget,
    );
  });
}
