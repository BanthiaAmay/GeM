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

## Phase 9 QA — 2026-10-12

### Search examples verified (Chrome / web)
| Query | Expected | Status |
|-------|----------|--------|
| bank guarantee | Finance item + FAQ hit | ✅ |
| LED tube light | Bid results with HighlightText | ✅ |
| 9405 | HSN category result | ✅ |
| Maharashtra + < ₹5 L + ≤7 d | Filter chips narrow bid list | ✅ |
| 87 · Product fit | Score reason visible in result card | ✅ |
| money before payment | FAQ / finance result | ✅ |
| bijli ka saman | Hindi keyword match | ✅ |
| tendor (typo) | Fuzzy match → "tender" | ✅ |
| Voice search | Web: mic hidden (kVoiceSearchEnabled=false) | ✅ Done with fallback |
| Why was my bid rejected? | AskBizReady card shown | ✅ |
| Save "office chairs, Pune" | Saved search persisted | ✅ |
| furn… (partial) | Fuzzy results for furniture | ✅ |
| ISO 9001 needed → Get certified | Next-action row in result card | ✅ |
| Buyer name (My data) | SearchType.myData item returned | ✅ |

### Accessibility
| Check | Status |
|-------|--------|
| Semantics labels on all interactive rows | ✅ |
| 48 px min tap targets (BidFilterChip, TrendingChip, SeeMoreRow, sort button) | ✅ |
| 200% text scale — no clipped/overflowing text (Flexible + TextOverflow.ellipsis throughout) | ✅ |
| Centred column at ≥ 900 px wide (LayoutBuilder + ConstrainedBox maxWidth 640) | ✅ |

### i18n
All new UI strings use `store.t(en, hi)` pattern. No new untranslated literals added in Phase 9.

### Build
| Command | Result |
|---------|--------|
| `flutter analyze lib/` | ✅ No issues |
| `flutter test test/search_phase8_test.dart` | ✅ 3/3 passed |
| `flutter build web` | ✅ (super_clipboard Rust hook warning pre-existing, non-blocking) |
