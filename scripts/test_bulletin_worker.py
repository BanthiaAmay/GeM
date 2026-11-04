import io
import json
import unittest
from urllib.error import URLError

from bulletin_worker import GEM_CHANNEL_ID, FeedError, fetch_feed, main, parse_bulletins

FEED = b'''<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns="http://www.w3.org/2005/Atom">
 <entry>
  <yt:videoId>AbCdEfGh_-1</yt:videoId>
  <title>GeM Bulletin October Week #3</title>
  <published>2026-10-22T10:30:00+00:00</published>
 </entry>
 <entry>
  <yt:videoId>ZyXwVuTs-_2</yt:videoId>
  <title>One Platform Changed Everything: How Amit Vishwa Traders Grew with GeM</title>
  <published>2026-10-31T09:00:00+00:00</published>
 </entry>
 <entry>
  <yt:videoId>QwErTyUiOp3</yt:videoId>
  <title>GeM   Weekly BULLETIN
   October 2026, Week 4</title>
  <published>2026-10-29T11:00:00+00:00</published>
 </entry>
 <entry>
  <yt:videoId>bad id</yt:videoId>
  <title>GeM Bulletin broken id</title>
  <published>2026-10-29T11:00:00+00:00</published>
 </entry>
 <entry>
  <yt:videoId>NoDate00001</yt:videoId>
  <title>GeM Bulletin no date</title>
  <published>yesterday</published>
 </entry>
</feed>'''

CHANNEL = 'UC' + 'a' * 22


class Response(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class ParseTest(unittest.TestCase):
    def test_keeps_only_valid_bulletins_newest_first(self):
        rows = parse_bulletins(FEED)
        self.assertEqual([r['video_id'] for r in rows], ['QwErTyUiOp3', 'AbCdEfGh_-1'])
        self.assertEqual(rows[0]['title'], 'GeM Weekly BULLETIN October 2026, Week 4')
        self.assertEqual(rows[0]['published_at'], '2026-10-29T11:00:00+00:00')
        self.assertEqual(set(rows[0]), {'video_id', 'title', 'published_at'})

    def test_bad_xml_is_a_feed_error(self):
        with self.assertRaises(FeedError):
            parse_bulletins(b'<html>not a feed')

    def test_network_failure_is_a_feed_error(self):
        def offline(*_, **__):
            raise URLError('offline')
        with self.assertRaises(FeedError):
            fetch_feed(CHANNEL, offline)


class MainTest(unittest.TestCase):
    def test_rejects_an_invalid_channel_override(self):
        self.assertEqual(main(['run', '--dry-run'], env={'GEM_YOUTUBE_CHANNEL_ID': '@GovernmenteMarketplace'}), 2)

    def test_defaults_to_the_gem_channel(self):
        calls = []

        def urlopen(request, timeout):
            calls.append(request.full_url)
            return Response(FEED)
        for env in ({}, {'GEM_YOUTUBE_CHANNEL_ID': ''}):
            calls.clear()
            self.assertEqual(main(['run', '--dry-run'], env=env, urlopen=urlopen), 0)
            self.assertEqual(calls, [f'https://www.youtube.com/feeds/videos.xml?channel_id={GEM_CHANNEL_ID}'])
        self.assertEqual(GEM_CHANNEL_ID, 'UC1LaBWVVZv3k23BZApfDlsQ')

    def test_dry_run_writes_nothing(self):
        calls = []

        def urlopen(request, timeout):
            calls.append(request.full_url)
            return Response(FEED)
        self.assertEqual(main(['run', '--dry-run'], env={'GEM_YOUTUBE_CHANNEL_ID': CHANNEL}, urlopen=urlopen), 0)
        self.assertEqual(calls, [f'https://www.youtube.com/feeds/videos.xml?channel_id={CHANNEL}'])

    def test_run_upserts_on_video_id(self):
        sent = []

        def urlopen(request, timeout):
            if 'youtube.com' in request.full_url:
                return Response(FEED)
            sent.append(request)
            return Response(json.dumps([{'video_id': 'QwErTyUiOp3'}, {'video_id': 'AbCdEfGh_-1'}]).encode())
        env = {'GEM_YOUTUBE_CHANNEL_ID': CHANNEL, 'SUPABASE_URL': 'https://example.supabase.co',
               'SUPABASE_SERVICE_ROLE_KEY': 'service-key'}
        self.assertEqual(main(['run'], env=env, urlopen=urlopen), 0)
        self.assertEqual(len(sent), 1)
        self.assertTrue(sent[0].full_url.endswith('/rest/v1/gem_bulletins?on_conflict=video_id&select=video_id'))
        self.assertIn('resolution=merge-duplicates', sent[0].get_header('Prefer'))
        self.assertEqual([r['video_id'] for r in json.loads(sent[0].data)], ['QwErTyUiOp3', 'AbCdEfGh_-1'])

    def test_run_without_secrets_fails(self):
        def urlopen(request, timeout):
            return Response(FEED)
        self.assertEqual(main(['run'], env={'GEM_YOUTUBE_CHANNEL_ID': CHANNEL}, urlopen=urlopen), 2)


if __name__ == '__main__':
    unittest.main()
