/// Builds SearchItems from the user's own AppStore data.
///
/// All indexing is on-device. PAN, Aadhaar numbers and OTPs are never
/// indexed — the profile map is known to hold only business / contact
/// fields from the onboarding flow, and those keys are allowed below
/// by an explicit allowlist rather than a blocklist.
library;

import '../../core/models.dart' show steps;
import '../../data/app_store.dart';
import 'search_models.dart';

// Allowed profile keys (all business-context, no identity numbers).
// This set documents intent: add a key here before reading it below.
// ignore: unused_element
const _kAllowedProfileKeys = {
  'fullName',
  'businessName',
  'category',
  'productDesc',
  'state',
  'city',
  'gstStatus',
  'udyamStatus',
  'businessType',
  'turnover',
};

/// Builds a list of [SearchItem]s typed [SearchType.myData] from [store].
///
/// Returns an empty list when the store holds no meaningful user data, so
/// callers can skip injecting user items into the index entirely.
List<SearchItem> buildUserDataItems(AppStore store) {
  final items = <SearchItem>[];

  // ── Business profile ─────────────────────────────────────────────────────

  final profile = store.profile;
  final businessName = profile['businessName'] as String? ?? '';
  final fullName = profile['fullName'] as String? ?? '';
  final city = profile['city'] as String? ?? '';
  final category = profile['category'] as String? ?? '';
  final productDesc = profile['productDesc'] as String? ?? '';

  if (businessName.isNotEmpty || fullName.isNotEmpty) {
    final kws = <String>[
      'profile',
      'business',
      'my business',
      if (businessName.isNotEmpty) businessName.toLowerCase(),
      if (fullName.isNotEmpty) fullName.toLowerCase(),
      if (city.isNotEmpty) city.toLowerCase(),
      if (category.isNotEmpty) category.toLowerCase(),
      if (productDesc.isNotEmpty) ...productDesc.toLowerCase().split(' '),
    ];
    items.add(
      SearchItem(
        id: 'mydata-profile',
        type: SearchType.myData,
        titleEn: 'Your business profile',
        titleHi: 'आपकी व्यवसाय प्रोफ़ाइल',
        subtitleEn: businessName.isNotEmpty ? businessName : fullName,
        subtitleHi: businessName.isNotEmpty ? businessName : fullName,
        keywords: kws,
        route: 'profile',
        actionEn: 'View',
        actionHi: 'देखें',
      ),
    );
  }

  // ── Outcomes — self-reported GeM milestones (stage + buyer/order ref) ────

  for (final outcome in store.outcomes) {
    final stage = outcome['stage'] as String? ?? '';
    final reference = outcome['reference'] as String? ?? '';
    if (reference.isEmpty) continue;
    items.add(
      SearchItem(
        id: 'mydata-outcome-$stage',
        type: SearchType.myData,
        titleEn: _stageLabelEn(stage),
        titleHi: _stageLabelHi(stage),
        subtitleEn: reference,
        subtitleHi: reference,
        keywords: [
          reference.toLowerCase(),
          ...reference.toLowerCase().split(RegExp(r'\s+')),
          stage.toLowerCase(),
          'order',
          'buyer',
          'outcome',
          'delivered',
        ],
        route: 'tracker',
        actionEn: 'View',
        actionHi: 'देखें',
      ),
    );
  }

  // ── Registration checklist progress ──────────────────────────────────────

  final checklist = store.checklist;
  final doneCount = checklist.where((b) => b).length;
  final nextIdx = checklist.indexOf(false);
  final nextStep = nextIdx >= 0 && nextIdx < steps.length
      ? steps[nextIdx][0]
      : 'All steps complete';
  items.add(
    SearchItem(
      id: 'mydata-checklist',
      type: SearchType.myData,
      titleEn: 'Registration checklist',
      titleHi: 'पंजीकरण जाँच सूची',
      subtitleEn: '$doneCount of ${steps.length} steps done • Next: $nextStep',
      subtitleHi: '${steps.length} में से $doneCount चरण पूर्ण',
      keywords: [
        'checklist',
        'registration',
        'steps',
        'progress',
        'tracker',
        'udyam',
        'gst',
        'gem registration',
      ],
      route: 'tracker',
      actionEn: 'View',
      actionHi: 'देखें',
    ),
  );

  // ── Completed tool results ────────────────────────────────────────────────

  for (final key in store.completed) {
    final toolLabelEn = _toolLabelEn(key);
    items.add(
      SearchItem(
        id: 'mydata-tool-$key',
        type: SearchType.myData,
        titleEn: toolLabelEn,
        titleHi: _toolLabelHi(key),
        subtitleEn: 'Your saved result',
        subtitleHi: 'आपका सहेजा गया परिणाम',
        keywords: [
          key,
          toolLabelEn.toLowerCase(),
          'calculator',
          'result',
          'my result',
          'saved',
        ],
        route: key,
        actionEn: 'View',
        actionHi: 'देखें',
      ),
    );
  }

  return items;
}

String _stageLabelEn(String stage) => switch (stage) {
  'first_order' => 'Your first GeM order',
  'first_payment' => 'Your first payment',
  'registered' => 'GeM registration',
  _ => 'Your GeM milestone',
};

String _stageLabelHi(String stage) => switch (stage) {
  'first_order' => 'आपका पहला GeM ऑर्डर',
  'first_payment' => 'आपका पहला भुगतान',
  'registered' => 'GeM पंजीकरण',
  _ => 'आपका GeM मील का पत्थर',
};

String _toolLabelEn(String key) => switch (key) {
  'eligibility' => 'Eligibility checker',
  'revenue' => 'Revenue estimator',
  'pricing' => 'Pricing & margin',
  'roi' => 'ROI & effort',
  _ => key,
};

String _toolLabelHi(String key) => switch (key) {
  'eligibility' => 'पात्रता जाँच',
  'revenue' => 'आय अनुमान',
  'pricing' => 'मूल्य और मार्जिन',
  'roi' => 'लाभ और प्रयास',
  _ => key,
};
