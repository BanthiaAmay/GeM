from datetime import datetime, timedelta, timezone
import unittest

from bid_valuer import prices, value
from bid_valuer.database.cache import MemoryCache
from bid_valuer.items import Extraction, Item
from bid_valuer.prices import StoredOffer
from bid_valuer.sources.base import Offer, PriceSource, SourceBlocked

NOW = datetime(2026, 11, 14, 6, 0, tzinfo=timezone.utc)
ITEM = Item('LED Street Light', 10, 'Nos', spec={'System Wattage (in Watt)': '36'})
KEY = prices.query_key(ITEM)


def stored(url, price, *, age_days=0, seller='', currency='INR', basis='gst_inclusive',
           score=0.9, source='indiamart', ident=None):
    return StoredOffer(ident or url, KEY, source, url, price, price, basis, currency, score,
                       NOW - timedelta(days=age_days), NOW - timedelta(days=age_days + 10),
                       seller_name=seller, seller_key=f'name:{seller}' if seller else '')


class FakeSource(PriceSource):
    def __init__(self, name, offers=(), error=None):
        super().__init__(None)
        self.name, self.offers, self.error, self.calls = name, list(offers), error, 0

    def search(self, item):
        self.calls += 1
        if self.error:
            raise self.error
        return self.offers


def listing(url, price, seller):
    return Offer('gem_marketplace', url, 'LED Street Light 36W', price, 'INR', 'Piece',
                 seller_name=seller, gst_included=True)


class PriceItem(unittest.TestCase):
    def test_reliability_tiers(self):
        three = [stored(f'https://a.in/{i}', p, seller=f's{i}') for i, p in enumerate((100, 110, 120))]
        self.assertEqual(prices.price_item(ITEM, three, NOW).price_reliability, 'normal')
        self.assertEqual(prices.price_item(ITEM, three[:2], NOW).price_reliability, 'reduced')
        one = prices.price_item(ITEM, three[:1], NOW)
        self.assertEqual((one.price_reliability, one.unit_price), ('provisional', 100))
        self.assertFalse(prices.price_item(ITEM, [], NOW).priced)

    def test_same_seller_counts_once_across_domains(self):
        offers = [stored('https://www.indiamart.com/p1', 100, seller='Acme Traders'),
                  stored('https://acme.example.in/p1', 104, seller='Acme Traders', source='manufacturers'),
                  stored('https://b.in/x', 110, seller='Beta Stores')]
        result = prices.price_item(ITEM, offers, NOW)
        self.assertEqual(len(result.offer_ids), 2)
        self.assertEqual(result.price_reliability, 'reduced')

    def test_non_inr_and_unknown_gst_never_reach_the_median(self):
        offers = [stored('https://a.in/1', 100, seller='a'),
                  stored('https://b.com/1', 5, seller='b', currency='USD'),
                  stored('https://c.in/1', 9000, seller='c', basis='unknown'),
                  stored('https://d.in/1', 9000, seller='d', basis='gst_exclusive'),
                  stored('https://e.in/1', 9000, seller='e', currency='XXX')]
        result = prices.price_item(ITEM, offers, NOW)
        self.assertEqual((result.unit_price, result.offer_ids), (100, ['https://a.in/1']))
        evidence_only = prices.price_item(ITEM, offers[1:], NOW)
        self.assertFalse(evidence_only.priced)
        self.assertIn('evidence', evidence_only.reason)

    def test_outliers_dropped(self):
        offers = [stored(f'https://a.in/{i}', p, seller=f's{i}') for i, p in enumerate((100, 105, 110, 900))]
        result = prices.price_item(ITEM, offers, NOW)
        self.assertEqual(result.unit_price, 105)
        self.assertEqual(len(result.offer_ids), 3)

    def test_stale_offer_excluded_even_if_previously_accepted(self):
        old = stored('https://a.in/old', 100, age_days=4, seller='a')
        self.assertFalse(prices.price_item(ITEM, [old], NOW).priced)


