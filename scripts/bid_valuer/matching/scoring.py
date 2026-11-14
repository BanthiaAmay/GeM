"""Structured product matching: is this listing the product the bid asks for?

A listing is accepted only when its unit converts, nothing conflicts, the
product type agrees, and at least one structured attribute (brand/model,
size, technical spec or material) actually matches. Similar names alone
never pass."""
from dataclasses import dataclass, field
import re

from . import normalise, specifications as sp

ACCEPT_AT = 0.75
NAME_COVERAGE_MIN = 0.5
WEIGHTS = {'brand_model': 0.25, 'size': 0.20, 'specs': 0.20, 'packaging': 0.15,
           'manufacturer': 0.05, 'description': 0.15}
SIZE_ATTRS = {'length_mm', 'volume_ml', 'mass_g', 'gsm'}
# Attributes whose disagreement means a different product. Length is left
# out: titles mix height, width and depth, so it only scores.
CONFLICT_ATTRS = {'volume_ml', 'mass_g', 'gsm', 'power_w', 'voltage_v', 'kva', 'battery_mah',
                  'storage_gb', 'megapixel', 'horsepower', 'tonnage', 'lumen',
                  'colour_temp_k', 'ip_rating'}
IDENTITY_KEYS = re.compile(r'brand|make|model|manufacturer|oem', re.I)
NO_BRAND = {'', 'any', 'generic', 'oem', 'na', 'n/a', 'nil', 'none', 'any brand', 'reputed',
            'reputed brand', 'make in india', 'as per gem', 'as per specification'}


@dataclass
class Match:
    accepted: bool
    score: float
    reason: str = ''
    components: dict = field(default_factory=dict)
    unit_price: float | None = None    # per bid unit, in the listing's tax basis
    tax_basis: str = 'unknown'
    pack_quantity: float = 1.0


def _stem(words):
    return {w[:-1] if w.endswith('s') and len(w) > 3 else w for w in words}


def _norm_brand(text):
    text = ' '.join(re.sub(r'[^a-z0-9 ]', ' ', str(text or '').lower()).split())
    return '' if text in NO_BRAND else text


def _has_words(needle, haystack):
    return bool(needle) and f' {needle} ' in f' {haystack} '


def score(item, offer):
    """Match one market listing against one bid item."""
    item_text = sp.spec_text(item.spec)
    offer_text = ' '.join([offer.title, sp.spec_text(offer.specs), offer.description])

    # 1. Units: the listing must convert to the bid's unit.
    pack = normalise.pack_of(offer.title, offer.listed_unit)
    per_unit = normalise.price_per_item_unit(offer.listed_price, pack, item.unit)
    if per_unit is None:
        return Match(False, 0.0, f'unit not convertible ({offer.listed_unit or "unstated"} '
                                 f'vs {item.unit or "unstated"})')
    price, basis = normalise.to_gst_inclusive(per_unit, offer.gst_included, offer.gst_rate)

    # 2. Hard conflicts.
    brand = _norm_brand(item.brand)
    offer_brand = _norm_brand(offer.brand)
    if brand and offer_brand and not (_has_words(brand, offer_brand) or _has_words(offer_brand, brand)):
        return Match(False, 0.0, f'brand conflict ({item.brand} vs {offer.brand})')
    item_models = sp.model_tokens(item.model) if item.model else set()
    offer_models = sp.model_tokens(' '.join([offer.model, offer.title]))
    if item_models and offer_models and not item_models & offer_models:
        return Match(False, 0.0, f'model conflict ({item.model} vs {", ".join(sorted(offer_models))})')
    wanted, offered = sp.measures(item_text + ' ' + item.name), sp.measures(offer_text)
    for attr in CONFLICT_ATTRS & wanted.keys() & offered.keys():
        if not sp.overlaps(wanted[attr], offered[attr]):
            return Match(False, 0.0, f'{attr} conflict')
    want_mat, offer_mat = sp.materials(item_text + ' ' + item.name), sp.materials(offer_text)
    if sp.materials_conflict(want_mat, offer_mat):
        return Match(False, 0.0, f'material conflict ({", ".join(sorted(want_mat))} vs '
                                 f'{", ".join(sorted(offer_mat))})')
    spec_matches, spec_conflicts = sp.compare_specs(item.spec, offer.specs)
    if spec_conflicts:
        return Match(False, 0.0, 'specification conflict (' + '; '.join(spec_conflicts[:2]) + ')')

    # 3. Product type: most of the item's name words must be in the listing's
    #    title, spec values or description (never in spec field names).
    name_words = _stem(sp.words(item.name))
    offer_words = _stem(sp.words(' '.join([offer.title, sp.spec_values(offer.specs),
                                           offer.description])))
    coverage = len(name_words & offer_words) / len(name_words) if name_words else 0.0
    if not sp.has_head_noun(item.name, offer_words):
        return Match(False, 0.0, f'different product type (no "{sp.head_noun(item.name)}")')
    if coverage < NAME_COVERAGE_MIN:
        return Match(False, 0.0, f'different product type (name coverage {coverage:.2f})')

    # 4. Weighted score over the components the bid gives information for.
    parts = {'packaging': 1.0 if pack.explicit else 0.7, 'description': coverage}
    brand_parts = []
    if brand:
        brand_parts.append(1.0 if _has_words(brand, _norm_brand(offer_text + ' ' + offer.brand)) else 0.0)
    if item_models:
        brand_parts.append(1.0 if item_models & offer_models else 0.0)
    if brand_parts:
        parts['brand_model'] = sum(brand_parts) / len(brand_parts)
    size_attrs = SIZE_ATTRS & wanted.keys()
    if size_attrs:
        parts['size'] = sum(attr in offered and sp.overlaps(wanted[attr], offered[attr])
                            for attr in size_attrs) / len(size_attrs)
    spec_checks = [attr in offered and sp.overlaps(wanted[attr], offered[attr])
                   for attr in wanted.keys() - SIZE_ATTRS]
    # A listing confirms a material only if it is as specific or more specific
    # ("mild steel" confirms "steel"; "metal" does not confirm "mild steel").
    spec_checks += [any(w == o or w in sp.ancestors(o) for w in want_mat for o in offer_mat)] if want_mat else []
    # Bid spec fields the listing does not state count as unmatched, so a
    # listing that says little cannot score as well as one that agrees.
    stated = [k for k in item.spec if sp.field_key(k) and not IDENTITY_KEYS.search(k)
              and not sp.measures(sp.spec_text({k: item.spec[k]})) and not sp.materials(item.spec[k])]
    spec_checks += [True] * len(spec_matches) + [False] * max(0, len(stated) - len(spec_matches))
    if spec_checks:
        parts['specs'] = sum(spec_checks) / len(spec_checks)
    if item.manufacturer:
        parts['manufacturer'] = 1.0 if _has_words(_norm_brand(item.manufacturer), _norm_brand(offer_text)) else 0.0

    structured = [parts[k] for k in ('brand_model', 'size', 'specs') if k in parts]
    total = sum(WEIGHTS[k] * v for k, v in parts.items()) / sum(WEIGHTS[k] for k in parts)
    total = round(total, 3)
    if not structured:
        return Match(False, total, 'bid gives no brand, size or specification to match', parts)
    if max(structured) == 0:
        return Match(False, total, 'no structured attribute matches', parts)
    if total < ACCEPT_AT:
        return Match(False, total, f'score {total:.2f} below {ACCEPT_AT}', parts)
    return Match(True, total, '', parts, round(price, 2), basis,
                 pack.count if pack.count_explicit else 1.0)
