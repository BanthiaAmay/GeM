from datetime import datetime
import io
import json
from pathlib import Path
import re
import unittest
from urllib.error import HTTPError
from urllib.parse import parse_qs

from gem_source import (IST, GemClient, GemError, document_links, enrich, gem_time,
                        listing_record, parse_document_text, state_from)

FIXTURE = (Path(__file__).parent / 'fixtures' / 'gem_bid_document.txt').read_text()


def pypdf_layout(text):
    """pypdf puts each Hindi word on its own (doubled) line and the English
    label after a slash on the next line; reproduce that from the fixture."""
    out = []
    for line in text.splitlines():
        hindi = [m.end() for m in re.finditer('[ऀ-ॿ]', line)]
        if not hindi:
            out.append(line)
            continue
        for word in line[:hindi[-1]].split():
            out += [word, word, ' ']
        if line[hindi[-1]:].strip():
            out.append(line[hindi[-1]:].strip())
    return '\n'.join(out)


def listing_doc(number='GEM/2026/B/8187525', **overrides):
    doc = {'b_id': [10066074], 'b_bid_number': [number],
           'b_category_name': ['LED Luminaire For Road And Street Lights'],
           'bd_category_name': ['LED Luminaire For Road And Street Lights Conforming To IS 10322'],
           'b_total_quantity': [156], 'b_type': [0], 'is_high_value': [False],
           'final_start_date_sort': ['2026-10-22T12:59:00Z'],
           'final_end_date_sort': ['2026-11-05T19:00:00Z'],
           'ba_official_details_deptName': ['Panchayats and Rural Housing Department Gujarat']}
    doc.update(overrides)
    return doc


class ListingTest(unittest.TestCase):
    def test_listing_times_are_ist_wall_clock(self):
        self.assertEqual(gem_time('2026-10-22T11:06:06Z'), datetime(2026, 10, 22, 11, 6, 6, tzinfo=IST))
        self.assertIsNone(gem_time(''))

    def test_normalizes_regular_bids_and_skips_reverse_auctions(self):
        record = listing_record(listing_doc())
        self.assertEqual(record['source_id'], 'GEM/2026/B/8187525')
        self.assertEqual(record['closes_at'], '2026-11-05T19:00:00+05:30')
        self.assertEqual(record['source_url'], 'https://bidplus.gem.gov.in/showbidDocument/10066074')
        self.assertEqual(record['state'], 'Gujarat')
        self.assertEqual(record['ministry'], '')
        self.assertEqual(record['quantity'], 156)
        self.assertTrue(record['title'].endswith('IS 10322'))
        self.assertIsNone(listing_record(listing_doc('GEM/2026/R/756866')))
        self.assertIsNone(listing_record(listing_doc(final_end_date_sort=[])))

    def test_state_names_follow_the_app_picker(self):
        self.assertEqual(state_from('Law Department Uttar Pradesh'), 'Uttar Pradesh')
        self.assertEqual(state_from('Ministry of Defence', 'Department of Military Affairs'), '')
        self.assertEqual(state_from('Government of Jammu & Kashmir'), 'Jammu and Kashmir')
        self.assertEqual(state_from('Orissa Police'), 'Odisha')
        self.assertEqual(state_from('', 'West Bengal Health Department'), 'West Bengal')


