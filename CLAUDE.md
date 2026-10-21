# Bid2Scale — agent instructions

- **UI work follows [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).** Use `AppColors`/`AppText`/`AppSpace`/`AppRadius`
  from `lib/core/tokens.dart` and the shared widgets in `lib/features/components.dart` and
  `lib/features/charts.dart`. No raw colours, font sizes, or styled Material buttons in feature files.
- Motion uses `lib/core/motion.dart` tokens and respects `Motion.reduced`.
- Every user-facing string needs all 9 languages (`kTranslations` in `lib/core/translations.dart`).
- Architecture, data and trust boundaries: [design.md](design.md). Product scope: [prd.md](prd.md).
- Verify with `flutter analyze` and `flutter test`.
- Charts follow the Charts section of DESIGN_SYSTEM.md. Analytics run on `lib/data/sample_bids.dart` and must stay labelled "Illustrative data" until a live bid source exists.
