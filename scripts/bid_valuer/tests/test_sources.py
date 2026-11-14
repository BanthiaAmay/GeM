from pathlib import Path
import unittest

from bid_valuer import select as selection
from bid_valuer.items import Item
from bid_valuer.matching import scoring
from bid_valuer.sources import base, indiamart
from bid_valuer.sources.other_suppliers import ConfiguredSite, item_query

FIXTURES = Path(__file__).parent / 'fixtures'
PRODUCT_PAGE = '''<html><head><script type="application/ld+json">
{"@context": "https://schema.org", "@graph": [{"@type": "Product", "name": "Acme LED Street Light 36W",
 "brand": {"@type": "Brand", "name": "Acme"}, "mpn": "AS-36",
 "offers": {"@type": "Offer", "price": "2,450.00", "priceCurrency": "INR",
  "url": "/p/as-36", "seller": {"@type": "Organization", "name": "Acme Lighting Pvt Ltd"},
  "priceSpecification": {"@type": "UnitPriceSpecification", "price": 2450,
   "priceCurrency": "INR", "valueAddedTaxIncluded": true, "unitText": "Piece"}}}]}
</script></head><body></body></html>'''


class Response:
    def __init__(self, status=200, text='', headers=None):
        self.status_code, self.text, self.headers = status, text, headers or {}


class FakeClient:
    def __init__(self, pages):
        self.pages, self.calls = pages, []

    def get(self, url):
        self.calls.append(url)
        page = self.pages.get(url, Response(404))
        return page.pop(0) if isinstance(page, list) else page


def http(pages):
    clock = iter(range(0, 10000, 5))
    return base.PoliteHttp(client=FakeClient(pages), clock=lambda: next(clock), sleep=lambda s: None)


class IndiaMartParser(unittest.TestCase):
    def test_real_category_page(self):
        offers = indiamart.parse((FIXTURES / 'indiamart_office_chairs.html').read_text())
        self.assertEqual(len(offers), 6)
        first = offers[0]
        self.assertEqual((first.listed_price, first.currency, first.listed_unit), (2000.0, 'INR', 'Piece'))
        self.assertEqual((first.brand, first.model), ('labycare', 'SKSS182OC'))
        self.assertEqual(first.seller_name, 'S.K. Scientific And Surgicals')
        self.assertTrue(first.source_url.startswith('https://www.indiamart.com/proddetail/'))
        self.assertIsNone(first.gst_included, 'IndiaMART does not state GST; never assumed')

    def test_unrelated_html(self):
        self.assertEqual(indiamart.parse('<html>nothing</html>'), [])

    def test_category_slugs(self):
        slugs = indiamart.category_slugs(Item('Office Chair', 1, 'Nos'))
        self.assertEqual(slugs[:2], ['office-chair', 'office-chairs'])
        long = indiamart.category_slugs(Item('LED Luminaire For Road And Street Lights Conforming To IS', 1, 'Nos'))
        self.assertNotIn('conforming', ' '.join(long))


class JsonLd(unittest.TestCase):
    def test_schema_org_product(self):
        offers = base.products_from_jsonld(PRODUCT_PAGE, 'https://acme.example.in/search', 'manufacturer:acme')
        self.assertEqual(len(offers), 1)
        o = offers[0]
        self.assertEqual((o.listed_price, o.currency, o.gst_included, o.listed_unit), (2450.0, 'INR', True, 'Piece'))
        self.assertEqual((o.brand, o.model, o.seller_name), ('Acme', 'AS-36', 'Acme Lighting Pvt Ltd'))
        self.assertEqual(o.source_url, 'https://acme.example.in/p/as-36')
        item = Item('LED Street Light', 10, 'Nos', spec={'System Wattage (in Watt)': '36'})
        self.assertTrue(scoring.score(item, o).accepted)

    def test_missing_currency_stays_unknown(self):
        page = PRODUCT_PAGE.replace('"priceCurrency": "INR",', '').replace(',\n   "priceCurrency": "INR"', '')
        self.assertIsNone(base.products_from_jsonld(page, 'https://x.in/', 's')[0].currency)


