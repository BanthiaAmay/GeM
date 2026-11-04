"""Reads public GeM bid listings and bid documents for the server worker.

Uses the same public endpoints the bidplus.gem.gov.in website calls; no login,
CAPTCHA or other access control is involved or bypassed. The session/token
approach is adapted from gem-search (MIT licence,
https://github.com/arush15june/gem-search). GeM can change these endpoints
without notice, so every failure raises GemError for the caller to handle.
"""
from datetime import datetime, timedelta, timezone
from http.cookiejar import CookieJar
import io
import json
import re
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import HTTPCookieProcessor, Request, build_opener

BASE_URL = 'https://bidplus.gem.gov.in'
LISTING_PAGE = BASE_URL + '/all-bids'
LISTING_DATA = BASE_URL + '/all-bids-data'
DOCUMENT_URL = BASE_URL + '/showbidDocument/{}'
USER_AGENT = 'Mozilla/5.0 (compatible; Bid2Scale-bid-alerts/1.0)'
IST = timezone(timedelta(hours=5, minutes=30))
MAX_DOCUMENT_BYTES = 15 * 1024 * 1024

# Same names as the app's state picker, so state filters compare exactly.
STATES = (
    'Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam',
    'Bihar', 'Chandigarh', 'Chhattisgarh', 'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi', 'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir',
    'Jharkhand', 'Karnataka', 'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh',
    'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha',
    'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
    'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
)
_STATE_ALIASES = {'orissa': 'Odisha', 'pondicherry': 'Puducherry',
                  'uttaranchal': 'Uttarakhand', 'nct of delhi': 'Delhi'}


class GemError(Exception):
    """GeM was unreachable or answered in an unexpected shape."""


class GemClient:
    """A polite session: one request at a time, at least `min_interval` apart."""

    def __init__(self, min_interval=1.0, timeout=30, opener=None, sleep=time.sleep,
                 clock=time.monotonic):
        self.opener = opener or build_opener(HTTPCookieProcessor(CookieJar()))
        self.min_interval, self.timeout = min_interval, timeout
        self.sleep, self.clock = sleep, clock
        self.csrf = None
        self._last = None

    def _fetch(self, url, body=None, headers=None):
        """Returns (status, bytes); retries timeouts and server errors with backoff."""
        delay = 2
        for attempt in range(3):
            if self._last is not None:
                self.sleep(max(0, self.min_interval - (self.clock() - self._last)))
            self._last = self.clock()
            request = Request(url, data=body, headers={'User-Agent': USER_AGENT, **(headers or {})})
            try:
                with self.opener.open(request, timeout=self.timeout) as response:
                    return response.status, response.read(MAX_DOCUMENT_BYTES + 1)
            except HTTPError as error:
                with error:
                    if error.code < 500 or attempt == 2:
                        return error.code, error.read()
            except (URLError, TimeoutError) as error:
                if attempt == 2:
                    raise GemError(f'GeM unreachable: {error}') from error
            self.sleep(delay)
            delay *= 2
        raise GemError('GeM unreachable')

    def _token(self):
        if not self.csrf:
            status, html = self._fetch(LISTING_PAGE, headers={'Accept': 'text/html'})
            match = re.search(rb"csrf_bd_gem_nk.*?'([a-f0-9]{32})'", html)
            if status != 200 or not match:
                raise GemError(f'No listing token (HTTP {status}); the GeM page may have changed')
            self.csrf = match.group(1).decode()
        return self.csrf

    def search(self, page=1, end_from='', end_to='', sort='Bid-Start-Date-Latest',
               status_type='ongoing_bids', query=''):
        """Returns (total, docs) for one listing page of about 10 bids."""
        payload = {'page': page, 'param': {'searchBid': query, 'searchType': 'fullText'},
                   'filter': {'bidStatusType': status_type, 'byType': 'all', 'highBidValue': '',
                              'byEndDate': {'from': end_from, 'to': end_to}, 'sort': sort}}
        headers = {'Content-Type': 'application/x-www-form-urlencoded',
                   'Accept': 'application/json', 'Referer': LISTING_PAGE,
                   'Origin': BASE_URL, 'X-Requested-With': 'XMLHttpRequest'}
        for attempt in range(2):
            body = urlencode({'payload': json.dumps(payload, separators=(',', ':')),
                              'csrf_bd_gem_nk': self._token()}).encode()
            status, raw = self._fetch(LISTING_DATA, body, headers)
            if status != 403:
                break
            self.csrf = None  # The session expired; start a fresh one once.
        try:
            data = json.loads(raw)
        except ValueError as error:
            raise GemError(f'Unexpected listing response (HTTP {status})') from error
        if str(data.get('code')) == '404':  # GeM's "no results" answer.
            return 0, []
        if data.get('code') != 200:
            raise GemError(f'Listing error {data.get("code")}')
        response = (data.get('response') or {}).get('response') or {}
        return int(response.get('numFound') or 0), list(response.get('docs') or [])

    def document(self, gem_id):
        """The bid document PDF. Reverse auctions have none at this address."""
        status, raw = self._fetch(DOCUMENT_URL.format(int(gem_id)), headers={'Referer': LISTING_PAGE})
        if status != 200 or not raw.startswith(b'%PDF'):
            raise GemError(f'No bid document for {gem_id} (HTTP {status})')
        if len(raw) > MAX_DOCUMENT_BYTES:
            raise GemError(f'Bid document {gem_id} is too large')
        return raw


