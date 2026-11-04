# Validation record

## 22 October 2026 — accounts and bid alerts

- `flutter analyze --no-pub`: no issues.
- Full Flutter suite: 50 tests passed; two optional capture tests skipped in the default run. The signup/guide capture was run separately with local fonts and inspected at mobile and desktop sizes. Signup/login now appears after language and before the GeM question, with email-only authentication.
- Signup checks cover the complete Welcome → language → app signup → email verification → GeM question journey, direct-route auth protection, returning signed-out login, WhatsApp format, consent off by default, 8-digit email codes, hidden Google signup, email success when alert storage is unavailable and a 320 px phone at 200% text size. Business questions retain their sequence, reuse signup contact details and no longer ask for a demo OTP. Business-question tests use an authenticated fixture; separate auth tests cover the actual gate.
- Python checks: two bid-import validation tests and four existing research tests passed.
- Isolated PostgreSQL 18: all three migrations, existing RLS/account-deletion checks, and new alert checks passed. The alert checks cover cross-user contact/inbox isolation, server-only writes, keyword/state matching, literal wildcard handling, expired/draft filtering, duplicate prevention, opt-out cancellation and data deletion.
- Configured web release and Android debug builds compiled. No production deployment, schema migration or notification delivery was performed.
- Read-only hosted preflight: Supabase auth healthy, email enabled, signup allowed, Google disabled; core and alert table endpoints returned 404. This does not verify email deliverability or a full OAuth round trip. See [the setup and delivery guide](auth-and-bid-alerts.md).
- Browser automation was unavailable in this session, so visual QA used offscreen Flutter renders rather than a real browser or physical device.

Previews: [signup on mobile](screenshots/signup-mobile.png), [signup on desktop](screenshots/signup-desktop.png), [GeM guide](screenshots/gem-guide-mobile.png).

```sh
flutter test test/account_visual_capture_test.dart --dart-define=SCREENSHOT_FONT=/PATH/TO/LOCAL_FONT.ttf
```

## 9 September 2026

- Flutter 3.44.4 / Dart 3.12.2, macOS host.
- `flutter analyze`: no issues.
- `flutter test`: 17 tests passed. Optional visual-capture test is skipped by default and was run separately with real fonts.
- `python3 -m unittest discover -s research -p 'test_*.py'`: 4 tests passed.
- Disposable PostgreSQL 18: schema migration and RLS smoke tests passed. Verified cross-user isolation, consent-gated events, forbidden client verification, server review, public benchmark filtering and project-data deletion. Test server stopped afterward.
- Web release and Android debug APK compiled locally. These builds have no Supabase credentials and run in local mode.
- Desktop, mobile English and mobile Hindi offscreen Flutter renders were inspected. The connected browser automation environment had no available browser, so this was widget-render visual QA rather than a hosted browser/device interaction test.

Previews: [desktop](screenshots/desktop.png), [mobile](screenshots/mobile.png), [mobile Hindi](screenshots/mobile-hindi.png).

## Reproduce visual captures

Use a locally installed font file (not copied into the repository):

```sh
flutter test test/visual_capture_test.dart --dart-define=SCREENSHOT_FONT=/PATH/TO/Roboto-Regular.ttf
```

The test loads bundled Noto Devanagari and Flutter Material Icons separately. Captures are generated under `docs/screenshots`.

## Still requires live verification
Email OTP delivery, hosted PostgREST behavior, cross-device restoration, support/milestone submission, Android physical-device sharing, and real browser storage/clipboard behavior require a configured Supabase project and target devices. Public deployment and store submission have not been performed. See the live checklist in `deployment.md`.
