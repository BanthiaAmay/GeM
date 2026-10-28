#!/usr/bin/env python3
"""Read-only Supabase preflight. Never requests an OTP or prints credentials."""
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


def main():
    config = json.loads(Path(sys.argv[1] if len(sys.argv) > 1 else 'config/env.json').read_text())
    base = config['SUPABASE_URL'].rstrip('/')
    key = config['SUPABASE_ANON_KEY']
    checks = [('/auth/v1/health', 'auth_health'), ('/auth/v1/settings', 'auth_settings'),
              ('/rest/v1/benchmarks?select=id&limit=1', 'core_schema'),
              ('/rest/v1/bid_alert_preferences?select=user_id&limit=1', 'alerts_schema')]
    failed = False
    for path, name in checks:
        try:
            request = urllib.request.Request(base + path, headers={'apikey': key})
            with urllib.request.urlopen(request, timeout=15) as response:
                payload = json.load(response)
                if name == 'auth_settings':
                    payload = {k: payload.get(k) for k in ('external', 'disable_signup', 'mailer_autoconfirm')}
                elif name.endswith('schema'):
                    payload = {'anonymous_rows': len(payload)}
                print(json.dumps({'check': name, 'status': response.status, 'result': payload}))
        except urllib.error.HTTPError as error:
            if name == 'alerts_schema' and error.code in (401, 403):
                print(json.dumps({'check': name, 'status': error.code,
                    'result': 'Private endpoint; authenticated schema check still required.'}))
                continue
            failed = True
            print(json.dumps({'check': name, 'status': error.code}))
        except (urllib.error.URLError, TimeoutError):
            failed = True
            print(json.dumps({'check': name, 'error': 'Host unreachable; check network and project status.'}))
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
