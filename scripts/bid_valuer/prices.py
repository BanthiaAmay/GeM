"""Market offers for one item, and the item's price from them.

Collection: sources are tried in priority order until three independent
comparable offers exist. A source's stored offers are reused only while
verified within FRESH_FOR; otherwise the source is read again. If that read
fails, the old offers stay as evidence with their old verification date and
are excluded from pricing.

Pricing uses only fresh, accepted, INR, GST-inclusive offers, one per seller.
Outliers outside 0.5x-2x of the median are dropped; the median of the rest
is the unit price."""
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
import hashlib
from statistics import median
from urllib.parse import urlparse

from .matching import normalise, scoring, specifications as sp
from .sources.base import SourceError

FRESH_FOR = timedelta(days=3)
ENOUGH_OFFERS = 3
RELIABILITY_WEIGHT = {'normal': 1.0, 'reduced': 0.7, 'provisional': 0.4}


@dataclass
class StoredOffer:
    """A row of item_prices."""
    id: str
    query_key: str
    source_name: str
    source_url: str
    listed_price: float
    unit_price: float | None
    tax_basis: str
    currency: str
    product_match_score: float | None
    last_verified_at: datetime
    first_seen_at: datetime | None = None
    seller_name: str = ''
    seller_key: str = ''
    title: str = ''
    gst_included: bool | None = None
    gst_rate: float | None = None
    pack_quantity: float = 1.0
    unit: str = ''


@dataclass
class ItemPrice:
    priced: bool
    unit_price: float | None = None
    match_score: float | None = None
    price_reliability: str = 'unpriced'
    offer_ids: list = field(default_factory=list)
    reason: str = ''


def query_key(item):
    """Stable key for "this product, this unit": name, brand, model, unit, spec hash."""
    name = '-'.join(sp.words(item.name))[:80] or 'item'
    digest = hashlib.sha1(sp.spec_text(item.spec).encode('utf-8')).hexdigest()[:10]
    return '|'.join([name, item.brand.lower()[:40], item.model.lower()[:40],
                     item.unit.lower()[:12], digest])[:300]


def is_fresh(offer, now):
    return now - offer.last_verified_at <= FRESH_FOR


def comparable(offer, now):
    return (is_fresh(offer, now) and offer.currency == 'INR' and offer.tax_basis == 'gst_inclusive'
            and offer.unit_price is not None and offer.product_match_score is not None
            and offer.product_match_score >= scoring.ACCEPT_AT)


def _seller(offer):
    return offer.seller_key or 'site:' + urlparse(offer.source_url).netloc


def independent(offers):
    """One offer per seller (the best-matching), so a seller listed on several
    URLs or sites counts once."""
    best = {}
    for offer in offers:
        key = _seller(offer)
        if key not in best or (offer.product_match_score or 0) > (best[key].product_match_score or 0):
            best[key] = offer
    return list(best.values())


def to_row(offer, match, key):
    """An accepted Offer + Match as an item_prices row (without id or dates)."""
    currency = offer.currency if offer.currency else 'XXX'   # ISO 4217 "no currency"
    host = urlparse(offer.source_url).netloc
    return {
        'query_key': key, 'source_name': offer.source_name, 'source_url': offer.source_url[:1000],
        'seller_name': offer.seller_name[:300],
        'seller_key': normalise.seller_key(offer.seller_name, offer.seller_gstin, host)[:300],
        'title': offer.title[:500], 'listed_price': offer.listed_price,
        'gst_included': offer.gst_included, 'gst_rate': offer.gst_rate,
        'unit_price': match.unit_price if currency == 'INR' else None,
        'unit': offer.listed_unit[:20], 'tax_basis': match.tax_basis,
        'pack_quantity': match.pack_quantity, 'currency': currency,
        'product_match_score': match.score,
    }


def collect_offers(item, sources, cache, now, log=print, on_error=None):
    """Stored + newly read offers for `item`. Returns (key, offers, notes).
    `on_error(source_name, error)` is told about each source that failed."""
    key = query_key(item)
    stored = {o.source_url: o for o in cache.get(key)}
    notes = []
    for source in sources:
        if not source.enabled:
            continue
        ready = independent([o for o in stored.values() if comparable(o, now)])
        if len(ready) >= ENOUGH_OFFERS:
            break
        mine = [o for o in stored.values() if o.source_name == source.name]
        if (mine and all(is_fresh(o, now) for o in mine)) or cache.tried(key, source.name):
            continue
        cache.mark_tried(key, source.name)
        try:
            offers = source.search(item)
        except SourceError as error:
            if on_error:
                on_error(source.name, error)
            notes.append(f'{source.name}: {error}')
            log(f'    {source.name}: {error} (its stored offers stay unverified)')
            continue
        rows = []
        for offer in offers:
            match = scoring.score(item, offer)
            if match.accepted:
                rows.append(to_row(offer, match, key))
        for saved in cache.save(rows, now):
            stored[saved.source_url] = saved
        notes.append(f'{source.name}: {len(offers)} listings, {len(rows)} matched')
    return key, list(stored.values()), notes


def price_item(item, offers, now):
    if item.qty is None:
        return ItemPrice(False, reason='quantity not stated')
    usable = independent([o for o in offers if comparable(o, now)])
    if not usable:
        evidence = len(offers)
        return ItemPrice(False, reason='no fresh INR GST-comparable matching offer'
                         + (f' ({evidence} kept as evidence only)' if evidence else ''))
    middle = median(o.unit_price for o in usable)
    kept = [o for o in usable if 0.5 * middle <= o.unit_price <= 2 * middle]
    n = len(kept)
    reliability = 'normal' if n >= 3 else 'reduced' if n == 2 else 'provisional'
    return ItemPrice(True, round(median(o.unit_price for o in kept), 2),
                     round(sum(o.product_match_score for o in kept) / n, 3), reliability,
                     [o.id for o in kept])


def utcnow():
    return datetime.now(timezone.utc)
