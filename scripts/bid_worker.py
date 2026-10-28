#!/usr/bin/env python3
"""Server worker: collects new GeM bids, queues matches and sends app notifications.

  python3 scripts/bid_worker.py collect --dry-run   read GeM and print; writes nothing
  python3 scripts/bid_worker.py collect             save new bids and queue matches
  python3 scripts/bid_worker.py push                send queued app notifications
  python3 scripts/bid_worker.py email               send queued email digests
  python3 scripts/bid_worker.py whatsapp            send queued WhatsApp digests
  python3 scripts/bid_worker.py whatsapp-stop +91…  record a STOP reply (opt-out)
  python3 scripts/bid_worker.py run                 collect, then push, email, WhatsApp
  python3 scripts/bid_worker.py test-push USER_ID   one test notification to a user

Server secrets only, never the Flutter app: SUPABASE_URL and
SUPABASE_SERVICE_ROLE_KEY; for push also FCM_SERVICE_ACCOUNT_JSON (the file's
contents) or FCM_SERVICE_ACCOUNT_FILE (its path); for email RESEND_API_KEY
and EMAIL_FROM (e.g. "Bid2Scale <alerts@yourdomain.in>"); for WhatsApp
WHATSAPP_TOKEN, WHATSAPP_PHONE_NUMBER_ID and WHATSAPP_TEMPLATE (an approved
template with body variables {{1}} bid count, {{2}} top bid, {{3}} its
deadline). Values may also sit in a git-ignored .env file. Dependencies:
scripts/requirements-worker.txt.
"""
import argparse
from datetime import datetime, timedelta, timezone
import html
import json
import os
from pathlib import Path
import sys
import urllib.request
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlparse

from gem_source import IST, GemClient, GemError, enrich, gem_time, listing_record, read_pdf

# New bids normally run for a week or more, while reverse auctions close within
# about four days of starting; listing only bids closing at least this far out
# keeps the newest-first listing free of auctions.
MIN_OPEN_DAYS = 6
QUIET_START, QUIET_END = 22, 7  # IST hours: notifications wait until morning.
NEW_COLUMNS = ('source_id', 'title', 'category', 'buyer', 'ministry', 'organisation', 'state',
               'quantity', 'starts_at', 'closes_at', 'source_url', 'published', 'details',
               'fetched_at')
REFRESH_COLUMNS = ('source_id', 'title', 'starts_at', 'closes_at', 'source_url', 'published',
                   'fetched_at')

PUSH_TEXT = {
    'en': ('New GeM bid for you', '{n} new GeM bids for you', 'Closes {date}', '+{n} more',
           'Bid alerts are on',
           "You'll get a notification like this when a GeM bid matches your business."),
    'hi': ('आपके लिए नई GeM बोली', 'आपके लिए {n} नई GeM बोलियाँ', 'अंतिम समय {date}', '+{n} और',
           'बोली अलर्ट चालू हैं',
           'आपके व्यवसाय से मेल खाती GeM बोली आने पर आपको ऐसी सूचना मिलेगी।'),
    'mr': ('तुमच्यासाठी नवीन GeM बोली', 'तुमच्यासाठी {n} नवीन GeM बोली', 'अंतिम वेळ {date}',
           '+आणखी {n}', 'बोली अलर्ट सुरू आहेत',
           'तुमच्या व्यवसायाशी जुळणारी GeM बोली आल्यावर तुम्हाला अशी सूचना मिळेल.'),
    'bn': ('আপনার জন্য নতুন GeM বিড', 'আপনার জন্য {n}টি নতুন GeM বিড', 'শেষ সময় {date}',
           '+আরও {n}টি', 'বিড অ্যালার্ট চালু আছে',
           'আপনার ব্যবসার সঙ্গে মেলে এমন GeM বিড এলে এইরকম বিজ্ঞপ্তি পাবেন।'),
    'gu': ('તમારા માટે નવી GeM બિડ', 'તમારા માટે {n} નવી GeM બિડ', 'છેલ્લો સમય {date}',
           '+{n} વધુ', 'બિડ એલર્ટ ચાલુ છે',
           'તમારા વ્યવસાયને મળતી GeM બિડ આવશે ત્યારે તમને આવી સૂચના મળશે.'),
    'pa': ('ਤੁਹਾਡੇ ਲਈ ਨਵੀਂ GeM ਬੋਲੀ', 'ਤੁਹਾਡੇ ਲਈ {n} ਨਵੀਆਂ GeM ਬੋਲੀਆਂ', 'ਆਖਰੀ ਸਮਾਂ {date}',
           '+{n} ਹੋਰ', 'ਬੋਲੀ ਅਲਰਟ ਚਾਲੂ ਹਨ',
           "ਤੁਹਾਡੇ ਕਾਰੋਬਾਰ ਨਾਲ ਮੇਲ ਖਾਂਦੀ GeM ਬੋਲੀ ਆਉਣ 'ਤੇ ਤੁਹਾਨੂੰ ਅਜਿਹੀ ਸੂਚਨਾ ਮਿਲੇਗੀ।"),
    'ta': ('உங்களுக்கான புதிய GeM ஏலம்', 'உங்களுக்கான {n} புதிய GeM ஏலங்கள்',
           'கடைசி நேரம் {date}', '+மேலும் {n}', 'ஏல அறிவிப்புகள் இயக்கத்தில் உள்ளன',
           'உங்கள் தொழிலுக்குப் பொருந்தும் GeM ஏலம் வந்தால் இதுபோன்ற அறிவிப்பு கிடைக்கும்.'),
    'te': ('మీ కోసం కొత్త GeM బిడ్', 'మీ కోసం {n} కొత్త GeM బిడ్‌లు', 'చివరి సమయం {date}',
           '+మరో {n}', 'బిడ్ అలర్ట్‌లు ఆన్‌లో ఉన్నాయి',
           'మీ వ్యాపారానికి సరిపోయే GeM బిడ్ వచ్చినప్పుడు మీకు ఇలాంటి నోటిఫికేషన్ వస్తుంది.'),
    'kn': ('ನಿಮಗಾಗಿ ಹೊಸ GeM ಬಿಡ್', 'ನಿಮಗಾಗಿ {n} ಹೊಸ GeM ಬಿಡ್‌ಗಳು', 'ಕೊನೆಯ ಸಮಯ {date}',
           '+ಇನ್ನೂ {n}', 'ಬಿಡ್ ಅಲರ್ಟ್‌ಗಳು ಆನ್ ಆಗಿವೆ',
           'ನಿಮ್ಮ ವ್ಯವಹಾರಕ್ಕೆ ಹೊಂದುವ GeM ಬಿಡ್ ಬಂದಾಗ ನಿಮಗೆ ಇಂತಹ ಅಧಿಸೂಚನೆ ಬರುತ್ತದೆ.'),
}