def gem_time(value):
    """Listing times end in "Z" but are IST wall-clock times (checked against
    GeM's own result pages), so the suffix is replaced, not converted."""
    if not value:
        return None
    return datetime.fromisoformat(str(value).replace('Z', '')).replace(tzinfo=IST)


def _first(doc, key, default=''):
    value = doc.get(key)
    if isinstance(value, list):
        value = value[0] if value else None
    return default if value is None else value


def _clean(value):
    return ' '.join(str(value or '').split())


def state_from(*texts):
    """The Indian state or UT named in a GeM ministry/department field, or ''."""
    for text in texts:
        lowered = ' ' + re.sub(r'[^a-z]+', ' ', _clean(text).lower().replace('&', ' and ')) + ' '
        for name in sorted(STATES, key=len, reverse=True):
            if f' {name.lower()} ' in lowered:
                return name
        for alias, name in _STATE_ALIASES.items():
            if f' {alias} ' in lowered:
                return name
    return ''


def listing_record(doc):
    """Normalizes a listing row. Reverse auctions return None: only bidders of
    the parent bid can take part, so they are not new opportunities."""
    number = _clean(_first(doc, 'b_bid_number'))
    title = _clean(_first(doc, 'bd_category_name') or _first(doc, 'b_category_name'))
    try:
        gem_id = int(_first(doc, 'b_id', 0))
        closes, starts = gem_time(_first(doc, 'final_end_date_sort')), gem_time(_first(doc, 'final_start_date_sort'))
    except ValueError:
        return None
    if '/B/' not in number or not title or not gem_id or closes is None:
        return None
    department = _clean(_first(doc, 'ba_official_details_deptName'))
    ministry = _clean(_first(doc, 'ba_official_details_minName'))
    quantity = _first(doc, 'b_total_quantity', None)
    return {
        'gem_id': gem_id,
        'source_id': number[:120],
        'title': title[:500],
        'buyer': department[:500],
        'ministry': '' if state_from(ministry) else ministry[:300],
        'state': state_from(ministry, department),
        'quantity': int(quantity) if str(quantity).isdigit() else None,
        'starts_at': (starts or closes).isoformat(),
        'closes_at': closes.isoformat(),
        'source_url': DOCUMENT_URL.format(gem_id),
        'published': True,
        'details': {'kind': 'service' if _first(doc, 'b_type', 0) == 1 else 'product',
                    'high_value': bool(_first(doc, 'is_high_value', False))},
    }


# English half of each bilingual label in the bid document, in document order.
_LABELS = {
    'bid_end': 'Bid End Date/Time',
    'bid_opening': 'Bid Opening Date/Time',
    'offer_validity': 'Bid Offer Validity (From End Date)',
    'ministry_state': 'Ministry/State Name',
    'department': 'Department Name',
    'organisation': 'Organisation Name',
    'office': 'Office Name',
    'quantity': 'Total Quantity',
    'item_category': 'Item Category',
    'bidder_turnover': 'Minimum Average Annual Turnover of the bidder',
    'oem_turnover': 'OEM Average Turnover (Last 3 Years)',
    'experience': 'Years of Past Experience Required for same/similar service',
    'mse_relaxation': 'MSE Relaxation for Years Of Experience and Turnover',
    'startup_relaxation': 'Startup Relaxation for Years Of Experience and Turnover',
    'documents_required': 'Document required from seller',
    'past_performance': 'Past Performance',
    'bid_type': 'Type of Bid',
    'technical_clarification_time': 'Time allowed for Technical Clarifications during technical evaluation',
    'evaluation_method': 'Evaluation Method',
    'emd_amount': 'EMD Amount',
}
_DEVANAGARI = re.compile('[ऀ-ॿ]')
_FOOTER = re.compile(r'^(\d+\s*/\s*\d+|.*Bid Number:.*|.*Dated:.*|---.*)$')


