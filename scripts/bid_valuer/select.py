"""Which bids to value: open, matched to at least one user, closing by the end
of the tenth day in IST, and not valued in the last three days. The window
is computed in SQL (valuation_window_end) so the app and the valuer agree.

Cancelled bids drop out of GeM's ongoing listing before their end date.
They are marked only when the lookup is shown to work in the same batch
(some other candidate was found), so a GeM search change can never mark
every bid cancelled."""
from gem_source import GemError


def gem_id(source_url):
    tail = str(source_url or '').rstrip('/').rsplit('/', 1)[-1]
    return int(tail) if tail.isdigit() else None


def is_ongoing(gem, source_id):
    """True / False from GeM's ongoing listing, or None if GeM could not answer."""
    try:
        _, docs = gem.search(query=source_id, status_type='ongoing_bids')
    except GemError:
        return None
    numbers = {str((d.get('b_bid_number') or [''])[0] if isinstance(d.get('b_bid_number'), list)
                   else d.get('b_bid_number') or '').strip() for d in docs}
    return source_id in numbers


def split_cancelled(gem, bids, log=print):
    """(open bids, cancelled bids). Unknown answers count as open."""
    answers = {bid['id']: is_ongoing(gem, bid['source_id']) for bid in bids}
    if not any(answers.values()):
        if len(bids) >= 3:
            log('Cancellation check skipped: GeM found none of the bids by number, '
                'so the lookup itself may have changed.')
        return bids, []
    cancelled = [b for b in bids if answers[b['id']] is False]
    return [b for b in bids if answers[b['id']] is not False], cancelled
