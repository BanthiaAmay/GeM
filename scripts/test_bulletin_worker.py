from datetime import datetime, timedelta, timezone
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
from urllib.error import URLError

import bid_worker
from bulletin_worker import main
from gem_videos import (VideoError, classify, mark_synced, parse_channel_videos,
                        parse_watch_details, sync_due, sync_videos)


def lockup(video_id, title):
    return {'lockupViewModel': {
        'contentId': video_id, 'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
        'metadata': {'lockupMetadataViewModel': {'title': {'content': title}}}}}


def channel_page(*items):
    data = {'contents': {'tabs': [{'richGridRenderer': {'contents': [
        {'richItemRenderer': {'content': item}} for item in items]}}]}}
    return f'<html><script>var ytInitialData = {json.dumps(data)};</script></html>'


def watch_page(published='2026-11-03T00:45:19-08:00', seconds='58'):
    return f'<script>{{"lengthSeconds":"{seconds}","publishDate":"{published}"}}</script>'


PAGE = channel_page(
    lockup('_xLQb-ZEfhE', 'GeM Bulletin November Week #1'),
    lockup('g9gsdEO7cTk', 'GeM Bid Showing "Not Eligible"? | #GeMShorts'),
    lockup('6YAjRZUPIug', 'How   Amit Vishwa Traders\nGrew with GeM'),
    {'videoRenderer': {'videoId': 'YQcmtPc4uq8', 'title': {'runs': [{'text': 'GeM Portal Explained'}]}}},
    lockup('bad id', 'Broken'),
    lockup('_xLQb-ZEfhE', 'Duplicate of the first'),
)


