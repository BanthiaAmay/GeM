/// Pure Dart eligibility-checking logic — no Flutter imports.
/// Parses bid requirements from the `details` JSONB extracted by
/// `scripts/gem_source.py` and compares them against user-provided data.
///
/// This is a preliminary, self-service check, never an official GeM
/// eligibility decision — verdicts are deliberately hedged
/// (`notEligible` reads as "potentially ineligible" in the UI) and a
/// relaxation (MSE/startup) is only ever applied when the bid's own
/// extracted data confirms it; it is never granted purely from the
/// user's own MSME/startup status.
library;

enum ConditionType { turnover, oem, experience, documents, emd, certification, atc }

/// [insufficientInformation] is distinct from [needsVerification]: it
/// means the check found nothing it could evaluate either way (no
/// conditions at all, or every single condition came back
/// [needsVerification]) — not "some things need a closer look".
enum Verdict { eligible, notEligible, needsVerification, insufficientInformation }

class EligibilityCondition {
  final ConditionType type;
  final String label;
  final String requirement;
  final double? numericValue;
  final List<String>? items;

  const EligibilityCondition({
    required this.type,
    required this.label,
    required this.requirement,
    this.numericValue,
    this.items,
  });
}

class ConditionResult {
  final EligibilityCondition condition;
  final Verdict verdict;
  final String? userValue;
  final String explanation;
  final bool relaxationApplied;

  const ConditionResult({
    required this.condition,
    required this.verdict,
    this.userValue,
    required this.explanation,
    this.relaxationApplied = false,
  });
}

// ── Turnover band mapping ──────────────────────────────────────────────────

const kTurnoverBands = <String, (double lower, double upper)>{
  'under10L': (0, 1000000),
  '10to40L': (1000000, 4000000),
  '40Lto1_5Cr': (4000000, 15000000),
  '1_5to5Cr': (15000000, 50000000),
  '5CrPlus': (50000000, double.infinity),
};

// ── Parsers ────────────────────────────────────────────────────────────────
//
// Both parsers preserve the original requirement text on the condition
// regardless of whether they can make sense of it (see
// `extractConditions` below) — a value that fails to parse is never
// silently dropped, only left as `numericValue: null` for the evaluator
// to treat as "needs verification".

final _currencyPrefixRe = RegExp(
  r'(₹|Rs\.?|INR|Rupees)',
  caseSensitive: false,
);

final _lakhCroreRe = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(?:\(s\)\s*)?(lakh|lac|crore|cr)s?\.?\b',
  caseSensitive: false,
);

double? parseLakhCrore(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final cleaned = text.replaceAll(_currencyPrefixRe, '').trim();
  final m = _lakhCroreRe.firstMatch(cleaned);
  if (m != null) {
    final n = double.tryParse(m.group(1)!.replaceAll(',', ''));
    if (n == null) return null;
    final unit = m.group(2)!.toLowerCase();
    return (unit == 'crore' || unit == 'cr') ? n * 10000000 : n * 100000;
  }
  // Plain-number fallback: strip thousands separators and anything that
  // isn't a digit or decimal point (leftover currency symbols, "/-",
  // stray words) rather than failing outright on "₹50,000" or "Rs. 5000/-".
  final digitsOnly = cleaned.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), '');
  if (digitsOnly.isEmpty) return null;
  return double.tryParse(digitsOnly);
}

final _yearsRe = RegExp(
  r'(\d+(?:\.\d+)?)\s*(?:\(s\)\s*)?(?:years?|yrs?)\b',
  caseSensitive: false,
);

double? parseYears(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final m = _yearsRe.firstMatch(text);
  if (m != null) return double.tryParse(m.group(1)!);
  return double.tryParse(text.trim());
}

final _certPatterns = <RegExp>[
  RegExp(r'ISO\s*\d{4,5}(?:[-:]\d+)?', caseSensitive: false),
  RegExp(r'\bBIS\b'),
  RegExp(r'\bFSSAI\b', caseSensitive: false),
  RegExp(r'\bGMP\b'),
  RegExp(r'\bNABL\b', caseSensitive: false),
  RegExp(r'\bOHSAS\b', caseSensitive: false),
  RegExp(r'\bZED\b'),
  RegExp(r'\bCE\b'),
  RegExp(r'\bHACCP\b', caseSensitive: false),
];

// ── Condition extraction ───────────────────────────────────────────────────

