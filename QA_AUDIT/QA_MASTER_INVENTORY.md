# QA Master Inventory — Bid2Scale / GeM Flutter Application
> Pre-audit preparation completed: 2026-11-16
> Actual test execution scheduled: 2026-11-17 02:00 IST
> Branch under test: Oct (HEAD: 23fc887)

---

## Application Overview

| Property | Value |
|---|---|
| App name | Bid2Scale (package: gem) |
| Platform | Flutter / Dart |
| Backend | Supabase (project: dytbiwlazqhiuwrcbrir) |
| Auth | Supabase Auth (email OTP + password + Google OAuth) |
| State management | ChangeNotifier (AppStore) |
| Navigation | Named routes via onGenerateRoute in main.dart |
| Design system | AppColors / AppText / AppSpace / AppRadius from lib/core/tokens.dart |
| Motion system | Motion tokens from lib/core/motion.dart |
| i18n | 9 languages via kTranslations in lib/core/translations.dart |
| Test count (pre-audit) | ~461 tests across 50 test files |

---

## Module Index

| Module ID | Module Name | Primary File(s) | Routes |
|---|---|---|---|
| AUTH | Authentication | lib/features/account_page.dart, lib/data/app_store.dart | /auth, /account |
| ONB | Onboarding Flow | lib/features/onboarding_flow_1–5.dart, onboarding_widgets.dart | /flow-name, /flow-phone, /flow-location, /flow-bizname, /flow-bizform, /flow-sector, /flow-products, /flow-role, /flow-authorised, /flow-privacy, /flow-records, /flow-pan, /flow-checklist, /flow-video, /flow-redirect, /flow-turnover, /flow-turnover-history, /flow-experience, /flow-experience-detail |
| HOME | Home Page | lib/features/home_page.dart | /home |
| BIDS | Bid Feed | lib/features/bid_feed.dart, bid_filter.dart | /bids |
| SRCH | Search | lib/features/search/*.dart | (search is embedded in home/tools) |
| TEND | Tender Analytics | lib/features/tender_analytics_page.dart | (opened from bid feed) |
| ELGB | Eligibility Checker | lib/features/eligibility_checker.dart, eligibility_engine.dart | /eligibility |
| SAATHI | Saathi AI Assistant | lib/features/saathi_page.dart | /saathi |
| TRAIN | Trainings | lib/features/trainings/trainings_page.dart, module_detail_page.dart, quiz_sheet.dart | /trainings, /training-module |
| TOOLS | Tools Hub | lib/features/tools_hub/tool_registry.dart, tool_card.dart, tool_page_scaffold.dart | /tool-* (17 tools) |
| BDOC | Bid Documents (Tools) | lib/features/bid_docs/*.dart | /tool-mii, /tool-escalation, /tool-bid-security, /tool-financial-standing, /tool-non-conviction, /tool-non-relation, /tool-atc-certificate, /tool-msme-turnover, /tool-msme-emd, /tool-warranty-declaration, /tool-nbc, /tool-lowest-price-declaration, /tool-oem-authorization, /tool-land-border-declaration, /tool-mrp-declaration, /tool-bank-solvency, /tool-bid-security |
| ALRT | Alerts | lib/features/alerts_page.dart | /alerts |
| INSGHT | Insights | lib/features/insights_page.dart | /insights, /insights-categories, /insights-trends, /insights-fit |
| NEWS | News | lib/features/news_page.dart | /news |
| SAVED | Saved Bids | lib/features/saved_bids_page.dart | /saved-bids |
| COMPARE | Bid Compare | lib/features/bid_compare.dart | /compare |
| OEM | OEM Hub | lib/features/oem/oem_page.dart | (drawer) |
| GEM_CHK | GeM Check | lib/features/gem_check_page.dart | /gem-check |
| GEM_GDE | GeM Guide | lib/features/gem_guide_page.dart | /gem-guide |
| LANG | Language Settings | lib/features/language_page.dart | /language |
| WELC | Welcome | lib/features/welcome_page.dart | /welcome |
| ANLYT | Analytics Charts | lib/features/analytics_charts.dart | (embedded in home Financial Hub tab) |
| PUSH | Push Notifications | lib/data/push_service.dart | (background) |
| STORE | App Store / State | lib/data/app_store.dart | (global state) |
| CORE | Core Tokens/Transitions | lib/core/*.dart | (system-wide) |

---

## Feature Inventory

### AUTH — Authentication

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| AUTH-001 | Sign in with OTP | Enter email → send OTP → verify 6-digit code | Email TextField, Send OTP button, 6 OTP boxes, Verify button | Supabase Auth sendOtp/verifyOtp | NOT TESTED |
| AUTH-002 | Sign in with password | Enter email + password → sign in | Email TextField, Password TextField, Sign in button | Supabase Auth signInWithPassword | NOT TESTED |
| AUTH-003 | Sign up with password | Enter email + create password → register | Email TextField, Password TextField, Confirm password, Register button | Supabase Auth signUpWithPassword | NOT TESTED |
| AUTH-004 | Sign in with Google | OAuth flow | Google sign-in button | Supabase Google OAuth | NOT TESTED |
| AUTH-005 | Password reset | Enter email → send reset link → verify code → new password | Email TextField, Send button, Code boxes, New password field | Supabase sendPasswordReset/verifyPasswordReset | NOT TESTED |
| AUTH-006 | Sign out | Confirm dialog → sign out | Sign out button, Confirm dialog | Supabase signOut | NOT TESTED |
| AUTH-007 | Delete account | Confirm dialog → account deletion | Delete account button, Confirm dialog | Supabase deleteAccount | NOT TESTED |
| AUTH-008 | Update password (signed in) | Enter current + new password | Old password, New password fields | Supabase updatePassword | NOT TESTED |
| AUTH-009 | Update contact preferences | Email for alerts, alert categories | Email toggle, category checkboxes | Supabase saveAlertPreferences | NOT TESTED |
| AUTH-010 | Session persistence | App restart retains auth state | App restart | Supabase session storage | NOT TESTED |

### ONB — Onboarding Flow

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| ONB-001 | Full name entry | Enter first + last name | TextFields, Next button | AppStore profile | NOT TESTED |
| ONB-002 | Phone number entry | Enter Indian phone number | Phone TextField, Next button | AppStore profile | NOT TESTED |
| ONB-003 | Location selection | Select state/city | Dropdown/search, Next button | AppStore profile | NOT TESTED |
| ONB-004 | Business name entry | Enter company name | TextField, Next button | AppStore profile | NOT TESTED |
| ONB-005 | Business form selection | Proprietorship/Partnership/etc | Radio/choice chips, Next | AppStore profile | NOT TESTED |
| ONB-006 | Sector selection | Select industry sector | Chip selector, Next | AppStore profile | NOT TESTED |
| ONB-007 | Product/HSN selection | Select products sold | Search + chip selector, Next | AppStore profile | NOT TESTED |
| ONB-008 | Role selection | Manufacturer/Reseller/Service | Radio buttons, Next | AppStore profile | NOT TESTED |
| ONB-009 | Authorised signatory | Is user authorised to sign? | Yes/No toggle, Next | AppStore profile | NOT TESTED |
| ONB-010 | Privacy & consent | Accept privacy policy | Checkbox, Next | AppStore consent | NOT TESTED |
| ONB-011 | Registrations (Udyam/GST) | Enter Udyam/GST numbers | TextFields, Next | AppStore profile | NOT TESTED |
| ONB-012 | PAN entry | Enter PAN number | TextField, Next | AppStore profile | NOT TESTED |
| ONB-013 | Checklist | Confirm documents ready | Checkboxes, Continue | AppStore checklist | NOT TESTED |
| ONB-014 | Intro video | Watch intro video | Video player, Skip button | — | NOT TESTED |
| ONB-015 | Redirect | Complete onboarding → home | Auto-redirect | AppStore completeOnboarding | NOT TESTED |
| ONB-016 | Turnover entry | Select turnover band | Band selector chips, Next | AppStore profile | NOT TESTED |
| ONB-017 | Turnover history | Enter past 3 years turnover | TextFields, Next | AppStore profile | NOT TESTED |
| ONB-018 | Experience entry | Select experience level | Choice chips, Next | AppStore profile | NOT TESTED |
| ONB-019 | Experience detail | Enter years/contract values | TextFields, Next | AppStore profile | NOT TESTED |
| ONB-020 | Progress persistence | Resume onboarding mid-flow | App restart | SharedPreferences | NOT TESTED |

### HOME — Home Page

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| HOME-001 | Home tab | Greeting section | Personalised greeting text | AppStore profile | NOT TESTED |
| HOME-002 | Home tab | Bid alerts section | Alert cards, All/Unread filter, tap to open | Supabase loadAlerts | NOT TESTED |
| HOME-003 | Home tab | Quick actions | Eligibility/Saathi/Insights/Bids tiles | Navigation | NOT TESTED |
| HOME-004 | Home tab | Learn section | Training card, bulletin | Supabase loadGemVideos | NOT TESTED |
| HOME-005 | Tab switching | Home/Tools/Calculators/Financial Hub/Profile | Bottom nav tabs | — | NOT TESTED |
| HOME-006 | Tools tab | Tools Hub | Grid of tool cards by group | kTools registry | NOT TESTED |
| HOME-007 | Calculators tab | Financial calculators | Calculator cards/links | — | NOT TESTED |
| HOME-008 | Financial Hub tab | Analytics charts | Charts, GemFact stats, OpenBidsValue | Supabase analytics | NOT TESTED |
| HOME-009 | Profile tab | Profile info display | Profile data, language chip | AppStore profile | NOT TESTED |
| HOME-010 | Side drawer | Drawer menu | 8 drawer items (News, Saved, OEM, etc) | Navigation | NOT TESTED |
| HOME-011 | Notification bell | View alerts | Bell icon, unread badge | Supabase bidNotifications | NOT TESTED |
| HOME-012 | Collapsing header | Scroll up/down header animation | Scroll gesture | — | NOT TESTED |
| HOME-013 | Language switcher | Select language from bottom sheet | Language chips | AppStore setLanguage | NOT TESTED |
| HOME-014 | Start over | Reset all onboarding data | Confirm dialog, Start over button | AppStore resetOnboarding | NOT TESTED |

### BIDS — Bid Feed

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| BIDS-001 | Bid listing | Display bid cards | Bid card list, loading state | Supabase gem_bids | NOT TESTED |
| BIDS-002 | Bid search | Filter by keyword | Search bar, text input | In-memory filter | NOT TESTED |
| BIDS-003 | Bid filter | Filter sheet | Category/status/EMD/document chips | _BidFilterSheet | NOT TESTED |
| BIDS-004 | Bid card | View bid details | Title, deadline, amount, documents | — | NOT TESTED |
| BIDS-005 | Save bid | Toggle save | Heart/bookmark icon | Supabase saved_bids | NOT TESTED |
| BIDS-006 | Open on GeM | External link | View on GeM button | url_launcher | NOT TESTED |
| BIDS-007 | Check eligibility | Navigate to eligibility checker | Check eligibility button | /eligibility route | NOT TESTED |
| BIDS-008 | Document chips | View all required documents | Chip list, _showAllDocs bottom sheet | — | NOT TESTED |
| BIDS-009 | Pull to refresh | Refresh bid list | Refresh action chip | Supabase gem_bids | NOT TESTED |
| BIDS-010 | Empty state | No bids matching filter | Empty state widget | — | NOT TESTED |
| BIDS-011 | Error state | Network error loading bids | Error state widget, retry | — | NOT TESTED |
| BIDS-012 | Staggered entrance animation | Cards animate in on first load | Visual | Motion system | NOT TESTED |

### TEND — Tender Analytics

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| TEND-001 | Overview tab | Summary metrics | Est. Execution Cost, Revenue, Net Profit | AppStore analyticsData | NOT TESTED |
| TEND-002 | Financial tab | Cost input fields | Procurement, Packaging, Delivery, etc cost inputs | AppStore saveAnalyticsDatum | NOT TESTED |
| TEND-003 | Financial tab | Selling price input | Price per unit field | — | NOT TESTED |
| TEND-004 | Financial tab | Save costs | Save button → cloud sync | Supabase tender_analytics_data | NOT TESTED |
| TEND-005 | Financial tab | Edit costs (after save) | Edit Costs toggle, expand/collapse | — | NOT TESTED |
| TEND-006 | Financial tab | Cloud sync indicator | Check/spinner/cloud-off icon | AnalyticsSyncStatus | NOT TESTED |
| TEND-007 | Financial tab | Sync failure + retry | Cloud-off icon tap, Retry SnackBar | — | NOT TESTED |
| TEND-008 | Financial tab | /unit label | Suffix on cost fields and metric cards | — | NOT TESTED |
| TEND-009 | Simulator tab | Input sliders | Quantity slider | — | NOT TESTED |
| TEND-010 | Simulator tab | Result cards | Expected Revenue, Cost, Net Profit (all /unit labeled) | — | NOT TESTED |
| TEND-011 | Tab switching animation | Fade between Overview/Financial/Simulator | Visual | Motion system | NOT TESTED |
| TEND-012 | Margin summary | Show margin after save | Bottom sheet | — | NOT TESTED |
| TEND-013 | Delete costs | Delete saved data | Delete action | Supabase tender_analytics_data | NOT TESTED |
| TEND-014 | Data persistence | Navigate away and back | Tab switch | AppStore | NOT TESTED |

### ELGB — Eligibility Checker

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| ELGB-001 | Step 0: Bid number entry | Enter bid ID, fetch bid | TextField, Check button | Supabase gem_bids | NOT TESTED |
| ELGB-002 | Step 0: Pre-fill from bid feed | Navigate with source_id argument | Auto-fill | Route arguments | NOT TESTED |
| ELGB-003 | Step 0: Bid not found error | Invalid bid ID | Error display | — | NOT TESTED |
| ELGB-004 | Step 1: Profile assumptions card | MSME/Startup status display | Update link → /account | AppStore profile | NOT TESTED |
| ELGB-005 | Step 1: Turnover selector | Band chips | Chip selection | — | NOT TESTED |
| ELGB-006 | Step 1: Experience field | Years input | TextField | — | NOT TESTED |
| ELGB-007 | Step 1: Document checklist | Have/don't have/not sure | Tri-state checkboxes | — | NOT TESTED |
| ELGB-008 | Step 1: EMD field | Can arrange EMD toggle | Toggle | — | NOT TESTED |
| ELGB-009 | Step 1: ATC acceptance | Review and accept toggle | Toggle | — | NOT TESTED |
| ELGB-010 | Step 2: Overall verdict badge | Likely eligible / Potentially ineligible / Needs verification / Insufficient info | Visual | eligibility_engine | NOT TESTED |
| ELGB-011 | Step 2: Condition-wise results | Per-condition result cards | — | eligibility_engine | NOT TESTED |
| ELGB-012 | Step 2: MSE relaxation display | Relaxation applied chip | — | eligibility_engine | NOT TESTED |
| ELGB-013 | Step 2: Preliminary disclaimer | "Not an official GeM decision" | — | — | NOT TESTED |
| ELGB-014 | Step 2: Check another bid | Reset to step 0 | Button | — | NOT TESTED |
| ELGB-015 | Eligibility engine | parseLakhCrore correctness | Unit test coverage | eligibility_engine.dart | PASS (30 tests) |
| ELGB-016 | Eligibility engine | parseYears correctness | Unit test coverage | eligibility_engine.dart | PASS (30 tests) |
| ELGB-017 | Eligibility engine | EMD never auto-granted | Unit test | eligibility_engine.dart | PASS |
| ELGB-018 | Eligibility engine | ATC always needsVerification | Unit test | eligibility_engine.dart | PASS |
| ELGB-019 | Eligibility engine | Relaxation rules | Unit test | eligibility_engine.dart | PASS |
| ELGB-020 | Eligibility engine | overallVerdict logic | Unit test | eligibility_engine.dart | PASS |

### SAATHI — Saathi AI Assistant

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| SAATHI-001 | Chat interface | Send message | Message composer, Send button | Supabase Edge Function / AI | NOT TESTED |
| SAATHI-002 | Pre-filled question | Navigate from home with question | Auto-send on open | Route arguments | NOT TESTED |
| SAATHI-003 | AI response display | Response bubbles | Bubble list | Supabase askSaathi | NOT TESTED |
| SAATHI-004 | Error handling | API failure | Error message | — | NOT TESTED |
| SAATHI-005 | Voice input | Mic button for speech | Mic button, speech_to_text | speech_to_text | NOT TESTED |

### TRAIN — Trainings

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| TRAIN-001 | Module grid | Display 6 modules | Grid cards, staggered entrance | training_data.dart | NOT TESTED |
| TRAIN-002 | Module detail | Video list in module | List of 34 videos | training_data.dart | NOT TESTED |
| TRAIN-003 | Video playback | Watch YouTube/embedded video | Video player | webview / youtube_video | NOT TESTED |
| TRAIN-004 | Mark video watched | Complete video | Mark complete action | AppStore markVideoWatched | NOT TESTED |
| TRAIN-005 | Quiz | Per-module quiz | Quiz sheet, MCQ answers | AppStore markQuizPassed | NOT TESTED |
| TRAIN-006 | Progress tracking | Completion percentage | Progress indicator | AppStore trainingState | NOT TESTED |
| TRAIN-007 | Training nudge | Nudge card on home | Nudge display | AppStore dismissTrainingNudge | NOT TESTED |
| TRAIN-008 | Persistence | Watched/quiz state persists | App restart | SharedPreferences | NOT TESTED |

### TOOLS — Tools Hub (17 tools total)

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| TOOLS-001 | Tools hub | Grid display | Tool cards by group | kTools registry | NOT TESTED |
| TOOLS-002 | Eligibility Checker | (see ELGB module) | — | — | NOT TESTED |
| TOOLS-003 | MII Certificate generator | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-004 | Escalation Matrix generator | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-005 | Bid Security certificate | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-006 | Financial Standing certificate | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-007 | Non-Conviction certificate | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-008 | Non-Relation declaration | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-009 | ATC Certificate | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-010 | MSME Turnover Exemption | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-011 | MSME EMD Exemption | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-012 | Warranty Declaration | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-013 | Non-Blacklist Certificate | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-014 | Lowest Price Declaration | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-015 | OEM Authorization | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-016 | Land Border Declaration | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-017 | MRP Declaration | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-018 | Bank Solvency Certificate | Form + PDF preview | Fields, Generate button | pdf / printing | NOT TESTED |
| TOOLS-019 | PDF download/share | Download or share generated PDF | Download/Share button | pdf, share_plus | NOT TESTED |
| TOOLS-020 | PDF preview | Preview generated document | Letter preview widget | pdf | NOT TESTED |
| TOOLS-021 | Pre-fill from profile | Form auto-fills from stored profile | Auto-fill on open | AppStore profile | NOT TESTED |

### ALRT — Alerts

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| ALRT-001 | Alerts list | Display bid alerts | Alert list, loading state | Supabase bid_alerts | NOT TESTED |
| ALRT-002 | Mark alert read | Tap alert → mark read | Alert row tap | Supabase markAlertRead | NOT TESTED |
| ALRT-003 | Alert preferences | Email on/off | Settings in account page | Supabase saveAlertPreferences | NOT TESTED |
| ALRT-004 | Bid interests | Set keywords for alerts | Keyword chips | Supabase saveBidInterests | NOT TESTED |
| ALRT-005 | Push notifications | Receive device notification | Background notification | Firebase Messaging | NOT TESTED |

### INSGHT — Insights

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| INSGHT-001 | Insights landing | Main insights page | Tab navigation | Supabase | NOT TESTED |
| INSGHT-002 | Trends | Bid volume/value trends | Charts | Supabase analytics | NOT TESTED |
| INSGHT-003 | Categories | Category breakdown | Charts/list | Supabase analytics | NOT TESTED |
| INSGHT-004 | Fit assessment | Sector fit scoring | Form + result | AppStore profile | NOT TESTED |

### SAVED — Saved Bids

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| SAVED-001 | Saved bids list | Display saved bids | Bid cards | Supabase saved_bids | NOT TESTED |
| SAVED-002 | Unsave bid | Remove from saved | Toggle icon | Supabase toggleSavedBid | NOT TESTED |
| SAVED-003 | Empty state | No saved bids | Empty state widget | — | NOT TESTED |

### COMPARE — Bid Compare

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| COMPARE-001 | Add to compare | Toggle compare on bid card | Compare icon | AppStore toggleCompare | NOT TESTED |
| COMPARE-002 | Compare table | Side-by-side comparison | Comparison table | AppStore compareBids | NOT TESTED |
| COMPARE-003 | Max 2 bids | Enforce compare limit | Error state | — | NOT TESTED |

### SRCH — Search

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| SRCH-001 | Text search | Search bar input | TextField, results list | search_engine.dart | NOT TESTED |
| SRCH-002 | Voice search | Mic input | Mic button, speech_to_text | speech_to_text | NOT TESTED |
| SRCH-003 | Search results | Ranked results display | Result cards | search_index.dart | NOT TESTED |
| SRCH-004 | Bid detail | View full bid detail | Detail page | bid_detail_page.dart | NOT TESTED |
| SRCH-005 | Sort | Sort search results | Sort sheet | sort_sheet.dart | NOT TESTED |
| SRCH-006 | Search suggestions | Autocomplete/synonyms | Suggestion chips | search_synonyms.dart | NOT TESTED |

### ANLYT — Analytics / Financial Hub

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| ANLYT-001 | Open bids value card | Total open bids value | Value display | Supabase loadOpenBidsValue | NOT TESTED |
| ANLYT-002 | Analytics charts | Various bid analytics charts | Charts | Supabase + sample_bids | NOT TESTED |
| ANLYT-003 | GemFact stats | Live Gem statistics | Count-up animation | Supabase loadGemStats | NOT TESTED |
| ANLYT-004 | Illustrative data label | "Illustrative data" badge | Visual | — | NOT TESTED |
| ANLYT-005 | ChartGrowIn animation | Charts regrow on data change | Visual | Motion system | NOT TESTED |

### CORE — System / Cross-cutting

| Feature ID | Feature | Sub-Feature | Interactive Elements | Backend | Test Status |
|---|---|---|---|---|---|
| CORE-001 | App launch | Splash → SplashGate → routing | — | Supabase init | NOT TESTED |
| CORE-002 | Routing | Named routes resolve correctly | Navigation | main.dart onGenerateRoute | NOT TESTED |
| CORE-003 | Theme | Light/dark mode | System theme | AppColors tokens | NOT TESTED |
| CORE-004 | i18n | 9 languages display correctly | Language selector | kTranslations | NOT TESTED |
| CORE-005 | Reduced motion | Motion.reduced honoured | Accessibility settings | Motion system | NOT TESTED |
| CORE-006 | Pressable feedback | Press scale on interactive widgets | Touch interaction | Pressable widget | NOT TESTED |
| CORE-007 | Page transitions | SoftRoute/FadeRoute transitions | Navigation | transitions.dart | NOT TESTED |
| CORE-008 | Analytics persistence | Save/sync/fail/retry cycle | — | Supabase + AnalyticsSyncStatus | PASS (5 tests) |
| CORE-009 | SharedPreferences persistence | Data survives app restart | — | shared_preferences | NOT TESTED |

---

## Existing Test Coverage (Pre-Audit Baseline)

| Test File | Tests | Status |
|---|---|---|
| analytics_persistence_test.dart | 5 | PASS |
| eligibility_engine_test.dart | 30 | PASS |
| account_actions_test.dart | ? | 36 pre-existing failures (confirmed before this session) |
| password_auth_store_test.dart | ? | Baseline |
| search_engine_test.dart | ? | Baseline |
| search_index_test.dart | ? | Baseline |
| store_test.dart | ? | Baseline |
| models_test.dart | ? | Baseline |
| bid_docs tests (×15) | ? | Baseline |
| training_*.dart (×3) | ? | Baseline |
| Total reported: 461 tests | | 36 pre-existing FAIL (unrelated to Oct branch work) |

---

## Total Feature Count Summary

| Module | Features Identified |
|---|---|
| AUTH | 10 |
| ONB | 20 |
| HOME | 14 |
| BIDS | 12 |
| TEND | 14 |
| ELGB | 20 |
| SAATHI | 5 |
| TRAIN | 8 |
| TOOLS | 21 |
| ALRT | 5 |
| INSGHT | 4 |
| SAVED | 3 |
| COMPARE | 3 |
| SRCH | 6 |
| ANLYT | 5 |
| CORE | 9 |
| **TOTAL** | **159 features** |
