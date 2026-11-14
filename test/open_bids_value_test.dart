import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/bid_valuation_sheet.dart';
import 'package:gem/features/components.dart';
import 'package:gem/features/open_bids_value_card.dart';

void main() {
  Future<AppStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return AppStore(await SharedPreferences.getInstance());
  }

  Widget host(Widget child) => MaterialApp(
    theme: saathiTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: AppCard(tone: AppCardTone.hero, child: child),
      ),
    ),
  );

  test('values are shown in lakh and crore', () {
    expect(inrShort(12500000), '₹1.25 Cr');
    expect(inrShort(1850000), '₹18.5 L');
    expect(inrShort(45000), '₹45,000');
    expect(inrShort(0), '₹0');
  });

  testWidgets('card before the first estimate', (tester) async {
    final s = await store();
    await tester.pumpWidget(host(OpenBidsValueCard(store: s)));
    expect(find.text('Open bids value'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Estimates not available yet'), findsOneWidget);
    expect(
      find.textContaining('not an official GeM valuation'),
      findsOneWidget,
    );
  });

  testWidgets('complete and partial values stay separate', (tester) async {
    final semantics = tester.ensureSemantics();
    final s = await store();
    s.openBidsValue = (
      open: 25,
      complete: 20,
      incomplete: 5,
      pending: 2,
      failed: 1,
      noPrice: 1,
      completeValue: 12500000,
      partialValue: 1850000,
    );
    await tester.pumpWidget(host(OpenBidsValueCard(store: s)));
    // The progress bar's shimmer repeats, so pump a fixed time, not settle.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('₹1.25 Cr'), findsOneWidget);
    expect(find.text('Complete contract value'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Partial estimates'), findsOneWidget);
    expect(find.text('₹18.5 L'), findsOneWidget);
    expect(
      find.textContaining('Partial estimates are excluded from the main total'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('20 of 25 bids completely valued')),
      findsOneWidget,
    );
    expect(
      find.text(
        '2 awaiting valuation · 1 failed, will retry · 1 no market price found',
      ),
      findsOneWidget,
    );
    for (final word in ['profit', 'Profit', 'earning', 'Earning']) {
      expect(find.textContaining(word), findsNothing);
    }
    semantics.dispose();
  });

  testWidgets('no ₹0 headline when no bid is fully valued', (tester) async {
    final s = await store();
    s.openBidsValue = (
      open: 3,
      complete: 0,
      incomplete: 3,
      pending: 3,
      failed: 0,
      noPrice: 0,
      completeValue: 0,
      partialValue: 0,
    );
    await tester.pumpWidget(host(OpenBidsValueCard(store: s)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('—'), findsOneWidget);
    expect(find.text('No bid fully valued yet'), findsOneWidget);
    expect(find.text('3 awaiting valuation'), findsOneWidget);
    expect(find.text('Complete contract value'), findsNothing);
  });

  testWidgets('no open bids', (tester) async {
    final s = await store();
    s.openBidsValue = (
      open: 0,
      complete: 0,
      incomplete: 0,
      pending: 0,
      failed: 0,
      noPrice: 0,
      completeValue: 0,
      partialValue: 0,
    );
    await tester.pumpWidget(host(OpenBidsValueCard(store: s)));
    // The progress bar's shimmer repeats, so pump a fixed time, not settle.
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.text('No matched bids close in the next 10 days.'),
      findsOneWidget,
    );
    expect(find.text('—'), findsOneWidget, reason: 'never a ₹0 headline');
  });

  testWidgets('card is translated', (tester) async {
    final s = await store();
    s.setLanguage('mr');
    await tester.pumpWidget(host(OpenBidsValueCard(store: s)));
    expect(find.text('खुल्या बोलींचे मूल्य'), findsOneWidget);
    s.setLanguage('hi');
    await tester.pumpWidget(host(OpenBidsValueCard(store: s)));
    expect(find.text('खुली बोलियों का मूल्य'), findsOneWidget);
  });

  Future<void> tallView(WidgetTester tester) async {
    // The sheet is a lazy list; make every row build.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    AppStore s,
    Map<String, dynamic>? data,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: Scaffold(
          body: BidValuationView(
            store: s,
            bidId: 'b1',
            title: 'Street lights',
            load: (_) async => data,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'valuation sheet: failed attempt is not shown as not valued or ₹0',
    (tester) async {
      final s = await store();
      await pumpSheet(tester, s, {
        'status': 'failed',
        'attempt': {
          'status': 'failed',
          'stage': 'fetch',
          'last_attempt_at': '2026-11-14T03:00:00Z',
        },
        'valuation': null,
        'items': [],
      });
      expect(find.text('Valuation failed'), findsOneWidget);
      expect(find.textContaining('It will be retried.'), findsOneWidget);
      expect(find.textContaining('14 Nov 2026'), findsOneWidget);
      expect(find.textContaining('₹'), findsNothing);
    },
  );

  testWidgets('valuation sheet: nothing priced says ₹0 is not an estimate', (
    tester,
  ) async {
    final s = await store();
    await pumpSheet(tester, s, {
      'status': 'valued',
      'valuation': {
        'priced_value_inr': 0,
        'priced_count': 0,
        'complete': false,
        'confidence': 'low',
      },
      'items': [
        {
          'name': 'Custom bracket',
          'qty': 2,
          'unit': 'Nos',
          'priced': false,
          'offers': [],
        },
      ],
    });
    expect(find.textContaining('₹0 here is not an estimate'), findsOneWidget);
    expect(find.text('₹0'), findsNothing);
  });

  testWidgets('valuation sheet explains the estimate', (tester) async {
    await tallView(tester);
    final s = await store();
    final detail = {
      'status': 'valued',
      'valuation': {
        'priced_value_inr': 12500,
        'priced_count': 1,
        'complete': false,
        'confidence': 'medium',
        'pricing_coverage': 0.5,
        'match_confidence': 0.88,
        'price_reliability': 0.7,
      },
      'items': [
        {
          'name': 'LED Street Light',
          'qty': 5,
          'unit': 'Nos',
          'priced': true,
          'unit_price': 2500,
          'line_value': 12500,
          'match_score': 0.88,
          'price_reliability': 'reduced',
          'offers': [
            {
              'source_name': 'gem_marketplace',
              'source_url': 'https://mkp.gem.gov.in/p/1',
              'seller_name': 'Acme Lighting',
              'unit_price': 2450,
            },
          ],
        },
        {
          'name': 'Custom pole bracket',
          'qty': 5,
          'unit': 'Nos',
          'priced': false,
          'price_reliability': 'unpriced',
          'offers': [],
        },
      ],
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: Scaffold(
          body: BidValuationView(
            store: s,
            bidId: 'b1',
            title: 'Street lights',
            load: (_) async => detail,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('₹12,500'), findsOneWidget);
    expect(find.text('Medium confidence'), findsOneWidget);
    expect(
      find.text('Partial estimate: not all items could be valued'),
      findsOneWidget,
    );
    expect(
      find.text('Price sources: based on number of independent offers'),
      findsOneWidget,
    );
    expect(find.textContaining('not a statistical measure'), findsOneWidget);
    expect(find.text('2 offers'), findsOneWidget);
    expect(find.textContaining('Acme Lighting'), findsOneWidget);
    expect(
      find.text('Not valued (1): excluded from the total'),
      findsOneWidget,
    );
    expect(find.text('• Custom pole bracket'), findsOneWidget);
    expect(
      find.textContaining('not an official GeM valuation'),
      findsOneWidget,
    );
  });

  testWidgets('valuation sheet before a bid is valued', (tester) async {
    final s = await store();
    await pumpSheet(tester, s, {
      'status': 'pending',
      'attempt': null,
      'valuation': null,
      'items': [],
    });
    expect(find.text('Not valued yet'), findsOneWidget);
    await pumpSheet(tester, s, null);
    expect(find.text('Not valued yet'), findsOneWidget);
  });
}