# Email digest wording per app language: intro, button, footer. Subjects
# reuse the PUSH_TEXT titles and deadlines its "Closes" text.
EMAIL_TEXT = {
    'en': ('These new GeM bids match what your business supplies.', 'View on GeM',
           'You get this because email alerts are on in Bid2Scale. Turn them off in the app '
           'under Updates. Always check eligibility on GeM before bidding.'),
    'hi': ('ये नई GeM बोलियाँ आपके व्यवसाय की आपूर्ति से मेल खाती हैं।', 'GeM पर देखें',
           'यह ईमेल इसलिए मिला क्योंकि Bid2Scale में ईमेल अलर्ट चालू हैं। इन्हें ऐप में सूचनाओं '
           'में बंद करें। बोली से पहले पात्रता GeM पर जाँचें।'),
    'mr': ('या नवीन GeM बोली तुमच्या व्यवसायाच्या पुरवठ्याशी जुळतात.', 'GeM वर पहा',
           'Bid2Scale मध्ये ईमेल अलर्ट सुरू असल्याने हा ईमेल मिळाला. ॲपमध्ये सूचना विभागात ते बंद करा. '
           'बोलीपूर्वी पात्रता GeM वर तपासा.'),
    'bn': ('এই নতুন GeM বিডগুলি আপনার ব্যবসার সরবরাহের সঙ্গে মেলে।', 'GeM-এ দেখুন',
           'Bid2Scale-এ ইমেল অ্যালার্ট চালু থাকায় এটি পেয়েছেন। অ্যাপে বিজ্ঞপ্তি বিভাগে বন্ধ করুন। '
           'বিড করার আগে GeM-এ যোগ্যতা যাচাই করুন।'),
    'gu': ('આ નવી GeM બિડ તમારા વ્યવસાયના પુરવઠા સાથે મેળ ખાય છે.', 'GeM પર જુઓ',
           'Bid2Scale માં ઈમેલ એલર્ટ ચાલુ હોવાથી આ મળ્યું છે. એપમાં સૂચનાઓમાં બંધ કરો. '
           'બિડ પહેલાં પાત્રતા GeM પર તપાસો.'),
    'pa': ('ਇਹ ਨਵੀਆਂ GeM ਬੋਲੀਆਂ ਤੁਹਾਡੇ ਕਾਰੋਬਾਰ ਦੀ ਸਪਲਾਈ ਨਾਲ ਮੇਲ ਖਾਂਦੀਆਂ ਹਨ।', 'GeM ਤੇ ਵੇਖੋ',
           'Bid2Scale ਵਿੱਚ ਈਮੇਲ ਅਲਰਟ ਚਾਲੂ ਹੋਣ ਕਰਕੇ ਇਹ ਮਿਲੀ ਹੈ। ਐਪ ਵਿੱਚ ਸੂਚਨਾਵਾਂ ਵਿੱਚ ਬੰਦ ਕਰੋ। '
           'ਬੋਲੀ ਤੋਂ ਪਹਿਲਾਂ ਯੋਗਤਾ GeM ਤੇ ਜਾਂਚੋ।'),
    'ta': ('இந்தப் புதிய GeM ஏலங்கள் உங்கள் தொழில் வழங்குவதுடன் பொருந்துகின்றன.', 'GeM-இல் பார்க்கவும்',
           'Bid2Scale-இல் மின்னஞ்சல் அறிவிப்புகள் இயக்கத்தில் இருப்பதால் இது வந்தது. ஆப்பில் அறிவிப்புகளில் '
           'அணைக்கலாம். ஏலத்துக்கு முன் தகுதியை GeM-இல் சரிபார்க்கவும்.'),
    'te': ('ఈ కొత్త GeM బిడ్‌లు మీ వ్యాపారం సరఫరా చేసే వాటికి సరిపోతాయి.', 'GeMలో చూడండి',
           'Bid2Scaleలో ఈమెయిల్ అలర్ట్‌లు ఆన్‌లో ఉన్నందున ఇది వచ్చింది. యాప్‌లో నోటిఫికేషన్‌లలో ఆఫ్ చేయండి. '
           'బిడ్‌కు ముందు అర్హతను GeMలో తనిఖీ చేయండి.'),
    'kn': ('ಈ ಹೊಸ GeM ಬಿಡ್‌ಗಳು ನಿಮ್ಮ ವ್ಯವಹಾರದ ಪೂರೈಕೆಗೆ ಹೊಂದುತ್ತವೆ.', 'GeM ನಲ್ಲಿ ನೋಡಿ',
           'Bid2Scale ನಲ್ಲಿ ಇಮೇಲ್ ಅಲರ್ಟ್ ಆನ್ ಇರುವುದರಿಂದ ಇದು ಬಂದಿದೆ. ಆ್ಯಪ್‌ನ ಅಧಿಸೂಚನೆಗಳಲ್ಲಿ ಆಫ್ ಮಾಡಿ. '
           'ಬಿಡ್ ಮಾಡುವ ಮೊದಲು ಅರ್ಹತೆಯನ್ನು GeM ನಲ್ಲಿ ಪರಿಶೀಲಿಸಿ.'),
}


