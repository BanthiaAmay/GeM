# Smart Search: phased prompts for Claude Code
Paste one phase at a time, in order. Wait for each to finish (tests green + commit) before pasting the next.

---
## Phase 1: Audit, design notes and the search field
GeM BizReady Flutter app (`GeM BizReady/GeM/`), branch `feature/smart-search`. Follow `CLAUDE.md` and `DESIGN_SYSTEM.md` (tokens only, shared components, all 9 languages in `kTranslations`). Search code already exists in `lib/features/search/`: extend or fix it, don't rebuild or duplicate it. Only do this phase.

1. Run `flutter pub get`, `flutter analyze` and `flutter test`, and write the pre-existing failures to `docs/search/baseline.md`.
2. Audit `lib/features/search/` against the 12 features below. Write `docs/search/status.md` as a table (Feature | Exists? | Gaps). Features: 1 Universal search, 2 Product/HSN/category, 3 Smart filters, 4 Opportunity Score sort, 5 Jargon mapping, 6 Hindi/Marathi/Hinglish/typos, 7 Voice, 8 Ask Copilot fallback, 9 Saved searches + alerts, 10 Recent & suggested, 11 Action-first results, 12 Personal data search.
3. Open the concept images `docs/search/concept-home-bids-details.png` and `docs/search/concept-insights.png`. If Mobbin tools are available, search (iOS) for: "search screen with recent searches and grouped results", "search results with filter chips, sort and result count", and "sort by bottom sheet". Otherwise use these references: Shopify https://mobbin.com/screens/83a79099-6b71-454f-817e-a701eb23811e, Fresha https://mobbin.com/screens/86a0b800-40fe-4cbe-a1b6-1355f84bd38d, GitHub https://mobbin.com/screens/f8e87985-87c7-4e81-b4ee-3c288fa34421, Cash App https://mobbin.com/screens/e96aae5c-23c4-4a16-a66a-3156efd8bd19, Shop sort sheet https://mobbin.com/screens/831b2eb5-77ab-4b2b-b0b5-fd1780eed679.
4. Write `docs/search/design-notes.md`: the Mobbin patterns you'll use, plus this visual spec taken from the concept images:
   - Off-white page, white surfaces, outlined line icons.
   - Header: back chevron, centred title, one action icon on the right.
   - Search field: grey-filled, rounded, no border, leading search icon, clear (x), optional mic.
   - Segmented control: grey track, near-black selected pill with white text.
   - "24 matches" on the left, "Sort: Best match ⌄" on the right.
   - Bid row: bold title, green "92% match" pill, building icon + department, calendar + date (red when ≤ 3 days, "1 day left"), chevron, hairline dividers.
   - Buttons: primary near-black filled; secondary white outlined. Accent = forest green; urgency = red.
   - Caption "Concept preview · Illustrative data" wherever bids appear.
   Take only patterns from Mobbin; take the look only from the concept.
5. Add any missing tokens to `lib/core/tokens.dart` (near-black primary, match-green tint, urgency red + tint, field grey).
6. Make sure there's one shared `AppSearchField` in `components.dart`, styled to the spec, used by both the Tools hub and search.
Done when there are no new analyzer issues, tests are green, and the work is committed as "search: phase 1 audit + field".

---
## Phase 2: Engine core (universal + HSN/category search)
GeM BizReady Flutter app (`GeM BizReady/GeM/`), branch `feature/smart-search`. Follow `CLAUDE.md`. Extend the existing `lib/features/search/` code; don't duplicate it. No fake data: bids come from `SampleBidSource` and are labelled "Illustrative data". Only do this phase.

1. `SampleBid` + generator (deterministic): make sure it has title, department, state, district, value, closing date, MSE/Startup relaxation, EMD exemption, required certifications (e.g. ISO 9001) and needs-bank-guarantee.
2. The index covers the tool registry, GeM 101 modules, Financial Hub products, calculators, GST/docs, FAQs, `categories` and bids. Results are grouped by type.
3. `lib/data/hsn_map.dart`: include only codes you're certain of (9405 → lighting). Header: "Verify against official GST HSN list before release".
4. Tests: "bank guarantee" → the GeM 101 M3 lesson + the Financial Hub BG option + bids needing a BG; "LED tube light" and "9405" → the lighting category + bids; every tool/module is indexed with a valid route; a 1,000-item index runs under 50 ms.
Done when tests are green, there are no new analyzer issues, and the work is committed as "search: phase 2 engine".

