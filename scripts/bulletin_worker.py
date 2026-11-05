#!/usr/bin/env python3
"""Saves new videos from the official GeM YouTube channel for the app.

  python3 scripts/bulletin_worker.py run --dry-run   read YouTube and print; writes nothing
  python3 scripts/bulletin_worker.py run             save new videos to gem_bulletins

Kept for existing schedules: the bid worker's `run` already does this every
3 hours (see scripts/gem_videos.py, which also explains the video kinds).
GEM_YOUTUBE_CHANNEL_ID optionally overrides the built-in GeM channel id.
Unless --dry-run, needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (or a
git-ignored .env file). Standard library only.
"""
import argparse
import os
from pathlib import Path
import sys
import urllib.request

from bid_worker import Supabase, load_env_file
from gem_videos import CHANNEL_ID, GEM_CHANNEL_ID, VideoError, sync_videos


def main(argv=None, env=None, urlopen=urllib.request.urlopen, sleep=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('run').add_argument('--dry-run', action='store_true',
                                            help='read YouTube only; needs no Supabase secrets')
    args = parser.parse_args(argv)
    if env is None:
        # Real runs: the git-ignored .env file, overridden by exported variables.
        # Callers passing env (tests) never pick up a developer's real keys.
        env = {**load_env_file(Path(__file__).resolve().parent.parent / '.env'), **os.environ}

    channel_id = (env.get('GEM_YOUTUBE_CHANNEL_ID') or '').strip() or GEM_CHANNEL_ID
    if not CHANNEL_ID.match(channel_id):
        print('GEM_YOUTUBE_CHANNEL_ID must be a channel id (starts with "UC", 24 characters).',
              file=sys.stderr)
        return 2
    db = None
    if not args.dry_run:
        missing = [k for k in ('SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY') if not env.get(k)]
        if missing:
            print('Missing ' + ', '.join(missing), file=sys.stderr)
            return 2
        db = Supabase(env['SUPABASE_URL'], env['SUPABASE_SERVICE_ROLE_KEY'], urlopen)
    try:
        sync_videos(db, channel_id=channel_id, urlopen=urlopen, dry_run=args.dry_run,
                    **({'sleep': sleep} if sleep else {}))
    except VideoError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
