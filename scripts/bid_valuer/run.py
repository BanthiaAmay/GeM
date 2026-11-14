#!/usr/bin/env python3
"""Bid valuer: estimated market value of open matched GeM bids.

  python scripts/bid_valuer/run.py run                    value up to 300 due bids
  python scripts/bid_valuer/run.py run --dry-run          print everything, write nothing
  python scripts/bid_valuer/run.py run --bid GEM/2026/B/… one bid (with --dry-run to inspect)
  python scripts/bid_valuer/run.py probe URL              save a page and show what parses

Runs on the office PC (GeM refuses cloud servers). Needs SUPABASE_URL and
SUPABASE_SERVICE_ROLE_KEY (env or the project .env), optional VALUER_CONTACT
(a URL or email shown in the User-Agent). Dependencies:
scripts/requirements-valuer.txt, plus Tesseract for scanned pages and
`playwright install chromium` for JavaScript sites.

The estimate is quantity x prevailing market price for priced items. It is
not an official GeM valuation, a guaranteed contract price, or profit."""
import os
import sys

# Run as a script, Python puts this folder first on sys.path, where select.py
# would shadow the standard library's `select`. Use the scripts folder instead.
_HERE = os.path.dirname(os.path.abspath(__file__))
_SCRIPTS = os.path.dirname(_HERE)
if sys.path and os.path.abspath(sys.path[0] or '.') == _HERE:
    sys.path[0] = _SCRIPTS
elif _SCRIPTS not in sys.path:
    sys.path.insert(0, _SCRIPTS)

import argparse  # noqa: E402
from contextlib import contextmanager  # noqa: E402
from pathlib import Path  # noqa: E402
import socket  # noqa: E402
import uuid  # noqa: E402

from bid_worker import load_env_file  # noqa: E402
from gem_source import GemClient, GemError  # noqa: E402

from bid_valuer import extract, fetch, items as items_mod, prices, select as selection, value  # noqa: E402
from bid_valuer.database.cache import MemoryCache  # noqa: E402
from bid_valuer.sources import base as source_base  # noqa: E402
from bid_valuer.sources.gem import GemAwarded, GemMarketplace  # noqa: E402
from bid_valuer.sources.indiamart import IndiaMart  # noqa: E402
from bid_valuer.sources.manufacturers import Manufacturers  # noqa: E402
from bid_valuer.sources.other_suppliers import OtherSuppliers, load_config  # noqa: E402

CONFIG = Path(_HERE) / 'sources' / 'config.json'
PROBE_DIR = Path(_HERE) / 'tests' / 'fixtures' / 'probe'
LOCK_PATH = Path(_SCRIPTS).parent / 'logs' / 'bid-valuer.lock'


@contextmanager
def run_lock(path=LOCK_PATH):
    """An exclusive lock on this computer for the whole run. Yields False when
    another run holds it. The OS releases it if the process dies."""
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = open(path, 'a+')
    locked = False
    try:
        try:
            if os.name == 'nt':
                import msvcrt
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            locked = True
        except OSError:
            pass
        yield locked
    finally:
        if locked and os.name == 'nt':
            import msvcrt
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        handle.close()


class StageFailure(Exception):
    """A bid failed at one stage (fetch, extract, price, save); the batch goes on."""

    def __init__(self, stage, error):
        super().__init__(f'{stage}: {type(error).__name__}: {str(error)[:300]}')
        self.stage = stage


class SourceErrors(dict):
    """{source: {"blocked": n, "disallowed": n, "unavailable": n}} for the run record."""

    def __call__(self, source_name, error):
        kind = ('blocked' if isinstance(error, source_base.SourceBlocked) else
                'disallowed' if isinstance(error, source_base.SourceDisallowed) else 'unavailable')
        counts = self.setdefault(source_name, {})
        counts[kind] = counts.get(kind, 0) + 1


def build_sources(http, config):
    """Price sources in the agreed priority order."""
    indiamart = IndiaMart(http)
    indiamart.enabled = bool((config.get('indiamart') or {}).get('enabled', True))
    return [GemMarketplace(http, config.get('gem_marketplace')),
            GemAwarded(http, config.get('gem_awarded')),
            indiamart,
            Manufacturers(http, config.get('manufacturers')),
            OtherSuppliers(http, config.get('other_suppliers'))]


class DryRunCache(MemoryCache):
    """Reads stored offers from Supabase, keeps new ones in memory only."""

    def __init__(self, reader):
        super().__init__()
        self.reader = reader

    def get(self, key):
        mine = super().get(key)
        seen = {o.source_url for o in mine}
        return mine + [o for o in (self.reader.get(key) if self.reader else []) if o.source_url not in seen]


