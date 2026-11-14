"""The product-wise list a bid asks for, with every gap flagged, never guessed.

Sources, in order: a BOQ table (attachment or PDF table), else the GeM bid
document's single item (category, specification table, consignee table).
A multi-product bid without per-item quantities is marked incomplete; its
category x total quantity is never used as a valuation."""
from dataclasses import dataclass, field
import re

from .extract import normalise_header
from .matching import normalise

# Blocking issues make extraction incomplete; the others are shown only.
BLOCKING = {'quantity_missing', 'unit_missing', 'unit_unknown', 'duplicate_product',
            'conflicting_specification', 'declared_quantity_mismatch',
            'delivery_quantity_mismatch', 'multiple_products_without_quantities',
            'no_items_found', 'attachment_unreadable'}
SERVICE_WORDS = re.compile(
    r'\b(manpower|outsourc\w*|hiring|hire|service|services|amc|maintenance|repair|repairing|'
    r'housekeeping|security guard|catering|consultan\w*|construction|civil work|works|'
    r'installation|annual maintenance|cleaning|transport\w*|event|training|audit)\b', re.I)


@dataclass
class Item:
    name: str
    qty: float | None = None
    unit: str = ''
    spec: dict = field(default_factory=dict)
    brand: str = ''
    model: str = ''
    manufacturer: str = ''
    category: str = ''
    delivery: list = field(default_factory=list)   # [{"location", "qty", "days"}]
    issues: list = field(default_factory=list)     # [{"code", "detail"}]

    def flag(self, code, detail=''):
        self.issues.append({'code': code, 'detail': detail[:200]})


@dataclass
class Extraction:
    items: list
    status: str                  # 'complete' | 'incomplete' | 'unpriceable'
    issues: list                 # bid-level [{"code", "detail"}]

    @property
    def reason(self):
        codes = [i['code'] for i in self.issues] + [
            i['code'] for item in self.items for i in item.issues if i['code'] in BLOCKING]
        return ', '.join(dict.fromkeys(codes))[:500]


def clean_name(text):
    text = re.split(r'\bconforming\b|\bas per\b|\(', str(text or ''), flags=re.I)[0]
    return ' '.join(text.split()).strip(' ,-:')[:200]


def _number(text):
    m = re.fullmatch(r'\s*([\d,]+(?:\.\d+)?)\s*([A-Za-z. ]{0,15})\s*', str(text or ''))
    if not m:
        return None, ''
    try:
        return float(m.group(1).replace(',', '')), m.group(2).strip(' .')
    except ValueError:
        return None, ''


def _spec_identity(spec, item):
    for key, value in spec.items():
        k = key.lower()
        if not value or value.lower() in ('na', 'n/a', 'any', 'not applicable'):
            continue
        if ('brand' in k or k in ('make', 'make/brand')) and not item.brand:
            item.brand = value
        elif 'model' in k and not item.model:
            item.model = value
        elif ('manufacturer' in k or 'oem name' in k) and not item.manufacturer:
            item.manufacturer = value
        elif re.search(r'unit of measure|\buom\b', k) and not item.unit:
            item.unit = value


# ---------- BOQ tables ----------

_COLUMNS = {
    'name': ('item', 'description', 'particulars', 'product', 'name', 'material'),
    'qty': ('qty', 'quantity', 'quantities'),
    'unit': ('unit', 'uom', 'units'),
    'brand': ('brand', 'make'),
    'model': ('model',),
    'spec': ('specification', 'specifications', 'specs', 'technical'),
    'location': ('location', 'consignee', 'address', 'place', 'delivery'),
    'days': ('days', 'period', 'schedule'),
}


def _header_map(row):
    found = {}
    for index, cell in enumerate(row):
        words = normalise_header(cell)
        for column, keys in _COLUMNS.items():
            if column not in found and any(k in words for k in keys):
                if column == 'location' and 'days' in words:
                    continue
                found[column] = index
                break
    return found if {'name', 'qty'} <= found.keys() else None