class CollectOffers(unittest.TestCase):
    def test_fresh_cache_is_reused_without_fetching_or_reverification(self):
        cached = [stored(f'https://a.in/{i}', 100 + i, seller=f's{i}', source='gem_marketplace', age_days=1)
                  for i in range(3)]
        cache = MemoryCache(cached)
        source = FakeSource('gem_marketplace', [listing('https://a.in/0', 999, 's0')])
        _, offers, _ = prices.collect_offers(ITEM, [source], cache, NOW, log=lambda *_: None)
        self.assertEqual(source.calls, 0)
        self.assertEqual({o.last_verified_at for o in offers}, {NOW - timedelta(days=1)},
                         'reusing a cached offer must not reset its verification date')

    def test_fresh_source_not_reread_while_next_source_is_tried(self):
        cache = MemoryCache([stored('https://g.in/1', 2400, seller='g1', source='gem_marketplace', age_days=2)])
        gem = FakeSource('gem_marketplace', [listing('https://g.in/2', 2500, 'g2')])
        other = FakeSource('indiamart', [listing('https://i.in/1', 2450, 'i1')])
        _, offers, _ = prices.collect_offers(ITEM, [gem, other], cache, NOW, log=lambda *_: None)
        self.assertEqual((gem.calls, other.calls), (0, 1))
        self.assertEqual(len(offers), 2)

    def test_stale_offer_excluded_when_source_is_blocked(self):
        old = stored('https://a.in/old', 100, age_days=4, seller='a', source='gem_marketplace')
        cache = MemoryCache([old])
        blocked = FakeSource('gem_marketplace', error=SourceBlocked('challenge page'))
        _, offers, notes = prices.collect_offers(ITEM, [blocked], cache, NOW, log=lambda *_: None)
        self.assertEqual(blocked.calls, 1, 'a stale source is read again')
        self.assertEqual(offers[0].last_verified_at, NOW - timedelta(days=4),
                         'a failed refresh leaves the old verification date')
        self.assertIn('challenge page', notes[0])
        self.assertFalse(prices.price_item(ITEM, offers, NOW).priced,
                         'the stale offer is kept as evidence but never prices the item')

    def test_successful_refresh_updates_verification_but_not_first_seen(self):
        old = stored('https://a.in/0', 100, age_days=4, seller='s0', source='gem_marketplace')
        first_seen = old.first_seen_at
        cache = MemoryCache([old])
        source = FakeSource('gem_marketplace', [listing('https://a.in/0', 2400, 's0')])
        _, offers, _ = prices.collect_offers(ITEM, [source], cache, NOW, log=lambda *_: None)
        refreshed = next(o for o in offers if o.source_url == 'https://a.in/0')
        self.assertEqual((refreshed.last_verified_at, refreshed.first_seen_at), (NOW, first_seen))
        self.assertEqual(refreshed.id, old.id)
        self.assertEqual(refreshed.listed_price, 2400)

    def test_sources_in_priority_order_until_three_independent_offers(self):
        first = FakeSource('gem_marketplace', [listing(f'https://g.in/{i}', 2400 + i, f'g{i}') for i in range(3)])
        second = FakeSource('indiamart', [listing('https://i.in/1', 2500, 'i1')])
        cache = MemoryCache()
        _, offers, _ = prices.collect_offers(ITEM, [first, second], cache, NOW, log=lambda *_: None)
        self.assertEqual((first.calls, second.calls), (1, 0))
        self.assertEqual(prices.price_item(ITEM, offers, NOW).price_reliability, 'normal')
        # The same product in another bid this run is not fetched again.
        prices.collect_offers(ITEM, [first, second], cache, NOW, log=lambda *_: None)
        self.assertEqual(first.calls, 1)


class ValueBid(unittest.TestCase):
    def _items(self, *qtys):
        return [Item(f'Item {i}', q, 'Nos') for i, q in enumerate(qtys)]

    def test_zero_priced_bid(self):
        extraction = Extraction(self._items(5, 2), 'complete', [])
        miss = prices.ItemPrice(False, reason='no offer')
        _, valuation = value.value_bid(extraction, [miss, miss])
        self.assertEqual(valuation['priced_value_inr'], 0)
        self.assertIsNone(valuation['match_confidence'])
        self.assertIsNone(valuation['price_reliability'])
        self.assertEqual((valuation['confidence'], valuation['complete']), ('low', False))
        self.assertEqual(valuation['confidence_factors']['rule'], 'no priced items')

    def test_complete_requires_every_item_priced(self):
        extraction = Extraction(self._items(10, 2), 'complete', [])
        p1 = prices.ItemPrice(True, 100.0, 0.9, 'normal', ['a'])
        p2 = prices.ItemPrice(True, 1000.0, 0.8, 'provisional', ['b'])
        items, valuation = value.value_bid(extraction, [p1, p2])
        self.assertTrue(valuation['complete'])
        self.assertEqual(valuation['priced_value_inr'], 3000)
        # Line-value weighted: (1000*0.9 + 2000*0.8) / 3000
        self.assertAlmostEqual(valuation['match_confidence'], 0.833, places=3)
        self.assertAlmostEqual(valuation['price_reliability'], (1000 * 1 + 2000 * 0.4) / 3000, places=3)
        self.assertEqual(items[1]['line_value'], 2000)
        _, partial = value.value_bid(extraction, [p1, prices.ItemPrice(False, reason='x')])
        self.assertFalse(partial['complete'])
        self.assertEqual(partial['priced_value_inr'], 1000)
        self.assertIn('1 item(s) unpriced', partial['incomplete_reason'])

    def test_incomplete_extraction_is_never_complete(self):
        extraction = Extraction(self._items(1), 'incomplete', [{'code': 'declared_quantity_mismatch', 'detail': ''}])
        _, valuation = value.value_bid(extraction, [prices.ItemPrice(True, 50.0, 0.95, 'normal', ['a'])])
        self.assertFalse(valuation['complete'])
        self.assertEqual(valuation['priced_value_inr'], 50)

    def test_confidence_bands(self):
        self.assertEqual(value.confidence_band(1, 0.9, 1.0)[0], 'high')
        self.assertEqual(value.confidence_band(0.8, 0.8, 0.7)[0], 'medium')
        self.assertEqual(value.confidence_band(1, 0.9, 0.4)[0], 'low')


if __name__ == '__main__':
    unittest.main()