---
## Phase 3: Search page, entry points, recent and suggested searches
GeM BizReady Flutter app (`GeM BizReady/GeM/`), branch `feature/smart-search`. Follow `CLAUDE.md`, `DESIGN_SYSTEM.md` and `docs/search/design-notes.md`, and match the concept images. Extend the existing search page; don't rebuild it. All 9 languages. Only do this phase.

1. Search page: back + "Search" header; autofocused `AppSearchField`; a scope segmented control with counts (All | Bids | Learn | Finance | Tools | My data); grouped results (3 per group + "See more"); "N matches"; matched text in bold.
2. Bid rows look exactly like the concept Bids list.
3. Empty query: "Recent searches" (last 8, x per row, Clear all, ↖ to fill the field), "Trending categories" chips, and a "Suggested for you" 2-column grid based on the user's profile/products.
4. Typing: live suggestions (200 ms debounce), e.g. "furn…" → "furniture – school desks".
5. No results: the existing empty state + "Try: tender, stationery, OD".
6. Entry points: the search field on Home and a search icon next to the bell both open `/search`.
7. Analytics: `search_performed` with length/results/scope only (never the raw query).
8. Widget tests for all of the above, including recents persisting across restarts.
Done when tests are green, there are no new analyzer issues, it visually matches the concept, and the work is committed as "search: phase 3 page".

---
## Phase 4: Smart filters, sort and Opportunity Score
GeM BizReady Flutter app (`GeM BizReady/GeM/`), branch `feature/smart-search`. Follow `CLAUDE.md` and `docs/search/design-notes.md`. Extend the existing code. Only do this phase.

1. A filter chip row on the Bids scope: State/District, Bid value (e.g. < ₹5 L), Closing in 3/7/30 days, Buyer department, Category, MSE/Startup relaxation, EMD exemption. Active chips are near-black; add "Reset filters".
2. "Sort: Best match ⌄" opens the sort bottom sheet (radio list, Reset + black Done) with Best match (Opportunity Score, falling back to `matchPct`), Closing soon, Highest value and Newest.
3. Each bid card shows the score with a reason, e.g. "87 · Product fit: Excellent".
4. Tests: Maharashtra + < ₹5 L + closing in 7 days filters correctly; reset works; each sort order is correct.
Done when tests are green, there are no new analyzer issues, and the work is committed as "search: phase 4 filters + sort".

---
## Phase 5: Bid details page and action-first results
GeM BizReady Flutter app (`GeM BizReady/GeM/`), branch `feature/smart-search`. Follow `CLAUDE.md` and `docs/search/design-notes.md`, and match the concept "Bid details" screen. Extend the existing `bid_detail_page.dart`. Only do this phase.

1. Bid details: back, bookmark, share; title, department, match pill, closing pill; Bid ID (marked illustrative), Delivery, Items; "Eligibility checklist · X of 5 ready" computed from the user's REAL profile/onboarding answers; an "Estimate working capital" row → the existing calculator/Financial Hub; a black "Open bid on GeM" button (official GeM portal); an outlined "Set reminder" button.
2. Every search result gets ONE next action: Review bid, Check eligibility, Calculate price, Open tool, Read lesson, Finance this order (→ Financial Hub), or Get certified (→ certification route if it exists, else the relevant GeM 101 lesson). A bid needing ISO 9001 shows "ISO 9001 needed → Get certified".
3. Tests: the checklist reflects the profile; the illustrative label shows; the ISO 9001 action appears.
Done when tests are green, there are no new analyzer issues, and the work is committed as "search: phase 5 bid detail + actions".

---
## Phase 6: Plain language, Hindi/Marathi/Hinglish and typo tolerance
GeM BizReady Flutter app (`GeM BizReady/GeM/`), branch `feature/smart-search`. Follow `CLAUDE.md`. Extend `search_synonyms.dart` and `search_engine.dart`. Only do this phase.

