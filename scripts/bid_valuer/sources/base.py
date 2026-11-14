"""What every price source shares: the Offer format, polite HTTP, and a
schema.org (JSON-LD) product reader.

Rules for every source: one identifiable User-Agent, robots.txt respected,
at most one request per second per host, backoff on 429/503, and no
CAPTCHA, login or other access control is ever bypassed: a challenge page
marks the source blocked for the run."""
from dataclasses import dataclass, field
import json
import re
import time
from urllib.parse import urljoin, urlparse
from urllib.robotparser import RobotFileParser

USER_AGENT = 'Bid2ScaleValuer/1.0'
ROBOTS_NAME = 'Bid2ScaleValuer'
_CHALLENGE = re.compile(r'captcha|cf-chl|challenge-platform|are you a (?:human|robot)|'
                        r'unusual traffic|access denied|verify you are human', re.I)


class SourceError(Exception):
    """The source could not be read this run; its old prices stay unverified."""


class SourceBlocked(SourceError):
    """A CAPTCHA, login wall or refusal. Never worked around."""


class SourceDisallowed(SourceError):
    """robots.txt (or the source's terms, via config) does not allow this path."""


class SourceUnavailable(SourceError):
    """Network error, timeout or repeated 429/503."""


@dataclass
class Offer:
    """One market listing, in the same shape from every source."""
    source_name: str
    source_url: str
    title: str
    listed_price: float
    currency: str | None            # None = unknown; never treated as INR
    listed_unit: str = ''           # "Piece", "Kg" ... from "₹ 450/Piece"
    seller_name: str = ''
    seller_gstin: str = ''
    brand: str = ''
    model: str = ''
    manufacturer: str = ''
    specs: dict = field(default_factory=dict)
    description: str = ''
    gst_included: bool | None = None
    gst_rate: float | None = None


class PoliteHttp:
    """httpx with the house rules. `client` and `clock`/`sleep` are injectable for tests."""

    def __init__(self, contact='', min_interval=1.0, timeout=30, client=None,
                 clock=time.monotonic, sleep=time.sleep):
        self.user_agent = f'{USER_AGENT} (+{contact})' if contact else USER_AGENT
        if client is None:
            import httpx
            client = httpx.Client(headers={'User-Agent': self.user_agent,
                                           'Accept-Language': 'en-IN,en;q=0.8'},
                                  timeout=timeout, follow_redirects=True)
        self.client, self.min_interval = client, min_interval
        self.clock, self.sleep = clock, sleep
        self._robots, self._last, self._delay = {}, {}, {}

    def _robots_for(self, url):
        parts = urlparse(url)
        origin = f'{parts.scheme}://{parts.netloc}'
        if origin not in self._robots:
            parser = RobotFileParser()
            try:
                response = self._raw_get(origin + '/robots.txt')
                if response.status_code in (401, 403):
                    parser.disallow_all = True
                elif response.status_code >= 400:
                    parser.allow_all = True
                else:
                    parser.parse(response.text.splitlines())
            except SourceError:
                parser.disallow_all = True   # Unknown rules: do not crawl this run.
            self._robots[origin] = parser
            delay = parser.crawl_delay(ROBOTS_NAME)
            self._delay[parts.netloc] = max(self.min_interval, float(delay or 0))
        return self._robots[origin]

    def allowed(self, url):
        return self._robots_for(url).can_fetch(ROBOTS_NAME, url)

    def _wait(self, host):
        gap = self._delay.get(host, self.min_interval)
        if host in self._last:
            self.sleep(max(0.0, gap - (self.clock() - self._last[host])))
        self._last[host] = self.clock()

    def _raw_get(self, url):
        host = urlparse(url).netloc
        backoff = 5.0
        for attempt in range(3):
            self._wait(host)
            try:
                response = self.client.get(url)
            except Exception as error:  # httpx network errors, timeouts
                if attempt == 2:
                    raise SourceUnavailable(f'{host}: {type(error).__name__}') from error
                self.sleep(backoff)
                backoff *= 2
                continue
            if response.status_code in (429, 503) and attempt < 2:
                retry = response.headers.get('Retry-After', '')
                self.sleep(min(60.0, float(retry)) if retry.isdigit() else backoff)
                backoff *= 2
                continue
            return response
        raise SourceUnavailable(f'{host}: HTTP {response.status_code} after retries')

    def get(self, url):
        """Page text, or raises SourceDisallowed / SourceBlocked / SourceUnavailable."""
        if not self.allowed(url):
            raise SourceDisallowed(f'robots.txt disallows {url}')
        response = self._raw_get(url)
        if response.status_code in (401, 403, 407):
            raise SourceBlocked(f'{urlparse(url).netloc}: HTTP {response.status_code}')
        if response.status_code == 404:
            return ''
        if response.status_code >= 400:
            raise SourceUnavailable(f'{urlparse(url).netloc}: HTTP {response.status_code}')
        text = response.text
        if is_challenge(text):
            raise SourceBlocked(f'{urlparse(url).netloc}: challenge page')
        return text

    def render(self, url, wait_ms=2500):
        """JavaScript-rendered page text via Playwright, under the same rules.
        Loads the page and reads it; never clicks, types or solves anything."""
        if not self.allowed(url):
            raise SourceDisallowed(f'robots.txt disallows {url}')
        try:
            from playwright.sync_api import sync_playwright
        except ImportError as error:
            raise SourceUnavailable('Playwright is not installed') from error
        self._wait(urlparse(url).netloc)
        try:
            with sync_playwright() as p:
                browser = p.chromium.launch()
                try:
                    page = browser.new_page(user_agent=self.user_agent)
                    response = page.goto(url, wait_until='domcontentloaded', timeout=45000)
                    page.wait_for_timeout(wait_ms)
                    status, text = (response.status if response else 0), page.content()
                finally:
                    browser.close()
        except Exception as error:
            raise SourceUnavailable(f'render failed: {type(error).__name__}') from error
        if status in (401, 403, 407) or is_challenge(text):
            raise SourceBlocked(f'{urlparse(url).netloc}: blocked in browser')
        return text


