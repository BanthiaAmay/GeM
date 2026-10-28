#!/usr/bin/env python3
"""Import normalized records from an authorized feed/export; not a GeM scraper.

Dry-run by default. --apply writes bids and queues matches; it never sends messages.
Credentials are read from the server environment, never from Flutter configuration.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import urllib.request
from urllib.parse import urlparse


def normalize(record):
    result = {}
    for field, limit in [('source_id', 120), ('title', 500), ('category', 200),
                         ('buyer', 500), ('state', 100)]:
        value = record.get(field, '')
        if not isinstance(value, str) or len(value.strip()) > limit:
            raise ValueError(f'Invalid {field}')
        result[field] = value.strip()
    if not result['source_id'] or not result['title']:
        raise ValueError('source_id and title are required')
    url = record.get('source_url', '')
    parsed = urlparse(url)
    if (parsed.scheme != 'https' or not parsed.hostname or
            not re.fullmatch(r'(?:[a-z0-9-]+\.)*gem\.gov\.in', parsed.hostname) or
            parsed.username or parsed.password or parsed.port not in (None, 443)):
        raise ValueError('source_url must be an official HTTPS GeM link')
    result['source_url'] = url
    closes = datetime.fromisoformat(record['closes_at'].replace('Z', '+00:00'))
    if closes.utcoffset() is None:
        raise ValueError('closes_at must include its timezone; use +05:30 for IST')
    result['closes_at'] = closes.astimezone(timezone.utc).isoformat()
    result['fetched_at'] = datetime.now(timezone.utc).isoformat()
    result['published'] = True
    return result


def post(base, key, path, payload, prefer=None):
    headers = {'apikey': key, 'Authorization': f'Bearer {key}',
               'Content-Type': 'application/json'}
    if prefer:
        headers['Prefer'] = prefer
    request = urllib.request.Request(base + '/rest/v1/' + path,
        data=json.dumps(payload).encode(), headers=headers, method='POST')
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path, help='JSON array of normalized bid records')
    parser.add_argument('--apply', action='store_true', help='Write records and queue matches')
    args = parser.parse_args()
    raw = json.loads(args.file.read_text())
    if not isinstance(raw, list):
        raise ValueError('Expected a JSON array')
    records = [normalize(record) for record in raw]
    if not args.apply:
        print(f'Validated {len(records)} bids. Dry-run only; no database writes or messages.')
        return
    base = os.environ['SUPABASE_URL'].rstrip('/')
    if urlparse(base).scheme != 'https':
        raise ValueError('Use an HTTPS Supabase URL')
    key = os.environ['SUPABASE_SERVICE_ROLE_KEY']
    for record in records:
        saved = post(base, key, 'gem_bids?on_conflict=source_id', record,
                     'resolution=merge-duplicates,return=representation')
        post(base, key, 'rpc/queue_bid_matches', {'p_bid_id': saved[0]['id']})
    print(f'Imported {len(records)} bids and queued matching alerts. No messages sent.')


if __name__ == '__main__':
    main()
