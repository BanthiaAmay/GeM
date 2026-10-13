# Deployment and live smoke test

## Supabase setup
Apply both migrations, in timestamp order:

1. `supabase/migrations/202609090001_initial.sql`
2. `supabase/migrations/202610130001_account_deletion.sql`

The second migration adds a no-argument account-deletion RPC scoped to the authenticated caller. It is required for the Play account-deletion policy.

In **Authentication → Providers → Email**, enable email sign-ins. Configure the Magic Link email template to include the numeric token:

```html
<h2>Your GeM BizReady sign-in code</h2>
<p>{{ .Token }}</p>
<p>Enter this code in the app. If you did not request it, ignore this email.</p>
```

Use a production SMTP provider and test rate limits/deliverability. Copy `config/env.example.json` to the ignored `config/env.json` and populate only the URL and publishable/anon key. The Flutter SDK call uses `publishableKey`; the build variable retains the familiar name `SUPABASE_ANON_KEY` for either public key format.

No anonymous auth provider or service-role client key is required. RLS must stay enabled. Public data consists only of explicitly published benchmark rows. Review database grants in the migration before changing schemas.

### Google sign-in

1. In Google Cloud / Google Auth Platform, configure the consent screen and audience.
2. Create an OAuth client whose application type is **Web application**. Supabase owns the OAuth callback even for the Android app; this flow does not need `google-services.json`.
3. Add your production web origin and development origins under **Authorized JavaScript origins**.
4. Add this exact Google **Authorized redirect URI**, replacing the project reference:

   `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`

5. In Supabase **Authentication → Providers → Google**, enable Google and paste that web client ID and client secret.
6. In Supabase **Authentication → URL Configuration**:
   - Set **Site URL** to the production web origin, such as `https://app.example.com`.
   - Add `https://app.example.com/**` for the production web app.
   - Add the exact Android/iOS callback `com.gembizready.app://login-callback/`.
   - During local web development, add only the localhost origins/ports you actually use, such as `http://localhost:*/**`; remove broad preview patterns when they are no longer needed.
7. Keep the Google client secret only in the Supabase dashboard. It never belongs in Flutter, `config/env.json`, or Play Console.

The app uses browser-based Supabase OAuth with PKCE. Google returns to Supabase, then Supabase returns the user to the web origin or to the mobile deep link declared in the Android manifest and iOS `Info.plist`.

## Web
Build with `flutter build web --release --dart-define-from-file=config/env.json`. Deploy the contents of `build/web` to your chosen static HTTPS host. Keep `index.html`, `flutter_bootstrap.js` and version metadata revalidated; fingerprinted assets can be cached. Hash navigation supports direct links without server rewrites. A non-root path needs `--base-href /YOUR_PATH/`.

A fresh browser requires network access for the Flutter runtime. Local inputs survive reload through browser storage, but this is not a fully offline-installed PWA. Test clipboard/file/WhatsApp sharing under HTTPS; the app offers a copy fallback.

## Android
Run `flutter build apk --debug` for an evaluation build. To prepare release:
1. Choose your final owned application ID and update the Gradle namespace/application ID plus Kotlin package/path.
2. Create and securely back up a release upload key.
3. Add ignored `android/key.properties` containing `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
4. Build `flutter build appbundle --release --dart-define-from-file=config/env.json`.

This repository uses the permanent application ID `com.gembizready.app`. The local release upload key is `android/upload-keystore.jks` and its ignored configuration is `android/key.properties`. Back up both files in a password manager or other secure storage before uploading the first bundle. Neither file is committed. If this checkout is moved to another machine, restore those two files before building.

Build and verify the signed bundle:

```sh
flutter build appbundle --release --dart-define-from-file=config/env.json
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

Upload `build/app/outputs/bundle/release/app-release.aab`, enable Play App Signing and retain the upload key. Do not upload debug-signed artifacts. The INTERNET permission and the OAuth callback filter are included.

Before production submission, increment the `version:` build number in `pubspec.yaml` for every Play upload.

## Play Console checklist

1. Create the Play app as **GeM BizReady**, choose the appropriate app category and use `com.gembizready.app` as the package identity by uploading the signed AAB.
2. Complete developer identity verification and Play App Signing. New personal accounts may have device verification and closed-testing requirements.
3. Publish the web build over HTTPS. Use `/privacy.html` as the privacy-policy URL and `/delete-account.html` as the account-deletion URL.
4. Complete **Data safety** from actual production behavior. The current app can process an email address, Google identity metadata, business-planning answers, optional research events/referral attribution, and user-requested support data. Supabase is the app backend; Google is used only when the user selects Google sign-in.
5. Declare that accounts can be deleted in-app under **Save progress → Privacy controls → Delete account permanently**, and through the hosted deletion page.
6. Complete App access, Ads, Content rating, Target audience, News-app and Government-app declarations accurately. This independent project must not be represented as an official GeM/government app.
7. Add phone screenshots, a feature graphic, short/full descriptions and a working developer contact email. Test the internal-track build on a physical Android device before closed or production release.

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
