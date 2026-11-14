"""Manufacturer and authorised-distributor sites, used only when the bid
names a brand. Sites come from the "manufacturers" map in sources/config.json:
lower-case brand -> {"search_url": "https://...{query}...", "render": false}.
Only add a site after checking its terms and robots.txt allow this use."""
from .base import PriceSource
from .other_suppliers import ConfiguredSite
from ..matching.scoring import _norm_brand


class Manufacturers(PriceSource):
    name = 'manufacturers'

    def __init__(self, http, brands):
        super().__init__(http)
        self.sites = {_norm_brand(brand): ConfiguredSite(http, f'manufacturer:{brand}', cfg)
                      for brand, cfg in (brands or {}).items() if _norm_brand(brand)}
        self.enabled = any(site.enabled for site in self.sites.values())

    def search(self, item):
        site = self.sites.get(_norm_brand(item.brand))
        return site.search(item) if site and site.enabled else []