def items_from_boq(tables):
    """Items from the first table that has item and quantity columns."""
    for table in tables:
        for header_at, row in enumerate(table[:8]):
            columns = _header_map(row)
            if not columns:
                continue
            items, seen_rows = [], 0
            for cells in table[header_at + 1:]:
                get = lambda c: cells[columns[c]].strip() if c in columns and columns[c] < len(cells) else ''
                name = get('name')
                if not name or re.match(r'^(sub\s*)?total\b|^grand total', name, re.I):
                    continue
                seen_rows += 1
                qty, unit_in_qty = _number(get('qty'))
                item = Item(clean_name(name) or name[:200], qty, get('unit') or unit_in_qty,
                            brand=get('brand'), model=get('model'))
                if get('spec'):
                    item.spec = {'Specification': get('spec')}
                if qty is None:
                    item.flag('quantity_missing', f'"{get("qty")}" is not a quantity')
                if get('location'):
                    days, _ = _number(get('days'))
                    item.delivery.append({'location': get('location')[:200], 'qty': qty,
                                          'days': int(days) if days else None})
                items.append(item)
            if seen_rows:
                return items
    return []


# ---------- GeM bid document ----------

_SPEC_HEADERS = {'specification', 'specification name', 'values', 'value', 'core', 'addon',
                 'addon(s)', 'generic', 'as per gem category specification',
                 'bid specific specification', 'parameter', 'requirement'}


def specs_from_tables(tables):
    spec = {}
    for table in tables:
        if not table or not any('specification' in ' '.join(r).lower() for r in table[:2]):
            continue
        for row in table:
            cells = [c for c in row if c]
            if len(cells) >= 2 and cells[-2].lower() not in _SPEC_HEADERS:
                spec.setdefault(cells[-2][:150], cells[-1][:300])
    return spec


def specs_from_text(section):
    """Pairs of lines after the "As per GeM Category Specification" marker."""
    lines = [l.strip() for l in section.splitlines() if l.strip()]
    lines = [l for l in lines if l.lower().lstrip('* ').split('/')[-1].strip() not in _SPEC_HEADERS
             and not re.search(r'[ऀ-ॿ]', l)]
    return {lines[i][:150]: lines[i + 1][:300] for i in range(0, len(lines) - 1, 2)}


def consignees_from_tables(tables):
    rows = []
    for table in tables:
        header = next((r for r in table[:3] if any('quantity' in c.lower() for c in r)
                       and any(k in ' '.join(r).lower() for k in ('consignee', 'address'))), None)
        if not header:
            continue
        lower = [c.lower() for c in header]
        q = next(i for i, c in enumerate(lower) if 'quantity' in c)
        a = next((i for i, c in enumerate(lower) if 'address' in c), None)
        d = next((i for i, c in enumerate(lower) if 'days' in c), None)
        for row in table[table.index(header) + 1:]:
            qty, _ = _number(row[q] if q < len(row) else '')
            if qty is None:
                continue
            days, _ = _number(row[d]) if d is not None and d < len(row) else (None, '')
            rows.append({'location': (row[a] if a is not None and a < len(row) else '')[:200],
                         'qty': qty, 'days': int(days) if days else None})
    return rows


def consignees_from_text(section):
    """Fallback for text-only documents: S.No, officer, address, quantity[, days]."""
    lines = [l.strip() for l in section.splitlines() if l.strip() and not re.search(r'[ऀ-ॿ]', l)]
    rows, i = [], 0
    while i < len(lines):
        if re.fullmatch(r'\d{1,3}', lines[i]) and i + 3 < len(lines):
            qty, _ = _number(lines[i + 3])
            if qty is not None:
                days, _ = _number(lines[i + 4]) if i + 4 < len(lines) else (None, '')
                rows.append({'location': lines[i + 2][:200], 'qty': qty,
                             'days': int(days) if days and days < 1000 else None})
                i += 5 if days and days < 1000 else 4
                continue
        i += 1
    return rows


def _section(text, start, ends):
    begin = text.find(start)
    if begin < 0:
        return ''
    stop = min([p for p in (text.find(e, begin + len(start)) for e in ends) if p > 0] or [len(text)])
    return text[begin + len(start):stop]


