"""Public supplier catalogues listed in sources/config.json.

Each site needs a search URL template containing {query}. The result page
is read for schema.org Product markup; when it only lists product links
(schema.org ItemList), up to `follow` product pages are read too. Sites
whose pages need JavaScript set "render": true (Playwright)."""
import json
import re
from urllib.parse import quote_plus, urljoin, urlparse

from .base import PriceSource, _jsonld_blocks, _types, products_from_jsonld


def item_query(item):
    """Search words: brand + model when known, else the name and key specs."""
    if item.brand and item.model:
        return f'{item.brand} {item.model}'
    name = re.split(r'\bconforming\b|\bas per\b|\(', item.name, flags=re.I)[0]
    return ' '.join(item.brand.split() + name.split())[:120]


def item_list_urls(html, page_url):
    urls = []
    for node in _jsonld_blocks(html):
        if 'itemlist' in _types(node):
            for element in node.get('itemListElement') or []:
                if not isinstance(element, dict):
                    continue
                target = element.get('item')
                url = element.get('url')
                if not url and isinstance(target, dict):
                    url = target.get('url') or target.get('@id')
                elif not url:
                    url = target
                if isinstance(url, str) and url:
                    urls.append(urljoin(page_url, url))
    return urls


class ConfiguredSite(PriceSource):
    """One site from config: {"search_url": "...{query}...", "render": false, "follow": 3}."""

    def __init__(self, http, name, config):
        super().__init__(http)
        self.name = name
        self.search_url = str(config.get('search_url') or '')
        self.render = bool(config.get('render'))
        self.follow = int(config.get('follow', 3))
        self.enabled = bool(config.get('enabled', True)) and '{query}' in self.search_url \
            and self.search_url.startswith('https://')

    def _page(self, url):
        return self.http.render(url) if self.render else self.http.get(url)

    def search(self, item):
        if not self.enabled:
            return []
        url = self.search_url.replace('{query}', quote_plus(item_query(item)))
        html = self._page(url)
        offers = products_from_jsonld(html, url, self.name)
        if not offers:
            host = urlparse(url).netloc
            for product_url in item_list_urls(html, url)[:self.follow]:
                if urlparse(product_url).netloc == host:
                    offers += products_from_jsonld(self._page(product_url), product_url, self.name)
        return offers


def load_config(path):
    try:
        with open(path, encoding='utf-8') as handle:
            return json.load(handle)
    except FileNotFoundError:
        return {}


class OtherSuppliers(PriceSource):
    """Every enabled site under "other_suppliers" in config, in listed order."""
    name = 'other_suppliers'

    def __init__(self, http, sites):
        super().__init__(http)
        self.sites = [ConfiguredSite(http, name, cfg) for name, cfg in (sites or {}).items()]
        self.enabled = any(site.enabled for site in self.sites)

    def search(self, item):
        offers = []
        for site in self.sites:
            if site.enabled:
                offers += site.search(item)
        return offers