List<EligibilityCondition> extractConditions(Map<String, dynamic> details) {
  final conditions = <EligibilityCondition>[];

  final turnoverText = details['bidder_turnover'] as String?;
  final turnoverVal = parseLakhCrore(turnoverText);
  if (turnoverText != null && turnoverText.trim().isNotEmpty) {
    conditions.add(EligibilityCondition(
      type: ConditionType.turnover,
      label: 'Minimum Annual Turnover',
      requirement: turnoverText.trim(),
      numericValue: turnoverVal,
    ));
  }

  final oemText = details['oem_turnover'] as String?;
  final oemVal = parseLakhCrore(oemText);
  if (oemText != null && oemText.trim().isNotEmpty) {
    conditions.add(EligibilityCondition(
      type: ConditionType.oem,
      label: 'OEM Annual Turnover',
      requirement: oemText.trim(),
      numericValue: oemVal,
    ));
  }

  final expText = details['experience'] as String?;
  final expVal = parseYears(expText);
  if (expText != null && expText.trim().isNotEmpty) {
    conditions.add(EligibilityCondition(
      type: ConditionType.experience,
      label: 'Past Experience',
      requirement: expText.trim(),
      numericValue: expVal,
    ));
  }

  final docs = details['documents_required'];
  if (docs is List && docs.isNotEmpty) {
    conditions.add(EligibilityCondition(
      type: ConditionType.documents,
      label: 'Required Documents',
      requirement: '${docs.length} documents',
      items: List<String>.from(docs),
    ));
  }

  final emdRequired = details['emd_required'] as String?;
  if (emdRequired != null &&
      emdRequired.toLowerCase() == 'yes') {
    final emdText = details['emd_amount'] as String? ?? '';
    final emdVal = parseLakhCrore(emdText);
    conditions.add(EligibilityCondition(
      type: ConditionType.emd,
      label: 'Earnest Money Deposit',
      requirement: emdText.isNotEmpty ? emdText.trim() : 'Required',
      numericValue: emdVal,
    ));
  }

  final atc = details['atc'] as String?;
  if (atc != null && atc.trim().isNotEmpty) {
    final found = <String>{};
    for (final re in _certPatterns) {
      for (final m in re.allMatches(atc)) {
        found.add(m.group(0)!.trim());
      }
    }
    for (final cert in found) {
      conditions.add(EligibilityCondition(
        type: ConditionType.certification,
        label: cert,
        requirement: 'Certificate required',
      ));
    }
    conditions.add(EligibilityCondition(
      type: ConditionType.atc,
      label: 'Additional Terms & Conditions',
      requirement: atc.length > 500 ? '${atc.substring(0, 500)}…' : atc,
    ));
  }

  return conditions;
}

// ── Evaluation ─────────────────────────────────────────────────────────────

/// A relaxation (MSE or startup) is applied only when:
/// (a) the user's own profile makes them eligible for it, AND
/// (b) the bid's own extracted data confirms that relaxation for this
///     specific condition (`mse_relaxation`/`startup_relaxation` cover
///     turnover and experience only — never EMD, which has no
///     bid-specific signal in the extracted data at all).
/// When (a) holds but the bid's field is simply missing — not an
/// explicit "No" — the result is [Verdict.needsVerification], never an
/// automatic pass.
enum _RelaxationState { confirmed, explicitlyNo, unknown }

_RelaxationState _relaxationState(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  if (v == 'yes') return _RelaxationState.confirmed;
  if (v == 'no') return _RelaxationState.explicitlyNo;
  return _RelaxationState.unknown;
}

List<ConditionResult> evaluateEligibility({
  required List<EligibilityCondition> conditions,
  required Map<String, dynamic> responses,
  required bool mseEligible,
  required bool startupEligible,
  String? mseRelaxation,
  String? startupRelaxation,
}) {
  final results = <ConditionResult>[];
  final mseState = _relaxationState(mseRelaxation);
  final startupState = _relaxationState(startupRelaxation);

  for (final c in conditions) {
    switch (c.type) {
      case ConditionType.turnover:
        results.add(_evalTurnover(c, responses, mseEligible, mseState));
      case ConditionType.oem:
        results.add(_evalOem(c, responses));
      case ConditionType.experience:
        results.add(_evalExperience(
          c,
          responses,
          mseEligible,
          mseState,
          startupEligible,
          startupState,
        ));
      case ConditionType.documents:
        results.add(_evalDocuments(c, responses));
      case ConditionType.emd:
        results.add(_evalEmd(c, responses, mseEligible));
      case ConditionType.certification:
        results.add(_evalCertification(c, responses));
      case ConditionType.atc:
        results.add(_evalAtc(c, responses));
    }
  }
  return results;
}

