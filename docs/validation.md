# Validation record — 9 September 2026

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