class FcmConfigError(Exception):
    """Firebase rejected the server credentials; retrying cannot help."""


_CONTROL = dict.fromkeys(c for c in range(32) if c not in (9, 10, 13))


def postgres_safe(value):
    """Drops control characters (e.g. NUL) some GeM PDFs contain; Postgres rejects them."""
    if isinstance(value, str):
        return value.translate(_CONTROL)
    if isinstance(value, dict):
        return {k: postgres_safe(v) for k, v in value.items()}
    if isinstance(value, list):
        return [postgres_safe(v) for v in value]
    return value


def in_filter(values):
    """A PostgREST `in.(...)` filter with every value quoted."""
    quoted = ','.join('"' + str(v).replace('\\', '\\\\').replace('"', '\\"') + '"' for v in values)
    return quote(f'in.({quoted})', safe='')


def chunks(items, size):
    for start in range(0, len(items), size):
        yield items[start:start + size]


class Supabase:
    def __init__(self, url, key, urlopen=urllib.request.urlopen):
        if urlparse(url).scheme != 'https':
            raise ValueError('Use an HTTPS Supabase URL')
        self.base, self.key, self.urlopen = url.rstrip('/') + '/rest/v1/', key, urlopen

    def request(self, method, path, payload=None, prefer=None):
        headers = {'apikey': self.key, 'Authorization': f'Bearer {self.key}',
                   'Content-Type': 'application/json'}
        if prefer:
            headers['Prefer'] = prefer
        data = None if payload is None else json.dumps(payload, default=str).encode()
        request = urllib.request.Request(self.base + path, data=data, headers=headers, method=method)
        try:
            with self.urlopen(request, timeout=60) as response:
                body = response.read()
        except HTTPError as error:
            raise RuntimeError(f'Supabase {method} {path.split("?")[0]} failed: HTTP {error.code} '
                               f'{error.read()[:300].decode(errors="replace")}') from error
        return json.loads(body) if body else None

    def rpc(self, name, args):
        return self.request('POST', 'rpc/' + name, args)

    def existing_source_ids(self, source_ids):
        found = set()
        for part in chunks(sorted(set(source_ids)), 50):
            rows = self.request('GET', f'gem_bids?select=source_id&source_id={in_filter(part)}')
            found.update(row['source_id'] for row in rows)
        return found

    def upsert_bids(self, rows):
        saved = []
        rows = [postgres_safe(row) for row in rows]
        for part in chunks(rows, 50):
            saved += self.request('POST', 'gem_bids?on_conflict=source_id&select=id,source_id', part,
                                  'resolution=merge-duplicates,return=representation')
        return saved

    def devices_for(self, user_ids):
        devices = {}
        for part in chunks(sorted(set(user_ids)), 100):
            for row in self.request('GET', 'push_devices?select=token,user_id,language'
                                           f'&user_id={in_filter(part)}'):
                devices.setdefault(row['user_id'], []).append((row['token'], row['language']))
        return devices

    def update_jobs(self, job_ids, values):
        for part in chunks(list(job_ids), 100):
            self.request('PATCH', f'bid_delivery_jobs?id={in_filter(part)}', values)

    def delete_device(self, token):
        self.request('DELETE', f'push_devices?token={in_filter([token])}')