ConditionResult _evalTurnover(
  EligibilityCondition c,
  Map<String, dynamic> responses,
  bool mseEligible,
  _RelaxationState mseState,
) {
  final band = responses['turnover_band'] as String?;
  if (band == null || band.isEmpty) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      explanation: 'Turnover information not provided.',
    );
  }
  if (mseEligible) {
    if (mseState == _RelaxationState.confirmed) {
      return ConditionResult(
        condition: c,
        verdict: Verdict.eligible,
        userValue: _bandLabel(band),
        explanation: 'MSE turnover relaxation applies — requirement waived.',
        relaxationApplied: true,
      );
    }
    if (mseState == _RelaxationState.unknown) {
      return ConditionResult(
        condition: c,
        verdict: Verdict.needsVerification,
        userValue: _bandLabel(band),
        explanation:
            'You may be MSE-eligible for a turnover relaxation, but this bid does not confirm either way — verify with the buyer.',
      );
    }
    // mseState == explicitlyNo: fall through to a normal comparison.
  }
  if (c.numericValue == null) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      userValue: _bandLabel(band),
      explanation:
          'Could not read a number from the bid\'s requirement ("${c.requirement}"). Verify manually.',
    );
  }
  final bounds = kTurnoverBands[band];
  if (bounds == null) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      userValue: band,
      explanation: 'Unknown turnover band.',
    );
  }
  final (lower, upper) = bounds;
  if (lower >= c.numericValue!) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.eligible,
      userValue: _bandLabel(band),
      explanation: 'Your turnover band meets the requirement.',
    );
  }
  if (upper < c.numericValue!) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.notEligible,
      userValue: _bandLabel(band),
      explanation: 'Your turnover band is below the requirement.',
    );
  }
  return ConditionResult(
    condition: c,
    verdict: Verdict.needsVerification,
    userValue: _bandLabel(band),
    explanation:
        'Your turnover band includes the threshold — verify with exact figures.',
  );
}

String _bandLabel(String key) => switch (key) {
  'under10L' => 'Under ₹10 lakh',
  '10to40L' => '₹10 lakh – ₹40 lakh',
  '40Lto1_5Cr' => '₹40 lakh – ₹1.5 crore',
  '1_5to5Cr' => '₹1.5 crore – ₹5 crore',
  '5CrPlus' => '₹5 crore and above',
  _ => key,
};

ConditionResult _evalOem(EligibilityCondition c, Map<String, dynamic> r) {
  final val = r['oem_turnover'] as double?;
  if (val == null) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      explanation: 'OEM turnover not provided.',
    );
  }
  if (c.numericValue == null) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      userValue: '₹${(val / 100000).toStringAsFixed(1)} lakh',
      explanation:
          'Could not read a number from the bid\'s requirement ("${c.requirement}"). Verify manually.',
    );
  }
  return ConditionResult(
    condition: c,
    verdict: val >= c.numericValue! ? Verdict.eligible : Verdict.notEligible,
    userValue: '₹${(val / 100000).toStringAsFixed(1)} lakh',
    explanation: val >= c.numericValue!
        ? 'OEM turnover meets the requirement.'
        : 'OEM turnover is below the requirement.',
  );
}

ConditionResult _evalExperience(
  EligibilityCondition c,
  Map<String, dynamic> r,
  bool mseEligible,
  _RelaxationState mseState,
  bool startupEligible,
  _RelaxationState startupState,
) {
  final years = r['experience_years'] as double?;
  final mseConfirmed = mseEligible && mseState == _RelaxationState.confirmed;
  final startupConfirmed =
      startupEligible && startupState == _RelaxationState.confirmed;
  if (mseConfirmed || startupConfirmed) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.eligible,
      userValue: years != null ? '${years.toStringAsFixed(0)} years' : null,
      explanation:
          'MSE/startup experience relaxation applies — requirement waived.',
      relaxationApplied: true,
    );
  }
  final mseUnknown = mseEligible && mseState == _RelaxationState.unknown;
  final startupUnknown =
      startupEligible && startupState == _RelaxationState.unknown;
  if (mseUnknown || startupUnknown) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      userValue: years != null ? '${years.toStringAsFixed(0)} years' : null,
      explanation:
          'You may be eligible for an MSE/startup experience relaxation, but this bid does not confirm either way — verify with the buyer.',
    );
  }
  if (years == null) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      explanation: 'Experience information not provided.',
    );
  }
  if (c.numericValue == null) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      userValue: '${years.toStringAsFixed(0)} years',
      explanation:
          'Could not read a number from the bid\'s requirement ("${c.requirement}"). Verify manually.',
    );
  }
  return ConditionResult(
    condition: c,
    verdict: years >= c.numericValue! ? Verdict.eligible : Verdict.notEligible,
    userValue: '${years.toStringAsFixed(0)} years',
    explanation: years >= c.numericValue!
        ? 'Your experience meets the requirement.'
        : 'Your experience is below the requirement.',
  );
}