def items_from_gem_document(doc, bid):
    """The GeM document's item(s). One "Technical Specifications" block is one
    product; several blocks without a BOQ cannot be split reliably."""
    text = doc.text
    blocks = text.count('Technical Specifications')
    details = bid.get('details') or {}
    if blocks > 1:
        return [], [{'code': 'multiple_products_without_quantities',
                     'detail': f'{blocks} product specification blocks and no BOQ table'}]
    name = clean_name(details.get('item_category') or bid.get('category') or bid.get('title'))
    if not name:
        return [], [{'code': 'no_items_found', 'detail': 'no item category in the bid document'}]
    item = Item(name, category=details.get('item_category', '') or bid.get('category', ''))
    spec_section = _section(text, 'Technical Specifications',
                            ['Consignees/Reporting Officer', 'Buyer Added Bid Specific'])
    item.spec = specs_from_tables(doc.tables) or specs_from_text(spec_section)
    _spec_identity(item.spec, item)
    declared = details.get('quantity') if details.get('quantity') is not None else bid.get('quantity')
    m = re.search(r'Total Quantity\s*\n\s*([\d,]+)\s*([A-Za-z.]{1,12})?\s*\n', text)
    if m:
        declared = float(m.group(1).replace(',', ''))
        if m.group(2) and normalise.unit_of(m.group(2)):
            item.unit = item.unit or m.group(2)
    item.delivery = consignees_from_tables(doc.tables) or consignees_from_text(
        _section(text, 'Consignees/Reporting Officer and Quantity', ['Buyer Added Bid Specific',
                                                                      'Disclaimer']))
    delivered = sum(d['qty'] for d in item.delivery if d.get('qty') is not None)
    item.qty = float(declared) if declared is not None else (delivered or None)
    if item.qty is None:
        item.flag('quantity_missing', 'no total quantity or consignee quantities')
    return [item], []


def validate(items, declared_total=None):
    """Adds issues in place; returns bid-level issues."""
    bid_issues = []
    seen = {}
    for item in items:
        if not item.unit:
            item.flag('unit_missing', 'the bid does not state the unit of measure')
        elif normalise.unit_of(item.unit) is None:
            item.flag('unit_unknown', f'unrecognised unit "{item.unit}"')
        key = (item.name.lower(), tuple(sorted((k.lower(), v.lower()) for k, v in item.spec.items())),
               item.brand.lower(), item.model.lower())
        if key in seen:
            item.flag('duplicate_product', f'same product as item {seen[key] + 1}')
        seen.setdefault(key, items.index(item))
        if not item.delivery:
            item.flag('delivery_missing', 'no consignee or delivery location found')
        else:
            located = [d for d in item.delivery if d.get('qty') is not None]
            if len(item.delivery) > 1 and item.qty is not None and located:
                total = sum(d['qty'] for d in located)
                if abs(total - item.qty) > 1e-6:
                    item.flag('delivery_quantity_mismatch',
                              f'consignee quantities add up to {total:g}, item quantity is {item.qty:g}')
            if any(d.get('days') is None for d in item.delivery):
                item.flag('delivery_days_missing', 'delivery period not stated for every location')
        spec_keys = {}
        for key, value in item.spec.items():
            norm = re.sub(r'[^a-z]', '', key.lower())
            if norm in spec_keys and spec_keys[norm] != value.strip().lower():
                item.flag('conflicting_specification', f'{key}: "{spec_keys[norm]}" vs "{value}"')
            spec_keys[norm] = value.strip().lower()
    if declared_total and declared_total > 1 and len(items) > 1:
        summed = sum(i.qty for i in items if i.qty is not None)
        if abs(summed - declared_total) > 1e-6:
            bid_issues.append({'code': 'declared_quantity_mismatch',
                               'detail': f'bid declares {declared_total:g}, items add up to {summed:g}'})
    return bid_issues


def item_from_row(row):
    """An Item back from bid_items, without pricing-stage issues."""
    return Item(row['name'], None if row.get('qty') is None else float(row['qty']),
                row.get('unit') or '', dict(row.get('spec') or {}), row.get('brand') or '',
                row.get('model') or '', '', '', list(row.get('delivery') or []),
                [i for i in row.get('issues') or [] if i.get('code') != 'unpriced'])


def extract_items(documents, bid):
    """Extraction for one bid from all its documents (bid PDF first)."""
    details = bid.get('details') or {}
    category_text = ' '.join([bid.get('title', ''), bid.get('category', ''),
                              details.get('item_category', '')])
    if details.get('kind') == 'service' or SERVICE_WORDS.search(category_text):
        return Extraction([], 'unpriceable', [{'code': 'service_or_works',
                                               'detail': 'services and works are not valued'}])
    tables = [t for d in documents for t in d.tables]
    items, bid_issues = items_from_boq(tables), []
    if not items and documents:
        items, bid_issues = items_from_gem_document(documents[0], bid)
    if not items and not bid_issues:
        bid_issues = [{'code': 'no_items_found', 'detail': 'no BOQ table or item details found'}]
    declared = details.get('quantity') if details.get('quantity') is not None else bid.get('quantity')
    bid_issues += validate(items, float(declared) if declared else None)
    blocking = any(i['code'] in BLOCKING for i in bid_issues) or any(
        i['code'] in BLOCKING for item in items for i in item.issues)
    return Extraction(items, 'incomplete' if blocking or not items else 'complete', bid_issues)
