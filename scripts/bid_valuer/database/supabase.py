"""Supabase access for the valuer (service role, server only). Reuses the bid
worker's REST client, adding retries: transient failures (network errors,
timeouts, HTTP 408/429/5xx) are retried after 1, 2, 4 and 8 seconds; other
errors (4xx) fail at once. Every call made here is safe to repeat."""
from datetime import timedelta
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote

from bid_worker import Supabase, chunks, in_filter, postgres_safe

from .cache import OfferCache, offer_from_row

EVIDENCE_KEPT_FOR = timedelta(days=30)
RETRY_DELAYS = (1, 2, 4, 8)
TRANSIENT_HTTP = {408, 429, 500, 502, 503, 504}


def is_transient(error):
    cause = error.__cause__ if isinstance(error, RuntimeError) else error
    if isinstance(cause, HTTPError):
        return cause.code in TRANSIENT_HTTP
    return isinstance(cause, (URLError, TimeoutError, ConnectionError))


class RetryingSupabase(Supabase):
    def __init__(self, url, key, sleep=time.sleep, log=print, **kwargs):
        super().__init__(url, key, **kwargs)
        self.sleep, self.log = sleep, log

    def request(self, method, path, payload=None, prefer=None):
        for attempt, delay in enumerate(RETRY_DELAYS + (None,)):
            try:
                return super().request(method, path, payload, prefer)
            except (RuntimeError, URLError, TimeoutError, ConnectionError) as error:
                if delay is None or not is_transient(error):
                    raise
                self.log(f'  Supabase {method} {path.split("?")[0]}: {type(error).__name__}; '
                         f'retrying in {delay} s ({attempt + 1}/{len(RETRY_DELAYS)})')
                self.sleep(delay)


class ValuerDb:
    def __init__(self, url, key, urlopen=None, sleep=time.sleep, log=print):
        self.db = RetryingSupabase(url, key, sleep=sleep, log=log,
                                   **({'urlopen': urlopen} if urlopen else {}))

    # ---- run lease and failure records ----

    def start_run(self, run_id, host):
        """True if this run may proceed; False while another run holds the lease."""
        return self.db.rpc('start_valuation_run', {'p_id': run_id, 'p_host': host[:200]}) == run_id

    def heartbeat(self, run_id):
        """False when the lease was lost; the run must stop."""
        return self.db.rpc('heartbeat_valuation_run', {'p_id': run_id}) is True

    def finish_run(self, run_id, status, ok, failed, source_errors, note=''):
        self.db.rpc('finish_valuation_run', {'p_id': run_id, 'p_status': status, 'p_ok': ok,
                                             'p_failed': failed, 'p_source_errors': source_errors,
                                             'p_note': note[:500]})

    def record_attempt(self, bid_id, status, stage='', error=''):
        self.db.rpc('record_bid_attempt', {'p_bid_id': bid_id, 'p_status': status,
                                           'p_stage': stage, 'p_error': error[:500]})

    def candidates(self, limit, stale_days=3):
        return self.db.rpc('valuer_candidate_bids',
                           {'p_limit': limit, 'p_stale': f'{int(stale_days)} days'}) or []

    def bid(self, source_id):
        rows = self.db.request('GET', 'gem_bids?select=id,source_id,title,category,quantity,details,'
                                      f'source_url,closes_at,status&source_id={in_filter([source_id])}')
        return rows[0] if rows else None

    def mark_cancelled(self, bid_id):
        self.db.request('PATCH', f'gem_bids?id={in_filter([bid_id])}', {'status': 'cancelled'})

    def document_hashes(self, bid_id):
        rows = self.db.request('GET', f'bid_documents?select=url,sha256&bid_id={in_filter([bid_id])}')
        return {r['url']: r['sha256'] for r in rows or []}

    def save_document_hashes(self, bid_id, hashes, now):
        rows = [{'bid_id': bid_id, 'url': url[:500], 'sha256': digest, 'fetched_at': now.isoformat()}
                for url, digest in hashes.items()]
        if rows:
            self.db.request('POST', 'bid_documents?on_conflict=bid_id,url', rows,
                            'resolution=merge-duplicates,return=minimal')

    def stored_extraction(self, bid_id):
        """(item rows, valuation row) from the last run, for unchanged documents."""
        items = self.db.request('GET', f'bid_items?select=*&bid_id={in_filter([bid_id])}&order=position')
        valuation = self.db.request('GET', f'bid_valuations?select=extraction_status,confidence_factors'
                                           f'&bid_id={in_filter([bid_id])}')
        return items or [], (valuation or [None])[0]

    def replace_valuation(self, bid_id, items, valuation):
        return self.db.rpc('replace_bid_valuation', postgres_safe(
            {'p_bid_id': bid_id, 'p_items': items, 'p_valuation': valuation}))

    def delete_old_evidence(self, now):
        cutoff = quote((now - EVIDENCE_KEPT_FOR).isoformat(), safe='')
        self.db.request('DELETE', f'item_prices?last_verified_at=lt.{cutoff}')


class SupabaseCache(OfferCache):
    def __init__(self, valuer_db):
        super().__init__()
        self.db = valuer_db.db

    def get(self, key):
        rows = self.db.request('GET', f'item_prices?select=*&query_key=eq.{quote(key, safe="")}')
        return [offer_from_row(r) for r in rows or []]

    def save(self, rows, now):
        saved = []
        rows = [postgres_safe({**r, 'last_verified_at': now.isoformat()}) for r in rows]
        for part in chunks(rows, 50):
            # Upsert: an existing listing gets its new price and verification
            # time; first_seen_at is not sent, so it keeps its original value.
            saved += self.db.request('POST', 'item_prices?on_conflict=query_key,source_url', part,
                                     'resolution=merge-duplicates,return=representation') or []
        return [offer_from_row(r) for r in saved]