ConditionResult _evalDocuments(EligibilityCondition c, Map<String, dynamic> r) {
  final docStatus = r['documents'] as Map<String, String>? ?? {};
  if (docStatus.isEmpty || c.items == null) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      explanation: 'Document availability not confirmed.',
    );
  }
  final missing = <String>[];
  final unsure = <String>[];
  for (final doc in c.items!) {
    final status = docStatus[doc] ?? 'unsure';
    if (status == 'no') missing.add(doc);
    if (status == 'unsure') unsure.add(doc);
  }
  if (missing.isNotEmpty) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.notEligible,
      userValue: '${missing.length} missing',
      explanation: 'Missing: ${missing.join(", ")}.',
    );
  }
  if (unsure.isNotEmpty) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      userValue: '${unsure.length} unconfirmed',
      explanation: 'Unconfirmed: ${unsure.join(", ")}.',
    );
  }
  return ConditionResult(
    condition: c,
    verdict: Verdict.eligible,
    userValue: 'All available',
    explanation: 'All required documents are available.',
  );
}

/// GeM's MSE EMD exemption is a blanket policy benefit, not something
/// this bid's own extracted data confirms (the extracted
/// `mse_relaxation`/`startup_relaxation` fields cover turnover and
/// experience only — there is no bid-specific EMD signal). So MSME
/// status alone is never enough to silently grant `eligible` here; it
/// always needs the user's own verification first.
ConditionResult _evalEmd(
  EligibilityCondition c,
  Map<String, dynamic> r,
  bool mseEligible,
) {
  if (mseEligible) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      explanation:
          'You may qualify for an MSE EMD exemption under GeM policy — confirm with the buyer or bid document before assuming it applies.',
    );
  }
  final canArrange = r['emd_can_arrange'] as bool?;
  if (canArrange == null) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      explanation: 'Confirm if you can arrange the EMD amount.',
    );
  }
  return ConditionResult(
    condition: c,
    verdict: canArrange ? Verdict.eligible : Verdict.notEligible,
    userValue: canArrange ? 'Yes' : 'No',
    explanation: canArrange
        ? 'You can arrange the required EMD.'
        : 'Cannot arrange the required EMD amount.',
  );
}

ConditionResult _evalCertification(EligibilityCondition c, Map<String, dynamic> r) {
  final status = r['cert_${c.label}'] as String?;
  if (status == 'yes') {
    return ConditionResult(
      condition: c,
      verdict: Verdict.eligible,
      userValue: 'Have it',
      explanation: '${c.label} certificate available.',
    );
  }
  if (status == 'applied') {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      userValue: 'Applied',
      explanation: '${c.label} application in progress — verify acceptance.',
    );
  }
  if (status == 'no') {
    return ConditionResult(
      condition: c,
      verdict: Verdict.notEligible,
      userValue: 'Don\'t have it',
      explanation: '${c.label} certificate is not available.',
    );
  }
  return ConditionResult(
    condition: c,
    verdict: Verdict.needsVerification,
    explanation: '${c.label} certificate status not confirmed.',
  );
}

/// Acknowledging these terms is never treated as satisfying them —
/// ticking a box cannot stand in for actually meeting whatever specific
/// obligations the terms describe (certifications found inside the text
/// are already pulled out as their own [ConditionType.certification]
/// conditions with their own real yes/no questions). This always comes
/// back [Verdict.needsVerification]; it never resolves to `eligible`.
ConditionResult _evalAtc(EligibilityCondition c, Map<String, dynamic> r) {
  final accepted = r['atc_accepted'] as bool? ?? false;
  return ConditionResult(
    condition: c,
    verdict: Verdict.needsVerification,
    userValue: accepted ? 'Reviewed' : 'Not yet reviewed',
    explanation: accepted
        ? 'You have reviewed these terms, but specific conditions inside them must still be verified individually — any certifications found in the text appear as their own checks above.'
        : 'Review the additional terms and conditions before bidding.',
  );
}

Verdict overallVerdict(List<ConditionResult> results) {
  if (results.isEmpty) return Verdict.insufficientInformation;
  if (results.any((r) => r.verdict == Verdict.notEligible)) {
    return Verdict.notEligible;
  }
  if (results.every((r) => r.verdict == Verdict.needsVerification)) {
    return Verdict.insufficientInformation;
  }
  if (results.any((r) => r.verdict == Verdict.needsVerification)) {
    return Verdict.needsVerification;
  }
  return Verdict.eligible;
}