def collect(gem, db, *, now, lookback, max_pages, max_documents, dry_run=False, log=print):
    """Saves bids published within `lookback` that we have not seen, then queues
    alerts for them. Older bids are never alerted: that is the launch cutoff."""
    today = now.astimezone(IST).date()
    end_from = (today + timedelta(days=MIN_OPEN_DAYS)).isoformat()
    end_to = (today + timedelta(days=365)).isoformat()
    since, settled = now - lookback, now - timedelta(minutes=30)
    fresh, known = {}, set()
    for page in range(1, max_pages + 1):
        _, docs = gem.search(page=page, end_from=end_from, end_to=end_to)
        if not docs:
            break
        records = [r for r in map(listing_record, docs) if r]
        page_known = db.existing_source_ids([r['source_id'] for r in records]) if db and records else set()
        known |= page_known
        for record in records:
            if datetime.fromisoformat(record['starts_at']) >= since:
                fresh.setdefault(record['source_id'], record)
        starts = [gem_time((d.get('final_start_date_sort') or [None])[0]) for d in docs]
        oldest = min((s for s in starts if s), default=since)
        if oldest < since or (db and records and len(page_known) == len(records) and oldest < settled):
            break
    else:
        log(f'Stopped at --max-pages {max_pages}; the next run continues from the newest bids.')

    new = [r for r in fresh.values() if r['source_id'] not in known]
    refreshed = [r for r in fresh.values() if r['source_id'] in known]
    fetched_at = now.isoformat()
    reading = min(len(new), max_documents)
    if reading:
        log(f'Found {len(new)} new bids; reading {reading} bid documents (about {reading} s)…')
    for index, record in enumerate(new):
        if index and index % 20 == 0 and index < reading:
            log(f'  …{index} of {reading} documents read')
        if index < max_documents:
            try:
                text, urls = read_pdf(gem.document(record['gem_id']))
                new[index] = record = enrich(record, text, urls)
            except (GemError, ValueError, KeyError) as error:
                log(f'{record["source_id"]}: saved without document details ({error})')
            except Exception as error:  # A malformed PDF must not stop the run.
                log(f'{record["source_id"]}: unreadable bid document ({type(error).__name__})')
        record['fetched_at'] = fetched_at
    if dry_run:
        for record in new:
            log(f'{record["source_id"]} | {record["state"] or "-"} | {record["closes_at"][:16]} | '
                f'{record["title"][:70]}')
        if new:
            log(json.dumps({k: new[0].get(k) for k in NEW_COLUMNS}, ensure_ascii=False, indent=1))
        log(f'Dry run: {len(new)} new and {len(refreshed)} known bids. Nothing was written.')
        return len(new)

    if refreshed:
        db.upsert_bids([{**{k: r[k] for k in REFRESH_COLUMNS if k != 'fetched_at'},
                         'fetched_at': fetched_at} for r in refreshed])
    saved = db.upsert_bids([{k: r.get(k, '' if k in ('category', 'organisation') else None)
                             for k in NEW_COLUMNS} for r in new]) if new else []
    matched = sum(int(db.rpc('queue_bid_matches', {'p_bid_id': row['id']}) or 0) for row in saved)
    log(f'Saved {len(saved)} new bids, refreshed {len(refreshed)}, {matched} user matches queued.')
    return len(saved)


def in_quiet_hours(now):
    hour = now.astimezone(IST).hour
    return hour >= QUIET_START or hour < QUIET_END


def _short(text, limit):
    text = ' '.join(str(text or '').split())
    return text if len(text) <= limit else text[:limit - 1].rstrip() + '…'


def build_message(jobs, language):
    """One notification covering every bid in `jobs`, in the device's language."""
    one, many, closes, more, *_ = PUSH_TEXT.get(language, PUSH_TEXT['en'])
    jobs = sorted(jobs, key=lambda j: j['closes_at'])
    if len(jobs) == 1:
        job = jobs[0]
        deadline = datetime.fromisoformat(job['closes_at']).astimezone(IST).strftime('%d/%m %H:%M')
        where = job.get('state') or _short(job.get('buyer'), 40)
        body = ' · '.join(part for part in (_short(job['title'], 90), where,
                                            closes.format(date=deadline)) if part)
        return {'title': one, 'body': body, 'data': {'route': '/alerts', 'bid': job['source_id']}}
    shown = '; '.join(_short(job['title'], 50) for job in jobs[:2])
    rest = len(jobs) - 2
    return {'title': many.format(n=len(jobs)),
            'body': shown + (f' {more.format(n=rest)}' if rest > 0 else ''),
            'data': {'route': '/alerts'}}


def retry_at(now, attempts):
    return now + min(timedelta(minutes=5) * 2 ** max(attempts - 1, 0), timedelta(hours=2))


