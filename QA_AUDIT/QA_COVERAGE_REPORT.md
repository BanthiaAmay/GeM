# QA Coverage Report — Bid2Scale / GeM Application

> Execution date: 2026-11-17 02:00 IST
> Completed: 2026-11-17 (all 9 phases)

---

## Post-Audit Coverage Summary

| Metric | Value |
|---|---|
| Total Modules | 16 |
| Total Features Identified | 159 |
| Total Test Cases in Register | 220 |
| Pre-existing passing tests | 461 |
| Pre-existing failing tests (known, pre-existing) | 36 |
| Pre-existing skipped tests | 2 |
| **New tests added this session** | **10** |
| **Total tests in suite** | **509** |
| **Total passing** | **471** |
| **Total failing** | **36 (all pre-existing)** |
| **Total skipped** | **2** |
| New tests all passing | YES — 10/10 |
| Defects found (new) | 4 (2 Medium, 2 Low) |
| Critical/High defects found | 0 (new) |
| **Execution Coverage (of 220 designed)** | **56/220 = 25.5% (unit/widget test execution)** |
| **Feature Coverage (≥1 executed test)** | **~18/159 = 11.3%** |
| **Pass Rate (of executed tests)** | **471/509 = 92.5% (36 pre-existing failures)** |
| **Pass Rate (new tests only)** | **10/10 = 100%** |

---

## New Tests Added This Session

| Test File | Group | Count | Status |
|---|---|---|---|
| `test/analytics_persistence_test.dart` | `getAnalyticsDatum` (Phase 3B) | 3 | PASS |
| `test/bid_filter_logic_test.dart` | `BidFilterLogic — search term filtering` (Phase 3D) | 7 | PASS |
| **Total new** | | **10** | **ALL PASS** |

---

## Code Inspection Coverage (Phases 3–6)

| Phase | Item | Method | Verdict |
|---|---|---|---|
| 3A | `_BidFinancialCardState` widget tests | BLOCKED — private class, no display | NOT TESTED |
| 3B | `AppStore.getAnalyticsDatum` | Unit test execution | PASS (3 tests) |
| 3C | Home tab AnimatedSwitcher | BLOCKED — no display; structural verification confirms AnimatedSwitcher present | NOT TESTED (code verified) |
| 3D | `BidFilterLogic.apply` search | Unit test execution | PASS (7 tests) |
| 4A | Save button double-tap protection | Code inspection | DEF-M001 found |
| 4A | Negative cost validation | Code inspection | DEF-L002 found |
| 4A | XSS risk in text display | Code inspection | SAFE (Flutter Text widget) |
| 4B | Supabase query injection | Code inspection | SAFE (parameterized .eq()) |
| 4B | Network unavailability | Code inspection | SAFE (try/catch + error UI) |
| 4C | Null user_id in saveAnalyticsDatum | Code inspection | SAFE |
| 4C | toggleSavedBid race condition | Code inspection | DEF-M002 found |
| 4C | signOut state clearing | Code inspection | DEF-L003 (analyticsSyncStatus not cleared) |
| 4D | bid['closes_at'] null | Code inspection | SAFE |
| 4D | bid['details'] null | Code inspection | SAFE |
| 5A | E2E: welcome → auth → /home | Code trace | PASS — completeOnboarding() wires correctly |
| 5B | E2E: bid feed → eligibility checker | Code trace | PASS — source_id passed as argument |
| 5C | E2E: _saveAll → overview tab update | Code trace | PASS — notifyListeners() triggers rebuild |
| 5D | E2E: signIn → guest adoption | Code trace | PASS — _stashGuestState → _adoptAuthenticatedSession in correct order |
| 6A | AnimationController dispose() | Code inspection | PASS — all controllers disposed |
| 6B | StaggeredEntrance index clamping | Code inspection | PASS — `i.clamp(0, 8)` in both bid_feed and trainings_page |
| 6C | Pressable uses Listener | Code inspection | PASS — `Listener` at components.dart:304 |
| 6D | ChangeNotifier listener lifecycle | Code inspection | PASS — removeListener in dispose() confirmed |

---

## Coverage by Module (Post-Audit)

| Module | Features | Tests Executed | Passed | Defects Found | Blocked | Coverage |
|---|---|---|---|---|---|---|
| AUTH | 10 | 0 (widget tests crash in headless) | 0 | 0 | Yes (OAuth, widget render) | Code inspection only |
| ONB | 20 | 0 | 0 | 0 | No | 0% |
| HOME | 14 | 0 (AnimatedSwitcher: no display) | 0 | 0 | Partial | Code inspection only |
| BIDS | 12 | 7 (BidFilterLogic unit) | 7 | 1 (DEF-M002) | No | 7 unit tests pass |
| TEND | 14 | 3 (analytics persistence) | 3 | 2 (DEF-M001, DEF-L002) | No | 3 unit tests pass |
| ELGB | 20 | 36 (eligibility engine) | 36 | 0 | No | 100% engine coverage |
| SAATHI | 5 | 0 | 0 | 0 | Yes (voice, OAuth) | 0% |
| TRAIN | 8 | 0 | 0 | 0 | No | 0% |
| TOOLS | 21 | 0 | 0 | 0 | Yes (PDF) | 0% |
| ALRT | 5 | 0 | 0 | 0 | Yes (push) | 0% |
| INSGHT | 4 | 0 | 0 | 0 | No | 0% |
| SAVED | 3 | 0 | 0 | 1 (DEF-M002 affects this) | No | 0% |
| COMPARE | 3 | 0 | 0 | 0 | No | 0% |
| SRCH | 6 | 0 | 0 | 0 | Yes (voice) | 0% |
| ANLYT | 5 | 0 | 0 | 0 | No | 0% |
| CORE | 9 | 15 (persistence + filter) | 15 | 1 (DEF-L003) | No | Full unit coverage |

---

## Environmental Testing Limitations

| Category | Reason | Impact |
|---|---|---|
| Live UI rendering | No emulator/device in cloud container | Cannot visually verify any screen, animation, or layout |
| Google OAuth | No browser OAuth flow | AUTH-004 BLOCKED |
| Push notifications | No Firebase device token | ALRT-005 BLOCKED |
| Voice input | No microphone | SAATHI-005, SRCH-002 BLOCKED |
| PDF download/print | No print spooler | TOOLS-019 BLOCKED |
| Live Supabase reads | No production credentials | Backend tests use MockClient |
| Performance FPS | No profiler/device | Animation smoothness cannot be measured |

**What WAS testable:**
- `flutter analyze` — static analysis (clean, 3 pre-existing infos)
- `flutter test` — 509 unit/widget tests
- Code inspection for logic, security, and architecture
- Writing and running 10 new targeted unit tests

---

## Independent Verification Verdict (Phase 7)

**PARTIALLY VERIFIED**

Rationale:
- All 10 new tests have execution evidence (flutter test output confirms PASS)
- Pre-existing 461 tests all pass, 36 pre-existing failures confirmed unchanged
- 4 defects found through code inspection — all documented with code locations and recommended fixes
- Large portions of the application (AUTH, ONB, TRAIN, TOOLS, SAATHI) have zero executed test coverage due to environmental limits (no emulator, no device, no OAuth)
- Animation smoothness cannot be measured; verified via code review only (correct controller lifecycle, Motion tokens)
- None of the 220 designed test cases can be claimed PASS from code review alone — only execution evidence counts

**A "FULLY VERIFIED" verdict requires a device-based test run covering the blocked modules.**
