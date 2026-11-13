# Bid2Scale — Design System

The rules every screen follows. Code lives in `lib/core/tokens.dart` (values),
`lib/core/theme.dart` (Material theme built from them), `lib/features/components.dart`
(shared widgets) and `lib/features/charts.dart` (charts). Motion rules are in
`lib/core/motion.dart`. Architecture and data live in [design.md](design.md).

**Rule zero:** feature files never contain a raw `Color(0x…)`, `Colors.*`, `fontSize:`,
pixel radius, or a styled `FilledButton`/`OutlinedButton`. Use a token or a component.
If none fits, add one to the system first.

## Character
Apple-inspired monochrome — charcoal ink on white, with a muted system red for "urgent",
amber for "caution", blue for "info" and a quiet green reserved for a true "safe / passed"
signal. The interface itself carries no hue; status colours appear only where they mean
something. Bordered white cards, tinted (grey) status chips, pill buttons, thin line icons.
Depth comes from two soft shadows only (`AppShadow.card` on outlined cards resting on the
`canvas` page colour, `AppShadow.floating` on floating chrome); no gradients or decoration.
Blur only in floating chrome: `GlassBar` (headers) and `GlassCapsule` (the phone tab bar,
which floats above the home indicator with content scrolling blurred behind it).
Home's header is one 48pt row under the status bar that tucks away while scrolling down
and returns on any scroll up; Home shows no scroll-more fade, since the capsule already
signals more content. Artwork and icons get animated depth: `Depth` (logos, illustrations,
icon PNGs — a silhouette shadow, a rise-in out of a 3D tilt, a tilt toward the finger while
pressed; pass plain artwork only, as it is painted twice) and `DepthIcon` (Material icons —
glyph shadow, rise-in, a 3D pop when `lifted`, e.g. the selected tab). Both use `Motion`
tokens and keep only the shadow under reduced motion.

## Colour (`AppColors`)
Apple-aligned monochrome palette. Historical token names (`brand`, `brandTint`, `brandDeep`,
`violet`, `violetTint`) are preserved so feature code keeps working, but their values now
collapse to the greyscale ramp — no module has its own hue.

| Token | Hex | Use | Contrast |
|---|---|---|---|
| `ink` | `#1D1D1F` | text, headings, primary button | 17.6:1 on white |
| `inkPressed` | `#424245` | primary button pressed | |
| `textSecondary` | `#6E6E73` | subtitles, helper text, captions | 5.3:1 |
| `textHint` | `#86868B` | placeholders, disabled only | 3.6:1 (never for required reading) |
| `surface` / `surfaceMuted` | `#FFFFFF` / `#F5F5F7` | page, card / selected row, inset panel | |
| `canvas` | `#F2F2F7` | page background behind cards | |
| `border` / `borderStrong` | `#D2D2D7` / `#A1A1A6` | card hairline / control border | |
| `brand` + `brandTint` | `#1D1D1F` / `#F5F5F7` | primary accent, featured card — monochrome | |
| `brandDeep` | `#000000` | hero card surface, inverted text | |
| `violet` + `violetTint` | `#1D1D1F` / `#EFEFF2` | second accent slot (Find Bids) — monochrome | |
| `success` + `successTint` | `#248A3D` / `#E5F2E8` | true "ready / passed" signal only | |
| `danger` + `dangerTint` | `#BF1E2E` / `#FDECEC` | urgent, error, destructive | 5.9:1 |
| `warning` + `warningTint` | `#8A5300` / `#FFF4E0` | needs attention | 5.7:1 on tint |
| `info` + `infoTint` | `#0066CC` / `#E6F0FA` | neutral information | |
| `disabled` | `#E5E5EA` | disabled fill | |

Colour is never the only signal: status always carries text or an icon. All body-size
text meets WCAG AA (4.5:1). The status colours (success / danger / warning / info) are
the ONLY non-grey values in the system and never appear on chrome — only on true status
signals.