def is_challenge(text):
    head = (text or '')[:6000]
    return bool(_CHALLENGE.search(head)) and len(text or '') < 60000


class PriceSource:
    """A price source. `search` returns Offers; `parse` is the pure HTML part,
    tested against saved pages so a site change shows up in CI."""
    name = 'base'
    enabled = True

    def __init__(self, http):
        self.http = http

    def search(self, item):
        raise NotImplementedError


def _jsonld_blocks(html):
    for raw in re.findall(r'<script[^>]+application/ld\+json[^>]*>(.*?)</script>', html or '',
                          re.S | re.I):
        try:
            data = json.loads(raw.strip())
        except ValueError:
            continue
        stack = data if isinstance(data, list) else [data]
        while stack:
            node = stack.pop()
            if isinstance(node, dict):
                if '@graph' in node:
                    stack.extend(node['@graph'] if isinstance(node['@graph'], list) else [node['@graph']])
                yield node
            elif isinstance(node, list):
                stack.extend(node)


def _types(node):
    kind = node.get('@type', '')
    return {str(k).lower() for k in (kind if isinstance(kind, list) else [kind])}


def _text(value):
    if isinstance(value, dict):
        return str(value.get('name') or '')
    if isinstance(value, list):
        return ', '.join(_text(v) for v in value)
    return str(value or '')


def products_from_jsonld(html, page_url, source_name):
    """Offers from schema.org Product markup. Tax status comes only from the
    standard `valueAddedTaxIncluded` flag; currency only from `priceCurrency`."""
    offers = []
    for node in _jsonld_blocks(html):
        if 'product' not in _types(node):
            continue
        raw_offers = node.get('offers') or []
        raw_offers = raw_offers if isinstance(raw_offers, list) else [raw_offers]
        specs = {}
        for prop in node.get('additionalProperty') or []:
            if isinstance(prop, dict) and prop.get('name'):
                specs[str(prop['name'])] = _text(prop.get('value'))
        for o in raw_offers:
            if not isinstance(o, dict):
                continue
            price = o.get('price', o.get('lowPrice'))
            spec = o.get('priceSpecification') or {}
            spec = spec[0] if isinstance(spec, list) and spec else spec
            if price in (None, '') and isinstance(spec, dict):
                price = spec.get('price')
            try:
                price = float(str(price).replace(',', ''))
            except ValueError:
                continue
            currency = o.get('priceCurrency') or (spec.get('priceCurrency') if isinstance(spec, dict) else None)
            vat = spec.get('valueAddedTaxIncluded') if isinstance(spec, dict) else None
            if isinstance(vat, str):
                vat = {'true': True, 'false': False}.get(vat.lower())
            url = urljoin(page_url, str(o.get('url') or node.get('url') or page_url))
            offers.append(Offer(
                source_name=source_name, source_url=url, title=_text(node.get('name')),
                listed_price=price, currency=str(currency).upper() if currency else None,
                listed_unit=_text((spec or {}).get('unitText') if isinstance(spec, dict) else ''),
                seller_name=_text(o.get('seller')), brand=_text(node.get('brand')),
                model=_text(node.get('model') or node.get('mpn') or node.get('sku')),
                manufacturer=_text(node.get('manufacturer')), specs=specs,
                description=_text(node.get('description'))[:1000],
                gst_included=vat if isinstance(vat, bool) else None))
    return offers
