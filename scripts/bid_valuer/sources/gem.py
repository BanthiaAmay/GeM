"""GeM sources: marketplace product listings, and historical awarded prices.

Both are configured in sources/config.json because GeM refuses connections
from cloud servers, so their page formats can only be checked from the
office PC. Until "search_url" is filled in (see `run.py probe`), the
marketplace source stays off and the valuer moves to the next source.

Awarded prices: GeM publishes bid results per bid, but no public search of
past award prices by product is known to exist. The source is therefore
disabled; enable it only after confirming a public, robots-allowed page."""
from .base import PriceSource
from .other_suppliers import ConfiguredSite


class GemMarketplace(ConfiguredSite):
    def __init__(self, http, config):
        super().__init__(http, 'gem_marketplace', config or {})


class GemAwarded(ConfiguredSite):
    def __init__(self, http, config):
        config = dict(config or {})
        config.setdefault('enabled', False)
        super().__init__(http, 'gem_awarded', config)
