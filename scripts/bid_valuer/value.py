"""One bid's estimated contract value from its priced items. No margin, no
profit: quantity x market unit price, priced items only."""
from .prices import RELIABILITY_WEIGHT


def confidence_band(coverage, match, reliability):
    if coverage == 1 and match >= 0.85 and reliability >= 0.9:
        return 'high', 'high: every item priced, strong matches, 3+ offers'
    if coverage >= 0.6 and match >= 0.75 and reliability >= 0.6:
        reasons = [r for r, bad in (('coverage<1', coverage < 1), ('match<0.85', match < 0.85),
                                    ('reliability<0.9', reliability < 0.9)) if bad]
        return 'medium', 'medium: ' + ', '.join(reasons)
    reasons = [r for r, bad in (('coverage<0.6', coverage < 0.6), ('match<0.75', match < 0.75),
                                ('reliability<0.6', reliability < 0.6)) if bad]
    return 'low', 'low: ' + ', '.join(reasons)


def value_bid(extraction, prices, documents_hash=''):
    """(items payload, valuation payload) for replace_bid_valuation.
    `prices` lines up with extraction.items (an ItemPrice each)."""
    items, line_values, scores, weights = [], [], [], []
    for item, price in zip(extraction.items, prices):
        row = {'name': item.name, 'spec': item.spec, 'brand': item.brand, 'model': item.model,
               'unit': item.unit, 'qty': item.qty, 'delivery': item.delivery,
               'issues': item.issues + ([{'code': 'unpriced', 'detail': price.reason}]
                                        if not price.priced and price.reason else []),
               'priced': False, 'offer_ids': [], 'price_reliability': 'unpriced'}
        if price.priced and item.qty is not None:
            line = round(item.qty * price.unit_price, 2)
            row.update(priced=True, unit_price=price.unit_price, line_value=line,
                       match_score=price.match_score, offer_ids=price.offer_ids,
                       price_reliability=price.price_reliability)
            line_values.append(line)
            scores.append(price.match_score)
            weights.append(RELIABILITY_WEIGHT[price.price_reliability])
        items.append(row)

    count, priced = len(items), len(line_values)
    total = round(sum(line_values), 2)
    coverage = priced / count if count else 0.0
    if priced == 0 or total == 0:
        # Nothing priced: no ratio is computed, so nothing divides by zero.
        valuation = {'match_confidence': None, 'price_reliability': None, 'confidence': 'low',
                     'confidence_factors': {'coverage': coverage, 'match': None,
                                            'reliability': None, 'rule': 'no priced items'}}
    else:
        match = round(sum(v * s for v, s in zip(line_values, scores)) / total, 3)
        reliability = round(sum(v * w for v, w in zip(line_values, weights)) / total, 3)
        band, rule = confidence_band(coverage, match, reliability)
        valuation = {'match_confidence': match, 'price_reliability': reliability, 'confidence': band,
                     'confidence_factors': {'coverage': round(coverage, 3), 'match': match,
                                            'reliability': reliability, 'rule': rule,
                                            'reliability_basis': 'number of independent offers'}}
    valuation['confidence_factors']['extraction_issues'] = extraction.issues
    complete = extraction.status == 'complete' and count > 0 and priced == count
    unpriced = [i['name'] for i in items if not i['priced']]
    reason = extraction.reason
    if not complete and unpriced:
        reason = (reason + '; ' if reason else '') + f'{len(unpriced)} item(s) unpriced'
    valuation.update(extraction_status=extraction.status, incomplete_reason=reason[:500],
                     documents_hash=documents_hash, priced_value_inr=total, complete=complete,
                     pricing_coverage=round(coverage, 3) if count else None)
    return items, valuation