def _money(value):
    return '-' if value is None else f'₹{value:,.2f}'


def print_bid(bid, extraction, priced, items_payload, valuation, log):
    log(f'  status {extraction.status}; value {_money(valuation["priced_value_inr"])}; '
        f'complete {valuation["complete"]}; confidence {valuation["confidence"]} '
        f'({valuation["confidence_factors"].get("rule", "")})')
    for issue in extraction.issues:
        log(f'  ! {issue["code"]}: {issue["detail"]}')
    for row, price in zip(items_payload, priced):
        log(f'  - {row["name"][:60]} | qty {row["qty"]} {row["unit"] or "?"} | '
            f'unit {_money(row.get("unit_price"))} | line {_money(row.get("line_value"))} | '
            f'{row["price_reliability"]} | offers {len(row["offer_ids"])}'
            + (f' | {price.reason}' if price.reason else ''))
        for issue in row['issues']:
            if issue['code'] != 'unpriced':
                log(f'      ! {issue["code"]}: {issue["detail"]}')


def value_one(bid, *, gem, db, sources, cache, now, dry_run, log, on_source_error=None):
    """Values one bid; any failure is raised as StageFailure naming the stage."""
    progress = {'stage': 'fetch'}
    try:
        return _value_one(bid, gem, db, sources, cache, now, dry_run, log, on_source_error, progress)
    except Exception as error:
        raise StageFailure(progress['stage'], error) from error


def _value_one(bid, gem, db, sources, cache, now, dry_run, log, on_source_error, progress):
    stored = db.document_hashes(bid['id']) if db else {}
    files, hashes, unchanged, notes = fetch.fetch(gem, bid, stored)
    progress['stage'] = 'extract'
    extraction = None
    if unchanged and db:
        rows, old = db.stored_extraction(bid['id'])
        if rows and old:
            extraction = items_mod.Extraction(
                [items_mod.item_from_row(r) for r in rows], old['extraction_status'],
                (old.get('confidence_factors') or {}).get('extraction_issues') or [])
            log('  documents unchanged; reusing the extracted item list')
    if extraction is None:
        documents = [extract.read(raw, url) for url, raw in files]
        unreadable = list(notes)   # attachments that could not be downloaded
        for doc in documents:
            if doc.error and not doc.text.strip() and not doc.tables:
                unreadable.append(f'{doc.url[:80]}: {doc.error}')
            elif doc.error:
                log(f'  note: {doc.url[:60]}: {doc.error}')
            if doc.ocr_pages:
                log(f'  OCR read {doc.ocr_pages} scanned page(s) of {doc.url[:60]}')
        extraction = items_mod.extract_items(documents, bid)
        if unreadable and extraction.status == 'complete':
            extraction.status = 'incomplete'
        extraction.issues += [{'code': 'attachment_unreadable', 'detail': n[:200]} for n in unreadable]
    progress['stage'] = 'price'
    priced = []
    for item in extraction.items:
        if extraction.status == 'unpriceable':
            priced.append(prices.ItemPrice(False, reason='service or works bid'))
            continue
        _, offers, source_notes = prices.collect_offers(item, sources, cache, now, log,
                                                        on_error=on_source_error)
        priced.append(prices.price_item(item, offers, now))
        for note in source_notes:
            log(f'    {item.name[:40]}: {note}')
    items_payload, valuation = value.value_bid(extraction, priced, fetch.combined_hash(hashes))
    print_bid(bid, extraction, priced, items_payload, valuation, log)
    progress['stage'] = 'save'
    if not dry_run:
        db.replace_valuation(bid['id'], items_payload, valuation)
        db.save_document_hashes(bid['id'], hashes, now)
    return valuation


def command_run(args, env, log=print):
    with run_lock() as held:
        if not held:
            log('Another valuer run is active on this computer; nothing to do.')
            return 0
        return _run(args, env, log)


