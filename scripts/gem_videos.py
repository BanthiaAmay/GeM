"""Keeps the app's GeM video lists fresh from the official GeM YouTube channel.

YouTube's public RSS feeds stopped answering (HTTP 404 for every channel), so
this reads the channel's public "Videos" page instead: its embedded data lists
the latest 30 uploads. Only videos not saved yet get their own watch page
fetched, for the exact upload time and length. No API key is needed.

Each video is sorted into a kind the app shows in a different place:
  bulletin  GeM Weekly Bulletin  -> News page, Home
  tip       GeM Shorts and other one-minute tips -> Trainings "New from GeM"
  learning  explainers, webinars, GeMCast -> Trainings "New from GeM"
  story     success stories, #GeMSellerSpeak/#GeMBuyerSpeak -> News page
Standard library only.
"""
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import time
import urllib.request
from urllib.error import URLError

GEM_CHANNEL_ID = 'UC1LaBWVVZv3k23BZApfDlsQ'  # youtube.com/@GovernmenteMarketplace
CHANNEL_VIDEOS_URL = 'https://www.youtube.com/channel/{}/videos'
WATCH_URL = 'https://www.youtube.com/watch?v={}'
# A browser-like agent: YouTube serves the full page (with its data) to these.
USER_AGENT = ('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0 Safari/537.36')
CHANNEL_ID = re.compile(r'^UC[A-Za-z0-9_-]{22}$')
VIDEO_ID = re.compile(r'^[A-Za-z0-9_-]{11}$')
SYNC_EVERY = timedelta(hours=3)
STAMP = Path(__file__).resolve().parent.parent / '.video-sync-stamp'


class VideoError(Exception):
    """YouTube could not be reached or its page no longer has the data we read."""


def _get(url, urlopen):
    request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT, 'Accept-Language': 'en-US,en'})
    try:
        with urlopen(request, timeout=30) as response:
            return response.read().decode('utf-8', errors='replace')
    except (URLError, TimeoutError) as error:
        raise VideoError(f'Could not reach YouTube: {error}') from error


def _initial_data(page):
    match = re.search(r'var ytInitialData = (\{.*?\});</script>', page, re.S)
    if not match:
        raise VideoError('The YouTube channel page has no video data (its layout may have changed).')
    try:
        return json.loads(match.group(1))
    except ValueError as error:
        raise VideoError('The YouTube channel page data could not be read.') from error


def parse_channel_videos(page):
    """[{video_id, title}] from a channel "Videos" page, newest first."""
    found, seen = [], set()

    def add(video_id, title):
        title = ' '.join(str(title or '').split())[:300]
        if VIDEO_ID.match(str(video_id or '')) and title and video_id not in seen:
            seen.add(video_id)
            found.append({'video_id': video_id, 'title': title})

    def walk(node):
        if isinstance(node, dict):
            lockup = node.get('lockupViewModel')
            if isinstance(lockup, dict) and lockup.get('contentType', '').endswith('VIDEO'):
                meta = lockup.get('metadata', {}).get('lockupMetadataViewModel', {})
                add(lockup.get('contentId'), meta.get('title', {}).get('content'))
            for key in ('videoRenderer', 'gridVideoRenderer'):  # older layouts
                video = node.get(key)
                if isinstance(video, dict):
                    title = video.get('title', {})
                    add(video.get('videoId'), title.get('simpleText') or
                        ''.join(run.get('text', '') for run in title.get('runs', [])))
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(_initial_data(page))
    if not found:
        raise VideoError('No videos found on the YouTube channel page (its layout may have changed).')
    return found


def parse_watch_details(page):
    """{published_at, duration_seconds} from a watch page, or None if missing."""
    date = re.search(r'"publishDate":"([^"]+)"', page) or re.search(r'"uploadDate":"([^"]+)"', page)
    length = re.search(r'"lengthSeconds":"(\d+)"', page)
    if not date:
        return None
    try:
        published = datetime.fromisoformat(date.group(1))
    except ValueError:
        return None
    if published.tzinfo is None:
        return None
    return {'published_at': published.isoformat(),
            'duration_seconds': int(length.group(1)) if length else None}


def classify(title, duration_seconds=None):
    """Which app section a GeM video belongs to (see the module docstring)."""
    text = title.lower()
    if 'bulletin' in text:
        return 'bulletin'
    if re.search(r'#gem(seller|buyer)speak|success|grew|growth story|journey|'
                 r'won .*deals|grows', text):
        return 'story'
    if '#gemshorts' in text or '#shorts' in text or (duration_seconds is not None and duration_seconds <= 60):
        return 'tip'
    return 'learning'


def sync_due(now, stamp=STAMP):
    """True when the last sync is older than SYNC_EVERY (the stamp file holds it)."""
    try:
        last = datetime.fromisoformat(stamp.read_text().strip())
    except (OSError, ValueError):
        return True
    return now - last >= SYNC_EVERY


def mark_synced(now, stamp=STAMP):
    try:
        stamp.write_text(now.isoformat())
    except OSError:
        pass  # Read-only hosts simply sync on every run.


def sync_videos(db, *, channel_id=GEM_CHANNEL_ID, urlopen=urllib.request.urlopen, sleep=time.sleep,
                max_new=30, dry_run=False, log=print):
    """Saves GeM channel videos the app does not have yet. Returns them."""
    if not CHANNEL_ID.match(channel_id):
        raise VideoError('The GeM channel id must start with "UC" and be 24 characters.')
    listed = parse_channel_videos(_get(CHANNEL_VIDEOS_URL.format(channel_id), urlopen))
    known = set()
    if db is not None:
        from bid_worker import in_filter
        rows = db.request('GET', 'gem_bulletins?select=video_id&video_id='
                          + in_filter([v['video_id'] for v in listed]))
        known = {row['video_id'] for row in rows or []}
    new = [video for video in listed if video['video_id'] not in known][:max_new]
    saved = []
    for index, video in enumerate(new):
        if index:
            sleep(1)  # One page a second: polite to YouTube.
        try:
            details = parse_watch_details(_get(WATCH_URL.format(video['video_id']), urlopen))
        except VideoError as error:
            log(f"{video['video_id']}: skipped this run ({error})")
            continue
        if details is None:
            log(f"{video['video_id']}: no upload date on its page; skipped this run")
            continue
        saved.append({**video, **details, 'kind': classify(video['title'], details['duration_seconds'])})
    for video in saved:
        log(f"{video['published_at'][:10]}  {video['kind']:<8} {video['video_id']}  {video['title'][:70]}")
    if saved and db is not None and not dry_run:
        db.request('POST', 'gem_bulletins?on_conflict=video_id', saved, 'resolution=merge-duplicates')
    log(f"Videos: {len(listed)} on the GeM channel page, {len(saved)} new"
        + (' (dry run, nothing saved).' if dry_run else ' saved.'))
    return saved