def _label(label):
    # Labels follow the Hindi half after a slash and may wrap across lines.
    words = r'\s+'.join(re.escape(word) for word in label.split())
    return re.compile(r'/\s*' + words + r'(?:\s*\([^)\n]*\))?')


def _noise(line):
    return bool(_DEVANAGARI.search(line) or _FOOTER.match(line.strip()))


def _value(text, label, max_lines=8):
    match = _label(label).search(text)
    if not match:
        return ''
    lines = []
    for line in text[match.end():].splitlines():
        line = line.strip()
        if not line:
            if lines:
                break
            continue
        if _noise(line) or line.startswith(('*', '/')) or len(lines) == max_lines:
            break
        lines.append(line)
    return _clean(' '.join(lines))


def _section(text, start, ends, limit):
    match = _label(start).search(text)
    if not match:
        return ''
    rest = text[match.end():]
    stops = [m.start() for m in (_label(end).search(rest) for end in ends) if m]
    body = rest[:min(stops)] if stops else rest
    # Drop the Hindi halves and the slashes left over from bilingual table headers.
    kept = (line.strip().strip('/').strip() for line in body.splitlines() if not _noise(line))
    return _clean(' '.join(line for line in kept if line))[:limit]


def parse_document_text(text):
    """Fields from a GeM bid document's text. Missing labels are left out."""
    fields = {key: _value(text, label) for key, label in _LABELS.items()}
    fields['documents_required'] = [
        item.strip() for item in fields['documents_required'].split(',') if item.strip()]
    fields['quantity'] = int(fields['quantity']) if fields['quantity'].isdigit() else None
    emd = re.search(r'/\s*EMD\s+Detail[\s\S]{0,300}?/\s*Required\s*\n\s*(Yes|No)\b', text)
    fields['emd_required'] = emd.group(1) if emd else ''
    fields['specifications'] = _section(
        text, 'Technical Specifications', ['Consignees', 'Buyer Added Bid Specific'], 4000)
    fields['atc'] = _section(
        text, 'Buyer Added Bid Specific Terms and Conditions', ['Disclaimer'], 12000)
    return {key: value for key, value in fields.items() if value not in ('', None, [], 'N/a', 'NA')}


def document_links(urls):
    """Official GeM links found in the document: catalogue specs, buyer files, terms."""
    seen, links = set(), []
    for url in urls:
        url = str(url).strip()
        parsed = urlparse(url)
        host = parsed.hostname or ''
        if parsed.scheme != 'https' or not re.fullmatch(r'(?:[a-z0-9-]+\.)*gem\.gov\.in', host):
            continue
        if url in seen or len(url) > 500 or parsed.path.strip('/') == '':
            continue
        seen.add(url)
        kind = ('specification' if 'showCatalogue' in url else
                'buyer_document' if 'upload_nas' in url or 'slafds' in url else
                'terms' if '/gtc/' in url or 'bidsla' in url else 'document')
        links.append({'kind': kind, 'url': url})
    return links[:20]


def read_pdf(raw, max_pages=40):
    """(text, link URLs) of a PDF. Needs pypdf (scripts/requirements-worker.txt)."""
    from pypdf import PdfReader
    reader = PdfReader(io.BytesIO(raw))
    texts, urls = [], []
    for page in reader.pages[:max_pages]:
        texts.append(page.extract_text() or '')
        for annotation in page.get('/Annots') or []:
            action = annotation.get_object().get('/A')
            uri = action.get_object().get('/URI') if action is not None else None
            if uri:
                urls.append(str(uri))
    return '\n'.join(texts), urls


def enrich(record, document_text, urls):
    """Adds document fields to a listing record (returns a new record)."""
    parsed = parse_document_text(document_text)
    links = document_links(urls)
    ministry_state = parsed.get('ministry_state', '')
    result = dict(record)
    result['details'] = {**record.get('details', {}), **parsed, **({'links': links} if links else {})}
    result['organisation'] = parsed.get('organisation', '')[:300]
    result['category'] = parsed.get('item_category', '')[:200]
    if ministry_state and not state_from(ministry_state):
        result['ministry'] = ministry_state[:300]
    result['state'] = state_from(ministry_state, parsed.get('department', ''), record['buyer']) or record['state']
    if parsed.get('quantity') is not None:
        result['quantity'] = parsed['quantity']
    return result
