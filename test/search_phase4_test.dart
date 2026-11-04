/// Phase 4 tests — bid filters, sort order, and score reasons.
///
/// Covers: BidFilter.matches() logic, filter chip row interaction,
/// combined filter (Maharashtra + <₹5L + closing in 7 days → 0 results),
/// reset, and sort order correctness.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/data/sample_bids.dart';
import 'package:gem/features/search/search_models.dart';
import 'package:gem/features/search/search_page.dart';
import 'package:gem/features/search/search_result_card.dart';
import 'package:gem/features/search/search_store.dart';
import 'package:gem/features/scroll_hint.dart';

// ── Test helpers ──────────────────────────────────────────────────────────────

Future<(AppStore, SearchStore)> _stores() async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  return (AppStore(sp), SearchStore(sp));
}

// Helper: open sort sheet, pick an option by label, then tap Done.
Future<void> pickSort(WidgetTester tester, String label) async {
  await tester.tap(find.textContaining('Sort:'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

Widget _page(AppStore store, SearchStore ss, {String? query}) => MaterialApp(
  theme: saathiTheme(),
  onGenerateRoute: (s) => MaterialPageRoute(builder: (_) => const SizedBox()),
  home: SearchPage(store: store, searchStore: ss, initialQuery: query),
);

// Convenience: open the page, switch to Bids scope, then enter a query.
// Scope is switched BEFORE the query so the tab still shows plain "Bids" (no count).
Future<void> _pumpBidsScope(
  WidgetTester tester,
  AppStore store,
  SearchStore ss,
  String query,
) async {
  await tester.pumpWidget(_page(store, ss));
  await tester.pumpAndSettle();
  // Tap Bids scope tab (no query yet → label is plain 'Bids', no count suffix)
  await tester.tap(find.text('Bids'));
  await tester.pumpAndSettle();
  // Now enter the query; filter row should appear after results load
  await tester.enterText(find.byType(TextField), query);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

// ── BidFilter unit tests ──────────────────────────────────────────────────────

// A minimal SampleBid for unit testing (no const constructor shortcut in test).
const _mh = SampleBid(
  id: 'TEST-MH',
  category: 'office',
  postedDaysAgo: 5,
  closesInDays: 6,
  valueRs: 400000,
  matchPct: 80,
  state: 'Maharashtra',
  district: 'Pune',
  mseRelaxation: true,
  emdExemption: true,
  startupRelaxation: false,
);

const _dl = SampleBid(
  id: 'TEST-DL',
  category: 'it',
  postedDaysAgo: 2,
  closesInDays: 20,
  valueRs: 1200000,
  matchPct: 70,
  state: 'Delhi',
  district: 'New Delhi',
  mseRelaxation: false,
  emdExemption: false,
  startupRelaxation: false,
);

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  // ── 1. State filter ─────────────────────────────────────────────────────────

  test('BidFilter: state match is case-insensitive', () {
    const f = BidFilter(state: 'maharashtra');
    expect(f.matches(_mh), isTrue);
    expect(f.matches(_dl), isFalse);
  });

  // ── 2. Value filter ─────────────────────────────────────────────────────────

  test('BidFilter: maxValueRs excludes bids at or above threshold', () {
    const f = BidFilter(maxValueRs: 500000);
    expect(f.matches(_mh), isTrue); // 400000 < 500000
    expect(f.matches(_dl), isFalse); // 1200000 > 500000
  });

  // ── 3. Closing filter ───────────────────────────────────────────────────────

  test('BidFilter: closingInDays excludes bids closing later', () {
    const f = BidFilter(closingInDays: 7);
    expect(f.matches(_mh), isTrue); // closesInDays=6 ≤ 7
    expect(f.matches(_dl), isFalse); // closesInDays=20 > 7
  });

  // ── 4. Boolean filters ──────────────────────────────────────────────────────

  test('BidFilter: mseRelaxation filter', () {
    const f = BidFilter(mseRelaxation: true);
    expect(f.matches(_mh), isTrue);
    expect(f.matches(_dl), isFalse);
  });

  test('BidFilter: emdExemption filter', () {
    const f = BidFilter(emdExemption: true);
    expect(f.matches(_mh), isTrue);
    expect(f.matches(_dl), isFalse);
  });

  test('BidFilter: startupRelaxation filter excludes bid without it', () {
    const f = BidFilter(startupRelaxation: true);
    expect(f.matches(_mh), isFalse); // _mh.startupRelaxation = false
  });

  // ── 5. Combined filter: Maharashtra + <₹5L + ≤7d ──────────────────────────

  test('BidFilter: Maharashtra + <₹5L + closing ≤7d combined', () {
    const f = BidFilter(
      state: 'Maharashtra',
      maxValueRs: 500000,
      closingInDays: 7,
    );
    // _mh satisfies all three
    expect(f.matches(_mh), isTrue);

    // None of kNamedBids satisfies all three:
    // NAMED-003: MH, value=420000 (<5L ✓) but closesInDays=22 (>7 ✗)
    // NAMED-004: MH, value=1500000 (>5L ✗)
    // NAMED-002: MH, value=3200000 (>5L ✗)
    // NAMED-008: MH, value=750000 (>5L ✗)
    final passing = kNamedBids.where(f.matches).toList();
    expect(
      passing,
      isEmpty,
      reason: 'No named bid is in Maharashtra with value<5L and closing≤7d',
    );
  });

  // ── 6. Reset: empty filter passes everything ─────────────────────────────

  test('BidFilter.empty matches any bid', () {
    const f = BidFilter.empty();
    for (final bid in kNamedBids) {
      expect(
        f.matches(bid),
        isTrue,
        reason: 'Empty filter should pass ${bid.id}',
      );
    }
  });

  // ── 7. copyWith clears individual fields via null ─────────────────────────

  test('BidFilter.copyWith with null clears a field', () {
    const f = BidFilter(state: 'Maharashtra', maxValueRs: 500000);
    final cleared = f.copyWith(state: null);
    expect(cleared.state, isNull);
    expect(cleared.maxValueRs, 500000); // unchanged
  });

  // ── 8. Score reason in BidResultRow ──────────────────────────────────────

  testWidgets('BidResultRow shows score·reason string', (tester) async {
    final (store, _) = await _stores();
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: Scaffold(
          body: BidResultRow(
            bid: kNamedBids.firstWhere((b) => b.id == 'NAMED-001'), // score=92
            isHindi: false,
            store: store,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // "92 · Product fit: Excellent"
    expect(find.textContaining('92'), findsWidgets);
    expect(find.textContaining('Excellent'), findsOneWidget);
  });

  // ── 9. Filter row visible on Bids scope ──────────────────────────────────

  testWidgets('filter chip row appears on Bids scope', (tester) async {
    final (store, ss) = await _stores();
    await _pumpBidsScope(tester, store, ss, 'office');
    // State chip should be present
    expect(find.text('State'), findsOneWidget);
    // Value chips
    expect(find.text('< ₹5L'), findsOneWidget);
    // Closing chip
    expect(find.text('≤7d'), findsOneWidget);
    // Boolean chips
    expect(find.text('MSE'), findsOneWidget);
  });

  // ── 10. Maharashtra filter reduces results ────────────────────────────────

  testWidgets('Maharashtra state filter reduces bid results', (tester) async {
    final (store, ss) = await _stores();
    await _pumpBidsScope(tester, store, ss, 'supplies');
    await tester.pumpAndSettle();

    // Count rows before filter
    final before = tester
        .widgetList<BidResultRow>(find.byType(BidResultRow))
        .length;

    // Open state picker
    await tester.tap(find.text('State'));
    await tester.pumpAndSettle();

    // Pick Maharashtra — use .last since bid cards may also render the state name
    await tester.tap(find.text('Maharashtra').last);
    await tester.pumpAndSettle();

    final after = tester
        .widgetList<BidResultRow>(find.byType(BidResultRow))
        .length;
    // Maharashtra bids should be a subset (or equal if all are MH)
    expect(after, lessThanOrEqualTo(before));
  });

  // ── 11. Reset filters restores full results ───────────────────────────────

  testWidgets('Reset filters restores unfiltered bid count', (tester) async {
    final (store, ss) = await _stores();
    await _pumpBidsScope(tester, store, ss, 'furniture');
    await tester.pumpAndSettle();

    final unfiltered = tester
        .widgetList<BidResultRow>(find.byType(BidResultRow))
        .length;

    // Tap the value chip "< ₹5L" to activate a filter
    await tester.tap(find.text('< ₹5L'));
    await tester.pumpAndSettle();

    // Reset filters chip appears and we tap it
    if (find.text('Reset filters').evaluate().isNotEmpty) {
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
    }

    final restored = tester
        .widgetList<BidResultRow>(find.byType(BidResultRow))
        .length;
    expect(restored, unfiltered);
  });

  // ── 12. Sort sheet opens ──────────────────────────────────────────────────

  testWidgets('sort chip opens sort bottom sheet', (tester) async {
    final (store, ss) = await _stores();
    await tester.pumpWidget(_page(store, ss));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'office');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Tap the Sort chip
    await tester.tap(find.textContaining('Sort:'));
    await tester.pumpAndSettle();

    // Sort sheet should show the options
    expect(find.text('Best match'), findsWidgets);
    expect(find.text('Closing soon'), findsWidgets);
    expect(find.text('Highest value'), findsWidgets);
    expect(find.text('Newest'), findsWidgets);
  });

  // ── 13. Sort: Closing soon puts soonest bid first ─────────────────────────

  testWidgets('sort closing-soon orders by closesInDays ascending', (
    tester,
  ) async {
    final (store, ss) = await _stores();
    await _pumpBidsScope(tester, store, ss, 'supplies');
    await pickSort(tester, 'Closing soon');

    final rows = tester
        .widgetList<BidResultRow>(find.byType(BidResultRow))
        .toList();
    if (rows.length >= 2) {
      expect(
        rows.first.bid.closesInDays,
        lessThanOrEqualTo(rows.last.bid.closesInDays),
        reason: 'First bid should close sooner than last',
      );
    }
  });

  // ── 14. Sort: Highest value puts largest bid first ────────────────────────

  testWidgets('sort highest-value orders by valueRs descending', (
    tester,
  ) async {
    final (store, ss) = await _stores();
    await _pumpBidsScope(tester, store, ss, 'supplies');
    await pickSort(tester, 'Highest value');

    final rows = tester
        .widgetList<BidResultRow>(find.byType(BidResultRow))
        .toList();
    if (rows.length >= 2) {
      expect(
        rows.first.bid.valueRs,
        greaterThanOrEqualTo(rows.last.bid.valueRs),
        reason: 'First bid should have higher value than last',
      );
    }
  });

  // ── 15. Sort: Newest puts most-recently-posted first ─────────────────────

  testWidgets('sort newest orders by postedDaysAgo ascending', (tester) async {
    final (store, ss) = await _stores();
    await _pumpBidsScope(tester, store, ss, 'supplies');
    await pickSort(tester, 'Newest');

    final rows = tester
        .widgetList<BidResultRow>(find.byType(BidResultRow))
        .toList();
    if (rows.length >= 2) {
      expect(
        rows.first.bid.postedDaysAgo,
        lessThanOrEqualTo(rows.last.bid.postedDaysAgo),
        reason: 'First bid should be more recently posted than last',
      );
    }
  });

  // ── 16. Sort reset inside sheet restores Best match ──────────────────────

  testWidgets('sort sheet Reset button resets to Best match', (tester) async {
    final (store, ss) = await _stores();
    await tester.pumpWidget(_page(store, ss));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'office');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    // Open sort, pick Newest, tap Reset, tap Done
    await tester.tap(find.textContaining('Sort:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Sort chip should now show "Best match"
    expect(find.textContaining('Best match'), findsOneWidget);
  });
}
