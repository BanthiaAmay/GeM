import 'package:flutter_test/flutter_test.dart';
import 'package:gem/features/eligibility_engine.dart';

void main() {
  group('parseLakhCrore', () {
    test('plain integer', () {
      expect(parseLakhCrore('50000'), 50000);
    });
    test('lakh variants, singular and plural, with "(s)"', () {
      expect(parseLakhCrore('10 Lakh (s)'), 1000000);
      expect(parseLakhCrore('10 Lakhs'), 1000000);
      expect(parseLakhCrore('10 Lakh'), 1000000);
      expect(parseLakhCrore('10 Lac'), 1000000);
    });
    test('crore variants, singular and plural', () {
      expect(parseLakhCrore('1 Crore'), 10000000);
      expect(parseLakhCrore('2 Crores'), 20000000);
      expect(parseLakhCrore('1 Cr'), 10000000);
    });
    test('currency symbols and prefixes are stripped', () {
      expect(parseLakhCrore('₹50,000'), 50000);
      expect(parseLakhCrore('Rs. 2.5 Lakh'), 250000);
      expect(parseLakhCrore('Rs 50000'), 50000);
      expect(parseLakhCrore('INR 50,000'), 50000);
    });
    test('malformed or missing input returns null, never throws', () {
      expect(parseLakhCrore('abc'), null);
      expect(parseLakhCrore(null), null);
      expect(parseLakhCrore(''), null);
      expect(parseLakhCrore('   '), null);
    });
    test('explicit non-values parse to null', () {
      expect(parseLakhCrore('Nil'), null);
      expect(parseLakhCrore('N/A'), null);
      expect(parseLakhCrore('-'), null);
    });
  });

  group('parseYears', () {
    test('"(s)" and plain forms', () {
      expect(parseYears('3 Year (s)'), 3.0);
      expect(parseYears('2.5 years'), 2.5);
    });
    test('abbreviations', () {
      expect(parseYears('5 yrs'), 5.0);
      expect(parseYears('1 yr'), 1.0);
    });
    test('malformed or missing input returns null', () {
      expect(parseYears('abc'), null);
      expect(parseYears(null), null);
      expect(parseYears(''), null);
    });
  });

  group('extractConditions preserves original text on parse failure', () {
    test('unparseable turnover text is kept verbatim, never dropped', () {
      final conditions = extractConditions({
        'bidder_turnover': 'To be confirmed by buyer',
      });
      expect(conditions.length, 1);
      expect(conditions.first.type, ConditionType.turnover);
      expect(conditions.first.requirement, 'To be confirmed by buyer');
      expect(conditions.first.numericValue, null);
    });

    test('no fields present yields no conditions, not an error', () {
      expect(extractConditions({}), isEmpty);
    });

    test('documents_required becomes a documents condition with items', () {
      final conditions = extractConditions({
        'documents_required': ['GST Certificate', 'PAN Card'],
      });
      expect(conditions.single.type, ConditionType.documents);
      expect(conditions.single.items, ['GST Certificate', 'PAN Card']);
    });

    test('certifications are extracted from ATC text alongside the ATC condition', () {
      final conditions = extractConditions({
        'atc': 'Bidder must hold ISO 9001 and BIS certification.',
      });
      final types = conditions.map((c) => c.type).toList();
      expect(types, contains(ConditionType.certification));
      expect(types, contains(ConditionType.atc));
    });
  });

  group('turnover boundary evaluation', () {
    List<ConditionResult> evalWith(String band, {String requirement = '15 Lakh'}) {
      final conditions = extractConditions({'bidder_turnover': requirement});
      return evaluateEligibility(
        conditions: conditions,
        responses: {'turnover_band': band},
        mseEligible: false,
        startupEligible: false,
      );
    }

    test('lower bound exactly meets requirement → eligible', () {
      // 10to40L lower bound is 10,00,000; requirement 10 Lakh = 10,00,000.
      final r = evalWith('10to40L', requirement: '10 Lakh');
      expect(r.single.verdict, Verdict.eligible);
    });

    test('upper bound strictly below requirement → notEligible', () {
      // under10L upper bound 10,00,000 < 15,00,000 requirement.
      final r = evalWith('under10L', requirement: '15 Lakh');
      expect(r.single.verdict, Verdict.notEligible);
    });

    test('band straddles the threshold → needsVerification', () {
      // 10to40L spans 10L–40L; a 15L requirement falls inside it.
      final r = evalWith('10to40L', requirement: '15 Lakh');
      expect(r.single.verdict, Verdict.needsVerification);
    });

    test('missing band → needsVerification', () {
      final conditions = extractConditions({'bidder_turnover': '15 Lakh'});
      final r = evaluateEligibility(
        conditions: conditions,
        responses: const {},
        mseEligible: false,
        startupEligible: false,
      );
      expect(r.single.verdict, Verdict.needsVerification);
    });
  });

  group('relaxation rules never auto-grant from status alone', () {
    test(
      'bid confirms MSE turnover relaxation + user MSE-eligible → eligible',
      () {
        final conditions = extractConditions({'bidder_turnover': '50 Crore'});
        final r = evaluateEligibility(
          conditions: conditions,
          responses: {'turnover_band': 'under10L'},
          mseEligible: true,
          startupEligible: false,
          mseRelaxation: 'Yes',
        );
        expect(r.single.verdict, Verdict.eligible);
        expect(r.single.relaxationApplied, true);
      },
    );

    test('bid explicitly denies relaxation → falls back to normal comparison', () {
      final conditions = extractConditions({'bidder_turnover': '50 Crore'});
      final r = evaluateEligibility(
        conditions: conditions,
        responses: {'turnover_band': 'under10L'},
        mseEligible: true,
        startupEligible: false,
        mseRelaxation: 'No',
      );
      expect(r.single.verdict, Verdict.notEligible);
      expect(r.single.relaxationApplied, false);
    });

    test(
      'relaxation field missing + user MSE-eligible → needsVerification, '
      'never an automatic pass',
      () {
        final conditions = extractConditions({'bidder_turnover': '50 Crore'});
        final r = evaluateEligibility(
          conditions: conditions,
          responses: {'turnover_band': 'under10L'},
          mseEligible: true,
          startupEligible: false,
          mseRelaxation: null,
        );
        expect(r.single.verdict, Verdict.needsVerification);
        expect(r.single.relaxationApplied, false);
      },
    );

    test('user not MSE-eligible → relaxation never considered regardless of bid flag', () {
      final conditions = extractConditions({'bidder_turnover': '50 Crore'});
      final r = evaluateEligibility(
        conditions: conditions,
        responses: {'turnover_band': 'under10L'},
        mseEligible: false,
        startupEligible: false,
        mseRelaxation: 'Yes',
      );
      expect(r.single.verdict, Verdict.notEligible);
    });
  });

  group('EMD never auto-granted from MSME status alone', () {
    test('MSME status alone → needsVerification, not eligible', () {
      final conditions = extractConditions({
        'emd_required': 'Yes',
        'emd_amount': '10000',
      });
      final r = evaluateEligibility(
        conditions: conditions,
        responses: const {},
        mseEligible: true,
        startupEligible: false,
      );
      expect(r.single.verdict, Verdict.needsVerification);
      expect(r.single.relaxationApplied, false);
    });

    test('non-MSME user who confirms they can arrange EMD → eligible', () {
      final conditions = extractConditions({
        'emd_required': 'Yes',
        'emd_amount': '10000',
      });
      final r = evaluateEligibility(
        conditions: conditions,
        responses: {'emd_can_arrange': true},
        mseEligible: false,
        startupEligible: false,
      );
      expect(r.single.verdict, Verdict.eligible);
    });
  });

  group('ATC acceptance never implies compliance', () {
    test('not yet reviewed → needsVerification', () {
      final conditions = extractConditions({'atc': 'Standard terms apply.'});
      final atc = conditions.firstWhere((c) => c.type == ConditionType.atc);
      final r = evaluateEligibility(
        conditions: [atc],
        responses: {'atc_accepted': false},
        mseEligible: false,
        startupEligible: false,
      );
      expect(r.single.verdict, Verdict.needsVerification);
    });

    test('reviewed and accepted → still needsVerification, never eligible', () {
      final conditions = extractConditions({'atc': 'Standard terms apply.'});
      final atc = conditions.firstWhere((c) => c.type == ConditionType.atc);
      final r = evaluateEligibility(
        conditions: [atc],
        responses: {'atc_accepted': true},
        mseEligible: false,
        startupEligible: false,
      );
      expect(r.single.verdict, Verdict.needsVerification);
      expect(r.single.relaxationApplied, false);
    });
  });

  group('overallVerdict', () {
    ConditionResult fake(Verdict v) => ConditionResult(
      condition: const EligibilityCondition(
        type: ConditionType.turnover,
        label: 'x',
        requirement: 'x',
      ),
      verdict: v,
      explanation: '',
    );

    test('empty results → insufficientInformation', () {
      expect(overallVerdict([]), Verdict.insufficientInformation);
    });

    test('all needsVerification → insufficientInformation', () {
      expect(
        overallVerdict([
          fake(Verdict.needsVerification),
          fake(Verdict.needsVerification),
        ]),
        Verdict.insufficientInformation,
      );
    });

    test('any notEligible dominates, even mixed with eligible (contradictory conditions)', () {
      expect(
        overallVerdict([fake(Verdict.eligible), fake(Verdict.notEligible)]),
        Verdict.notEligible,
      );
    });

    test('mix of eligible and needsVerification → needsVerification', () {
      expect(
        overallVerdict([fake(Verdict.eligible), fake(Verdict.needsVerification)]),
        Verdict.needsVerification,
      );
    });

    test('all eligible → eligible', () {
      expect(
        overallVerdict([fake(Verdict.eligible), fake(Verdict.eligible)]),
        Verdict.eligible,
      );
    });
  });
}
