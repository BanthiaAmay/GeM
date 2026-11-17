# QA Defect Log — Bid2Scale / GeM Application

> Updated during execution. Defect IDs: DEF-{severity-initial}{sequence}
> Severities: Critical (C), High (H), Medium (M), Low (L)

---

## Pre-Existing Known Defects (before this audit session)

| Defect ID | Module | Severity | Description | Status |
|---|---|---|---|---|
| DEF-H001 | AUTH/CORE | High | 36 test failures spread across 12 test files (`account_actions_test.dart`, widget tests for AUTH, HOME, BIDS screens) — primarily RenderFlex overflow and "deactivated widget ancestor" errors that only manifest in headless container widget rendering. **Correction from pre-audit log: failures are NOT all in account_actions_test.dart — they span 12 files.** | KNOWN / PRE-EXISTING — not introduced by Nov branch work |
| DEF-L001 | CORE | Low | `flutter analyze` shows 3 deprecation infos (pre-existing, unrelated to this session's work) | KNOWN / PRE-EXISTING |

---

## Defects Found During This Audit (2026-11-17)

| Defect ID | Module | Feature | Severity | Description | Steps to Reproduce | Expected | Actual | Root Cause | Code Location | Recommended Fix |
|---|---|---|---|---|---|---|---|---|---|---|
| DEF-M001 | TEND | Financial tab Save button | Medium | Save button (`ElevatedButton.icon`) is not disabled while a save is in-flight. Rapid double-tap fires two concurrent `_saveAll()` calls to Supabase. The first sets `_saving = true` via setState, but the button's `onPressed` is not guarded by `_saving ? null : _saveAll`. | 1. Open Financial tab for any bid. 2. Enter values. 3. Tap Save twice quickly before spinner appears. | Save button disabled (null onPressed) while `_saving == true` | Two concurrent upserts are submitted. Impact is low (upserts are idempotent for same data) but adds unnecessary network traffic and may cause brief UI state inconsistency. | `onPressed: _saveAll` at line 1162 is not guarded | `lib/features/tender_analytics_page.dart:1162` | **FIXED 2026-11-17**: Changed `onPressed: _saveAll` to `onPressed: _saving ? null : _saveAll` |
| DEF-M002 | BIDS | Save/unsave bid | Medium | `toggleSavedBid` has no mutex/debounce. Rapid double-taps on the save icon fire two concurrent operations: first tap adds to `_savedBidIds` and schedules upsert; second tap immediately finds it in `_savedBidIds` (optimistic state) and schedules delete. The final DB state depends on network timing. UI recovers via `loadSavedBids()` after each call, but the user sees a flicker and may get the opposite save state. | 1. View any bid card. 2. Tap the save icon twice rapidly. | Icon shows final correct state; only one write operation. | UI flickers between saved/unsaved; two conflicting DB operations in flight. | No lock or busy-flag in `toggleSavedBid` | `lib/data/app_store.dart:149-188` | **FIXED 2026-11-17**: Added `bool _togglingBid = false` flag with guard + try/finally in `toggleSavedBid` |
| DEF-L002 | TEND | Financial tab costs | Low | No validation against negative cost values. `num.tryParse('-100')` returns -100, which is stored and used in margin calculations. A user entering a negative cost produces a misleadingly high profit margin. No lower-bound check on any numeric field. | 1. Open Financial tab. 2. Enter `-100` in any cost field. 3. Tap Save. | Error or zero clamping on negative cost input | Negative value accepted, stored, and used in profit calculation | `num.tryParse()` does not reject negatives; no business-logic guard | `lib/features/tender_analytics_page.dart:683-689` | **FIXED 2026-11-17**: Applied `.clamp(0, double.infinity)` to cost and selling_price fields |
| DEF-L003 | CORE | Sign out | Low | `analyticsSyncStatus` map is NOT cleared in `signOut()`. After signing out, the sync-status indicators from the previous user's session persist in memory. If a second user signs in on the same device, they briefly see stale sync-status badges from the previous account until they open a Financial tab and trigger a fresh load. | 1. Sign in as User A. 2. Save financial data (status: synced). 3. Sign out. 4. Sign in as User B (same device). 5. Open Financial tab for the same bid ID. | No sync-status badge (fresh state). | Stale `analyticsSyncStatus` entries from User A are visible. | `signOut()` clears `analyticsData` but not `analyticsSyncStatus` | `lib/data/app_store.dart:998-1012` | **FIXED 2026-11-17**: Added `analyticsSyncStatus.clear();` in `signOut()` alongside `analyticsData = []` |

---

## Security Inspection Results (Phase 4 — Code Review)

| Item | Finding | Verdict |
|---|---|---|
| Supabase query injection risk (eligibility_checker) | `.eq('source_id', bidId)` — parameterized via SDK. No string concatenation into SQL. | SAFE |
| Network unavailability (eligibility_checker) | Fetch wrapped in try/catch; error state surfaced to UI via `_error` field | SAFE |
| XSS risk (tender_analytics_page text display) | Flutter `Text` widget does not interpret HTML/JS. No innerHTML-equivalent. | SAFE — not applicable |
| Null `user_id` in saveAnalyticsDatum | `currentUser?.id ?? ''` — empty string used when not signed in; Supabase write is skipped for not-signed-in case. | ACCEPTABLE |
| `bid['closes_at']` null in bid_feed | `DateTime.tryParse(bid['closes_at'] as String? ?? '')` — returns null for null/empty; UI handles null case | SAFE |
| `bid['details']` null in bid_feed | `Map<String, dynamic>.from(bid['details'] as Map? ?? {})` — falls back to empty map | SAFE |

---

## Defect Severity Reference

| Severity | Criteria |
|---|---|
| Critical | Data loss, security vulnerability, app crash, auth bypass |
| High | Major feature broken, key workflow blocked, incorrect financial calculation |
| Medium | Partial feature failure, incorrect display, significant UX issue |
| Low | Minor visual inconsistency, non-critical inconvenience |
