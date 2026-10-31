/// Phase 7 tests — saved searches, alert trigger, and question detection.
///
/// Covers:
///   1. saveSearch / isSaved / removeSaved round-trip.
///   2. renameSaved preserves order.
///   3. checkAlerts triggers on first call (sentinel −1 → any count > −1).
///   4. checkAlerts does NOT re-trigger when count is unchanged.
///   5. clearAlert marks query read; hasUnread goes false.
///   6. SearchEngine.isQuestion detects question-like queries.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gem/features/search/search_engine.dart';
import 'package:gem/features/search/search_index.dart';
import 'package:gem/features/search/search_store.dart';

void main() {
  // Set up a fresh in-memory SharedPreferences for each test.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── 1. saveSearch / isSaved / removeSaved ────────────────────────────────────

  test(
    'saveSearch adds query, isSaved returns true, removeSaved clears it',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SearchStore(prefs);

      expect(store.isSaved('office chair'), isFalse);

      await store.saveSearch('office chair');
      expect(store.isSaved('office chair'), isTrue);
      expect(store.saved, contains('office chair'));

      await store.removeSaved('office chair');
      expect(store.isSaved('office chair'), isFalse);
      expect(store.saved, isNot(contains('office chair')));
    },
  );

  // ── 2. renameSaved preserves position ────────────────────────────────────────

  test('renameSaved keeps the same slot in the list', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SearchStore(prefs);

    await store.saveSearch('b');
    await store.saveSearch('a'); // saved = ['a', 'b'] (newest first)

    await store.renameSaved('a', 'alpha');

    final list = store.saved;
    expect(list.first, equals('alpha'));
    expect(list[1], equals('b'));
    expect(list, isNot(contains('a')));
  });

  // ── 3. checkAlerts triggers on first call ────────────────────────────────────

  test('checkAlerts triggers for every saved search on first call', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SearchStore(prefs);
    final engine = SearchEngine(index: SearchIndex.instance);

    await store.saveSearch('office chair');

    final alerts = await store.checkAlerts(engine);
    // 'office chair' has some results → count > −1 → alert fired
    expect(alerts, contains('office chair'));
    expect(store.hasUnread, isTrue);
    expect(store.unreadAlerts, contains('office chair'));
  });

  // ── 4. checkAlerts does not re-trigger on unchanged count ────────────────────

  test(
    'checkAlerts does not re-trigger when match count is unchanged',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SearchStore(prefs);
      final engine = SearchEngine(index: SearchIndex.instance);

      await store.saveSearch('office chair');

      // First call always triggers.
      await store.checkAlerts(engine);
      await store.clearAllAlerts();

      // Second call with the same data → count unchanged → no new alerts.
      final alerts2 = await store.checkAlerts(engine);
      expect(alerts2, isEmpty);
      expect(store.hasUnread, isFalse);
    },
  );

  // ── 5. clearAlert marks single query read ────────────────────────────────────

  test(
    'clearAlert removes query from unreadAlerts; hasUnread goes false',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SearchStore(prefs);
      final engine = SearchEngine(index: SearchIndex.instance);

      await store.saveSearch('office chair');
      await store.checkAlerts(engine);

      expect(store.hasUnread, isTrue);

      await store.clearAlert('office chair');

      expect(store.unreadAlerts, isNot(contains('office chair')));
      expect(store.hasUnread, isFalse);
    },
  );

  // ── 6. SearchEngine.isQuestion detects question intent ───────────────────────

  group('SearchEngine.isQuestion', () {
    test('query with "?" is a question', () {
      expect(SearchEngine.isQuestion('Why was my bid rejected?'), isTrue);
    });

    test('query starting with "why" is a question', () {
      expect(SearchEngine.isQuestion('why was my tender rejected'), isTrue);
    });

    test('query with "how" is a question', () {
      expect(SearchEngine.isQuestion('how to register on GeM'), isTrue);
    });

    test('Hinglish "kya" is a question', () {
      expect(SearchEngine.isQuestion('kya MSME ko EMD dena padta hai'), isTrue);
    });

    test('Hinglish "kaise" is a question', () {
      expect(SearchEngine.isQuestion('kaise karein registration'), isTrue);
    });

    test('plain search term is NOT a question', () {
      expect(SearchEngine.isQuestion('office chair furniture'), isFalse);
    });

    test('product search is NOT a question', () {
      expect(SearchEngine.isQuestion('laptop procurement Delhi'), isFalse);
    });
  });
}
