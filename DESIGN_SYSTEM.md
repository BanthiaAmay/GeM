# Bid2Scale — Design System

The rules every screen follows. Code lives in `lib/core/tokens.dart` (values),
`lib/core/theme.dart` (Material theme built from them), `lib/features/components.dart`
(shared widgets) and `lib/features/charts.dart` (charts). Motion rules are in
`lib/core/motion.dart`. Architecture and data live in [design.md](design.md).

**Rule zero:** feature files never contain a raw `Color(0x…)`, `Colors.*`, `fontSize:`,
pixel radius, or a styled `FilledButton`/`OutlinedButton`. Use a token or a component.
If none fits, add one to the system first.

## Character
Calm, precise, text-first — near-black ink on white, one green for "good", one red for
"urgent". Bordered white cards, tinted status chips, pill buttons, thin line icons.
No shadows, gradients or decoration; blur only in `GlassBar`.

## Colour (`AppColors`)
| Token | Hex | Use | Contrast |
|---|---|---|---|
| `ink` | `#151515` | text, headings, primary button | 18.3:1 on white |
| `textSecondary` | `#5F6873` | subtitles, helper text, captions | 5.6:1 |
| `textHint` | `#8A9199` | placeholders, disabled only | 3.2:1 (never for required reading) |
| `surface` / `surfaceMuted` | `#FFFFFF` / `#F5F6F4` | page, card / selected row, inset panel | |
| `border` / `borderStrong` | `#E1E5E2` / `#C9CFCB` | card hairline / control border | |
| `brand` + `brandTint` | `#22654C` / `#E5F1EA` | ready, positive, links, featured card | 6.9:1 |
| `danger` + `dangerTint` | `#B3261E` / `#FCE9E7` | urgent, error, destructive | 6.5:1 |
| `warning` + `warningTint` | `#8A5300` / `#FFF1D6` | needs attention | 5.7:1 on tint |
| `info` + `infoTint` | `#1F5F8B` / `#E6F0F7` | neutral information | 5.9:1 on tint |
| `disabled` | `#CCCCCC` | disabled fill | |

Colour is never the only signal: status always carries text or an icon. All body-size
text meets WCAG AA (4.5:1).

## Typography (`AppText`) — SF Pro on iOS, system font elsewhere, bundled Noto Sans fallback per script
`display` 40/800 (welcome) · `h1` 30/800 (screen headline) · `h2` 24/800 (page/card group)
· `h3` 20/700 (section, option label) · `title` 17/700 (card/list title) · `body` 16
· `bodySmall` 14 · `caption` 13 secondary (helper, metadata) · `label` 12/700 (chips, tab
labels) · `overline` 12/700 uppercase (eyebrow) · `lead` 20 secondary · `input` 18
(typed text) · `button` 17/700 · `buttonLg` 22/700. Use `AppText.secondary(style)` for the
muted variant. Documented exceptions: the language-screen hero greeting (`display` resized),
and the handwriting on the name card (art overlay).

Every script in `supportedLanguages` (core/models.dart) has a matching bundled font in
`theme.dart`'s `fontFamilyFallback` (Devanagari, Bengali, Gujarati, Gurmukhi, Tamil, Telugu,
Kannada — `assets/fonts/`), so text renders correctly even on a device whose OS doesn't ship
that script. **Adding a language means adding its script's font here too**, not just its
translations.

## Spacing, radius, size
`AppSpace`: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48 (`gutter` = 24 side margin on phone
screens). `AppRadius`: `sm` 8 (chips) · `md` 14 (inputs, option rows) · `lg` 16 (cards) ·
`xl` 20 (hero cards, sheets) · `pill` (buttons). `AppSize`: tap target 48 · buttons
66 / 52 / 40 · content max 1200 · wide layout ≥ 768.

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
