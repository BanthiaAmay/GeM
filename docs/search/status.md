# Search feature audit — Phase 1

Audited: 2026-10-12  
Branch: `feature/smart-search`  
Files: `lib/features/search/` (10 files)

| # | Feature | Exists? | Gaps |
|---|---------|---------|------|
| 1 | **Universal search** | ✅ Yes | `SearchPage` + `SearchEngine` return bids, tools and other types. No live data source; all illustrative. Missing: HSN code and category-name search paths. |
| 2 | **Product / HSN / category** | 🟡 Partial | `lib/data/hsn_map.dart` (`kHsnToCategory`) exists but HSN codes are not indexed in `SearchIndex`. Bid category not a first-class filter facet. |
| 3 | **Smart filters** | 🟡 Partial | `BidFilter` model has state/district/value/days/MSE/EMD fields. `SearchEngine.query` accepts it. **Filter UI is missing** — no filter chips or sheet on `SearchPage`. |
| 4 | **Opportunity Score / sort** | 🟡 Partial | `SortOption` enum + `bestMatch` sort (score desc) work. `closingSoon`, `highestValue`, `newest` all fall back to score sort — no real closing-date or value data on `SampleBid` in the sort path. |
| 5 | **Jargon mapping** | ✅ Yes | `kSynonyms`, `kHinglishMap`, `kDevanagariMap` cover tender/banking/registration/product jargon. Multi-word phrase entries use single-word expansion. |
| 6 | **Hindi / Marathi / Hinglish / typos** | 🟡 Partial | Devanagari preserved through normalise; `kDevanagariMap` covers common Hindi fragments; Damerau-Levenshtein fuzzy (≤1 edit / ≤2 at len≥8). Marathi not specifically covered; Hinglish transliteration sparse. |
| 7 | **Voice input** | ❌ Missing | No mic button, no `speech_to_text` dependency. UI placeholder not yet added. |
| 8 | **Ask Copilot / BizReady fallback** | ✅ Yes | `SearchEngine.isQuestion()` detects question tokens + `?`. `_AskBizReady` widget shown when results are empty and query is a question. Routes to `/gem-check`. |
| 9 | **Saved searches + alerts** | 🟡 Partial | `SearchStore` has `saveSearch`/`removeSaved`/`isSaved`. **No save button in search UI**; no saved-searches panel in `_Suggestions`; no alert/notification wiring. |
| 10 | **Recent & suggested searches** | 🟡 Partial | `SearchStore.recent` (max 10) persisted; shown in `_Suggestions`. No trending/suggested list; no personalised suggestions. |
| 11 | **Action-first results** | 🟡 Partial | Chevron on every result row. `SearchResultRow` labels the action (`actionEn`/`actionHi`). No inline action button (e.g. "Fill form") without tapping into the detail page. |
| 12 | **Personal data search** | ❌ Missing | User profile fields (business name, GSTIN, Udyam number) not indexed. `SearchType.myData` defined but nothing adds myData items to `SearchIndex`. |

## Summary

- **3 features fully present:** Universal search (1), Jargon mapping (5), Ask Copilot fallback (8)
- **7 features partially present:** Product/HSN (2), Smart filters (3), Sort (4), Language/typos (6), Saved (9), Recent (10), Action-first (11)
- **2 features missing:** Voice (7), Personal data (12)

## Phase 1 deliverable scope (this audit)

Add `AppSearchField` to `components.dart`, fill token gaps in `tokens.dart`,  
write design notes. Feature gaps above are Phase 2+ work.
