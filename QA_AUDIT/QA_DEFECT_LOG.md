# QA Defect Log — Bid2Scale / GeM Application

> Updated during execution. Pre-audit known defects listed below.
> Defect IDs: DEF-{severity-initial}{sequence} e.g. DEF-C001 (Critical), DEF-H001 (High), DEF-M001 (Medium), DEF-L001 (Low)

---

## Pre-Existing Known Defects (from prior development sessions)

| Defect ID | Test ID | Module | Severity | Description | Root Cause | Status |
|---|---|---|---|---|---|---|
| DEF-H001 | AUTH-N/A | AUTH/CORE | High | 36 tests in account_actions_test.dart fail with RenderFlex overflow and "Looking up a deactivated widget's ancestor" | Pre-existing in Nov branch before Oct work; not introduced by this session | KNOWN / NOT INTRODUCED |
| DEF-L001 | CORE-N/A | CORE | Low | flutter analyze shows 3 deprecation infos (pre-existing) | Pre-existing, unrelated to current session's work | KNOWN / NOT INTRODUCED |

---

## Defects Found During Execution

*(Populated during the 2026-11-17 02:00 IST execution session)*

| Defect ID | Test ID | Module | Feature | Severity | Description | Steps to Reproduce | Expected | Actual | Root Cause | Code Location | Evidence | Recommended Fix |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| (none yet) | | | | | | | | | | | | |

---

## Defect Severity Reference

| Severity | Criteria |
|---|---|
| Critical | Data loss, security vulnerability, app crash, auth bypass |
| High | Major feature broken, key workflow blocked, incorrect financial calculation |
| Medium | Partial feature failure, incorrect display, significant UX issue |
| Low | Minor visual inconsistency, non-critical inconvenience |