def push(db, make_sender, *, now, min_gap_minutes=60, respect_quiet_hours=True, log=print):
    """Sends one grouped notification per user for their claimed jobs."""
    if respect_quiet_hours and in_quiet_hours(now):
        log('Quiet hours (22:00–07:00 IST): notifications wait until morning.')
        return 0
    sender = make_sender()
    if sender is None:
        log('Push skipped: FCM_SERVICE_ACCOUNT_JSON or FCM_SERVICE_ACCOUNT_FILE is not set.')
        return 0
    jobs = db.rpc('claim_push_jobs', {'p_limit': 500, 'p_min_gap': f'{min_gap_minutes} minutes'}) or []
    by_user = {}
    for job in jobs:
        by_user.setdefault(job['user_id'], []).append(job)
    devices = db.devices_for(list(by_user)) if by_user else {}
    delivered = 0
    for user_id, user_jobs in by_user.items():
        ids = [job['job_id'] for job in user_jobs]
        sent, retry, errors = None, False, []
        for token, language in devices.get(user_id, []):
            status, detail = sender.send(token, build_message(user_jobs, language))
            if status == 'sent':
                sent = sent or detail
            elif status == 'invalid':
                db.delete_device(token)
            else:
                retry = retry or status == 'retry'
            if status != 'sent':
                errors.append(detail)
        if sent:
            db.update_jobs(ids, {'status': 'sent', 'sent_at': now.isoformat(),
                                 'provider_message_id': _short(sent, 200), 'last_error': None})
            delivered += 1
        elif retry:
            attempts = max(job['attempts'] for job in user_jobs)
            db.update_jobs(ids, {'status': 'failed' if attempts >= 5 else 'pending',
                                 'available_at': retry_at(now, attempts).isoformat(),
                                 'last_error': _short('; '.join(errors), 500)})
        else:
            db.update_jobs(ids, {'status': 'cancelled',
                                 'last_error': _short('; '.join(errors) or 'No registered device', 500)})
    log(f'Push: {len(jobs)} bid alerts for {len(by_user)} users, {delivered} users notified.')
    return delivered


def build_email(jobs, language):
    """One digest email (subject, html, text) listing every bid in `jobs`."""
    one, many, closes, *_ = PUSH_TEXT.get(language, PUSH_TEXT['en'])
    intro, view, footer = EMAIL_TEXT.get(language, EMAIL_TEXT['en'])
    jobs = sorted(jobs, key=lambda j: j['closes_at'])
    subject = one if len(jobs) == 1 else many.format(n=len(jobs))
    rows, lines = [], [intro, '']
    for job in jobs[:30]:
        deadline = datetime.fromisoformat(job['closes_at']).astimezone(IST).strftime('%d/%m/%Y %H:%M IST')
        where = ' · '.join(p for p in (job.get('buyer'), job.get('state')) if p)
        details = job.get('details') or {}
        needs = ', '.join(details.get('documents_required') or [])[:200]
        rows.append(
            '<tr><td style="padding:16px 0;border-bottom:1px solid #E1E5E2">'
            f'<div style="font:12px sans-serif;color:#5F6873">{html.escape(job["source_id"])}</div>'
            f'<div style="font:bold 16px sans-serif;color:#151515;margin:4px 0">{html.escape(_short(job["title"], 160))}</div>'
            f'<div style="font:14px sans-serif;color:#5F6873">{html.escape(where)}</div>'
            f'<div style="font:bold 14px sans-serif;color:#151515;margin-top:4px">{html.escape(closes.format(date=deadline))}</div>'
            + (f'<div style="font:13px sans-serif;color:#5F6873;margin-top:4px">{html.escape(needs)}</div>' if needs else '')
            + f'<a href="{html.escape(job["source_url"])}" style="display:inline-block;margin-top:8px;'
            f'font:bold 14px sans-serif;color:#22654C">{html.escape(view)} →</a></td></tr>')
        lines += [job['source_id'], _short(job['title'], 160), where, closes.format(date=deadline),
                  job['source_url'], '']
    body = ('<div style="max-width:560px;margin:0 auto;padding:24px">'
            f'<h2 style="font:bold 22px sans-serif;color:#151515">{html.escape(subject)}</h2>'
            f'<p style="font:15px sans-serif;color:#5F6873">{html.escape(intro)}</p>'
            f'<table width="100%" cellspacing="0" cellpadding="0">{"".join(rows)}</table>'
            f'<p style="font:12px sans-serif;color:#8A9199;margin-top:24px">{html.escape(footer)}</p></div>')
    return {'subject': subject, 'html': body, 'text': '\n'.join(lines + [footer])}


