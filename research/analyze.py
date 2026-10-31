#!/usr/bin/env python3
"""Analyze an operator CSV export of research_export. Python stdlib only."""
import argparse
import csv
import json
import math
from datetime import datetime, timezone


def fisher_exact(a, b, c, d):
    """Two-sided fixed-margin Fisher exact p-value using hypergeometric tables."""
    n1, n2, successes = a + b, c + d, a + c
    denominator = math.comb(n1 + n2, successes)
    def prob(x):
        return math.comb(n1, x) * math.comb(n2, successes - x) / denominator
    observed = prob(a)
    return min(1.0, sum(prob(x) for x in range(max(0, successes-n2), min(n1, successes)+1)
                        if prob(x) <= observed + 1e-12))


def wilson(k, n):
    if not n:
        return None
    z = 1.959963984540054
    p = k/n
    centre = (p + z*z/(2*n))/(1+z*z/n)
    half = z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/(1+z*z/n)
    return [centre-half, centre+half]


def parse_date(value):
    d = datetime.fromisoformat(value.replace('Z', '+00:00'))
    return d.replace(tzinfo=timezone.utc) if d.tzinfo is None else d


def truth(v):
    if v.lower() not in {'true', 'false', 't', 'f'}:
        raise ValueError(f'Unexpected boolean value: {v!r}')
    return v.lower() in {'true', 't'}


def analyze(rows, as_of):
    ids = [r['participant_id'] for r in rows]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate participants: export one row per assigned participant')
    eligible = [r for r in rows if parse_date(r['followup_due_at']) <= as_of]
    result = {'as_of': as_of.isoformat(), 'participants': len(rows),
              'pending_followup': len(rows)-len(eligible), 'completed_followup': len(eligible),
              'warning': 'Observed consented signed-in cohort only. Non-randomised comparison is not causal. Opt-outs retained in assigned-group denominators.'}
    groups = {g: [r for r in eligible if r['cohort'] == g] for g in ('tool_assisted', 'comparison')}
    if sum(map(len, groups.values())) != len(eligible):
        raise ValueError('Unknown cohort')
    result['groups'] = {}
    for name, group in groups.items():
        result['groups'][name] = {'n': len(group), 'assignment_methods': sorted(set(r['assignment_method'] for r in group))}
        for metric in ('engaged', 'registration_intent', 'disqualified_by_choice', 'verified_registration', 'verified_first_order'):
            k = sum(truth(r[metric]) for r in group)
            result['groups'][name][metric] = {'count': k, 'rate': k/len(group) if group else None, 'wilson_95_ci': wilson(k, len(group))}
    if all(groups.values()):
        a = result['groups']['tool_assisted']['verified_registration']['count']
        c = result['groups']['comparison']['verified_registration']['count']
        b, d = len(groups['tool_assisted'])-a, len(groups['comparison'])-c
        result['primary_outcome'] = {'name': 'verified_registration', 'two_sided_fisher_p': fisher_exact(a,b,c,d),
                                     'absolute_rate_difference': a/(a+b)-c/(c+d)}
    else:
        result['primary_outcome'] = {'reason': 'Two non-empty observed groups required; no significance test performed.'}
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv_file')
    parser.add_argument('--as-of', help='ISO timestamp; defaults to current UTC')
    args = parser.parse_args()
    with open(args.csv_file, newline='', encoding='utf-8-sig') as f:
        rows = list(csv.DictReader(f))
    print(json.dumps(analyze(rows, parse_date(args.as_of) if args.as_of else datetime.now(timezone.utc)), indent=2))
