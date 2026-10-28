from datetime import datetime, timedelta, timezone
import json
import unittest
from urllib.parse import unquote

from bid_worker import (postgres_safe, EMAIL_TEXT, PUSH_TEXT, build_email, build_whatsapp, send_emails,
                        send_whatsapp, FcmConfigError, build_message, classify_fcm_error, collect,
                        in_filter, in_quiet_hours, push, retry_at)
from gem_source import IST

NOW = datetime(2026, 10, 22, 7, 30, tzinfo=timezone.utc)  # 13:00 IST


def job(n, title='LED Street Light', state='Gujarat', closes='2026-11-05T13:30:00+00:00', attempts=1):
    return {'job_id': f'job-{n}', 'user_id': 'user-1', 'attempts': attempts, 'source_id': f'GEM/2026/B/{n}',
            'title': title, 'buyer': 'Rural Department', 'state': state, 'closes_at': closes}


class MessageTest(unittest.TestCase):
    def test_every_app_language_has_all_texts(self):
        self.assertEqual(set(PUSH_TEXT), {'en', 'hi', 'mr', 'bn', 'gu', 'pa', 'ta', 'te', 'kn'})
        for texts in PUSH_TEXT.values():
            self.assertEqual(len(texts), 6)
            self.assertIn('{n}', texts[1])
            self.assertIn('{date}', texts[2])

    def test_single_bid_message_shows_deadline_in_ist(self):
        message = build_message([job(1)], 'hi')
        self.assertEqual(message['title'], PUSH_TEXT['hi'][0])
        self.assertEqual(message['body'], 'LED Street Light · Gujarat · अंतिम समय 05/11 19:00')
        self.assertEqual(message['data'], {'route': '/alerts', 'bid': 'GEM/2026/B/1'})

    def test_several_bids_become_one_message(self):
        message = build_message([job(1), job(2, 'Office chairs'), job(3, 'Tables')], 'xx')
        self.assertEqual(message['title'], '3 new GeM bids for you')
        self.assertTrue(message['body'].endswith('+1 more'))

    def test_quiet_hours_are_ist(self):
        self.assertFalse(in_quiet_hours(NOW))
        self.assertTrue(in_quiet_hours(datetime(2026, 10, 22, 17, 0, tzinfo=timezone.utc)))  # 22:30 IST
        self.assertTrue(in_quiet_hours(datetime(2026, 10, 22, 1, 0, tzinfo=timezone.utc)))  # 06:30 IST

    def test_retry_backoff_is_capped(self):
        self.assertEqual(retry_at(NOW, 1), NOW + timedelta(minutes=5))
        self.assertEqual(retry_at(NOW, 10), NOW + timedelta(hours=2))

    def test_filters_quote_values(self):
        self.assertEqual(unquote(in_filter(['GEM/2026/B/1', 'a"b'])), 'in.("GEM/2026/B/1","a\\"b")')

    def test_fcm_errors(self):
        unregistered = json.dumps({'error': {'details': [{'errorCode': 'UNREGISTERED'}]}}).encode()
        self.assertEqual(classify_fcm_error(404, unregistered)[0], 'invalid')
        self.assertEqual(classify_fcm_error(503, b'')[0], 'retry')
        self.assertEqual(classify_fcm_error(400, b'{}')[0], 'failed')
        with self.assertRaises(FcmConfigError):
            classify_fcm_error(401, b'{}')


class FakeDb:
    def __init__(self, jobs=(), devices=None, known=()):
        self.jobs, self.devices, self.known = list(jobs), devices or {}, set(known)
        self.updates, self.deleted, self.saved, self.queued = [], [], [], []

    def rpc(self, name, args):
        if name in ('claim_push_jobs', 'claim_email_jobs', 'claim_whatsapp_jobs'):
            return self.jobs
        self.queued.append(args['p_bid_id'])
        return 1

    def devices_for(self, user_ids):
        return {u: self.devices[u] for u in user_ids if u in self.devices}

    def update_jobs(self, ids, values):
        self.updates.append((sorted(ids), values))

    def delete_device(self, token):
        self.deleted.append(token)

    def existing_source_ids(self, ids):
        return {i for i in ids if i in self.known}

    def upsert_bids(self, rows):
        self.saved.append(rows)
        return [{'id': f'id-{row["source_id"]}', 'source_id': row['source_id']} for row in rows]


