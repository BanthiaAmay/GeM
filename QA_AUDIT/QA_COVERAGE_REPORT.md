# QA Coverage Report — Bid2Scale / GeM Application

> Pre-audit state: 2026-11-16
> Execution coverage will be updated after 2026-11-17 02:00 IST audit run

---

## Pre-Audit Coverage State

| Metric | Pre-Audit Value |
|---|---|
| Total Modules | 16 |
| Total Features Identified | 159 |
| Total Test Cases Designed | 134 |
| Tests with PASS status (pre-existing + this session) | 41 (35 new + 6 pre-existing pass) |
| Tests Blocked (environmental limits) | 4 |
| Tests Not Yet Tested | 89 |
| Tests Not Applicable | 0 |
| Execution Coverage | 41/134 = 30.6% |
| Feature Coverage | Features with ≥1 executed test: ~12/159 = 7.5% |
| Pass Rate (of executed tests) | 41/41 = 100% |

> Note: "Executed" here means unit/widget tests via flutter test, not live UI testing (no emulator available).

---

## Coverage by Module (Pre-Audit)

| Module | Features | Tests Designed | Executed | Passed | Failed | Blocked | Not Tested | Coverage % |
|---|---|---|---|---|---|---|---|---|
| AUTH | 10 | 16 | 0 | 0 | 0 | 0 | 15 | 0% |
| ONB | 20 | 6 | 0 | 0 | 0 | 0 | 6 | 0% |
| HOME | 14 | 14 | 0 | 0 | 0 | 0 | 14 | 0% |
| BIDS | 12 | 12 | 0 | 0 | 0 | 0 | 12 | 0% |
| TEND | 14 | 14 | 0 | 0 | 0 | 0 | 14 | 0% |
| ELGB | 20 | 20 | 36 | 36 | 0 | 0 | 0 | 100% (engine unit tests) |
| SAATHI | 5 | 3 | 0 | 0 | 0 | 1 | 2 | 0% (1 blocked) |
| TRAIN | 8 | 8 | 0 | 0 | 0 | 0 | 8 | 0% |
| TOOLS | 21 | 6 | 0 | 0 | 0 | 1 | 5 | 0% (1 blocked) |
| ALRT | 5 | 3 | 0 | 0 | 0 | 1 | 2 | 0% (1 blocked) |
| INSGHT | 4 | 2 | 0 | 0 | 0 | 0 | 2 | 0% |
| SAVED | 3 | 3 | 0 | 0 | 0 | 0 | 3 | 0% |
| COMPARE | 3 | 2 | 0 | 0 | 0 | 0 | 2 | 0% |
| SRCH | 6 | 2 | 0 | 0 | 0 | 0 | 2 | 0% |
| ANLYT | 5 | 5 | 0 | 0 | 0 | 0 | 5 | 0% |
| CORE | 9 | 12 | 5 | 5 | 0 | 0 | 7 | 42% (persistence tests) |
| SECURITY | — | 6 | 0 | 0 | 0 | 0 | 6 | 0% |
| PERFORMANCE | — | 3 | 0 | 0 | 0 | 0 | 3 | 0% |
| E2E | — | 5 | 0 | 0 | 0 | 0 | 5 | 0% |

---

## Post-Audit Coverage (Updated After 2026-11-17 02:00 IST Execution)

*(All numbers below will be filled in after the scheduled execution runs)*

| Metric | Post-Audit Value |
|---|---|
| Tests Executed | TBD |
| Tests Passed | TBD |
| Tests Failed | TBD |
| Tests Blocked | TBD |
| Tests Not Tested | TBD |
| Execution Coverage | TBD |
| Feature Coverage | TBD |
| Pass Rate | TBD |
| Independent Verification | TBD |

---

## Environmental Testing Limitations

The following test categories are **structurally BLOCKED** in this environment regardless of execution:

| Category | Reason | Impact |
|---|---|---|
| Live UI rendering | No emulator/device in cloud container | Cannot visually verify any screen, animation, or layout |
| Google OAuth | No browser OAuth flow | AUTH-004 BLOCKED |
| Push notifications | No Firebase device token | ALRT-005 BLOCKED |
| Voice input | No microphone | SAATHI-005, SRCH-002 BLOCKED |
| PDF download/print | No print spooler | TOOLS-019 BLOCKED |
| Live Supabase reads | No production credentials | Backend tests use MockClient |
| Performance FPS | No profiler/device | Animation smoothness cannot be measured |

**What CAN be tested in this environment:**
- `flutter analyze` — static analysis
- `flutter test` — unit and widget tests
- Code inspection for logic, security, and architecture issues
- Writing new test coverage and running it
- Database schema verification via Supabase MCP tools
