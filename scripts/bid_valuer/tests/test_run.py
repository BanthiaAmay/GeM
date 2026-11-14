import argparse
import io
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock
from urllib.error import HTTPError, URLError

from bid_valuer import run
from bid_valuer.database import supabase
from bid_valuer.sources.base import SourceBlocked, SourceUnavailable

ENV = {'SUPABASE_URL': 'https://example.supabase.co', 'SUPABASE_SERVICE_ROLE_KEY': 'service'}


class Lock(unittest.TestCase):
    def test_second_run_is_refused_while_the_first_holds_the_lock(self):
        path = Path(tempfile.mkdtemp()) / 'logs' / 'bid-valuer.lock'
        with run.run_lock(path) as first:
            self.assertTrue(first)
            with run.run_lock(path) as second:
                self.assertFalse(second)
        with run.run_lock(path) as again:
            self.assertTrue(again, 'the lock is released when the run ends')


class Response:
    def __init__(self, body=b'[]'):
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def read(self):
        return self.body


def http_error(code):
    return HTTPError('https://example.supabase.co/rest/v1/x', code, 'err', {}, io.BytesIO(b'{}'))


class SupabaseRetries(unittest.TestCase):
    def client(self, outcomes):
        calls, sleeps = [], []

        def urlopen(request, timeout=60):
            calls.append(request.full_url)
            outcome = outcomes.pop(0)
            if isinstance(outcome, Exception):
                raise outcome
            return outcome
        db = supabase.RetryingSupabase(ENV['SUPABASE_URL'], 'k', sleep=sleeps.append,
                                       log=lambda *_: None, urlopen=urlopen)
        return db, calls, sleeps

    def test_transient_errors_are_retried_with_backoff(self):
        db, calls, sleeps = self.client([http_error(503), URLError('timed out'), Response(b'[1]')])
        self.assertEqual(db.request('GET', 'gem_bids'), [1])
        self.assertEqual((len(calls), sleeps), (3, [1, 2]))

    def test_client_errors_are_not_retried(self):
        db, calls, sleeps = self.client([http_error(400)])
        with self.assertRaises(RuntimeError):
            db.request('GET', 'gem_bids')
        self.assertEqual((len(calls), sleeps), (1, []))

    def test_gives_up_after_four_retries(self):
        db, calls, sleeps = self.client([http_error(502)] * 5)
        with self.assertRaises(RuntimeError):
            db.request('GET', 'gem_bids')
        self.assertEqual(sleeps, [1, 2, 4, 8])


class FakeDb:
    def __init__(self, bids, lease=True):
        self.bids, self.lease = bids, lease
        self.attempts, self.finished, self.started = [], None, False

    def start_run(self, run_id, host):
        self.started = True
        return self.lease

    def heartbeat(self, run_id):
        return True

    def finish_run(self, run_id, status, ok, failed, source_errors, note=''):
        self.finished = (status, ok, failed, source_errors, note)

    def record_attempt(self, bid_id, status, stage='', error=''):
        self.attempts.append((bid_id, status, stage))

    def candidates(self, limit):
        return self.bids

    def delete_old_evidence(self, now):
        pass


class Batch(unittest.TestCase):
    def setUp(self):
        self.args = argparse.Namespace(dry_run=False, bid=None, max_bids=10)
        self.lock = mock.patch.object(run, 'LOCK_PATH', Path(tempfile.mkdtemp()) / 'v.lock')
        self.lock.start()
        self.addCleanup(self.lock.stop)

    def _run(self, db, value_one):
        with mock.patch.object(supabase, 'ValuerDb', return_value=db), \
                mock.patch.object(supabase, 'SupabaseCache'), \
                mock.patch.object(run, 'GemClient'), \
                mock.patch.object(run.source_base, 'PoliteHttp'), \
                mock.patch.object(run, 'build_sources', return_value=[]), \
                mock.patch.object(run.selection, 'split_cancelled', side_effect=lambda g, b, log: (b, [])), \
                mock.patch.object(run, 'value_one', side_effect=value_one):
            return run.command_run(self.args, ENV, log=lambda *_: None)

    def test_one_failing_bid_does_not_stop_the_batch(self):
        db = FakeDb([{'id': 'a', 'source_id': 'A'}, {'id': 'b', 'source_id': 'B'}, {'id': 'c', 'source_id': 'C'}])

        def value_one(bid, **kw):
            kw['on_source_error']('indiamart', SourceUnavailable('timeout'))
            if bid['id'] == 'b':
                raise run.StageFailure('price', SourceBlocked('challenge page'))
        self.assertEqual(self._run(db, value_one), 0)
        self.assertEqual(db.attempts, [('a', 'ok', ''), ('b', 'failed', 'price'), ('c', 'ok', '')])
        status, ok, failed, source_errors, _ = db.finished
        self.assertEqual((status, ok, failed), ('finished', 2, 1))
        self.assertEqual(source_errors, {'indiamart': {'unavailable': 3}})

    def test_stage_is_named_on_failure(self):
        failure = None
        try:
            run.value_one({'id': 'x', 'source_id': 'X', 'closes_at': '', 'title': '',
                           'source_url': 'https://bidplus.gem.gov.in/showbidDocument/notanumber'},
                          gem=None, db=None, sources=[], cache=None, now=None, dry_run=True,
                          log=lambda *_: None)
        except run.StageFailure as error:
            failure = error
        self.assertEqual(failure.stage, 'fetch')

    def test_no_work_while_another_run_holds_the_lease(self):
        db = FakeDb([{'id': 'a', 'source_id': 'A'}], lease=False)
        called = []
        self.assertEqual(self._run(db, lambda bid, **kw: called.append(bid)), 0)
        self.assertEqual((called, db.finished), ([], None))

    def test_run_is_recorded_as_failed_when_it_crashes(self):
        db = FakeDb([])
        db.candidates = mock.Mock(side_effect=RuntimeError('Supabase down'))
        with self.assertRaises(RuntimeError):
            self._run(db, lambda bid, **kw: None)
        self.assertEqual(db.finished[0], 'failed')
        self.assertIn('Supabase down', db.finished[4])


if __name__ == '__main__':
    unittest.main()
