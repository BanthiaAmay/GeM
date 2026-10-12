# Search feature — platform status

## Voice search (`kVoiceSearchEnabled`)

| Platform | Status | Notes |
|----------|--------|-------|
| iOS | ✅ Enabled | `NSSpeechRecognitionUsageDescription` + `NSMicrophoneUsageDescription` in `Info.plist` |
| Android | ✅ Enabled | `RECORD_AUDIO` in `AndroidManifest.xml` |
| macOS | ✅ Enabled | — |
| Web | ❌ Disabled | `kVoiceSearchEnabled = !kIsWeb`; speech\_to\_text is unreliable in browsers |
| Linux / Windows | ✅ Enabled (untested) | Build confirmed; runtime depends on platform speech engine |

`kVoiceSearchEnabled` is defined in `lib/features/search/voice_search.dart`.
Set it to `false` to hide the mic button on all platforms.

## My data scope

Indexes on-device only. Never sends data to any server. Excluded fields:
PAN numbers, Aadhaar numbers, OTPs, passwords. See
`lib/features/search/user_data_index.dart` for the field allowlist.