### Phase 2 refinements (screen-level)
- **Overline eyebrows** (`SectionHeader`, onboarding step labels, GEM WEEKLY): plain
  `AppText.overline` (uses `textSecondary`) — NOT `brand`-colored. With brand = charcoal ≈ ink,
  a brand-tinted overline was too heavy; neutral grey restores the intended subdued hierarchy.
- **Quick action tiles** (Home): all four tiles are uniform monochrome —
  `surfaceMuted` background, `ink` icon. No per-tile colour. This is the Apple approach:
  non-status chrome carries no hue.
- **Notification dot** (Home bell icon): `danger` red, not `brand`. The dot signals unread
  attention; a charcoal dot on a charcoal icon was invisible.
- **Legacy aliases** (`green`, `lime`, `ink` in `theme.dart`): resolve correctly through the
  alias chain but should NOT be used in new code. Feature files use `AppColors.*` directly.
  `pages.dart` has been fully migrated.

## Typography (`AppText`) — SF Pro on iOS, system font elsewhere, bundled Noto Sans fallback per script
Apple's Display / Text pairing, with negative tracking on larger sizes for the characteristic
tight-but-airy feel.

`display` 44/700 (welcome) · `h1` 32/700 (screen headline) · `h2` 24/700 (page/card group)
· `h3` 20/600 (section, option label) · `title` 17/600 (card/list title) · `body` 16
· `bodySmall` 14 · `caption` 13 secondary (helper, metadata) · `label` 12/600 (chips, tab
labels) · `overline` 11/600 uppercase (eyebrow) · `lead` 19 secondary · `input` 17
(typed text) · `button` 16/600 · `buttonLg` 18/600. Use `AppText.secondary(style)` for the
muted variant. Documented exceptions: the language-screen hero greeting (`display` resized),
and the handwriting on the name card (art overlay).

Every script in `supportedLanguages` (core/models.dart) has a matching bundled font in
`theme.dart`'s `fontFamilyFallback` (Devanagari, Bengali, Gujarati, Gurmukhi, Tamil, Telugu,
Kannada — `assets/fonts/`), so text renders correctly even on a device whose OS doesn't ship
that script. **Adding a language means adding its script's font here too**, not just its
translations.

## Spacing, radius, size
`AppSpace`: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 (`gutter` = 24 side margin on phone
screens). `AppRadius`: `sm` 8 (chips) · `md` 12 (inputs, option rows) · `lg` 16 (cards) ·
`xl` 20 (hero cards, sheets) · `pill` (buttons). `AppSize`: tap target 48 · buttons
66 / 52 / 40 · content max 1200 · wide layout ≥ 768.
Icons: `sm` 18 · `md` 24 · `lg` 32.

## Buttons (`AppButton`, `AppIconButton`)
| Variant | Look | Use |
|---|---|---|
| `primary` | solid ink pill | the one main action per screen |
| `secondary` | white pill, 1.4px border | alternative action |
| `tertiary` | underlined text | low emphasis ("Not now", "View all") |

Sizes `lg` 66 (screen CTA in the bottom `GlassBar`), `md` 52 (default), `sm` 40 (48px
tap target). States: **pressed** 0.98 scale + ripple; **focused** 3px brand ring
(keyboard only); **disabled** grey pill, `onPressed: null` (use `onDisabledTap` to explain);
**loading** spinner replaces label, width held, taps ignored. `danger: true` for
destructive confirmations. Icon-only actions use `AppIconButton` — a tooltip is required.
Plain `TextButton`s (nav links, footer) inherit the theme's tertiary style.

## Icons
Material **outlined** set, one meaning per glyph, colour = text colour (brand/danger only
when carrying status). Sizes `AppIconSize`: 18 inline · 24 default · 32 empty/error states.
Filled variant = selected/active state of the *same* glyph (tab bar, checked). Illustrations
and per-option line icons come from the design mockups: `assets/illustrations/`,
`assets/icons/` (shown via `OnboardingArt`, `OnboardingIcon`); never recreate them in code.

