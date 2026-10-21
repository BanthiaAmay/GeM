# Search — design notes

Written: 2026-10-12  
Source: concept images (`concept-home-bids-details.png`, `concept-insights.png`)  
and Mobbin references listed below.

---

## Mobbin patterns used

| Pattern | Reference | How we apply it |
|---------|-----------|-----------------|
| Search bar with recent + grouped results | Shopify, Fresha | `_Suggestions` shows recents in a flat list with clock icons; `_buildBody` groups results into labelled sections (Bids / Tools / Other) |
| Filter chips + sort + match count | Cash App | Sort chip (`AppDropdownChip`) on the right; "N results" on the left; scope tabs above |
| Sort bottom sheet | Shop sort sheet | `sort_sheet.dart` exists as a prepared sheet; current UI uses inline dropdown chip — sheet can be activated if needed |
| Grouped result rows with chevron | GitHub mobile | Bold title, muted subtitle, trailing chevron on every row |

---

## Visual spec (from concept images)

### Page chrome

- **Background:** off-white page (`AppColors.surfaceMuted`) or white (`AppColors.surface`)
- **Surfaces:** white cards, minimal elevation
- **Icons:** Material *outlined* only; filled variant marks active state
- **Header:** back chevron (left) · centred title ("Search" / "Bid details") · one icon right (share or none)

### Search field

| Property | Value | Token |
|----------|-------|-------|
| Fill | grey, no border | `AppColors.surfaceMuted` |
| Corner radius | rounded rectangle | `AppRadius.input` (14 pt) |
| Leading icon | search, grey | `Icons.search`, `AppColors.textHint` |
| Trailing clear | × when text present | `Icons.close` |
| Trailing mic | grey, Phase 3 | `Icons.mic_none`, `AppColors.textHint` |
| Text style | body | `AppText.body` |
| Hint style | body + hint colour | `AppText.body` + `AppColors.textHint` |
| Height | 48 pt minimum | `AppSize.tap` |

### Scope tabs

- Grey track, near-black selected pill, white label — delivered by `AppSegmentedControl`
- Values: All · Bids · Tools · Learn · Finance

### Result count + sort row

```
24 matches                          Sort: Best match ⌄
```

- Count: `AppText.caption` on left
- Sort chip: `AppDropdownChip` on right, label "Sort: {option} ⌄"

### Bid result row (concept spec)

```
Office stationery supplies       [92% match ■]
🏛 Department of Education                  ›
📅 Closes 25 Sep 2026 · 1 day left (red)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ (hairline)
```

| Element | Style |
|---------|-------|
| Title | `AppText.title` (bold, 17 pt) |
| Match pill | `StatusChip` with `StatusTone.success`; background `AppColors.brandTint`; text `AppColors.brand` |
| Department | `AppText.caption`, building icon |
| Closing date | `AppText.caption`; red + bold when ≤ 3 days (`AppColors.danger`) |
| Urgency tag | "1 day left" — red, weight 700 |
| Chevron | `Icons.chevron_right`, `AppColors.textHint` |
| Divider | `Divider(height: 1)` between rows |

### Buttons

| Role | Style |
|------|-------|
| Primary | Near-black fill (`AppColors.ink`), white text, pill radius |
| Secondary | White, outlined `AppColors.borderStrong`, pill radius |
| Accent colour | Forest green `AppColors.brand` (links, icons, active states) |
| Urgency | Red `AppColors.danger` (closing-soon labels, destructive) |

### Caption

Every screen that shows bids must show one of:
- "Concept preview · Illustrative data" (standalone page footer)
- "Illustrative data — not real GeM bids" (inline above bid list)

Delivered by `IllustrativeLabel` widget in `search_result_card.dart`.

---

## Token mapping

All colours needed by search are already in `AppColors` — no new colour tokens required.

| Design spec name | Token | Value |
|-----------------|-------|-------|
| Near-black primary | `AppColors.ink` | `0xFF151515` |
| Match-green text | `AppColors.brand` | `0xFF22654C` |
| Match-green tint | `AppColors.brandTint` | `0xFFE5F1EA` |
| Urgency red | `AppColors.danger` | `0xFFB3261E` |
| Urgency red tint | `AppColors.dangerTint` | `0xFFFCE9E7` |
| Field grey fill | `AppColors.surfaceMuted` | `0xFFF5F6F4` |
| Hint text | `AppColors.textHint` | `0xFF8A9199` |

The only addition needed is a `searchFieldBorder` semantic alias — but since the  
spec says **no border**, no token is needed; the field simply has no `border` param.

---

## `AppSearchField` component spec

```dart
AppSearchField({
  required TextEditingController controller,
  required String hint,
  required ValueChanged<String> onChanged,
  ValueChanged<String>? onSubmitted,
  FocusNode? focusNode,
  bool autofocus = false,
  bool showMic = false,       // Phase 3: voice input
  VoidCallback? onMic,
  TextInputAction textInputAction = TextInputAction.search,
})
```

- Replaces private `_SearchField` in `tool_card.dart`
- Used in search AppBar as the live-search field
- Used in ToolsHub as the filter field
- **No border** — contrast comes from the grey fill against the white card/page