class Politeness(unittest.TestCase):
    def test_robots_disallow_is_respected(self):
        h = http({'https://shop.in/robots.txt': Response(200, 'User-agent: *\nDisallow: /search')})
        with self.assertRaises(base.SourceDisallowed):
            h.get('https://shop.in/search?q=chair')
        self.assertEqual(h.client.calls, ['https://shop.in/robots.txt'])

    def test_challenge_page_blocks_and_is_not_retried(self):
        h = http({'https://shop.in/robots.txt': Response(404),
                  'https://shop.in/p': Response(200, '<title>Just a moment</title> verify you are human')})
        with self.assertRaises(base.SourceBlocked):
            h.get('https://shop.in/p')
        self.assertEqual(h.client.calls.count('https://shop.in/p'), 1)

    def test_403_is_blocked_and_429_backs_off(self):
        h = http({'https://shop.in/robots.txt': Response(404), 'https://shop.in/a': Response(403),
                  'https://shop.in/b': [Response(429, headers={'Retry-After': '2'}), Response(200, 'ok')]})
        with self.assertRaises(base.SourceBlocked):
            h.get('https://shop.in/a')
        self.assertEqual(h.get('https://shop.in/b'), 'ok')

    def test_one_identifiable_user_agent(self):
        h = base.PoliteHttp(contact='https://bid2scale.example/contact', client=FakeClient({}))
        self.assertEqual(h.user_agent, 'Bid2ScaleValuer/1.0 (+https://bid2scale.example/contact)')

    def test_crawl_delay_is_honoured(self):
        sleeps = []
        clock = iter(range(0, 1000))
        h = base.PoliteHttp(client=FakeClient({'https://slow.in/robots.txt': Response(200, 'User-agent: *\nCrawl-delay: 10'),
                                               'https://slow.in/1': Response(200, 'a'),
                                               'https://slow.in/2': Response(200, 'b')}),
                            clock=lambda: next(clock), sleep=sleeps.append)
        h.get('https://slow.in/1')
        h.get('https://slow.in/2')
        self.assertTrue(any(s >= 8 for s in sleeps), sleeps)


class ConfiguredSites(unittest.TestCase):
    def test_disabled_without_search_url(self):
        self.assertFalse(ConfiguredSite(None, 'x', {'enabled': True, 'search_url': ''}).enabled)
        self.assertFalse(ConfiguredSite(None, 'x', {'search_url': 'http://insecure/{query}'}).enabled)

    def test_search_reads_product_markup(self):
        h = http({'https://acme.example.in/robots.txt': Response(404),
                  'https://acme.example.in/search?q=Acme+AS-36': Response(200, PRODUCT_PAGE)})
        site = ConfiguredSite(h, 'manufacturer:acme', {'search_url': 'https://acme.example.in/search?q={query}'})
        item = Item('LED Street Light', 1, 'Nos', brand='Acme', model='AS-36')
        self.assertEqual(item_query(item), 'Acme AS-36')
        self.assertEqual(len(site.search(item)), 1)


class FakeGem:
    def __init__(self, found):
        self.found = found

    def search(self, query='', status_type=''):
        return 1, ([{'b_bid_number': [query]}] if query in self.found else [])


class Cancellation(unittest.TestCase):
    bids = [{'id': str(i), 'source_id': f'GEM/2026/B/{i}'} for i in range(4)]

    def test_marks_missing_bids_when_the_lookup_works(self):
        open_bids, cancelled = selection.split_cancelled(FakeGem({'GEM/2026/B/0', 'GEM/2026/B/1', 'GEM/2026/B/2'}),
                                                         self.bids, log=lambda *_: None)
        self.assertEqual([b['id'] for b in cancelled], ['3'])
        self.assertEqual(len(open_bids), 3)

    def test_never_cancels_everything_when_the_lookup_finds_nothing(self):
        open_bids, cancelled = selection.split_cancelled(FakeGem(set()), self.bids, log=lambda *_: None)
        self.assertEqual((len(open_bids), cancelled), (4, []))

    def test_gem_id(self):
        self.assertEqual(selection.gem_id('https://bidplus.gem.gov.in/showbidDocument/10066074'), 10066074)


if __name__ == '__main__':
    unittest.main()