## Components (`components.dart`)
`AppCard` (outlined / muted / brand tone, optional tap) · `SectionHeader` (+ trailing
action) · `StatusChip` (success/danger/warning/info/neutral) · `StatusItem` (done /
attention / pending check line) · `KeyValueRow` + `DividedList` · `AppListTile` ·
`StateView` (loading / empty / error) · `AppProgressBar` · `AppProgressRing` ·
`SheetHandle` · `AppSegmentedControl` · `AppChoiceChips` · `AppDropdownChip` ·
`Depth` · `DepthIcon` · `AppKeywordField` (free-text tags: input + Add, removable ink pills, outlined
tap-to-add suggestions; used for "What do you sell?") ·
`ReassuranceNote` (muted green panel, brand-tint background + 3px brand left border, no
radius — a short line reassuring the user a screen is optional/preparation-only, not a
form or eligibility decision; used throughout onboarding wherever that reassurance
applies). Page-level wrappers in `widgets.dart`: `Panel`, `Heading`, `Stat`,
`NextActions`, `SourceNote`, and the animated figures `AnimatedMoney`/`AnimatedPercent`.

## Patterns
- **Screens:** white `Scaffold`; 24 gutter; headline (`h1`) → subtitle (`secondary body`)
  → content; primary CTA pinned in `GlassBar.bottom`.
- **Lists:** rows inside an `AppCard`, hairline dividers, 48px minimum row height, chevron
  when tappable.
- **Forms:** theme `InputDecoration` (ink focus border, danger error border, helper/error in
  `caption`); label above the field; validation inline; invalid Continue shakes.
- **Dialogs:** `AlertDialog` (r20); secondary `sm` button left, primary/danger `sm` right.
- **Sheets:** `showModalBottomSheet` with `SheetHandle`, top radius 20, motion tokens.
- **Empty / loading / error:** `StateView` — never a blank screen or a bare spinner.
- **Nav:** bottom bar (phone) / rail (≥768); selected = filled brand icon + bold label.
- **Motion:** only `Motion` tokens; honour `Motion.reduced`; see `docs/animation-prompts.md`.

## Charts
Two files, no chart dependency (`CustomPainter`): `charts.dart` holds the compact result
charts (`RangeChart`, `CompositionBar`, `ValueBars`, `moneyCompact`); `analytics_charts.dart`
holds the four interactive analytics charts. Tokens are `AppChart` in `tokens.dart`.

**Choose the chart by the question**
| Question | Chart | Component |
|---|---|---|
| Compare counts across periods/categories | bar | `AppBarChart` |
| How does one measure change over time | line (+ dashed previous period) | `AppLineChart`, `LineLegend` |
| What share does each part have of a whole | pie, ≤ 6 slices, with legend + total | `AppPieChart` |
| How do two measures relate, per item | scatter | `AppScatterChart` |
| A range / part-of-whole / signed values inside a result card | range / stacked / signed bars | `RangeChart` / `CompositionBar` / `ValueBars` |

Never 3D, shadows, gradients or dual y-axes. Bars start at zero. Pie only for parts of one whole.

**Shared look (all four)** — plot insets `AppChart.plotInsets`; 1px `AppChart.grid` lines behind data;
1.2px `AppChart.axis` baseline; tick labels `AppText.tick` (12, secondary); integer/1-2-5 tick steps;
₹ axes in Indian compact units (`moneyCompact`: ₹1.5 L, ₹2 Cr); height 240 (bar/line), 260 (pie),
300 (scatter); bars radius 6; line 2.5px; markers 10px (15px selected).

**Colour and accessibility**
- Categorical series = `AppChart.series` (green, blue, amber, purple, slate), all ≥ 5.4:1 on white,
  so white labels sit on them. **Series are never told apart by colour alone:** each also has a
  marker shape (`ChartShape`: circle, square, diamond, triangle, cross) and a text label/legend entry.
- Highlight pattern for bars: the latest (or selected) bar is `series[0]`, the rest `AppChart.muted`.
  Selection adds an ink outline, not just a colour change.
- Green/red are reserved for good/urgent meaning (delta, closing soon); never for arbitrary series.
- Every chart is one Semantics node that reads all its data; the selected datum is also shown as text
  under the chart (a live region) — nothing depends on a tooltip or on hovering.

