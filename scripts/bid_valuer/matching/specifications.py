"""Structured product attributes from free text and spec key/value pairs."""
import re

# measured attribute unit -> (attribute, factor to its base unit)
_ATTR_UNITS = {
    'mm': ('length_mm', 1), 'cm': ('length_mm', 10), 'm': ('length_mm', 1000),
    'mtr': ('length_mm', 1000), 'meter': ('length_mm', 1000), 'metre': ('length_mm', 1000),
    'inch': ('length_mm', 25.4), 'inches': ('length_mm', 25.4),
    '"': ('length_mm', 25.4), 'ft': ('length_mm', 304.8), 'feet': ('length_mm', 304.8),
    'ml': ('volume_ml', 1), 'l': ('volume_ml', 1000), 'ltr': ('volume_ml', 1000),
    'litre': ('volume_ml', 1000), 'liter': ('volume_ml', 1000), 'litres': ('volume_ml', 1000),
    'g': ('mass_g', 1), 'gm': ('mass_g', 1), 'gsm': ('gsm', 1), 'kg': ('mass_g', 1000),
    'w': ('power_w', 1), 'watt': ('power_w', 1), 'watts': ('power_w', 1), 'kw': ('power_w', 1000),
    'v': ('voltage_v', 1), 'volt': ('voltage_v', 1), 'volts': ('voltage_v', 1),
    'kva': ('kva', 1), 'va': ('kva', 0.001), 'mah': ('battery_mah', 1), 'ah': ('battery_mah', 1000),
    'gb': ('storage_gb', 1), 'tb': ('storage_gb', 1024), 'mp': ('megapixel', 1),
    'hp': ('horsepower', 1), 'tr': ('tonnage', 1), 'ton': ('tonnage', 1),
    'lumen': ('lumen', 1), 'lumens': ('lumen', 1), 'lm': ('lumen', 1),
    'ip': ('ip_rating', 1),
}
_COLOUR_TEMP = re.compile(r'\b(\d{4})\s*k\b', re.I)
# Units that also name everyday sizes; read only right after a number.
_UNIT_RE = '|'.join(sorted((re.escape(u) for u in _ATTR_UNITS if u not in ('"', 'ip')),
                           key=len, reverse=True))
# "36 W", "220-240 V", "220 to 240V": a value, or a range kept as (low, high).
_MEASURE = re.compile(
    rf'(?:(\d+(?:\.\d+)?)\s*(?:-|–|to)\s*)?(\d+(?:\.\d+)?)\s*({_UNIT_RE}|")(?![a-z])', re.I)
_IP = re.compile(r'\bip\s*-?\s*(\d{2})\b', re.I)
# "(in Watt)" style unit hints in GeM spec keys.
_KEY_UNIT = re.compile(r'\(\s*in\s+([a-z"]+)\s*\)', re.I)

MATERIALS = (
    'stainless steel', 'mild steel', 'cast iron', 'steel', 'metal', 'aluminium', 'aluminum', 'iron',
    'copper', 'brass', 'plastic', 'pvc', 'hdpe', 'abs', 'polycarbonate', 'polypropylene',
    'nylon', 'polyester', 'cotton', 'leather', 'leatherette', 'mesh', 'fabric', 'rubber',
    'wood', 'wooden', 'teak', 'plywood', 'mdf', 'particle board', 'glass', 'ceramic', 'paper',
    'cardboard', 'fibre', 'fiber', 'frp', 'granite', 'marble',
)
_MATERIAL_ALIASES = {'aluminum': 'aluminium', 'wooden': 'wood', 'fiber': 'fibre',
                     'leatherette': 'leather', 'ss': 'stainless steel', 'ms': 'mild steel'}
# Material hierarchy: a material agrees with its broader kinds ("mild steel"
# fits "steel" and "metal") but not with a sibling ("stainless steel").
_MATERIAL_PARENT = {'stainless steel': 'steel', 'mild steel': 'steel', 'cast iron': 'iron',
                    'steel': 'metal', 'iron': 'metal', 'aluminium': 'metal', 'copper': 'metal',
                    'brass': 'metal', 'teak': 'wood', 'plywood': 'wood', 'mdf': 'wood',
                    'particle board': 'wood'}

# Common GeM goods sold under several names; the head noun may be any of them.
SYNONYMS = [{'almirah', 'cupboard', 'wardrobe', 'locker'}, {'luminaire', 'light', 'lamp', 'fixture'},
            {'desktop', 'computer', 'pc'}, {'table', 'desk'}, {'tubelight', 'tube'},
            {'dustbin', 'bin'}, {'carpet', 'rug'}, {'mattress', 'matress'}]

STOPWORDS = frozenset(
    'a an and as at by for from in is it of on or the to with without per set pack pcs '
    'nos piece pieces unit units type size new best quality high grade item items product '
    'products buy price online india made supply supplier conforming conform is as specification'
    .split())


def _add(attrs, name, low, high=None):
    low = round(float(low), 2)
    high = low if high is None else round(float(high), 2)
    attrs.setdefault(name, set()).add((min(low, high), max(low, high)))


def measures(text):
    """{'power_w': {(36.0, 36.0)}, 'voltage_v': {(220.0, 240.0)}, ...} from free text.
    Every value is a (low, high) interval; single values have low == high."""
    attrs = {}
    for low, number, unit in _MEASURE.findall(str(text or '')):
        name, factor = _ATTR_UNITS[unit.lower()]
        value = float(number) * factor
        _add(attrs, name, float(low) * factor if low else value, value)
    for number in _IP.findall(str(text or '')):
        _add(attrs, 'ip_rating', number)
    for number in _COLOUR_TEMP.findall(str(text or '')):
        _add(attrs, 'colour_temp_k', number)
    return attrs


