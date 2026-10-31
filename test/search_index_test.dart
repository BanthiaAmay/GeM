import 'package:flutter_test/flutter_test.dart';
import 'package:gem/features/search/search_index.dart';
import 'package:gem/features/search/search_models.dart';

void main() {
  group('SearchIndex', () {
    test('builds and contains items', () {
      final index = SearchIndex.instance;
      expect(index.items, isNotEmpty);
    });

    test('contains bid items from kNamedBids', () {
      final index = SearchIndex.instance;
      final bids = index.items.where((i) => i.type == SearchType.bid).toList();
      expect(bids.length, 8); // kNamedBids has 8 entries
    });

    test('contains tool items from kTools', () {
      final index = SearchIndex.instance;
      final tools = index.items
          .where((i) => i.type == SearchType.tool)
          .toList();
      expect(tools, isNotEmpty);
    });

    test('all items have non-empty id and route', () {
      for (final item in SearchIndex.instance.items) {
        expect(item.id, isNotEmpty);
        expect(item.route, isNotEmpty);
      }
    });

    test('all bid items have routeArg set', () {
      for (final item in SearchIndex.instance.items.where(
        (i) => i.type == SearchType.bid,
      )) {
        expect(item.routeArg, isNotNull);
        expect(item.routeArg, isNotEmpty);
      }
    });

    test('rebuild produces same count', () {
      final index = SearchIndex.instance;
      final count = index.items.length;
      index.build();
      expect(index.items.length, count);
    });
  });
}
