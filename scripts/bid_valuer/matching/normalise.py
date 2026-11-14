"""Units, pack sizes, prices, GST and seller identity, normalised so offers
compare like with like. Nothing here guesses: unknown stays unknown."""
from dataclasses import dataclass
import re

# unit word -> (dimension, factor to the dimension's base unit)
_UNITS = {
    'nos': ('count', 1), 'no': ('count', 1), 'number': ('count', 1), 'numbers': ('count', 1),
    'pcs': ('count', 1), 'pc': ('count', 1), 'piece': ('count', 1), 'pieces': ('count', 1),
    'each': ('count', 1), 'unit': ('count', 1), 'units': ('count', 1), 'item': ('count', 1),
    'dozen': ('count', 12), 'set': ('set', 1), 'sets': ('set', 1), 'pair': ('pair', 1),
    'pairs': ('pair', 1), 'ream': ('ream', 1), 'reams': ('ream', 1),
    'kg': ('mass', 1000), 'kgs': ('mass', 1000), 'kilogram': ('mass', 1000),
    'kilograms': ('mass', 1000), 'g': ('mass', 1), 'gm': ('mass', 1), 'gms': ('mass', 1),
    'gram': ('mass', 1), 'grams': ('mass', 1), 'quintal': ('mass', 100000),
    'tonne': ('mass', 1000000), 'ton': ('mass', 1000000),
    'l': ('volume', 1000), 'ltr': ('volume', 1000), 'ltrs': ('volume', 1000),
    'litre': ('volume', 1000), 'litres': ('volume', 1000), 'liter': ('volume', 1000),
    'liters': ('volume', 1000), 'ml': ('volume', 1), 'kl': ('volume', 1000000),
    'm': ('length', 1000), 'mtr': ('length', 1000), 'mtrs': ('length', 1000),
    'meter': ('length', 1000), 'meters': ('length', 1000), 'metre': ('length', 1000),
    'metres': ('length', 1000), 'rmt': ('length', 1000), 'cm': ('length', 10),
    'mm': ('length', 1), 'km': ('length', 1000000), 'ft': ('length', 304.8),
    'feet': ('length', 304.8), 'sqm': ('area', 1), 'sq m': ('area', 1), 'sq mtr': ('area', 1),
    'sqft': ('area', 0.092903), 'sq ft': ('area', 0.092903),
    'month': ('month', 1), 'months': ('month', 1), 'year': ('month', 12), 'years': ('month', 12),
    'day': ('day', 1), 'days': ('day', 1), 'hour': ('hour', 1), 'hours': ('hour', 1),
}
COUNT_LIKE = {'count', 'set', 'pair'}


def unit_of(text):
    """(dimension, factor) for a unit word like "Nos", "Kg", "sq ft"; None if unknown."""
    key = re.sub(r'[^a-z ]', '', str(text or '').lower()).strip()
    key = re.sub(r'\s+', ' ', key)
    return _UNITS.get(key) or _UNITS.get(key.replace(' ', ''))


@dataclass(frozen=True)
class Pack:
    """What one listing contains. `per` is the listing's stated price unit
    ("/Piece", "/Kg"); `count` the pieces in a pack ("Pack of 10"); `measure`
    a size in the title ("500 ml"), used only for measured bid units."""
    count: int = 1
    count_explicit: bool = False
    measure: tuple | None = None      # (amount in base units, dimension)
    per: tuple | None = None          # (dimension, factor)

    @property
    def explicit(self):
        return self.per is not None or self.count_explicit


_NUM = r'(\d+(?:\.\d+)?)'
_UNIT_WORDS = '|'.join(sorted((re.escape(u) for u in _UNITS if u not in ('m', 'l', 'g', 'no')),
                              key=len, reverse=True))
_U = rf'(?:{_UNIT_WORDS}|m|l|g)'
_MEASURE = re.compile(rf'{_NUM}\s*({_UNIT_WORDS}|m|l|g)\b', re.I)


