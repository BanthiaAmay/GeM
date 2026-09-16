# GeM BizReady

Flutter application for **Android and web**: GeM education, eligibility/classification, revenue scenarios, pricing, ROI, onboarding tracker, combined reports and Supabase-backed follow-up.

## Run locally
Requires Flutter 3.44.4 / Dart 3.12 or a compatible newer SDK.

```sh
flutter pub get
flutter run -d chrome
# With an Android emulator/device connected:
flutter run -d <device-id>
```

No credentials are needed to explore the full local calculator journey. Progress is saved on the current device. Online saving and support/milestone submission are explicitly unavailable until Supabase is configured.

## Connect Supabase
1. Create a Supabase project and run [the migration](supabase/migrations/202609090001_initial.sql) in its SQL editor, or use `supabase db push` from a linked CLI project.
2. Enable email authentication and user signups. Configure **Authentication → Email Templates → Magic Link** to show the OTP using `{{ .Token }}`. The app verifies a code; it does not depend on a magic-link redirect. Configure production SMTP and suitable auth rate limits before rollout.
3. Copy `config/env.example.json` to `config/env.json`. Enter the project URL and **publishable/anon key**. Do not use a service-role key.
4. Run:

```sh
flutter run -d chrome --dart-define-from-file=config/env.json
flutter run -d <android-device-id> --dart-define-from-file=config/env.json
```

Build-time public configuration is embedded in the client by design; RLS protects data. The real configuration file is gitignored. A service-role key belongs only in trusted server/operator environments.

## Build and verify
```sh
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=config/env.json
flutter build apk --debug --dart-define-from-file=config/env.json
```

Omit the `--dart-define-from-file` option for local-only builds. Web artifacts are in `build/web`; Android evaluation APK is `build/app/outputs/flutter-apk/app-debug.apk`. Serve the web directory over HTTPS. Hash routes need no application-route rewrites. Use links such as `https://your-host/?ref=ca_pune_01#/eligibility`.

Android release signing accepts `android/key.properties` (see [deployment guide](docs/deployment.md)). The default `com.example.gem` ID should be replaced with your owned ID before store distribution. Existing iOS/desktop scaffolding is retained but not in this release's tested scope.

## What is included
- Responsive forest-green/cream UI, mobile drawer and English/Hindi toggle.
- Validated financial models with dated official policy citations.
- Editable revenue scenarios; no fabricated category data or order promises.
- Local persistence and optional email-code cloud restoration.
- Combined UTF-8 text report: download/share, copy, WhatsApp handoff.
- Explicit research consent, referral codes and idempotent queued events.
- Support requests, self-reported milestones and server-only evidence review.
- Supabase schema, RLS/column grants, operator export, research analysis script and CI.

See [prd.md](prd.md), [design.md](design.md), [deployment](docs/deployment.md) and [research operations](docs/research.md).

## Important data distinctions
The brief's survey is provisional until raw data and field dates are supplied. Revenue defaults are examples, not public procurement benchmarks. Fee calculations follow the cited August 2024 model; confirm GeM's current terms before bidding. Micro classification uses the April 2025 thresholds. MSE preference does not guarantee contracts.

Guest research events are not uploaded until the user signs in and opts in. Central conversion metrics therefore cover that observed cohort, not every anonymous visitor. Registration/first-order self-reports never count as verified until an operator checks evidence.

## Remaining configuration
Supabase credentials/migration/SMTP, verified category samples, confirmed workshop and CA operators, live cloud smoke testing, Android distribution signing and public web hosting. These depend on external accounts/data and are not faked in the app.

## Validation and previews
[Validation record](docs/validation.md) · [Desktop preview](docs/screenshots/desktop.png) · [Mobile Hindi preview](docs/screenshots/mobile-hindi.png)