**Interaction (shared `_ChartSurface`)** — hover (pointer) previews; tap or horizontal drag (touch)
pins the nearest datum (hit radius 28px); arrow keys / Home / End move it, Esc clears; a green focus
ring shows for keyboard users. A tooltip (ink, white text) and the text readout show the same string.
Legends that filter are toggle rows ≥ 48px (`AppPieChart`); filters above charts are
`AppChoiceChips`; date range is `AppSegmentedControl` (7D / 30D / 90D) or `AppDropdownChip`.

**Motion** — data grows in once (`Motion.slow`); instant under reduced motion; selection changes are
instant. Charts sit in a `RepaintBoundary`.

**Data honesty** — real data where the app has it; anything else is labelled `Illustrative data`
(`StatusChip` info tone) on every screen that uses it. Sample data lives in `lib/data/sample_bids.dart`
behind one type (`SampleBid`), so a live source can replace it without touching the charts.
Progress uses `AppProgressBar`/`AppProgressRing`, never raw `LinearProgressIndicator`.

**Insights flow** — `Insights` overview (`/insights`) → `Bid trends` (`/insights-trends`, line) ·
`Category mix` (`/insights-categories`, pie) · `Bid fit` (`/insights-fit`, scatter). The date range
(`AppStore.insightsDays`) is shared by all four screens. Entry points: Home tab card and Tools tab card.

## Search (`/search`)

### AppSearchField
`AppSearchField` is the universal search input — a rounded `TextField` with a search icon prefix,
clear button when non-empty, and an optional pulsing mic button.

| Param | Type | Notes |
|-------|------|-------|
| `controller` | `TextEditingController` | required |
| `hint` | `String` | required |
| `onChanged` | `ValueChanged<String>` | required |
| `onSubmitted` | `ValueChanged<String>?` | — |
| `focusNode` | `FocusNode?` | — |
| `autofocus` | `bool` | default `false` |
| `showMic` | `bool` | default `false`; set `kVoiceSearchEnabled` (false on web) |
| `isListening` | `bool` | default `false`; animates mic red when true |
| `onMic` | `VoidCallback?` | called on mic tap/keyboard activation |

The mic button is a `_PulsingMicButton` in `components.dart` — `Icons.mic_none` (idle) /
`Icons.mic` (active, red) + a scale-pulse animation. Background radius is `AppRadius.md`.

### Scope control
`AppSegmentedControl<SearchScope>` — values All / Bids / Tools / Learn / My data.
Passes `semanticLabel` = `'Search scope'` / `'खोज दायरा'`.
Scope labels show a count badge when results exist: e.g. `Bids 12`.

### Result card (`BidResultRow`)
Each bid in the results list uses `BidResultRow` from `search_result_card.dart`:
- Whole row: `Semantics(button: true, label: '<title>. <n>% match. <reason>. <dept>. <n>d left.', excludeSemantics: true)`
- Min height: `ConstrainedBox(BoxConstraints(minHeight: AppSize.tap))`
- Right of title: `StatusChip('${score}%', tone: StatusTone.success)` (green pill)
- Department row: `Icons.business_outlined` (12 px) + `HighlightText`
- Score+reason row: `Flexible` text (brand, w600) + state text + `Spacer` + clock icon + closing days
  — closing ≤ 3 days uses `AppColors.danger` and `FontWeight.w700`
- Next-action row: italic caption, `AppColors.textSecondary`
- Chevron: `Icons.chevron_right`, `AppIconSize.md`, `AppColors.textHint`

`SearchResultRow` (tools/lessons/finance/FAQs/myData) uses an icon in a 40 px circular muted
surface, then title + subtitle `HighlightText` + italic action caption.

`HighlightText` renders matched query tokens in `FontWeight.w700` / `AppColors.ink`; falls
back to plain `Text` when no tokens match.

`IllustrativeLabel` must appear above every bid result group and on the empty-query "Suggested
for you" row — text `'Illustrative data — not real GeM bids'` / `'चित्रण डेटा — वास्तविक GeM बोलियाँ नहीं'`,
`AppText.caption`, `AppColors.textHint`.

