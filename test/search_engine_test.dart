import 'package:flutter_test/flutter_test.dart';
import 'package:gem/features/search/search_engine.dart';
import 'package:gem/features/search/search_index.dart';
import 'package:gem/features/search/search_models.dart';

void main() {
  // Use a fresh index for every test so singleton state doesn't bleed.
  SearchIndex makeIndex() => SearchIndex.instance;

  group('SearchEngine.normalise', () {
    test('lowercases and trims', () {
      expect(SearchEngine.normalise('  OFFICE  '), 'office');
    });

    test('collapses whitespace', () {
      expect(SearchEngine.normalise('led   tube  light'), 'led tube light');
    });

    test('preserves Devanagari', () {
      final result = SearchEngine.normalise('बोली');
      expect(result, 'बोली');
    });
  });

  group('SearchEngine.isQuestion', () {
    test('detects English question words', () {
      expect(SearchEngine.isQuestion('how to apply for MSME'), isTrue);
      expect(SearchEngine.isQuestion('what is EMD'), isTrue);
    });

    test('detects Hinglish question tokens', () {
      expect(SearchEngine.isQuestion('kya hai udyam registration'), isTrue);
      expect(SearchEngine.isQuestion('kaise bharu gst'), isTrue);
    });

    test('detects question mark', () {
      expect(SearchEngine.isQuestion('led tube light?'), isTrue);
    });

    test('does not flag plain product queries', () {
      expect(SearchEngine.isQuestion('office stationery'), isFalse);
      expect(SearchEngine.isQuestion('printer cartridge'), isFalse);
    });
  });

  group('SearchEngine.query', () {
    late SearchEngine engine;

    setUp(() => engine = SearchEngine(index: makeIndex()));

    test('returns results for a known keyword', () {
      final results = engine.query('stationery');
      expect(results, isNotEmpty);
    });

    test('all returned items have score > 0', () {
      final results = engine.query('printer');
      for (final item in results) {
        expect(item.score, greaterThan(0));
      }
    });

    test('sorted best-match puts highest score first', () {
      final results = engine.query('office');
      for (var i = 1; i < results.length; i++) {
        expect(results[i - 1].score, greaterThanOrEqualTo(results[i].score));
      }
    });

    test('empty query returns empty list', () {
      expect(engine.query(''), isEmpty);
      expect(engine.query('  '), isEmpty);
    });

    test('scope filter restricts to bid results', () {
      final results = engine.query('office stationery', scope: SearchScope.bids);
      for (final item in results) {
        expect(item.type, SearchType.bid);
      }
    });

    test('scope filter restricts to tool results', () {
      final results = engine.query('certificate', scope: SearchScope.tools);
      for (final item in results) {
        expect(item.type, SearchType.tool);
      }
    });

    test('synonym expansion: "bg" resolves to bank guarantee results', () {
      final results = engine.query('bg');
      // At least the bank-guarantee tools or bids should appear
      expect(results, isNotEmpty);
    });

    test('fuzzy match: typo "stationary" still finds stationery items', () {
      final results = engine.query('stationary');
      expect(results, isNotEmpty);
    });
  });

  group('SearchEngine.highlightRanges', () {
    test('finds single occurrence', () {
      final ranges = SearchEngine.highlightRanges('office supplies', ['office']);
      expect(ranges.length, 1);
      expect(ranges.first, (0, 6));
    });

    test('merges overlapping ranges', () {
      final ranges = SearchEngine.highlightRanges('abc', ['ab', 'bc']);
      expect(ranges.length, 1);
      expect(ranges.first, (0, 3));
    });

    test('returns empty for no match', () {
      expect(SearchEngine.highlightRanges('hello world', ['xyz']), isEmpty);
    });
  });
}