class DocumentTest(unittest.TestCase):
    def check_core_fields(self, fields):
        self.assertEqual(fields['ministry_state'], 'Gujarat')
        self.assertEqual(fields['bid_end'], '28-09-2026 19:00:00')
        self.assertEqual(fields['bid_opening'], '29-09-2026 19:00:00')
        self.assertEqual(fields['quantity'], 156)
        self.assertEqual(fields['item_category'], 'LED Luminaire For Road And Street Lights Conforming '
                         'To IS 10322 (Part 5/Section 3) (V3) (Under BIS Scheme - II) (Q2)')
        self.assertEqual(fields['experience'], '3 Year (s)')
        self.assertEqual(fields['oem_turnover'], '10 Lakh (s)')
        self.assertEqual(fields['documents_required'], [
            'Experience Criteria', 'Past Performance', 'Bidder Turnover',
            'Certificate (Requested in ATC)', 'OEM Authorization Certificate', 'OEM Annual Turnover'])
        self.assertEqual(fields['past_performance'], '80 %')
        self.assertEqual(fields['bid_type'], 'Two Packet Bid')
        self.assertEqual(fields['technical_clarification_time'], '2 Days')
        self.assertEqual(fields['emd_required'], 'No')
        self.assertIn('System Wattage (in Watt) 36', fields['specifications'])
        self.assertIn('Agency must have registration within Gujarat.', fields['atc'])
        self.assertNotIn('Disclaimer', fields['atc'])
        self.assertNotIn('5 / 8', fields['atc'])
        self.assertNotIn('organisation', fields)  # "N/a" is left out.

    def test_reads_the_bid_document_fields(self):
        self.check_core_fields(parse_document_text(FIXTURE))

    def test_reads_the_pypdf_text_layout_too(self):
        self.check_core_fields(parse_document_text(pypdf_layout(FIXTURE)))

    def test_missing_labels_are_left_out(self):
        self.assertEqual(parse_document_text('Unrelated text'), {})

    def test_keeps_only_official_links(self):
        links = document_links([
            'https://bidplus.gem.gov.in/bidding/bid/showCatalogue/abc',
            'https://bidplus.gem.gov.in/bidding/bid/showCatalogue/abc',
            'https://admin.gem.gov.in/apis/v1/gtc/pdfByDate/?date=20260918',
            'https://bidplus.gem.gov.in/resources/upload_nas/SepQ326/bidding/biddoc/bid-1/2.pdf',
            'https://gem.gov.in/', 'https://gem.gov.in.evil.test/file', 'http://bidplus.gem.gov.in/a'])
        self.assertEqual([link['kind'] for link in links], ['specification', 'terms', 'buyer_document'])

    def test_enrich_adds_document_details(self):
        record = enrich(listing_record(listing_doc(ba_official_details_deptName=['Rural Department'])),
                        FIXTURE, ['https://bidplus.gem.gov.in/bidding/bid/showCatalogue/abc'])
        self.assertEqual(record['state'], 'Gujarat')
        self.assertEqual(record['organisation'], '')
        self.assertTrue(record['category'].startswith('LED Luminaire'))
        self.assertEqual(record['details']['links'][0]['kind'], 'specification')
        self.assertEqual(record['details']['kind'], 'product')
        json.dumps(record)  # Stored as JSON as-is.


class FakeResponse(io.BytesIO):
    def __init__(self, body, status=200):
        super().__init__(body)
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeOpener:
    def __init__(self, *answers):
        self.answers, self.requests = list(answers), []

    def open(self, request, timeout):
        self.requests.append(request)
        status, body = self.answers.pop(0)
        if status >= 400:
            raise HTTPError(request.full_url, status, 'error', {}, io.BytesIO(body))
        return FakeResponse(body, status)


TOKEN_PAGE = (200, b"var x = {'csrf_bd_gem_nk': '0123456789abcdef0123456789abcdef'};")


class ClientTest(unittest.TestCase):
    def client(self, *answers):
        opener = FakeOpener(*answers)
        return GemClient(opener=opener, sleep=lambda s: None, clock=lambda: 0), opener

    def test_search_posts_the_session_token(self):
        data = {'code': 200, 'response': {'response': {'numFound': 1, 'docs': [listing_doc()]}}}
        client, opener = self.client(TOKEN_PAGE, (200, json.dumps(data).encode()))
        total, docs = client.search(end_from='2026-10-28')
        self.assertEqual((total, len(docs)), (1, 1))
        form = parse_qs(opener.requests[1].data.decode())
        self.assertEqual(form['csrf_bd_gem_nk'], ['0123456789abcdef0123456789abcdef'])
        self.assertEqual(json.loads(form['payload'][0])['filter']['byEndDate']['from'], '2026-10-28')

    def test_expired_session_is_renewed_once_and_no_results_is_empty(self):
        client, opener = self.client(TOKEN_PAGE, (403, b'forbidden'), TOKEN_PAGE,
                                     (404, b'{"code": 404, "message": "No data found"}'))
        self.assertEqual(client.search(), (0, []))
        self.assertEqual(len(opener.requests), 4)

    def test_server_errors_are_retried_then_reported(self):
        client, _ = self.client(TOKEN_PAGE, (500, b''), (502, b''), (503, b''))
        with self.assertRaises(GemError):
            client.search()

    def test_document_must_be_a_pdf(self):
        client, _ = self.client((200, b'<html>login</html>'))
        with self.assertRaises(GemError):
            client.document(1)
        client, _ = self.client((200, b'%PDF-1.4 ...'))
        self.assertTrue(client.document(1).startswith(b'%PDF'))


if __name__ == '__main__':
    unittest.main()