def send_emails(db, make_sender, *, now, min_gap_hours=12, respect_quiet_hours=True, log=print):
    """Sends one digest per user covering all their claimed email jobs."""
    if respect_quiet_hours and in_quiet_hours(now):
        log('Quiet hours (22:00–07:00 IST): emails wait until morning.')
        return 0
    sender = make_sender()
    if sender is None:
        log('Email skipped: RESEND_API_KEY or EMAIL_FROM is not set.')
        return 0
    jobs = db.rpc('claim_email_jobs', {'p_limit': 1000, 'p_min_gap': f'{min_gap_hours} hours'}) or []
    by_user = {}
    for job in jobs:
        by_user.setdefault(job['user_id'], []).append(job)
    delivered = 0
    for user_jobs in by_user.values():
        ids = [job['job_id'] for job in user_jobs]
        status, detail = sender.send(user_jobs[0]['email'], build_email(user_jobs, user_jobs[0]['language']))
        if status == 'sent':
            db.update_jobs(ids, {'status': 'sent', 'sent_at': now.isoformat(),
                                 'provider_message_id': _short(detail, 200), 'last_error': None})
            delivered += 1
        elif status == 'retry':
            attempts = max(job['attempts'] for job in user_jobs)
            db.update_jobs(ids, {'status': 'failed' if attempts >= 5 else 'pending',
                                 'available_at': retry_at(now, attempts).isoformat(),
                                 'last_error': _short(detail, 500)})
        else:
            db.update_jobs(ids, {'status': 'failed', 'last_error': _short(detail, 500)})
    log(f'Email: {len(jobs)} bid alerts for {len(by_user)} users, {delivered} emails sent.')
    return delivered


# Languages a WhatsApp template is approved in; others fall back to English.
# Add a code here once Meta approves the template in that language.
WHATSAPP_TEMPLATE_LANGUAGES = {'en': 'en', 'hi': 'hi'}


def _template_text(text, limit):
    """WhatsApp template variables may not contain new lines, tabs or runs of spaces."""
    return _short(' '.join(str(text or '').split()), limit) or '-'


def build_whatsapp(jobs, language):
    """Template variables for one digest: count, the soonest-closing bid, its deadline."""
    jobs = sorted(jobs, key=lambda j: j['closes_at'])
    top = jobs[0]
    deadline = datetime.fromisoformat(top['closes_at']).astimezone(IST).strftime('%d/%m %H:%M')
    where = top.get('state') or top.get('buyer') or ''
    headline = top['title'] + (f' ({where})' if where else '')
    return {'language': WHATSAPP_TEMPLATE_LANGUAGES.get(language, 'en'),
            'params': [str(len(jobs)), _template_text(headline, 120), deadline]}


def send_whatsapp(db, make_sender, *, now, min_gap_hours=24, respect_quiet_hours=True, log=print):
    """One template message per user covering all their claimed WhatsApp jobs."""
    if respect_quiet_hours and in_quiet_hours(now):
        log('Quiet hours (22:00–07:00 IST): WhatsApp messages wait until morning.')
        return 0
    sender = make_sender()
    if sender is None:
        log('WhatsApp skipped: WHATSAPP_TOKEN, WHATSAPP_PHONE_NUMBER_ID or WHATSAPP_TEMPLATE is not set.')
        return 0
    jobs = db.rpc('claim_whatsapp_jobs', {'p_limit': 1000, 'p_min_gap': f'{min_gap_hours} hours'}) or []
    by_user = {}
    for job in jobs:
        by_user.setdefault(job['user_id'], []).append(job)
    delivered = 0
    for user_jobs in by_user.values():
        ids = [job['job_id'] for job in user_jobs]
        status, detail = sender.send(user_jobs[0]['phone'], build_whatsapp(user_jobs, user_jobs[0]['language']))
        if status == 'sent':
            db.update_jobs(ids, {'status': 'sent', 'sent_at': now.isoformat(),
                                 'provider_message_id': _short(detail, 200), 'last_error': None})
            delivered += 1
        elif status == 'retry':
            attempts = max(job['attempts'] for job in user_jobs)
            db.update_jobs(ids, {'status': 'failed' if attempts >= 5 else 'pending',
                                 'available_at': retry_at(now, attempts).isoformat(),
                                 'last_error': _short(detail, 500)})
        else:
            db.update_jobs(ids, {'status': 'failed', 'last_error': _short(detail, 500)})
    log(f'WhatsApp: {len(jobs)} bid alerts for {len(by_user)} users, {delivered} messages sent.')
    return delivered


class WhatsAppConfigError(Exception):
    """Meta rejected the token or phone number ID; retrying cannot help."""


class WhatsAppSender:
    """Template messages through Meta's WhatsApp Cloud API."""

    def __init__(self, token, phone_number_id, template, api_version='v23.0',
                 urlopen=urllib.request.urlopen):
        self.token, self.template, self.urlopen = token, template, urlopen
        self.endpoint = f'https://graph.facebook.com/{api_version}/{phone_number_id}/messages'

    def send(self, phone, message):
        body = {'messaging_product': 'whatsapp', 'to': phone.lstrip('+'), 'type': 'template',
                'template': {'name': self.template, 'language': {'code': message['language']},
                             'components': [{'type': 'body', 'parameters': [
                                 {'type': 'text', 'text': p} for p in message['params']]}]}}
        request = urllib.request.Request(self.endpoint, data=json.dumps(body).encode(), headers={
            'Authorization': f'Bearer {self.token}', 'Content-Type': 'application/json'})
        try:
            with self.urlopen(request, timeout=30) as response:
                return 'sent', (json.load(response).get('messages') or [{}])[0].get('id', '')
        except HTTPError as error:
            with error:
                raw = error.read()[:400].decode(errors='replace')
            detail = f'WhatsApp {error.code}: {raw}'
            if error.code == 401 or '"code":190' in raw.replace(' ', ''):
                raise WhatsAppConfigError(detail) from error
            return ('retry' if error.code == 429 or error.code >= 500 else 'failed'), detail
        except (URLError, TimeoutError) as error:
            return 'retry', f'WhatsApp unreachable: {error}'