class FakeSender:
    def __init__(self, *results):
        self.results, self.sent = list(results), []

    def send(self, token, message):
        self.sent.append((token, message))
        return self.results.pop(0)


class PushTest(unittest.TestCase):
    def run_push(self, db, sender, now=NOW):
        return push(db, lambda: sender, now=now, log=lambda *_: None)

    def test_one_grouped_notification_per_user(self):
        db = FakeDb([job(1), job(2)], {'user-1': [('token-1', 'ta')]})
        sender = FakeSender(('sent', 'projects/x/messages/1'))
        self.assertEqual(self.run_push(db, sender), 1)
        self.assertEqual(len(sender.sent), 1)
        self.assertEqual(sender.sent[0][1]['title'], PUSH_TEXT['ta'][1].format(n=2))
        self.assertEqual(db.updates[0][0], ['job-1', 'job-2'])
        self.assertEqual(db.updates[0][1]['status'], 'sent')

    def test_invalid_tokens_are_removed_and_retries_back_off(self):
        db = FakeDb([job(1)], {'user-1': [('stale', 'en'), ('busy', 'en')]})
        self.run_push(db, FakeSender(('invalid', 'gone'), ('retry', 'FCM 503')))
        self.assertEqual(db.deleted, ['stale'])
        self.assertEqual(db.updates[0][1]['status'], 'pending')

    def test_users_without_devices_are_cancelled(self):
        db = FakeDb([job(1)])
        self.run_push(db, FakeSender())
        self.assertEqual(db.updates[0][1]['status'], 'cancelled')

    def test_nothing_is_claimed_in_quiet_hours_or_without_credentials(self):
        db = FakeDb([job(1)], {'user-1': [('token', 'en')]})
        self.run_push(db, FakeSender(), now=datetime(2026, 10, 22, 18, 0, tzinfo=timezone.utc))
        self.assertEqual(push(db, lambda: None, now=NOW, log=lambda *_: None), 0)
        self.assertEqual(db.updates, [])


def listing(n, start):
    return {'b_id': [n], 'b_bid_number': [f'GEM/2026/B/{n}'], 'b_category_name': [f'Item {n}'],
            'final_start_date_sort': [start.astimezone(IST).strftime('%Y-%m-%dT%H:%M:%SZ')],
            'final_end_date_sort': ['2026-11-30T19:00:00Z'], 'ba_official_details_deptName': ['Dept']}


class FakeGem:
    def __init__(self, pages):
        self.pages, self.searches, self.documents = pages, [], []

    def search(self, page, end_from, end_to):
        self.searches.append((page, end_from, end_to))
        return 0, self.pages[page - 1] if page <= len(self.pages) else []

    def document(self, gem_id):
        self.documents.append(gem_id)
        raise __import__('gem_source').GemError('no document in tests')