def pack_of(title, listed_unit=''):
    """Contents of one listing: "Pack of 10", "500 ml x 12", "12 x 1 kg", "/Piece"."""
    t = str(title or '').lower().replace('×', 'x')
    count, explicit = 1, False
    m = re.search(r'\b(?:pack|box|set|bundle|carton|case) of\s*(\d+)', t)
    m_mult = re.search(rf'{_NUM}\s*{_U}\b\s*x\s*(\d+)\b|\b(\d+)\s*x\s*{_NUM}\s*{_U}\b', t)
    if m:
        count, explicit = int(m.group(1)), True
    elif m_mult:
        count, explicit = int(m_mult.group(2) or m_mult.group(3)), True
    measure = None
    found = _MEASURE.search(t)
    if found:
        dim, factor = unit_of(found.group(2))
        if dim not in COUNT_LIKE:
            measure = (float(found.group(1)) * factor * count, dim)
    return Pack(count, explicit, measure, unit_of(listed_unit))


def price_per_item_unit(price, pack, item_unit):
    """Price of one bid unit, or None when the units cannot be converted.
    A missing or unknown bid unit is never assumed."""
    target = unit_of(item_unit)
    if target is None or price is None:
        return None
    dim, factor = target
    if pack.per:
        per_dim, per_factor = pack.per
        if per_dim != dim:
            return None
        return price / per_factor * factor
    if dim in COUNT_LIKE:
        # A listing with no stated unit is one piece (or one pack of `count`).
        return price / pack.count * factor
    if pack.measure and pack.measure[1] == dim:
        return price / pack.measure[0] * factor
    return None


_PRICE = re.compile(r'(₹|rs\.?|inr|\$|usd|€|eur|£|gbp)?\s*([\d,]+(?:\.\d+)?)', re.I)
_CURRENCY = {'₹': 'INR', 'rs': 'INR', 'rs.': 'INR', 'inr': 'INR', '$': 'USD', 'usd': 'USD',
             '€': 'EUR', 'eur': 'EUR', '£': 'GBP', 'gbp': 'GBP'}


def parse_price(text, default_currency=None):
    """(amount, currency) from "₹ 1,23,456.00/Piece". The currency is None when
    neither the text nor the caller states it; such prices are never used."""
    m = _PRICE.search(str(text or ''))
    if not m or not m.group(2).replace(',', '').replace('.', ''):
        return None, None
    amount = float(m.group(2).replace(',', ''))
    symbol = (m.group(1) or '').lower()
    return amount, _CURRENCY.get(symbol) or default_currency


def parse_gst(text):
    """(included, rate) from a listing's wording; either may be None."""
    t = str(text or '').lower()
    rate = re.search(r'(\d{1,2}(?:\.\d+)?)\s*%\s*(?:gst|igst)|gst\s*@?\s*(\d{1,2}(?:\.\d+)?)\s*%', t)
    rate = float(rate.group(1) or rate.group(2)) if rate else None
    if re.search(r'incl(?:\.|usive|uding)?\s*(?:of\s*)?(?:all\s*taxes|gst|tax)|with\s+gst|gst\s+incl', t):
        return True, rate
    if re.search(r'excl(?:\.|usive|uding)?\s*(?:of\s*)?(?:all\s*taxes|gst|tax)|\+\s*gst|plus\s+gst|gst\s+extra|gst\s+excl', t):
        return False, rate
    return None, rate


def to_gst_inclusive(price, included, rate):
    """(price, tax_basis). Converts only when both the treatment and rate are known."""
    if included is True:
        return price, 'gst_inclusive'
    if included is False and rate is not None:
        return round(price * (1 + rate / 100), 2), 'gst_inclusive'
    if included is False:
        return price, 'gst_exclusive'
    return price, 'unknown'


_GSTIN = re.compile(r'\b\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]\b')
_SUFFIXES = r'\b(private|pvt|limited|ltd|llp|inc|co|company|the|m/s|ms)\b'


def seller_key(name, gstin='', fallback=''):
    """One key per seller: GSTIN when shown, else the normalised name, else
    `fallback` (the listing's domain, so unnamed sellers on one site count once)."""
    found = _GSTIN.search(str(gstin or '').upper()) or _GSTIN.search(str(name or '').upper())
    if found:
        return 'gstin:' + found.group(0)
    key = re.sub(r'[^a-z0-9 ]', ' ', str(name or '').lower())
    key = ' '.join(re.sub(_SUFFIXES, ' ', key).split())
    return ('name:' + key) if key else ('site:' + fallback if fallback else '')
