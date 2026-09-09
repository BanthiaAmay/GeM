import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/models.dart';

void main() {
  group('MSME composite classification, lakh units', () {
    test('inclusive 2025 boundaries and either-limit upgrade', () {
      expect(classify(250, 1000), Enterprise.micro);
      expect(classify(250.01, 1000), Enterprise.small);
      expect(classify(1, 1000.01), Enterprise.small);
      expect(classify(2500, 10000), Enterprise.small);
      expect(classify(2500.01, 10000), Enterprise.medium);
      expect(classify(12500, 50000), Enterprise.medium);
      expect(classify(12500, 50000.01), Enterprise.other);
    });
    test('invalid values never receive a classification', () {
      expect(() => classify(-1, 0), throwsArgumentError);
      expect(() => classify(double.nan, 0), throwsArgumentError);
    });
  });
  test('Udyam absence and no prior supply are not disqualifiers', () {
    final r = Eligibility.evaluate({
      'investment': 10,
      'turnover': 100,
      'pan': true,
      'bank': true,
      'gst': 'yes',
      'udyam': false,
      'experience': false,
      'category': 'office',
    });
    expect(r.verdict, 'yes');
    expect(r.gaps, isEmpty);
  });
  test('GST exemption needs review and opt-out is a distinct segment', () {
    final p = {
      'investment': 10,
      'turnover': 100,
      'pan': true,
      'bank': true,
      'gst': 'exempt',
    };
    expect(Eligibility.evaluate(p).gaps, ['gst']);
    expect(Eligibility.evaluate({...p, 'interested': false}).verdict, 'choice');
  });
  test('order fee uses total value, exemption and cap', () {
    expect(transactionFee(1000000), 0);
    expect(transactionFee(1000001), closeTo(3000.003, .0001));
    expect(transactionFee(100000000), 300000);
    expect(transactionFee(200000000), 300000);
    expect(() => transactionFee(double.infinity), throwsArgumentError);
  });
  test('gross margin is not markup, competitive loss is visible', () {
    final r = PriceResult.calculate(80, 10, 10, 20, 90);
    expect(r.price, 125);
    expect(r.profit, 25);
    expect(r.competitiveMargin, closeTo(-11.1111, .001));
    expect(() => PriceResult.calculate(1, 1, 1, 100, 0), throwsArgumentError);
  });
  test('revenue cannot reverse bounds or hide zero-order outcome', () {
    expect(RevenueResult.calculate(1000, 0, 4).low, 0);
    expect(() => RevenueResult.calculate(1000, 5, 4), throwsArgumentError);
  });
  test('ROI subtracts costs and uses delay only once', () {
    final r = RoiResult.calculate(
      orderValue: 100000,
      annualOrders: 12,
      margin: 20,
      cash: 10000,
      hours: 10,
      hourlyRate: 1000,
      delayMonths: 3,
      recurring: 0,
    );
    expect(r.setup, 20000);
    expect(r.annualContribution, 240000);
    expect(r.firstYearNet, 160000);
    expect(r.threeYearNet, 640000);
    expect(r.paybackMonths, 4);
  });
  test('zero sales has no payback; fees charged per order', () {
    final zero = RoiResult.calculate(
      orderValue: 100000,
      annualOrders: 0,
      margin: 20,
      cash: 1000,
      hours: 0,
      hourlyRate: 0,
      delayMonths: 3,
      recurring: 0,
    );
    expect(zero.paybackMonths, isNull);
    expect(zero.firstYearNet, -1000);
    final paid = RoiResult.calculate(
      orderValue: 2000000,
      annualOrders: 2,
      margin: 20,
      cash: 0,
      hours: 0,
      hourlyRate: 0,
      delayMonths: 0,
      recurring: 0,
    );
    expect(paid.annualFees, 12000);
  });
}