def _run(args, env, log):
    from bid_valuer.database.supabase import SupabaseCache, ValuerDb
    if not env.get('SUPABASE_URL') or not env.get('SUPABASE_SERVICE_ROLE_KEY'):
        raise SystemExit('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (env or .env).')
    db = ValuerDb(env['SUPABASE_URL'], env['SUPABASE_SERVICE_ROLE_KEY'], log=log)
    run_id = str(uuid.uuid4())
    if not args.dry_run and not db.start_run(run_id, socket.gethostname()):
        log('Another valuer run holds the lease (possibly on another computer); nothing to do.')
        return 0
    source_errors = SourceErrors()
    ok = failed = 0
    status, note = 'failed', ''
    try:
        now = prices.utcnow()
        gem = GemClient()
        http = source_base.PoliteHttp(contact=env.get('VALUER_CONTACT', ''))
        sources = build_sources(http, load_config(CONFIG))
        log('Sources: ' + ', '.join(f'{s.name}{"" if s.enabled else " (off)"}' for s in sources))
        cache = DryRunCache(SupabaseCache(db)) if args.dry_run else SupabaseCache(db)
        if args.bid:
            bid = db.bid(args.bid)
            if not bid:
                raise SystemExit(f'{args.bid} is not in gem_bids.')
            bids = [bid]
        else:
            bids = db.candidates(args.max_bids)
        log(f'{len(bids)} bid(s) to value' + (' (dry run: nothing is written)' if args.dry_run else ''))
        if not args.bid:
            bids, cancelled = selection.split_cancelled(gem, bids, log)
            for bid in cancelled:
                log(f'{bid["source_id"]}: no longer in GeM\'s ongoing bids; marked cancelled')
                if not args.dry_run:
                    db.mark_cancelled(bid['id'])
        for bid in bids:
            if not args.dry_run and not db.heartbeat(run_id):
                note = 'lease lost; stopped early'
                log('The run lease was lost (another run took over); stopping.')
                break
            try:
                value_one(bid, gem=gem, db=db, sources=sources, cache=cache, now=now,
                          dry_run=args.dry_run, log=log, on_source_error=source_errors)
                ok += 1
                result = ('ok', '', '')
            except StageFailure as failure:
                failed += 1
                log(f'  failed at {failure}')
                result = ('failed', failure.stage, str(failure))
            if not args.dry_run:
                try:
                    db.record_attempt(bid['id'], *result)
                except Exception as error:  # Recording must not stop the batch either.
                    log(f'  could not record the attempt: {error}')
        if not args.dry_run:
            db.delete_old_evidence(now)
        status = 'finished'
    except Exception as error:
        note = f'{type(error).__name__}: {str(error)[:300]}'
        raise
    finally:
        if not args.dry_run:
            try:
                db.finish_run(run_id, status, ok, failed, dict(source_errors), note)
            except Exception as error:
                log(f'Could not record the run: {error}')
        log(f'Valued {ok} bid(s); {failed} failed (will retry). Source errors: {dict(source_errors) or "none"}.')
    return 0 if failed == 0 or ok else 1


def command_probe(args, env, log=print):
    """Fetch one page under the house rules, save it, and show what parses."""
    from bid_valuer.sources import indiamart
    http = source_base.PoliteHttp(contact=env.get('VALUER_CONTACT', ''))
    try:
        html = http.render(args.url) if args.render else http.get(args.url)
    except source_base.SourceError as error:
        log(f'Not read: {error}')
        return 1
    PROBE_DIR.mkdir(parents=True, exist_ok=True)
    name = ''.join(c if c.isalnum() else '_' for c in args.url.split('://', 1)[-1])[:100] + '.html'
    (PROBE_DIR / name).write_text(html, encoding='utf-8')
    log(f'Saved {len(html):,} characters to {PROBE_DIR / name}')
    found = source_base.products_from_jsonld(html, args.url, 'probe') + indiamart.parse(html, args.url)
    log(f'{len(found)} offer(s) parsed (schema.org Product markup or IndiaMART page data):')
    for offer in found[:15]:
        log(f'  {offer.listed_price} {offer.currency or "?"} /{offer.listed_unit or "?"} | '
            f'GST {offer.gst_included} | {offer.seller_name[:30]} | {offer.title[:60]}')
    return 0


def main(argv=None, env=None):
    env = dict(os.environ if env is None else env)
    for key, val in load_env_file(Path(_SCRIPTS).parent / '.env').items():
        env.setdefault(key, val)
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    sub = parser.add_subparsers(dest='command', required=True)
    run = sub.add_parser('run', help='value due bids')
    run.add_argument('--max-bids', type=int, default=300)
    run.add_argument('--dry-run', action='store_true')
    run.add_argument('--bid', help='value one bid number, e.g. GEM/2026/B/1234567')
    probe = sub.add_parser('probe', help='fetch a page politely and show what parses')
    probe.add_argument('url')
    probe.add_argument('--render', action='store_true', help='load with Playwright')
    args = parser.parse_args(argv)
    return command_run(args, env) if args.command == 'run' else command_probe(args, env)


if __name__ == '__main__':
    sys.exit(main())
