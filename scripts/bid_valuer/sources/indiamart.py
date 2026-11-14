"""IndiaMART supplier listings, from its public category pages.

IndiaMART's robots.txt disallows its search pages (/search.mp), so this
source only reads category pages (/impcat/<category>.html), which robots.txt
allows. Each page embeds its product list as JSON (window.__INITIAL_STATE__).
Listings state price and unit ("₹ 2,000/Piece") but not whether GST is
included, so these offers are stored as evidence with an unknown tax basis
unless the listing text itself says so."""
import json
import re

from ..matching import normalise
from .base import Offer, PriceSource

CATEGORY_URL = 'https://dir.indiamart.com/impcat/{}.html'
_STATE = 'window.__INITIAL_STATE__'


def _slug(text):
    text = re.split(r'\bconforming\b|\bas per\b|\(|,', str(text or ''), flags=re.I)[0]
    return '-'.join(re.findall(r'[a-z0-9]+', text.lower()))


def category_slugs(item, limit=3):
    """Category page names to try, most specific first: "office-chairs"."""
    slugs = []
    for name in (item.name, item.category):
        base = _slug(name)
        if not base:
            continue
        words = base.split('-')
        last = words[-1]
        variants = [base, '-'.join(words[:-1] + [last + 's']) if not last.endswith('s') else '-'.join(words[:-1] + [last[:-1]])]
        if len(words) > 2:
            variants.append('-'.join(words[-2:]))
        for slug in variants:
            if slug and slug not in slugs:
                slugs.append(slug)
    return slugs[:limit]


def _product_rows(state):
    stack = [state]
    while stack:
        node = stack.pop()
        if isinstance(node, dict):
            data = node.get('data')
            if isinstance(data, list) and data and isinstance(data[0], dict) and 'pr' in data[0]:
                return data
            stack.extend(node.values())
        elif isinstance(node, list):
            stack.extend(node)
    return []


def parse(html, page_url=''):
    """Offers on one category page."""
    start = (html or '').find(_STATE)
    if start < 0:
        return []
    start = html.find('=', start) + 1
    try:
        state, _ = json.JSONDecoder().raw_decode(html[start:].lstrip())
    except ValueError:
        return []
    offers = []
    for row in _product_rows(state):
        label = str(row.get('pr') or '')
        amount, currency = normalise.parse_price(label)
        if amount is None and str(row.get('prd_price') or '').replace('.', '').isdigit():
            amount, currency = float(row['prd_price']), None  # bare number: currency unknown
        url = str(row.get('p_url') or '')
        if amount is None or not url.startswith('https://'):
            continue
        specs = {str(q.get('MASTER_DESC', '')).strip(): str(q.get('OPTIONS_DESC', '')).strip()
                 for q in row.get('isq') or [] if isinstance(q, dict) and q.get('MASTER_DESC')}
        title = str(row.get('p_nm') or row.get('f_nm') or '')
        included, rate = normalise.parse_gst(label + ' ' + title)
        offers.append(Offer(
            source_name='indiamart', source_url=url, title=title, listed_price=amount,
            currency=currency, listed_unit=label.split('/', 1)[1].strip() if '/' in label else '',
            seller_name=str(row.get('CMP') or ''), brand=specs.get('Brand', ''),
            model=specs.get('Model Name/Number', ''), specs=specs,
            gst_included=included, gst_rate=rate))
    return offers


class IndiaMart(PriceSource):
    name = 'indiamart'

    def search(self, item):
        offers = []
        for slug in category_slugs(item):
            url = CATEGORY_URL.format(slug)
            offers += parse(self.http.get(url), url)
            if offers:
                break
        return offers
