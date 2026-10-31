/// Phase 2 engine tests.
///
/// Verifies that the search index surfaces the correct items for key queries,
/// that every tool is indexed with a valid route, and that a large index is
/// fast enough for interactive use.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:gem/features/search/search_content.dart';
import 'package:gem/features/search/search_engine.dart';
import 'package:gem/features/search/search_index.dart';
import 'package:gem/features/search/search_models.dart';
import 'package:gem/features/tools_hub/tool_registry.dart';

void main() {
  // Build a shared full index once for all tests.
  late SearchIndex index;
  late SearchEngine engine;

  setUpAll(() {
    index = SearchIndex.instance;
    engine = SearchEngine(index: index);
  });

  // ── Test 1: "bank guarantee" ─────────────────────────────────────────────

  test(
    '"bank guarantee" returns gem101-m3, fin-bg, and BG bids (NAMED-002, NAMED-005)',
    () {
      final results = engine.query('bank guarantee');
      final ids = results.map((r) => r.id).toSet();

      expect(ids, contains('gem101-m3'), reason: 'GeM 101 BG lesson not found');
      expect(
        ids,
        contains('fin-bg'),
        reason: 'Financial Hub BG option not found',
      );
      expect(
        ids,
        contains('NAMED-002'),
        reason: 'IT hardware BG bid not found',
      );
      expect(
        ids,
        contains('NAMED-005'),
        reason: 'LED tube lights BG bid not found',
      );
    },
  );

  // ── Test 2: "LED tube light" ─────────────────────────────────────────────

  test('"LED tube light" returns NAMED-005 bid and cat-it category', () {
    final results = engine.query('LED tube light');
    final ids = results.map((r) => r.id).toSet();

    expect(ids, contains('NAMED-005'), reason: 'LED tube lights bid not found');
    expect(ids, contains('cat-it'), reason: 'IT/lighting category not found');
  });

  // ── Test 3: HSN code "9405" ──────────────────────────────────────────────

  test('"9405" returns NAMED-005 bid and cat-it category', () {
    final results = engine.query('9405');
    final ids = results.map((r) => r.id).toSet();

    expect(
      ids,
      contains('NAMED-005'),
      reason: 'NAMED-005 (HSN 9405) not found',
    );
    expect(
      ids,
      contains('cat-it'),
      reason: 'cat-it (HSN 9405 keyword) not found',
    );
  });

  // ── Test 4: All kTools are indexed with a non-empty route ────────────────

  test('Every kTools entry is indexed with a valid route', () {
    final indexedIds = index.items.map((i) => i.id).toSet();
    for (final tool in kTools) {
      expect(
        indexedIds,
        contains(tool.route),
        reason:
            'Tool "${tool.titleEn}" (route: ${tool.route}) missing from index',
      );
      expect(
        tool.route.isNotEmpty,
        isTrue,
        reason: 'Tool "${tool.titleEn}" has an empty route',
      );
    }
  });

  // ── Test 5: 1,000-item index query under 50 ms ───────────────────────────

  test('1,000-item index: query completes in < 50 ms', () {
    // Build a synthetic 1,000-item index using the calculator template.
    final items = List.generate(
      1000,
      (i) => SearchItem(
        id: 'perf-$i',
        type: SearchType.calculator,
        titleEn: 'Test item $i',
        titleHi: 'परीक्षण आइटम $i',
        subtitleEn: 'Performance test item number $i',
        subtitleHi: 'प्रदर्शन परीक्षण आइटम $i',
        keywords: [
          'test',
          'item',
          'performance',
          'bank',
          'guarantee',
          'led',
          '9405',
        ],
        route: 'home',
        actionEn: 'Open',
        actionHi: 'खोलें',
      ),
    );
    final largeIndex = SearchIndex.withItems(items);
    final largeEngine = SearchEngine(index: largeIndex);

    final sw = Stopwatch()..start();
    largeEngine.query('bank guarantee');
    sw.stop();

    expect(
      sw.elapsedMilliseconds,
      lessThan(50),
      reason:
          '1,000-item query took ${sw.elapsedMilliseconds} ms (limit: 50 ms)',
    );
  });

  // ── Regression: all static content lists have non-empty IDs and routes ──

  test(
    'kLessons, kFinanceItems, kCalculators, kCategories, kFaqs are well-formed',
    () {
      for (final item in [
        ...kLessons,
        ...kFinanceItems,
        ...kCalculators,
        ...kCategories,
        ...kFaqs,
      ]) {
        expect(
          item.id.isNotEmpty,
          isTrue,
          reason: 'Empty id in ${item.runtimeType}',
        );
        expect(
          item.route.isNotEmpty,
          isTrue,
          reason: 'Empty route for ${item.id}',
        );
        expect(
          item.titleEn.isNotEmpty,
          isTrue,
          reason: 'Empty titleEn for ${item.id}',
        );
      }
    },
  );
}
