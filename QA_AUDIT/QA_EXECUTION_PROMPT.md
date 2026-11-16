# QA Execution Session — Bid2Scale / GeM Application
## This file is the prompt for the 2026-11-17 02:00 IST scheduled execution

---

## Context

The pre-audit preparation is complete. All QA documentation has been created in /home/user/GeM/QA_AUDIT/. The application inventory (QA_MASTER_INVENTORY.md) identifies 159 features across 16 modules. The test register (QA_TEST_REGISTER.csv) contains 134 test cases.

It is now 2:00 AM IST on 17 November 2026. BEGIN FULL QA EXECUTION.

---

## Execution Instructions

Execute the following phases in sequence without stopping for approval. 

---

### PHASE 1: Static Analysis (flutter analyze)

Run `flutter analyze` from /home/user/GeM.

Document exact output in QA_EXECUTION_LOG.md.

Expected: clean or only the 3 pre-existing deprecation infos. Any new error = defect.

---

### PHASE 2: Full Test Suite Baseline

Run `flutter test --reporter expanded 2>&1 | tee /home/user/GeM/QA_AUDIT/QA_EVIDENCE/flutter_test_baseline.txt`

Count: total / passed / failed / skipped.

Compare against known baseline (461 tests, 36 pre-existing failures).

Any newly introduced failure = High/Critical defect.

---

### PHASE 3: Write and Run New Functional Tests

Write tests for the following features that currently have no test coverage:

**3A — Tender Analytics financial persistence (UI layer)**
Write widget tests for _BidFinancialCardState covering:
- _saving state shows CircularProgressIndicator
- _syncFailed state shows cloud_off icon and SnackBar retry action
- _saved + signedIn state shows check_circle with brand color
- _saved + not signed in state shows check_circle_outline with hint color
- /unit suffix appears on all cost fields (suffixText)

**3B — AppStore analytics data**
Write unit tests for:
- getAnalyticsDatum returns empty map when no data exists for sourceId
- getAnalyticsDatum merges correctly when data exists

**3C — Home tab switching**
Write widget tests verifying AnimatedSwitcher wraps the tab body in home_page.dart.

**3D — Bid feed filter**
Write unit tests for _displayBids filter logic (search term filtering).

After writing each test group, run with:
`flutter test test/<filename>.dart --reporter expanded`

---

### PHASE 4: Code Inspection — Security & Edge Cases

Inspect the following files for security and robustness issues. Document findings in QA_DEFECT_LOG.md:

**4A — lib/features/tender_analytics_page.dart**
- Are cost field values sanitized before being sent to Supabase?
- Can a negative cost value be entered? What happens?
- Is there any XSS risk in label/text display?
- Double-tap protection on Save button?

**4B — lib/features/eligibility_checker.dart**
- Bid ID input: is there any injection risk in the Supabase query?
- What happens if the network is unavailable when fetching bid?

**4C — lib/data/app_store.dart**
- saveAnalyticsDatum: does it correctly handle null user_id when not signed in?
- toggleSavedBid: race condition if tapped rapidly?
- signOut: are all sensitive state fields cleared?

**4D — lib/features/bid_feed.dart**
- What happens if bid['closes_at'] is null or malformed?
- What happens if bid['details'] is null?

---

### PHASE 5: End-to-End Workflow Verification (Code Review)

Since the app cannot be run, verify these workflows via code inspection:

**E2E-001: New user sign-up → onboarding → home**
Trace the route: /welcome → auth → /flow-name → ... → /home
Verify: each step saves to AppStore profile; completeOnboarding() is called; routing is correct.

**E2E-002: Search bid → check eligibility**
Trace: BidFeed._BidCard "Check eligibility" button → Navigator.pushNamed('/eligibility', arguments: source_id) → EligibilityChecker receives source_id → auto-fetches bid.
Verify: source_id argument is passed and received correctly.

**E2E-003: Enter costs → see in overview**
Trace: TenderAnalyticsPage._BidFinancialCardState._saveAll() → saveAnalyticsDatum() → OverviewTab reads analyticsData → computes costs/revenue.
Verify: data flows correctly from Financial tab save through to Overview tab display.

**E2E-004: Sign in → data adoption**
Trace: signInWithPassword() → _stashGuestState() → _adoptAuthenticatedSession() → restoreCloud().
Verify: local guest state is preserved and synced to cloud on sign-in.

Document any broken links, missing connections, or logic gaps as defects.

---

### PHASE 6: Performance & Reliability Inspection

**6A — Animation controller lifecycle**
Search all new StatefulWidget classes added in Oct branch for AnimationController.
Verify every controller has a matching dispose() call.

**6B — Staggered entrance index clamping**
Verify StaggeredEntrance index is clamped in bid_feed.dart and trainings_page.dart.

**6C — Pressable double-tap risk**
Verify Pressable uses Listener (not GestureDetector) so it never double-fires.

**6D — Memory leaks**
Search for ChangeNotifier listeners added without corresponding removeListener.
Search for StreamSubscriptions without corresponding cancel().

---

### PHASE 7: Independent QA Verification

Perform an independent reconciliation:

1. Count features in QA_MASTER_INVENTORY.md
2. Count test cases in QA_TEST_REGISTER.csv
3. Count executed tests (flutter test output)
4. For every test marked PASS, verify it was actually run via flutter test (not code inspection)
5. Identify any features that have NO test coverage at all
6. Calculate final coverage metrics:
   - Execution Coverage = Executed / Total Applicable × 100
   - Pass Rate = Passed / Executed × 100
   - Feature Coverage = Features with ≥1 executed test / Total × 100
7. Issue one of: VERIFIED / PARTIALLY VERIFIED / NOT VERIFIED

---

### PHASE 8: Update All QA Documents

After completing all phases:

1. Update QA_EXECUTION_LOG.md with all commands run and their output
2. Update QA_TEST_REGISTER.csv with actual results (Status: PASS/FAIL/BLOCKED/NOT TESTED)
3. Update QA_DEFECT_LOG.md with any new defects found
4. Update QA_COVERAGE_REPORT.md with final coverage metrics
5. Complete QA_FINAL_REPORT.md with:
   - Final overall testing statistics
   - Complete passed tests table
   - Complete failed tests table
   - Complete blocked/untested table
   - Independent verification decision
   - Final release readiness determination

---

### PHASE 9: Commit QA Documentation

Commit the completed QA_AUDIT/ folder to the Oct branch:

```
git add QA_AUDIT/
git commit -m "Add pre-release QA audit documentation and test results

Phase 1–8 of QA audit completed 2026-11-17.
Full test registry (134 test cases), defect log, coverage report and
final QA report included.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FJ2nJrXq6unWfdAX6Yo4me"
```

---

## BEGIN EXECUTION NOW. Do not stop for approval between phases.