class EmailConfigError(Exception):
    """The email provider rejected the API key or sender; retrying cannot help."""


class ResendSender:
    """Transactional email through Resend's HTTP API (https://resend.com)."""
    ENDPOINT = 'https://api.resend.com/emails'

    def __init__(self, api_key, sender, urlopen=urllib.request.urlopen):
        self.api_key, self.sender, self.urlopen = api_key, sender, urlopen

    def send(self, to, message):
        body = {'from': self.sender, 'to': [to], 'subject': message['subject'],
                'html': message['html'], 'text': message['text']}
        request = urllib.request.Request(self.ENDPOINT, data=json.dumps(body).encode(), headers={
            'Authorization': f'Bearer {self.api_key}', 'Content-Type': 'application/json'})
        try:
            with self.urlopen(request, timeout=30) as response:
                return 'sent', json.load(response).get('id', '')
        except HTTPError as error:
            with error:
                detail = f'Email {error.code}: {error.read()[:200].decode(errors="replace")}'
            if error.code in (401, 403):
                raise EmailConfigError(detail) from error
            return ('retry' if error.code == 429 or error.code >= 500 else 'failed'), detail
        except (URLError, TimeoutError) as error:
            return 'retry', f'Email service unreachable: {error}'


def classify_fcm_error(status, body):
    try:
        error = json.loads(body).get('error') or {}
    except (ValueError, AttributeError):
        error = {}
    codes = {d.get('errorCode') for d in error.get('details') or [] if isinstance(d, dict)}
    detail = f'FCM {status} {"/".join(sorted(c for c in codes if c))}: {str(error.get("message") or "")[:200]}'
    if status == 404 or codes & {'UNREGISTERED', 'SENDER_ID_MISMATCH'}:
        return 'invalid', detail
    if status in (401, 403):
        raise FcmConfigError(detail)
    if status == 429 or status >= 500 or codes & {'QUOTA_EXCEEDED', 'UNAVAILABLE', 'INTERNAL'}:
        return 'retry', detail
    return 'failed', detail


class FcmSender:
    """Firebase Cloud Messaging HTTP v1 with a service-account token."""
    SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'

    def __init__(self, info, urlopen=urllib.request.urlopen):
        from google.auth.transport.requests import Request as AuthRequest
        from google.oauth2 import service_account
        self._credentials = service_account.Credentials.from_service_account_info(info, scopes=[self.SCOPE])
        self._auth_request = AuthRequest()
        self.endpoint = f'https://fcm.googleapis.com/v1/projects/{info["project_id"]}/messages:send'
        self.urlopen = urlopen

    def send(self, token, message):
        if not self._credentials.valid:
            self._credentials.refresh(self._auth_request)
        # The app registers Firebase Installation IDs (FIDs). FCM accepts them in
        # `token` during its migration; switch to the `fid` target once FCM
        # retires `token`.
        body = {'message': {
            'token': token,
            'notification': {'title': message['title'], 'body': message['body']},
            'data': message['data'],
            'android': {'priority': 'high'},
            'apns': {'payload': {'aps': {'sound': 'default'}}},
        }}
        request = urllib.request.Request(self.endpoint, data=json.dumps(body).encode(), headers={
            'Authorization': f'Bearer {self._credentials.token}',
            'Content-Type': 'application/json; charset=utf-8'})
        try:
            with self.urlopen(request, timeout=30) as response:
                return 'sent', json.load(response).get('name', '')
        except HTTPError as error:
            return classify_fcm_error(error.code, error.read())
        except (URLError, TimeoutError) as error:
            return 'retry', f'FCM unreachable: {error}'


def service_account_info(env):
    raw = env.get('FCM_SERVICE_ACCOUNT_JSON', '').strip()
    if not raw and env.get('FCM_SERVICE_ACCOUNT_FILE'):
        raw = Path(env['FCM_SERVICE_ACCOUNT_FILE']).read_text()
    return json.loads(raw) if raw else None


def test_push(db, sender, user_id, log=print):
    targets = db.devices_for([user_id]).get(user_id, [])
    if not targets:
        log('No registered device for that user. Sign in on the phone and allow notifications first.')
        return 1
    for token, language in targets:
        *_, title, body = PUSH_TEXT.get(language, PUSH_TEXT['en'])
        status, detail = sender.send(token, {'title': title, 'body': body, 'data': {'route': '/alerts'}})
        if status == 'invalid':
            db.delete_device(token)
        log(f'Device …{token[-6:]} ({language}): {status} {detail}')
    return 0