1. Jargon map: "money before payment" / "loan for order" → Invoice Financing / OD; "Udyam" → MSME registration; tender = bid; BG = bank guarantee; EMD = earnest money deposit.
2. Hinglish map: "bijli ka saman" → electrical, "kursi" → chair, "gst bharna" → GST filing.
3. Typo tolerance: Damerau-Levenshtein ≤ 1 for words of 4+ letters, ≤ 2 for 8+ letters ("tendor" → tender).
4. Match against English, Hindi and current-locale titles (Devanagari and Marathi queries work).
5. Tests for every example above; the 50 ms benchmark still passes.
Done when tests are green, there are no new analyzer issues, and the work is committed as "search: phase 6 language + typos".

---
## Phase 7: Saved searches, alerts and the Ask BizReady fallback
GeM BizReady Flutter app (`GeM BizReady/GeM/`), branch `feature/smart-search`. Follow `CLAUDE.md` and `docs/search/design-notes.md`. Extend `search_store.dart`. Only do this phase.

1. A bookmark icon on the results header for "Save this search", plus a "Saved searches" list (rename/delete), persisted with shared_preferences.
2. On app open, re-run saved searches against `BidSource`. New matches add an in-app notification (the existing notifications section + bell dot), e.g. "Notify me: office chairs, Pune". No push notifications.
3. An "Ask BizReady" card appears when the query looks like a question (why/how/what/kya/kaise/kyun or "?") or results are weak, e.g. "Why was my bid rejected?". It opens the existing Ask BizReady entry with the query pre-filled (or a support request if no working Copilot exists). Never fake AI answers.
4. Tests for saving, the alert trigger and question detection.
Done when tests are green, there are no new analyzer issues, and the work is committed as "search: phase 7 saved + ask".

---
## Phase 8: Voice search and personal data search
GeM BizReady Flutter app (`GeM BizReady/GeM/`), branch `feature/smart-search`. Follow `CLAUDE.md`. Extend the existing code. Only do this phase.

1. Voice: add `speech_to_text`; a mic in `AppSearchField` with a listening pulse (motion tokens, respects reduced motion); locale from the app language; Android `RECORD_AUDIO` + iOS usage strings. If it won't build on web/Android or adds analyzer errors, set `kVoiceSearchEnabled = false`, keep the code and note it in `docs/search/status.md`.
2. "My data" scope: index the user's own `AppStore` data (profile, checklist, orders, receivables, documents, support requests), labelled "Your data". On-device only. Never index PAN, Aadhaar or OTPs.
3. Tests: the mic is hidden when the flag is off; searching a buyer name returns the user's order under "Your data".
Done when tests are green, there are no new analyzer issues, and the work is committed as "search: phase 8 voice + my data".

---
## Phase 9: Final QA and polish
GeM BizReady Flutter app (`GeM BizReady/GeM/`), branch `feature/smart-search`. Follow `CLAUDE.md` and `DESIGN_SYSTEM.md`. Only do this phase.

1. Run the app (`flutter run -d chrome`) and check each example works. Fix any that fail:
   "bank guarantee", "LED tube light", "9405", Maharashtra + < ₹5 L + 7 days, the "87 · Product fit" line, "money before payment", "bijli ka saman", "tendor", voice, "Why was my bid rejected?", saving "office chairs, Pune", "furn…", "ISO 9001 needed → Get certified", a buyer name under "Your data".
2. Accessibility: Semantics labels, 48 px tap targets, 200% text scale with no overflow; a centred column at width ≥ 900.
3. Every new string exists in all 9 languages.
4. Compare the search and bid detail screens at 390×844 with the concept images; fix mismatches.
5. Update `DESIGN_SYSTEM.md` (AppSearchField, result card, scope control, filter chips, sort sheet, bid detail, new tokens) and `docs/search/status.md`.
6. Run `flutter analyze`, `flutter test` and `flutter build web`.
Finish with a table: Feature # | Done / Done with fallback | Notes. Commit as "search: phase 9 QA".
