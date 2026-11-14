"""Offer storage behind one small interface, so the pricing logic runs the
same against Supabase or memory (tests and --dry-run).

save() is an upsert on (query_key, source_url): first_seen_at is set once,
last_verified_at is set to the time the listing was actually read. Reading
cached offers never changes either date."""
from datetime import datetime
import uuid

from ..prices import StoredOffer


def offer_from_row(row):
    def when(value):
        if value is None or isinstance(value, datetime):
            return value
        return datetime.fromisoformat(str(value).replace('Z', '+00:00'))
    return StoredOffer(
        id=str(row['id']), query_key=row['query_key'], source_name=row['source_name'],
        source_url=row['source_url'], listed_price=float(row['listed_price']),
        unit_price=None if row.get('unit_price') is None else float(row['unit_price']),
        tax_basis=row['tax_basis'], currency=row['currency'],
        product_match_score=None if row.get('product_match_score') is None
        else float(row['product_match_score']),
        last_verified_at=when(row['last_verified_at']), first_seen_at=when(row.get('first_seen_at')),
        seller_name=row.get('seller_name') or '', seller_key=row.get('seller_key') or '',
        title=row.get('title') or '', gst_included=row.get('gst_included'),
        gst_rate=None if row.get('gst_rate') is None else float(row['gst_rate']),
        pack_quantity=float(row.get('pack_quantity') or 1), unit=row.get('unit') or '')


class OfferCache:
    """Remembers which (query, source) pairs were read this run, so one
    product shared by several bids is fetched once per run."""

    def __init__(self):
        self._tried = set()

    def tried(self, key, source_name):
        return (key, source_name) in self._tried

    def mark_tried(self, key, source_name):
        self._tried.add((key, source_name))

    def get(self, key):
        raise NotImplementedError

    def save(self, rows, now):
        raise NotImplementedError


class MemoryCache(OfferCache):
    def __init__(self, offers=()):
        super().__init__()
        self.rows = {}
        for offer in offers:
            self.rows.setdefault(offer.query_key, {})[offer.source_url] = offer

    def get(self, key):
        return list(self.rows.get(key, {}).values())

    def save(self, rows, now):
        saved = []
        for row in rows:
            bucket = self.rows.setdefault(row['query_key'], {})
            old = bucket.get(row['source_url'])
            record = offer_from_row({**row, 'id': old.id if old else str(uuid.uuid4()),
                                     'first_seen_at': old.first_seen_at if old else now,
                                     'last_verified_at': now})
            bucket[row['source_url']] = record
            saved.append(record)
        return saved
