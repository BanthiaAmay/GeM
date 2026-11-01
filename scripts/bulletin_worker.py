#!/usr/bin/env python3
"""Server worker: saves new "GeM Weekly Bulletin" videos for the app's News page.

  python3 scripts/bulletin_worker.py run --dry-run   read the feed and print; writes nothing
  python3 scripts/bulletin_worker.py run             save new bulletins to gem_bulletins

Reads the official GeM YouTube channel's public upload feed (latest 15 uploads,
no API key). Needs GEM_YOUTUBE_CHANNEL_ID (the channel's "UC..." id) and, unless
--dry-run, the server secrets SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY. Values
may also sit in a git-ignored .env file. Standard library only.
"""
import argparse
from datetime import datetime
import os
from pathlib import Path
import re
import sys
import urllib.request
from urllib.error import URLError
import xml.etree.ElementTree as ET

from bid_worker import Supabase, load_env_file

FEED_URL = 'https://www.youtube.com/feeds/videos.xml?channel_id={}'
USER_AGENT = 'Mozilla/5.0 (compatible; Bid2Scale-bulletins/1.0)'
CHANNEL_ID = re.compile(r'^UC[A-Za-z0-9_-]{22}$')
VIDEO_ID = re.compile(r'^[A-Za-z0-9_-]{11}$')
BULLETIN = re.compile(r'bulletin', re.IGNORECASE)
NS = {'atom': 'http://www.w3.org/2005/Atom', 'yt': 'http://www.youtube.com/xml/schemas/2015'}


class FeedError(Exception):
    """The feed could not be fetched or read."""


def fetch_feed(channel_id, urlopen=urllib.request.urlopen):
    request = urllib.request.Request(FEED_URL.format(channel_id), headers={'User-Agent': USER_AGENT})
    try:
        with urlopen(request, timeout=30) as response:
            return response.read()
    except (URLError, TimeoutError) as error:
        raise FeedError(f'Could not fetch the YouTube feed: {error}') from error


def parse_bulletins(xml_bytes):
    """Bulletin rows from a YouTube channel Atom feed, newest first."""
    try:
        root = ET.fromstring(xml_bytes)
    except ET.ParseError as error:
        raise FeedError(f'The YouTube feed is not valid XML: {error}') from error
    rows = []
    for entry in root.findall('atom:entry', NS):
        video_id = (entry.findtext('yt:videoId', '', NS)).strip()
        title = ' '.join(entry.findtext('atom:title', '', NS).split())[:300]
        published = entry.findtext('atom:published', '', NS).strip()
        if not (VIDEO_ID.match(video_id) and title and BULLETIN.search(title)):
            continue
        try:
            published_at = datetime.fromisoformat(published)
        except ValueError:
            continue
        if published_at.tzinfo is None:
            continue
        rows.append({'video_id': video_id, 'title': title, 'published_at': published_at.isoformat()})
    rows.sort(key=lambda row: row['published_at'], reverse=True)
    return rows


def save(db, rows):
    if not rows:
        return []
    return db.request('POST', 'gem_bulletins?on_conflict=video_id&select=video_id', rows,
                      'resolution=merge-duplicates,return=representation')


def main(argv=None, env=os.environ, urlopen=urllib.request.urlopen):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('run').add_argument('--dry-run', action='store_true',
                                            help='read the feed only; needs no Supabase secrets')
    args = parser.parse_args(argv)
    env = {**load_env_file(Path(__file__).resolve().parent.parent / '.env'), **env}

    channel_id = env.get('GEM_YOUTUBE_CHANNEL_ID', '').strip()
    if not CHANNEL_ID.match(channel_id):
        print('Set GEM_YOUTUBE_CHANNEL_ID to the GeM channel id (starts with "UC", 24 characters).',
              file=sys.stderr)
        return 2
    try:
        rows = parse_bulletins(fetch_feed(channel_id, urlopen))
    except FeedError as error:
        print(error, file=sys.stderr)
        return 1
    for row in rows:
        print(f"{row['published_at'][:10]}  {row['video_id']}  {row['title']}")
    if not rows:
        print('No bulletin in the latest uploads.')
    if args.dry_run:
        return 0

    missing = [k for k in ('SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY') if not env.get(k)]
    if missing:
        print('Missing ' + ', '.join(missing), file=sys.stderr)
        return 2
    saved = save(Supabase(env['SUPABASE_URL'], env['SUPABASE_SERVICE_ROLE_KEY'], urlopen), rows)
    print(f'Saved {len(saved or [])} bulletin(s).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