class CollectTest(unittest.TestCase):
    def test_saves_only_recent_unknown_bids_and_queues_them(self):
        pages = [[listing(3, NOW - timedelta(minutes=5)), listing(2, NOW - timedelta(minutes=20))],
                 [listing(1, NOW - timedelta(hours=5))]]
        gem, db = FakeGem(pages), FakeDb(known=['GEM/2026/B/2'])
        collect(gem, db, now=NOW, lookback=timedelta(hours=3), max_pages=10, max_documents=5,
                log=lambda *_: None)
        self.assertEqual(gem.searches[0][1], '2026-10-28')  # Six days out, skipping auctions.
        self.assertEqual(len(gem.searches), 2)  # Stopped once bids were older than the lookback.
        refreshed, new = db.saved
        self.assertEqual([r['source_id'] for r in refreshed], ['GEM/2026/B/2'])
        self.assertNotIn('details', refreshed[0])
        self.assertEqual([r['source_id'] for r in new], ['GEM/2026/B/3'])
        self.assertEqual(new[0]['category'], '')
        self.assertEqual(db.queued, ['id-GEM/2026/B/3'])
        self.assertEqual(gem.documents, [3])

    def test_dry_run_writes_nothing(self):
        gem = FakeGem([[listing(3, NOW - timedelta(minutes=5))]])
        lines = []
        self.assertEqual(collect(gem, None, now=NOW, lookback=timedelta(hours=1), max_pages=3,
                                 max_documents=5, dry_run=True, log=lines.append), 1)
        self.assertIn('Nothing was written', lines[-1])


class EmailTest(unittest.TestCase):
    def email_job(self, n, **extra):
        return {**job(n), 'email': 'seller@example.com', 'language': 'hi',
                'source_url': f'https://bidplus.gem.gov.in/showbidDocument/{n}',
                'details': {'documents_required': ['OEM Authorization Certificate']}, **extra}

    def test_every_language_has_email_text(self):
        self.assertEqual(set(EMAIL_TEXT), set(PUSH_TEXT))

    def test_digest_lists_every_bid_escaped(self):
        message = build_email([self.email_job(1), self.email_job(2, title='Chairs <b>&</b> tables')], 'hi')
        self.assertEqual(message['subject'], PUSH_TEXT['hi'][1].format(n=2))
        self.assertIn('Chairs &lt;b&gt;&amp;&lt;/b&gt; tables', message['html'])
        self.assertIn('OEM Authorization Certificate', message['html'])
        self.assertIn('https://bidplus.gem.gov.in/showbidDocument/2', message['text'])

    def test_one_email_per_user(self):
        db = FakeDb([self.email_job(1), self.email_job(2)])
        mailer = FakeSender(('sent', 'email-1'))
        self.assertEqual(send_emails(db, lambda: mailer, now=NOW, log=lambda *_: None), 1)
        self.assertEqual(mailer.sent[0][0], 'seller@example.com')
        self.assertEqual(db.updates[0][1]['status'], 'sent')
        self.assertEqual(send_emails(db, lambda: None, now=NOW, log=lambda *_: None), 0)


class WhatsAppTest(unittest.TestCase):
    def test_template_variables_are_single_line(self):
        jobs = [job(1, title='LED\nStreet   Light', closes='2026-11-09T13:30:00+00:00'),
                job(2, closes='2026-11-05T13:30:00+00:00')]
        message = build_whatsapp(jobs, 'ta')
        self.assertEqual(message['language'], 'en')  # Tamil template not approved yet.
        self.assertEqual(message['params'][0], '2')
        self.assertEqual(message['params'][2], '05/11 19:00')  # Soonest deadline, IST.
        self.assertNotIn('\n', message['params'][1])

    def test_one_message_per_user(self):
        db = FakeDb([{**job(1), 'phone': '+919876543210', 'language': 'hi'}, {**job(2), 'phone': '+919876543210', 'language': 'hi'}])
        sender = FakeSender(('sent', 'wamid.1'))
        self.assertEqual(send_whatsapp(db, lambda: sender, now=NOW, log=lambda *_: None), 1)
        self.assertEqual(sender.sent[0][1]['language'], 'hi')
        self.assertEqual(db.updates[0][1]['status'], 'sent')


class StorageTest(unittest.TestCase):
    def test_pdf_control_characters_are_dropped(self):
        row = {'title': 'LED\x00 light', 'details': {'atc': ['a\x00b\x07c', 'line\nkept']}, 'quantity': 3}
        self.assertEqual(postgres_safe(row), {'title': 'LED light', 'details': {'atc': ['abc', 'line\nkept']}, 'quantity': 3})


if __name__ == '__main__':
    unittest.main()
