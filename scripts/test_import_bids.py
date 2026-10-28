from datetime import datetime
import unittest
from import_bids import normalize


class ImportBidsTest(unittest.TestCase):
    def record(self, **overrides):
        return dict(source_id='TEST-1', title='Stationery',
                    closes_at='2026-11-15T17:00:00+05:30',
                    source_url='https://bidplus.gem.gov.in/test', **overrides)

    def test_normalizes_ist_and_keeps_source_identity(self):
        record = normalize(self.record())
        self.assertEqual(record['closes_at'], '2026-11-15T11:30:00+00:00')
        self.assertEqual(record['source_id'], 'TEST-1')
        self.assertIsNotNone(datetime.fromisoformat(record['fetched_at']).tzinfo)

    def test_rejects_non_official_sources_and_naive_dates(self):
        for url in ['https://gem.gov.in.evil.test/a', 'https://gem.gov.in@evil.test/a',
                    'http://gem.gov.in/a', 'https://evil.test/a']:
            record = self.record(); record['source_url'] = url
            with self.assertRaises(ValueError): normalize(record)
        record = self.record(); record['closes_at'] = '2026-11-15T17:00:00'
        with self.assertRaises(ValueError): normalize(record)


if __name__ == '__main__':
    unittest.main()
