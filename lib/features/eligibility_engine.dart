/// Pure Dart eligibility-checking logic — no Flutter imports.
/// Parses bid requirements from the `details` JSONB extracted by
/// `scripts/gem_source.py` and compares them against user-provided data.
library;

enum ConditionType { turnover, oem, experience, documents, emd, certification, atc }
enum Verdict { eligible, notEligible, needsVerification }

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

final _lakhCroreRe = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(?:\(s\)\s*)?(lakh|lac|crore|cr)\b',
  caseSensitive: false,
);

double? parseLakhCrore(String? text) {
  if (text == null || text.isEmpty) return null;
  final m = _lakhCroreRe.firstMatch(text);
  if (m != null) {
    final n = double.tryParse(m.group(1)!.replaceAll(',', ''));
    if (n == null) return null;
    final unit = m.group(2)!.toLowerCase();
    return (unit == 'crore' || unit == 'cr') ? n * 10000000 : n * 100000;
  }
  final plain = double.tryParse(text.replaceAll(',', '').trim());
  return plain;
}

final _yearsRe = RegExp(r'(\d+(?:\.\d+)?)\s*(?:\(s\)\s*)?year', caseSensitive: false);

double? parseYears(String? text) {
  if (text == null || text.isEmpty) return null;
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

List<ConditionResult> evaluateEligibility({
  required List<EligibilityCondition> conditions,
  required Map<String, dynamic> responses,
  required bool mseEligible,
  required bool startupEligible,
  String? mseRelaxation,
  String? startupRelaxation,
}) {
  final results = <ConditionResult>[];
  final mseRelax = (mseRelaxation ?? '').toLowerCase() == 'yes';
  final startupRelax = (startupRelaxation ?? '').toLowerCase() == 'yes';

  for (final c in conditions) {
    switch (c.type) {
      case ConditionType.turnover:
        results.add(_evalTurnover(c, responses, mseEligible && mseRelax));
      case ConditionType.oem:
        results.add(_evalOem(c, responses));
      case ConditionType.experience:
        results.add(_evalExperience(
          c,
          responses,
          (mseEligible && mseRelax) || (startupEligible && startupRelax),
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
  bool relaxationApplies,
) {
  final band = responses['turnover_band'] as String?;
  if (band == null || band.isEmpty) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      explanation: 'Turnover information not provided.',
    );
  }
  if (relaxationApplies) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.eligible,
      userValue: band,
      explanation: 'MSE turnover relaxation applies — requirement waived.',
      relaxationApplied: true,
    );
  }
  if (c.numericValue == null) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.needsVerification,
      userValue: band,
      explanation: 'Could not parse the bid requirement. Verify manually.',
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
      explanation: 'Could not parse the bid requirement. Verify manually.',
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
  bool relaxationApplies,
) {
  final years = r['experience_years'] as double?;
  if (relaxationApplies) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.eligible,
      userValue: years != null ? '${years.toStringAsFixed(0)} years' : null,
      explanation: 'MSE/startup experience relaxation applies — requirement waived.',
      relaxationApplied: true,
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
      explanation: 'Could not parse the bid requirement. Verify manually.',
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

ConditionResult _evalEmd(
  EligibilityCondition c,
  Map<String, dynamic> r,
  bool mseEligible,
) {
  if (mseEligible) {
    return ConditionResult(
      condition: c,
      verdict: Verdict.eligible,
      explanation: 'MSME EMD exemption applies.',
      relaxationApplied: true,
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

ConditionResult _evalAtc(EligibilityCondition c, Map<String, dynamic> r) {
  final accepted = r['atc_accepted'] as bool? ?? false;
  return ConditionResult(
    condition: c,
    verdict: accepted ? Verdict.eligible : Verdict.needsVerification,
    userValue: accepted ? 'Reviewed & accepted' : 'Not reviewed',
    explanation: accepted
        ? 'Additional terms reviewed and accepted.'
        : 'Review the additional terms and conditions before bidding.',
  );
}

Verdict overallVerdict(List<ConditionResult> results) {
  if (results.any((r) => r.verdict == Verdict.notEligible)) {
    return Verdict.notEligible;
  }
  if (results.any((r) => r.verdict == Verdict.needsVerification)) {
    return Verdict.needsVerification;
  }
  return Verdict.eligible;
}
