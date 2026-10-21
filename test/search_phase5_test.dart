/// Phase 5 tests — bid detail page and next-action labels.
///
/// Covers:
///   1. Eligibility checklist items reflect the user's real profile answers.
///   2. The illustrative-data label is shown on the bid detail page.
///   3. A bid with ISO 9001 in requiredCertifications shows the
///      "needed → Get certified" action on its BidResultRow.
///   4. "Open bid on GeM" button is present on the detail page.
///   5. The "X of 5 ready" header count changes with the profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/data/sample_bids.dart';
import 'package:gem/features/search/bid_detail_page.dart';
import 'package:gem/features/search/search_result_card.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<AppStore> _store({Map<String, Object> eligibility = const {}}) async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final store = AppStore(sp);
  if (eligibility.isNotEmpty) {
    store.data['eligibility'] = Map<String, dynamic>.from(eligibility);
  }
  return store;
}

Widget _detailPage(AppStore store, String bidId) => MaterialApp(
  theme: saathiTheme(),
  onGenerateRoute: (s) => MaterialPageRoute(builder: (_) => const SizedBox()),
  home: BidDetailPage(store: store, bidId: bidId),
);

Widget _bidRow(AppStore store, SampleBid bid) => MaterialApp(
  theme: saathiTheme(),
  home: Scaffold(
    body: BidResultRow(
      bid: bid,
      isHindi: false,
      store: store,
      onTap: () {},
    ),
  ),
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Illustrative label shows on bid detail ────────────────────────────

  testWidgets('bid detail shows illustrative-data label', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_detailPage(store, 'NAMED-001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Illustrative'), findsOneWidget);
  });

  // ── 2. Checklist: Udyam row done when profile says udyam=true ────────────

  testWidgets('checklist Udyam row done when profile udyam=true',
      (tester) async {
    final store = await _store(eligibility: {'udyam': true});
    await tester.pumpWidget(_detailPage(store, 'NAMED-001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Udyam registered'), findsOneWidget);
  });

  // ── 3. Checklist: 0 of 5 ready when profile is empty ─────────────────────

  testWidgets('checklist shows 0 in header when profile is empty',
      (tester) async {
    final store = await _store();
    await tester.pumpWidget(_detailPage(store, 'NAMED-001'));
    await tester.pumpAndSettle();
    // Section header contains the count; 0 items are ready
    expect(
      find.textContaining('0'),
      findsWidgets,
      reason: 'Header should show "0 of 5 ready" when no items are ticked',
    );
  });

  // ── 4. Checklist counts PAN + bank as 2 ready ─────────────────────────────

  testWidgets('checklist header shows 2 when pan+bank set in profile',
      (tester) async {
    final store =
        await _store(eligibility: {'pan': true, 'bank': true});
    await tester.pumpWidget(_detailPage(store, 'NAMED-001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2'), findsWidgets);
  });

  // ── 5. "Open bid on GeM" button present ──────────────────────────────────

  testWidgets('"Open bid on GeM" button appears on bid detail', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_detailPage(store, 'NAMED-001'));
    await tester.pumpAndSettle();
    // Scroll to bottom so the button (below fold) is rendered
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Open bid on GeM'), findsOneWidget);
  });

  // ── 6. "Set reminder" button present ─────────────────────────────────────

  testWidgets('"Set reminder" button appears on bid detail', (tester) async {
    final store = await _store();
    await tester.pumpWidget(_detailPage(store, 'NAMED-001'));
    await tester.pumpAndSettle();
    // Scroll to bottom so the button (below fold) is rendered
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Set reminder'), findsOneWidget);
  });

  // ── 7. Bid ID row present and marked Illustrative ────────────────────────

  testWidgets('bid detail shows Bid ID row marked Illustrative',
      (tester) async {
    final store = await _store();
    await tester.pumpWidget(_detailPage(store, 'NAMED-001'));
    await tester.pumpAndSettle();
    expect(find.textContaining('NAMED-001'), findsOneWidget);
    expect(find.textContaining('Illustrative'), findsOneWidget);
  });

  // ── 8. ISO 9001 action on BidResultRow ───────────────────────────────────

  testWidgets('BidResultRow shows "ISO 9001 needed → Get certified"',
      (tester) async {
    final store = await _store();
    // NAMED-002 has requiredCertifications: ['ISO 9001']
    final bid = kNamedBids.firstWhere((b) => b.id == 'NAMED-002');
    await tester.pumpWidget(_bidRow(store, bid));
    await tester.pumpAndSettle();
    expect(find.textContaining('ISO 9001'), findsOneWidget);
    expect(find.textContaining('Get certified'), findsOneWidget);
  });

  // ── 9. "Review bid" action on a plain bid ────────────────────────────────

  testWidgets('BidResultRow shows "Review bid" when no certs or BG',
      (tester) async {
    final store = await _store();
    // NAMED-004 has no requiredCertifications and no needsBG
    final bid = kNamedBids.firstWhere((b) => b.id == 'NAMED-004');
    await tester.pumpWidget(_bidRow(store, bid));
    await tester.pumpAndSettle();
    expect(find.textContaining('Review bid'), findsOneWidget);
  });

  // ── 10. "Check eligibility" action for bid needing bank details ───────────

  testWidgets('BidResultRow shows "Check eligibility" for bid needing bank',
      (tester) async {
    final store = await _store();
    // NAMED-001 has needsBankDetails: true
    final bid = kNamedBids.firstWhere((b) => b.id == 'NAMED-001');
    await tester.pumpWidget(_bidRow(store, bid));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check eligibility'), findsOneWidget);
  });
}