class FakeResponse(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeYouTube:
    """Serves the channel page and watch pages; records the URLs asked for."""

    def __init__(self, page=PAGE, watch=None, fail=False):
        self.page, self.watch, self.fail, self.urls = page, watch or {}, fail, []

    def __call__(self, request, timeout):
        self.urls.append(request.full_url)
        if self.fail:
            raise URLError('offline')
        if '/videos' in request.full_url:
            return FakeResponse(self.page.encode())
        video_id = request.full_url.rsplit('=', 1)[-1]
        return FakeResponse(self.watch.get(video_id, watch_page()).encode())


class FakeDb:
    def __init__(self, known=()):
        self.known, self.saved = set(known), []

    def request(self, method, path, payload=None, prefer=None):
        if method == 'GET':
            return [{'video_id': v} for v in self.known if v in path]
        self.saved.extend(payload)
        return None


class ParseTest(unittest.TestCase):
    def test_reads_new_and_old_page_layouts(self):
        videos = parse_channel_videos(PAGE)
        self.assertEqual([v['video_id'] for v in videos],
                         ['_xLQb-ZEfhE', 'g9gsdEO7cTk', '6YAjRZUPIug', 'YQcmtPc4uq8'])
        self.assertEqual(videos[2]['title'], 'How Amit Vishwa Traders Grew with GeM')

    def test_a_changed_page_is_reported_not_ignored(self):
        with self.assertRaises(VideoError):
            parse_channel_videos('<html>no data</html>')
        with self.assertRaises(VideoError):
            parse_channel_videos(channel_page())

    def test_watch_page_gives_exact_date_and_length(self):
        self.assertEqual(parse_watch_details(watch_page()),
                         {'published_at': '2026-11-03T00:45:19-08:00', 'duration_seconds': 58})
        self.assertIsNone(parse_watch_details('<html></html>'))
        self.assertIsNone(parse_watch_details(watch_page(published='2026-11-03')))

    def test_videos_are_sorted_into_app_sections(self):
        self.assertEqual(classify('GeM Bulletin November Week #1', 58), 'bulletin')
        self.assertEqual(classify('#GeMSellerSpeak | मदन लाल शर्मा', 120), 'story')
        self.assertEqual(classify('From ₹55 Cr to ₹250 Cr: How GeM Powered Ethos’ Growth Story', 600), 'story')
        self.assertEqual(classify('GeM Bid Showing "Not Eligible"? | #GeMShorts', 45), 'tip')
        self.assertEqual(classify('Limited tender in Hindi', 50), 'tip')
        self.assertEqual(classify('GeM Portal Explained: Bidding Rules', 900), 'learning')


class SyncTest(unittest.TestCase):
    def test_saves_only_new_videos_with_kind_and_date(self):
        youtube, db = FakeYouTube(), FakeDb(known=['_xLQb-ZEfhE'])
        saved = sync_videos(db, urlopen=youtube, sleep=lambda s: None, log=lambda *_: None)
        self.assertEqual([v['video_id'] for v in saved], ['g9gsdEO7cTk', '6YAjRZUPIug', 'YQcmtPc4uq8'])
        self.assertEqual(db.saved, saved)
        self.assertEqual({v['kind'] for v in saved}, {'tip', 'story'})  # 58 s explainer = tip
        self.assertFalse(any('_xLQb-ZEfhE' in url for url in youtube.urls if 'watch' in url))

    def test_a_video_without_a_date_waits_for_the_next_run(self):
        youtube = FakeYouTube(watch={'g9gsdEO7cTk': '<html></html>'})
        saved = sync_videos(FakeDb(), urlopen=youtube, sleep=lambda s: None, log=lambda *_: None)
        self.assertNotIn('g9gsdEO7cTk', [v['video_id'] for v in saved])
        self.assertEqual(len(saved), 3)

    def test_dry_run_and_offline(self):
        db = FakeDb()
        sync_videos(db, urlopen=FakeYouTube(), sleep=lambda s: None, dry_run=True, log=lambda *_: None)
        self.assertEqual(db.saved, [])
        with self.assertRaises(VideoError):
            sync_videos(db, urlopen=FakeYouTube(fail=True), log=lambda *_: None)

    def test_runs_at_most_every_three_hours(self):
        now = datetime(2026, 11, 5, 9, 0, tzinfo=timezone.utc)
        with tempfile.TemporaryDirectory() as folder:
            stamp = Path(folder) / 'stamp'
            self.assertTrue(sync_due(now, stamp))
            mark_synced(now, stamp)
            self.assertFalse(sync_due(now + timedelta(hours=2), stamp))
            self.assertTrue(sync_due(now + timedelta(hours=3), stamp))


class MainTest(unittest.TestCase):
    def test_dry_run_needs_no_secrets(self):
        with mock.patch('sys.stdout', new_callable=io.StringIO) as out:
            self.assertEqual(main(['run', '--dry-run'], env={}, urlopen=FakeYouTube(),
                                  sleep=lambda s: None), 0)
        self.assertIn('4 new (dry run, nothing saved)', out.getvalue())

    def test_run_without_secrets_fails(self):
        self.assertEqual(main(['run'], env={}, urlopen=FakeYouTube()), 2)

    def test_bad_channel_override_is_refused(self):
        self.assertEqual(main(['run', '--dry-run'], env={'GEM_YOUTUBE_CHANNEL_ID': 'nope'}), 2)

    def test_offline_youtube_is_an_error(self):
        self.assertEqual(main(['run', '--dry-run'], env={}, urlopen=FakeYouTube(fail=True)), 1)


class BidWorkerVideosTest(unittest.TestCase):
    """The office PC's scheduled bid worker also keeps the videos fresh."""
    ENV = {'SUPABASE_URL': 'https://example.supabase.co', 'SUPABASE_SERVICE_ROLE_KEY': 'test-key'}

    def test_videos_command_saves_now_and_stamps(self):
        with mock.patch('gem_videos.sync_videos', return_value=[]) as sync, \
                mock.patch('gem_videos.mark_synced') as mark:
            self.assertEqual(bid_worker.main(['videos'], env=dict(self.ENV)), 0)
        self.assertEqual(sync.call_args.kwargs['channel_id'], 'UC1LaBWVVZv3k23BZApfDlsQ')
        mark.assert_called_once()

    def test_a_failed_sync_is_reported_and_retried_next_run(self):
        with mock.patch('gem_videos.sync_videos', side_effect=VideoError('down')), \
                mock.patch('gem_videos.mark_synced') as mark, \
                mock.patch('sys.stderr', new_callable=io.StringIO) as err:
            self.assertEqual(bid_worker.main(['videos'], env=dict(self.ENV)), 1)
        mark.assert_not_called()
        self.assertIn('Video sync failed: down', err.getvalue())


if __name__ == '__main__':
    unittest.main()