def overlaps(a, b, tolerance=0.02):
    """True if any interval in `a` meets any in `b`, allowing 2 % for rounding."""
    for lo1, hi1 in a:
        for lo2, hi2 in b:
            slack = tolerance * max(abs(hi1), abs(hi2), 1e-9)
            if lo1 <= hi2 + slack and lo2 <= hi1 + slack:
                return True
    return False


def materials(text):
    t = ' ' + re.sub(r'[^a-z ]', ' ', str(text or '').lower()) + ' '
    found = set()
    for word in MATERIALS:
        if f' {word} ' in t:
            found.add(_MATERIAL_ALIASES.get(word, word))
            t = t.replace(f' {word} ', ' ')
    for short, full in (('ss', 'stainless steel'), ('ms', 'mild steel')):
        if f' {short} ' in t:
            found.add(full)
    # "Mild steel ... steel almirah": keep the specific kind only, so the
    # generic word cannot agree with a sibling (stainless steel).
    return {m for m in found if not any(m in ancestors(other) for other in found)}


def ancestors(material):
    found = []
    while material in _MATERIAL_PARENT:
        material = _MATERIAL_PARENT[material]
        found.append(material)
    return found


def materials_compatible(a, b):
    return a == b or a in ancestors(b) or b in ancestors(a)


def materials_conflict(wanted, offered):
    """True when both name materials and none of the wanted ones agrees with
    any offered one (mild steel vs stainless steel conflicts; vs metal agrees)."""
    if not wanted or not offered:
        return False
    return not any(materials_compatible(w, o) for w in wanted for o in offered)


def model_tokens(text):
    """Model-number-like tokens: letters and digits together, 4+ chars ("LJ1220", "HP-15S")."""
    tokens = set()
    for raw in re.findall(r'[A-Za-z0-9][A-Za-z0-9\-/]{2,}[A-Za-z0-9]', str(text or '')):
        token = re.sub(r'[\-/]', '', raw).upper()
        if len(token) >= 4 and re.search(r'[A-Z]', token) and re.search(r'\d', token) \
                and not re.fullmatch(r'\d+(MM|CM|ML|KG|GM|GB|TB|MAH|KVA|W|V|MP|HP|INCH|LTR)', token) \
                and not re.fullmatch(r'IS\d+', token):
            tokens.add(token)
    return tokens


def words(text):
    return {w for w in re.findall(r'[a-z]{3,}', str(text or '').lower()) if w not in STOPWORDS}


def field_key(text):
    text = _KEY_UNIT.sub('', str(text or '').lower())
    return ' '.join(w[:-1] if w.endswith('s') and len(w) > 3 else w
                    for w in re.findall(r'[a-z]+', text) if w not in ('no', 'of', 'the', 'number'))


def _values(text):
    """Comparable form of a spec value: its numbers, else its words."""
    numbers = {round(float(n), 2) for n in re.findall(r'\d+(?:\.\d+)?', str(text or ''))}
    return ('num', numbers) if numbers else ('words', words(text))


def compare_specs(wanted, offered):
    """(matched keys, conflicts) for spec fields both sides state.
    "Number of Doors: 2" vs "No. of Doors: 4" is a conflict; vague bid values
    ("As per requirement", "Yes") are not compared."""
    offer_by_key = {field_key(k): v for k, v in (offered or {}).items() if field_key(k)}
    matched, conflicts = [], []
    for key, value in (wanted or {}).items():
        norm = field_key(key)
        # Materials are compared by materials_conflict, which knows their kinds.
        if not norm or norm not in offer_by_key or 'material' in norm:
            continue
        kind_w, want = _values(value)
        kind_o, got = _values(offer_by_key[norm])
        if not want or not got or kind_w != kind_o:
            continue
        if kind_w == 'num':
            ok = any(abs(a - b) <= 0.02 * max(abs(a), abs(b), 1e-9) for a in want for b in got)
        else:
            ok = bool(want & got)
        (matched if ok else conflicts).append(f'{key}: {value} vs {offer_by_key[norm]}')
    return matched, conflicts


def head_noun(name):
    """The product word of a name: its last significant word ("chair" in
    "Office Chair", "light" in "LED Luminaire For Road And Street Lights")."""
    found = [w for w in re.findall(r'[a-z]{3,}', str(name or '').lower()) if w not in STOPWORDS]
    if not found:
        return ''
    word = found[-1]
    return word[:-1] if word.endswith('s') and len(word) > 3 else word


def has_head_noun(name, offer_words):
    noun = head_noun(name)
    if not noun:
        return False
    options = next((group for group in SYNONYMS if noun in group), {noun})
    return bool(options & offer_words)


def spec_values(spec):
    """Only the values of a spec map, so field names ("Almirah Type") never
    count as the product itself."""
    if isinstance(spec, str):
        return spec
    return ' '.join(str(v) for v in (spec or {}).values())


def spec_text(spec):
    """One searchable line per GeM spec pair, carrying the key's unit hint:
    {"System Wattage (in Watt)": "36"} -> "36 watt System Wattage"."""
    if isinstance(spec, str):
        return spec
    lines = []
    for key, value in (spec or {}).items():
        hint = _KEY_UNIT.search(str(key))
        value = str(value)
        if hint and re.fullmatch(r'\s*\d+(?:\.\d+)?\s*', value):
            value = f'{value.strip()} {hint.group(1)}'
        lines.append(f'{value} {key}')
    return '\n'.join(lines)
