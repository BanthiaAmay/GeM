# Search feature — test baseline

Captured: 2026-10-12  
Command: `flutter pub get && flutter analyze && flutter test`

## flutter analyze

```
No issues found!
```

## flutter test summary

```
293 passed · 1 skipped · 2 failed
```

## Pre-existing failures (unrelated to search)

### 1. `test/widget_test.dart: complete calculator journey updates report and tracker immediately`

**Error:** `Expected: exactly one matching candidate`  
`Actual: _TextWidgetFinder:<Found 0 widgets with text "Copy report": []>`

**Cause:** The "Copy report" label text expected by this test is no longer rendered  
at the time the test looks for it. This is a pre-existing timing/UI issue in the  
calculator flow, unrelated to the search feature.

### 2. `test/widget_test.dart: desktop tool navigation and validation work`

**Error:** Same stack — the desktop layout test is failing due to a widget-lookup  
mismatch in the tools hub test harness. Pre-existing before `feature/smart-search`.

## Search-related test files present

| File | Tests | Status |
|------|-------|--------|
| `test/search_engine_test.dart` | 14 | ✅ All pass |
| `test/search_index_test.dart` | 6 | ✅ All pass |
| `test/tools_hub_test.dart` | pass | ✅ All pass |

## Missing search tests (to write in a later phase)

- `test/search_page_test.dart` — widget test for `SearchPage`
- `test/bid_detail_test.dart` — widget test for `BidDetailPage`