### Filter chips (`_BidFilterChip`)
Shown in a horizontal `SingleChildScrollView` (Bids scope only). Each chip:
- `Semantics(button: true, label: label, selected: active, excludeSemantics: true)`
- `ConstrainedBox(BoxConstraints(minHeight: AppSize.tap))` — 48 px WCAG tap target
- Active: `AppColors.ink` background, `AppColors.surface` text
- Inactive: `AppColors.surfaceMuted` background, `AppColors.textSecondary` text
- Border radius: `AppRadius.pill`

### Sort sheet (`_SortSheet`)
`showModalBottomSheet` with `AppColors.surface` background and `AppRadius.xl` top radius.
Sort button in the count row: `Semantics(button: true, label: 'Sort: <option>')` wrapping a
`GestureDetector` → `Container` with `BoxConstraints(minHeight: AppSize.tap)`.

### Bid detail (`/bid-detail`)
Title in `AppText.h2`; match score as `StatusChip(score%, tone: StatusTone.success)`;
section labels in `AppText.overline`; action buttons use `AppButton` / `AppOutlinedButton`.

### Tokens added
| Token | Value | Location |
|-------|-------|----------|
| `AppSize.tap` | `48.0` | `tokens.dart` |
| `AppSize.wide` | `768.0` | `tokens.dart` |
| `AppSize.contentMax` | `1200.0` | `tokens.dart` |
| `_kWideBreak` (local) | `900.0` | `search_page.dart` — wide layout break |
| `_kContentMaxWidth` (local) | `640.0` | `search_page.dart` — centred column max width |

### Wide layout
At `constraints.maxWidth >= 900` the `body` wraps in
`Center > ConstrainedBox(maxWidth: 640)` via `LayoutBuilder`. Below 900 it fills the screen.

### Voice search
`VoiceSearchController` in `voice_search.dart`. Enabled via `kVoiceSearchEnabled = !kIsWeb`.
Locale: `hi_IN` when app language is Hindi, `en_IN` otherwise. On-device only; no query text
is sent to any server. See `docs/search/status.md` for platform permission details.

### My-data scope
`buildUserDataItems(AppStore)` in `user_data_index.dart` — allowlist-only indexing of
profile, checklist, outcomes and completed tools. PAN/Aadhaar/OTPs/passwords are never indexed.
Results appear under `SearchType.myData` with `Icons.person_outline`.

### Analytics (search)
Events fired (no raw query text ever logged):
- `search_performed` — `{len, results, scope}`
- `search_result_opened` — `{type, id}`
- `search_saved` — `{action: 'save'|'remove'}`
- `bid_detail_opened` — `{id}`

## Responsive
Phone-first single column; ≥768 switches to a navigation rail and `ResponsiveRow`
(1/2/3 columns); content max width 1200. Text scales with the OS setting — never fix a
text container's height.

## Localized greeting (`LanguagePage`)
The language screen's headline is `_GreetingIntro` (`language_page.dart`): the first time a
device reaches it, it tours every other supported language's own greeting (a quick crossfade
per language, `AnimatedSwitcher` + `FittedBox` so long words in any script never clip) before
settling on the greeting for whichever language is selected — sourced from the app's existing
`'Hello.'` translation via `tr(code, 'Hello.', 'नमस्ते.')`, never a new hardcoded string. A
"Skip" button jumps straight to the settled greeting; tapping a language card does the same and
switches the tour's destination. The headline is excluded from the semantics tree and replaced
with one static label — the settled greeting — so a screen reader is never read the tour.
Reduced motion skips the tour outright. It plays once per device
(`AppStore.hasSeenGreetingIntro`); later visits (and simple back/forward) show the settled
greeting immediately. **This costs nothing when a language is added**: the tour and the settle
step both just read `supportedLanguages` and the existing `'Hello.'` key, so a new language
that has a `'Hello.'` translation (see the font-fallback note above too) is included
automatically.

## Adding to the system
New value → `tokens.dart`; new look for a Material widget → `theme.dart`; new reusable
widget → `components.dart`/`charts.dart`. Update this file in the same change.
Every new string needs all 9 languages (`kTranslations`).
