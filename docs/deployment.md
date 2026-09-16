# Deployment and live smoke test

## Supabase setup
Apply the migration once. Configure email signups and a Magic Link email template that includes the numeric token:

```html
<h2>Your GeM BizReady sign-in code</h2>
<p>{{ .Token }}</p>
<p>Enter this code in the app. If you did not request it, ignore this email.</p>
```

Use a production SMTP provider and test rate limits/deliverability. Copy `config/env.example.json` to the ignored `config/env.json` and populate only the URL and publishable/anon key. The Flutter SDK call uses `publishableKey`; the build variable retains the familiar name `SUPABASE_ANON_KEY` for either public key format.

No anonymous auth provider or service-role client key is required. RLS must stay enabled. Public data consists only of explicitly published benchmark rows. Review database grants in the migration before changing schemas.

## Web
Build with `flutter build web --release --dart-define-from-file=config/env.json`. Deploy the contents of `build/web` to your chosen static HTTPS host. Keep `index.html`, `flutter_bootstrap.js` and version metadata revalidated; fingerprinted assets can be cached. Hash navigation supports direct links without server rewrites. A non-root path needs `--base-href /YOUR_PATH/`.

A fresh browser requires network access for the Flutter runtime. Local inputs survive reload through browser storage, but this is not a fully offline-installed PWA. Test clipboard/file/WhatsApp sharing under HTTPS; the app offers a copy fallback.

## Android
Run `flutter build apk --debug` for an evaluation build. To prepare release:
1. Choose your final owned application ID and update the Gradle namespace/application ID plus Kotlin package/path.
2. Create and securely back up a release upload key.
3. Add ignored `android/key.properties` containing `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
4. Build `flutter build appbundle --release --dart-define-from-file=config/env.json`.

Release builds must use the configured upload key; do not upload debug-signed artifacts. INTERNET permission is included. Email-code authentication does not need app links.

## Live acceptance (requires your project)
- Open locally with no config: calculators work, online actions clearly unavailable.
- Start a guest scenario, reload and confirm state and language restore.
- Use a referral URL, grant research consent and complete a tool.
- Request an email code; verify it, then inspect own profile and queued events.
- Sign in on a second device and confirm the newer saved report restores.
- Sign out, use another email and verify there is no cross-account report leakage.
- Submit a support request with consent; confirm it arrives once in the database.
- Submit a registration reference: status must be `self_reported`.
- Try changing `status` from an authenticated client: must fail.
- Use the trusted review RPC: verify status, audit and research export update.
- Turn research consent off: no new events upload. Delete project data: verify project rows disappear.
- Test airplane-mode edits and reconnect/retry. Simultaneous edits on multiple devices use snapshot semantics, not a merged collaboration model.

## Isolated SQL checks
`supabase/tests/bootstrap.sql` supplies minimal auth roles/functions only for a disposable plain PostgreSQL database. Never apply it to a real Supabase project. Run bootstrap, migration, then `supabase/tests/rls.sql` with `psql -v ON_ERROR_STOP=1`. These test real PostgreSQL RLS and grants, but do not substitute for hosted PostgREST/GoTrue smoke testing.