def load_env_file(path):
    """KEY=value lines from a local, git-ignored .env file; exported vars win."""
    values = {}
    if path.is_file():
        for line in path.read_text().splitlines():
            key, sep, value = line.strip().partition('=')
            if sep and key and not key.startswith('#'):
                values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def main(argv=None, env=os.environ):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest='command', required=True)
    for name in ('collect', 'run'):
        command = commands.add_parser(name)
        command.add_argument('--lookback-minutes', type=int, default=180,
                             help='only bids published this recently are new (default 180)')
        command.add_argument('--max-pages', type=int, default=60)
        command.add_argument('--max-documents', type=int, default=200)
        if name == 'collect':
            command.add_argument('--dry-run', action='store_true', help='read GeM only; needs no secrets')
    for name in ('push', 'run'):
        command = commands.choices.get(name) or commands.add_parser(name)
        command.add_argument('--min-gap-minutes', type=int, default=60,
                             help='at most one notification per user in this time (default 60)')
        command.add_argument('--ignore-quiet-hours', action='store_true')
    for name in ('email', 'run'):
        command = commands.choices.get(name) or commands.add_parser(name)
        command.add_argument('--email-gap-hours', type=int, default=12,
                             help='at most one digest email per user in this time (default 12)')
        if name == 'email':
            command.add_argument('--ignore-quiet-hours', action='store_true')
    for name in ('whatsapp', 'run'):
        command = commands.choices.get(name) or commands.add_parser(name)
        command.add_argument('--whatsapp-gap-hours', type=int, default=24,
                             help='at most one WhatsApp message per user in this time (default 24)')
        if name == 'whatsapp':
            command.add_argument('--ignore-quiet-hours', action='store_true')
    commands.add_parser('whatsapp-stop').add_argument('phone', help='+91… number that replied STOP')
    commands.add_parser('test-push').add_argument('user_id')
    args = parser.parse_args(argv)
    now = datetime.now(timezone.utc)

    if args.command in ('collect', 'run'):
        try:
            import pypdf  # noqa: F401  (bid documents are read with it)
        except ModuleNotFoundError:
            print('The PDF reader is not installed. Run once:\n'
                  '  python3 -m pip install -r scripts/requirements-worker.txt', file=sys.stderr)
            return 2
    if args.command == 'collect' and args.dry_run:
        collect(GemClient(), None, now=now, lookback=timedelta(minutes=args.lookback_minutes),
                max_pages=args.max_pages, max_documents=args.max_documents, dry_run=True)
        return 0
    env = {**load_env_file(Path(__file__).resolve().parent.parent / '.env'), **env}
    missing = [k for k in ('SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY') if not env.get(k)]
    if missing:
        print(f'Missing {", ".join(missing)}. Export them, or put them in a .env file '
              'in the project folder (it is git-ignored). See the top of this file.',
              file=sys.stderr)
        return 2
    db = Supabase(env['SUPABASE_URL'], env['SUPABASE_SERVICE_ROLE_KEY'])

    def make_sender():
        info = service_account_info(env)
        return FcmSender(info) if info else None

    if args.command == 'test-push':
        sender = make_sender()
        if sender is None:
            print('Set FCM_SERVICE_ACCOUNT_JSON or FCM_SERVICE_ACCOUNT_FILE first.')
            return 1
        return test_push(db, sender, args.user_id)
    failed = False
    if args.command in ('collect', 'run'):
        try:
            collect(GemClient(), db, now=now, lookback=timedelta(minutes=args.lookback_minutes),
                    max_pages=args.max_pages, max_documents=args.max_documents)
        except (GemError, URLError, TimeoutError) as error:
            print(f'Collection failed: {error}', file=sys.stderr)
            failed = True
    if args.command in ('push', 'run'):
        push(db, make_sender, now=datetime.now(timezone.utc), min_gap_minutes=args.min_gap_minutes,
             respect_quiet_hours=not args.ignore_quiet_hours)
    if args.command == 'whatsapp-stop':
        print(f'Opted out {db.rpc("whatsapp_opt_out", {"p_phone": args.phone}) or 0} account(s).')
        return 0
    if args.command in ('whatsapp', 'run'):
        def make_whatsapp():
            token, number = env.get('WHATSAPP_TOKEN', ''), env.get('WHATSAPP_PHONE_NUMBER_ID', '')
            template = env.get('WHATSAPP_TEMPLATE', '')
            if not (token and number and template):
                return None
            return WhatsAppSender(token, number, template, env.get('WHATSAPP_API_VERSION') or 'v23.0')
        send_whatsapp(db, make_whatsapp, now=datetime.now(timezone.utc),
                      min_gap_hours=args.whatsapp_gap_hours,
                      respect_quiet_hours=not args.ignore_quiet_hours)
    if args.command in ('email', 'run'):
        def make_mailer():
            key, sender = env.get('RESEND_API_KEY', ''), env.get('EMAIL_FROM', '')
            return ResendSender(key, sender) if key and sender else None
        send_emails(db, make_mailer, now=datetime.now(timezone.utc),
                    min_gap_hours=args.email_gap_hours,
                    respect_quiet_hours=not args.ignore_quiet_hours)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
