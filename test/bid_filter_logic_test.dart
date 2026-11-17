import 'package:flutter_test/flutter_test.dart';
import 'package:gem/features/bid_filter.dart';

void main() {
  // Three sample bids covering distinct title/org/buyer/id text
  final bids = <Map<String, dynamic>>[
    {
      'source_id': 'GEM/2026/B/001',
      'title': 'Office Furniture Supply',
      'organisation': 'Ministry of Finance',
      'buyer': 'DGS&D',
      'details': <String, dynamic>{},
      'closes_at': '2027-01-01T00:00:00Z',
      'state': '',
      'ministry': '',
    },
    {
      'source_id': 'GEM/2026/B/002',
      'title': 'Medical Equipment Procurement',
      'organisation': 'AIIMS Delhi',
      'buyer': 'AIIMS Procurement Cell',
      'details': <String, dynamic>{},
      'closes_at': '2027-02-01T00:00:00Z',
      'state': '',
      'ministry': '',
    },
    {
      'source_id': 'GEM/2026/B/003',
      'title': 'Computer Hardware',
      'organisation': 'NIC',
      'buyer': 'Ministry of IT',
      'details': <String, dynamic>{},
      'closes_at': '2027-03-01T00:00:00Z',
      'state': '',
      'ministry': '',
    },
  ];

  group('BidFilterLogic — search term filtering', () {
    test('empty search returns all bids', () {
      final result = BidFilterLogic.apply(bids, BidFilterState.empty);
      expect(result.length, 3);
    });

    test('search matches title (case-insensitive)', () {
      final result = BidFilterLogic.apply(
        bids,
        const BidFilterState(searchQuery: 'furniture'),
      );
      expect(result.length, 1);
      expect(result.first['source_id'], 'GEM/2026/B/001');
    });

    test('search matches source_id substring', () {
      final result = BidFilterLogic.apply(
        bids,
        const BidFilterState(searchQuery: 'B/002'),
      );
      expect(result.length, 1);
      expect(result.first['title'], 'Medical Equipment Procurement');
    });

    test('search matches organisation (case-insensitive)', () {
      final result = BidFilterLogic.apply(
        bids,
        const BidFilterState(searchQuery: 'aiims'),
      );
      expect(result.length, 1);
      expect(result.first['source_id'], 'GEM/2026/B/002');
    });

    test('search matches buyer', () {
      final result = BidFilterLogic.apply(
        bids,
        const BidFilterState(searchQuery: 'ministry of it'),
      );
      expect(result.length, 1);
      expect(result.first['source_id'], 'GEM/2026/B/003');
    });

    test('no match returns empty list', () {
      final result = BidFilterLogic.apply(
        bids,
        const BidFilterState(searchQuery: 'xyz_nonexistent_query_123'),
      );
      expect(result, isEmpty);
    });

    test('partial match across multiple bids', () {
      // 'ministry' appears in org of bid/001 AND buyer of bid/003
      final result = BidFilterLogic.apply(
        bids,
        const BidFilterState(searchQuery: 'ministry'),
      );
      expect(result.length, 2);
      final ids = result.map((b) => b['source_id'] as String).toSet();
      expect(ids, containsAll(['GEM/2026/B/001', 'GEM/2026/B/003']));
    });
  });
}
