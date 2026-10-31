import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'translations.dart';

/// Every language this app can display, in the order shown on the
/// language picker: [code, native name, English name].
const supportedLanguages = <List<String>>[
  ['en', 'English', 'English'],
  ['hi', 'हिन्दी', 'Hindi'],
  ['mr', 'मराठी', 'Marathi'],
  ['bn', 'বাংলা', 'Bengali'],
  ['gu', 'ગુજરાતી', 'Gujarati'],
  ['pa', 'ਪੰਜਾਬੀ', 'Punjabi'],
  ['ta', 'தமிழ்', 'Tamil'],
  ['te', 'తెలుగు', 'Telugu'],
  ['kn', 'ಕನ್ನಡ', 'Kannada'],
];

const ruleVersion = '2026-09-09.v1';
const udyamSource = 'https://udyamregistration.gov.in/Important.aspx';
const feeSource = 'https://www.pib.gov.in/Pressreleaseshare.aspx?PRID=2057276';
const gemSource = 'https://gem.gov.in/';
const policySource =
    'https://champions.gov.in/Ministry-of-MSME/skills%2Cloan%2Ccredit_guarantee%2CPM-atmnirbhar-Economic-Package%2Celigibility_criteria%2Cguidelines_Schemes/query_questions_FAQs.htm';
String money(num value) => NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
).format(value);

/// Resolves an (English, Hindi) pair authored at the call site to the
/// current language. English and Hindi are exactly what was authored
/// there; every other language is looked up in the central
/// [kTranslations] table by the English text, falling back to English
/// itself if that specific string hasn't been translated for `lang` yet
/// — so an unsupported combination never shows blank text or crashes.
String tr(String lang, String en, String hindi) => switch (lang) {
  'hi' => hindi,
  'en' => en,
  _ => kTranslations[en]?[lang] ?? en,
};

enum Enterprise { micro, small, medium, other }

Enterprise classify(double investmentLakh, double turnoverLakh) {
  checkNumber(investmentLakh);
  checkNumber(turnoverLakh);
  if (investmentLakh <= 250 && turnoverLakh <= 1000) return Enterprise.micro;
  if (investmentLakh <= 2500 && turnoverLakh <= 10000) return Enterprise.small;
  if (investmentLakh <= 12500 && turnoverLakh <= 50000) {
    return Enterprise.medium;
  }
  return Enterprise.other;
}

void checkNumber(double n) {
  if (!n.isFinite || n < 0) {
    throw ArgumentError('Enter a finite, non-negative number');
  }
}

String classificationName(Enterprise e, String lang) => switch (e) {
  Enterprise.micro => tr(lang, 'Micro enterprise', 'सूक्ष्म उद्यम'),
  Enterprise.small => tr(lang, 'Small enterprise', 'लघु उद्यम'),
  Enterprise.medium => tr(lang, 'Medium enterprise', 'मध्यम उद्यम'),
  Enterprise.other => tr(lang, 'Outside MSME thresholds', 'MSME सीमा से बाहर'),
};

class Eligibility {
  final String verdict;
  final Enterprise enterprise;
  final List<String> gaps;
  Eligibility(this.verdict, this.enterprise, this.gaps);
  factory Eligibility.evaluate(Map<String, dynamic> p) {
    final c = classify(
      (p['investment'] as num).toDouble(),
      (p['turnover'] as num).toDouble(),
    );
    if (p['interested'] == false) return Eligibility('choice', c, []);
    final gaps = <String>[];
    if (p['pan'] != true) gaps.add('pan');
    if (p['bank'] != true) gaps.add('bank');
    if (p['gst'] != 'yes') gaps.add('gst');
    if (p['category'] == 'other') gaps.add('category');
    return Eligibility(gaps.isEmpty ? 'yes' : 'partial', c, gaps);
  }
}

/// Published 9 Aug 2024 policy. GST on fees and other incidentals excluded.
double transactionFee(double orderValue) {
  checkNumber(orderValue);
  return orderValue <= 1000000 ? 0 : math.min(orderValue * .003, 300000);
}

class PriceResult {
  final double cost, price, profit, competitiveMargin;
  PriceResult(this.cost, this.price, this.profit, this.competitiveMargin);
  factory PriceResult.calculate(
    double inputs,
    double overhead,
    double logistics,
    double margin,
    double benchmark,
  ) {
    for (final n in [inputs, overhead, logistics, margin, benchmark]) {
      checkNumber(n);
    }
    if (margin >= 100) throw ArgumentError('Margin must be below 100%');
    final cost = inputs + overhead + logistics;
    final price = cost / (1 - margin / 100);
    return PriceResult(
      cost,
      price,
      price - cost,
      benchmark == 0 ? 0 : (benchmark - cost) / benchmark * 100,
    );
  }
}

class RevenueResult {
  /// Gross revenue at the cautious scenario.
  final double low;

  /// Gross revenue at the optimistic scenario.
  final double high;

  /// Midpoint gross revenue: midpoint order value × midpoint order count.
  /// In the fixed-value mode this is `orderValue × (ordersLow+ordersHigh)/2`.
  final double typical;

  final double ordersLow, ordersHigh;

  /// In fixed mode, the single order value for every order.
  /// In varying mode, equals [minOrderValue] — preserved for backward
  /// compatibility with persisted `section('revenue')` maps that read
  /// this field.
  final double orderValue;

  /// Non-null only in the varying-order-value mode.
  final double? minOrderValue;
  final double? maxOrderValue;

  /// True when this result was produced by [calculateVarying].
  bool get isVaryingOrderValue => minOrderValue != null;

  // ── Optional track-record reference ──────────────────────────────
  // Stored and exposed for display; never folded into low/high/typical.
  final int? priorOrdersCount;
  final double? priorOrdersValue;

  // ── Optional seasonality metadata ────────────────────────────────
  // Carried through without affecting any calculation.
  final bool hasSeasonality;
  final List<int>? seasonalMonths;

  RevenueResult._({
    required this.low,
    required this.high,
    required this.typical,
    required this.orderValue,
    required this.ordersLow,
    required this.ordersHigh,
    this.minOrderValue,
    this.maxOrderValue,
    this.priorOrdersCount,
    this.priorOrdersValue,
    this.hasSeasonality = false,
    this.seasonalMonths,
  });

  /// Fixed order value — the original factory; positional signature is
  /// unchanged for full backward compatibility with existing call sites
  /// and persisted data.  New parameters are optional and named.
  factory RevenueResult.calculate(
    double value,
    double low,
    double high, {
    int? priorOrdersCount,
    double? priorOrdersValue,
    bool hasSeasonality = false,
    List<int>? seasonalMonths,
  }) {
    for (final n in [value, low, high]) {
      checkNumber(n);
    }
    if (priorOrdersValue != null) checkNumber(priorOrdersValue);
    if (low > high) {
      throw ArgumentError('Lower order count exceeds upper count');
    }
    if (priorOrdersCount != null && priorOrdersCount < 0) {
      throw ArgumentError('Prior orders count must be non-negative');
    }
    return RevenueResult._(
      low: value * low,
      high: value * high,
      typical: value * (low + high) / 2,
      orderValue: value,
      ordersLow: low,
      ordersHigh: high,
      priorOrdersCount: priorOrdersCount,
      priorOrdersValue: priorOrdersValue,
      hasSeasonality: hasSeasonality,
      seasonalMonths: seasonalMonths,
    );
  }

  /// Varying order value — [minOrderValue] pairs with [ordersLow] and
  /// [maxOrderValue] pairs with [ordersHigh]; [typical] uses the
  /// midpoint of both ranges.
  factory RevenueResult.calculateVarying({
    required double minOrderValue,
    required double maxOrderValue,
    required double ordersLow,
    required double ordersHigh,
    int? priorOrdersCount,
    double? priorOrdersValue,
    bool hasSeasonality = false,
    List<int>? seasonalMonths,
  }) {
    for (final n in [minOrderValue, maxOrderValue, ordersLow, ordersHigh]) {
      checkNumber(n);
    }
    if (priorOrdersValue != null) checkNumber(priorOrdersValue);
    if (ordersLow > ordersHigh) {
      throw ArgumentError('Lower order count exceeds upper count');
    }
    if (minOrderValue > maxOrderValue) {
      throw ArgumentError('Minimum order value exceeds maximum order value');
    }
    if (priorOrdersCount != null && priorOrdersCount < 0) {
      throw ArgumentError('Prior orders count must be non-negative');
    }
    return RevenueResult._(
      low: minOrderValue * ordersLow,
      high: maxOrderValue * ordersHigh,
      typical:
          (minOrderValue + maxOrderValue) / 2 * (ordersLow + ordersHigh) / 2,
      orderValue: minOrderValue,
      minOrderValue: minOrderValue,
      maxOrderValue: maxOrderValue,
      ordersLow: ordersLow,
      ordersHigh: ordersHigh,
      priorOrdersCount: priorOrdersCount,
      priorOrdersValue: priorOrdersValue,
      hasSeasonality: hasSeasonality,
      seasonalMonths: seasonalMonths,
    );
  }
}

class RoiResult {
  final double setup,
      annualRevenue,
      annualFees,
      annualContribution,
      firstYearNet,
      threeYearNet;
  final double? paybackMonths;
  RoiResult._(
    this.setup,
    this.annualRevenue,
    this.annualFees,
    this.annualContribution,
    this.firstYearNet,
    this.threeYearNet,
    this.paybackMonths,
  );
  factory RoiResult.calculate({
    required double orderValue,
    required double annualOrders,
    required double margin,
    required double cash,
    required double hours,
    required double hourlyRate,
    required double delayMonths,
    required double recurring,
  }) {
    for (final n in [
      orderValue,
      annualOrders,
      margin,
      cash,
      hours,
      hourlyRate,
      delayMonths,
      recurring,
    ]) {
      checkNumber(n);
    }
    if (margin >= 100 || delayMonths > 36) {
      throw ArgumentError('Invalid margin or delay');
    }
    final setup = cash + hours * hourlyRate;
    final revenue = orderValue * annualOrders;
    final fees = transactionFee(orderValue) * annualOrders;
    final annual = revenue * margin / 100 - fees - recurring;
    final first = annual * math.max(0, 12 - delayMonths) / 12 - setup;
    final third = annual * math.max(0, 36 - delayMonths) / 12 - setup;
    return RoiResult._(
      setup,
      revenue,
      fees,
      annual,
      first,
      third,
      annual > 0 ? delayMonths + setup / (annual / 12) : null,
    );
  }
}

class WorkingCapitalResult {
  final double orderValue, cashOnHand, cycleDays, gap;
  WorkingCapitalResult(
    this.orderValue,
    this.cashOnHand,
    this.cycleDays,
    this.gap,
  );
  factory WorkingCapitalResult.calculate(
    double orderValue,
    double productionDays,
    double delayDays,
    double cashOnHand,
  ) {
    for (final n in [orderValue, productionDays, delayDays, cashOnHand]) {
      checkNumber(n);
    }
    return WorkingCapitalResult(
      orderValue,
      cashOnHand,
      productionDays + delayDays,
      math.max(0, orderValue - cashOnHand),
    );
  }
}

class EmdResult {
  final double tenderValue, emdPercent, emdPayable;
  final bool exempt;
  EmdResult(this.tenderValue, this.emdPercent, this.emdPayable, this.exempt);
  factory EmdResult.calculate(
    double tenderValue,
    double emdPercent,
    bool udyamExempt,
  ) {
    for (final n in [tenderValue, emdPercent]) {
      checkNumber(n);
    }
    return EmdResult(
      tenderValue,
      emdPercent,
      udyamExempt ? 0 : tenderValue * emdPercent / 100,
      udyamExempt,
    );
  }
}

class UnitEconomicsResult {
  final double fixedCosts, variableCost, sellingPrice, contribution;
  final double? breakEvenUnits, breakEvenRevenue;
  UnitEconomicsResult(
    this.fixedCosts,
    this.variableCost,
    this.sellingPrice,
    this.contribution,
    this.breakEvenUnits,
    this.breakEvenRevenue,
  );
  factory UnitEconomicsResult.calculate(
    double fixedCosts,
    double variableCost,
    double sellingPrice,
  ) {
    for (final n in [fixedCosts, variableCost, sellingPrice]) {
      checkNumber(n);
    }
    final contribution = sellingPrice - variableCost;
    final units = contribution > 0 ? fixedCosts / contribution : null;
    return UnitEconomicsResult(
      fixedCosts,
      variableCost,
      sellingPrice,
      contribution,
      units,
      units == null ? null : units * sellingPrice,
    );
  }
}

class GstResult {
  final double saleValue, gstRate, gstAmount, cgst, sgst, igst, total;
  GstResult(
    this.saleValue,
    this.gstRate,
    this.gstAmount,
    this.cgst,
    this.sgst,
    this.igst,
    this.total,
  );
  factory GstResult.calculate(
    double saleValue,
    double gstRate,
    bool sameState,
  ) {
    for (final n in [saleValue, gstRate]) {
      checkNumber(n);
    }
    final gst = saleValue * gstRate / 100;
    return GstResult(
      saleValue,
      gstRate,
      gst,
      sameState ? gst / 2 : 0,
      sameState ? gst / 2 : 0,
      sameState ? 0 : gst,
      saleValue + gst,
    );
  }
}

class NetCashReceivableResult {
  final double invoiceValue,
      gstAmount,
      gstTds,
      incomeTaxTds,
      transactionFeeAmount,
      ldDeducted,
      netReceivable;
  NetCashReceivableResult(
    this.invoiceValue,
    this.gstAmount,
    this.gstTds,
    this.incomeTaxTds,
    this.transactionFeeAmount,
    this.ldDeducted,
    this.netReceivable,
  );

  /// GST-TDS under s. 51 CGST Act applies at 2% (1%+1%) once the
  /// contract's taxable value exceeds ₹2.5 lakh. Re-verify the
  /// threshold/rate before relying on this for filing.
  factory NetCashReceivableResult.calculate({
    required double invoiceValue,
    required double gstRate,
    required double incomeTaxTdsPercent,
    required double ldDeducted,
  }) {
    for (final n in [invoiceValue, gstRate, incomeTaxTdsPercent, ldDeducted]) {
      checkNumber(n);
    }
    final gstAmount = invoiceValue * gstRate / 100;
    final gstTds = invoiceValue > 250000 ? invoiceValue * 0.02 : 0.0;
    final incomeTds = invoiceValue * incomeTaxTdsPercent / 100;
    final fee = transactionFee(invoiceValue);
    final net =
        invoiceValue + gstAmount - gstTds - incomeTds - fee - ldDeducted;
    return NetCashReceivableResult(
      invoiceValue,
      gstAmount,
      gstTds,
      incomeTds,
      fee,
      ldDeducted,
      net,
    );
  }
}

class ReverseAuctionResult {
  final double landedCost, minMargin, floorPrice, l1Price;
  final bool isMse;

  /// Null when no L1 price was entered (unknown).
  final double? headroomVsL1;

  /// Null unless both an L1 price and MSE status are known.
  final bool? withinMsePreferenceBand;

  ReverseAuctionResult(
    this.landedCost,
    this.minMargin,
    this.floorPrice,
    this.l1Price,
    this.isMse,
    this.headroomVsL1,
    this.withinMsePreferenceBand,
  );

  /// Floor price uses the same cost/(1-margin) technique as
  /// [PriceResult]. MSE purchase-preference band is L1 + 15%
  /// (champions.gov.in FAQ) — re-verify against the specific tender.
  factory ReverseAuctionResult.calculate({
    required double landedCost,
    required double minMargin,
    required double l1Price,
    required bool isMse,
  }) {
    for (final n in [landedCost, minMargin, l1Price]) {
      checkNumber(n);
    }
    if (minMargin >= 100) throw ArgumentError('Margin must be below 100%');
    final floor = landedCost / (1 - minMargin / 100);
    final hasL1 = l1Price > 0;
    return ReverseAuctionResult(
      landedCost,
      minMargin,
      floor,
      l1Price,
      isMse,
      hasL1 ? floor - l1Price : null,
      hasL1 && isMse ? floor <= l1Price * 1.15 : null,
    );
  }
}

const categories = <String, List<String>>{
  'office': ['Office supplies', 'कार्यालय सामग्री'],
  'furniture': ['Furniture', 'फर्नीचर'],
  'it': ['IT equipment & services', 'आईटी उपकरण और सेवाएँ'],
  'cleaning': ['Cleaning & housekeeping', 'सफाई और हाउसकीपिंग'],
  'other': ['Other / help me find it', 'अन्य / श्रेणी ढूँढने में मदद'],
};
const steps = <List<String>>[
  [
    'Identity & bank details',
    'पहचान और बैंक विवरण',
    'Keep PAN, authorised-person details and business bank information ready. Names should match official records.',
    'PAN, अधिकृत व्यक्ति और व्यवसाय बैंक की जानकारी रखें। नाम आधिकारिक रिकॉर्ड से मेल खाने चाहिए।',
  ],
  [
    'Check GST applicability',
    'GST की आवश्यकता जाँचें',
    'Confirm your GST obligations and any applicable exemption. Do not assume every seller has the same requirement.',
    'अपनी GST आवश्यकता और छूट की पुष्टि करें। हर विक्रेता के लिए नियम समान नहीं हैं।',
  ],
  [
    'Udyam & MSE benefits',
    'उद्यम और MSE लाभ',
    'Udyam is MSME registration. Check classification and benefit eligibility; it is not a universal GeM entry requirement.',
    'उद्यम MSME पंजीकरण है। वर्गीकरण और लाभ जाँचें; यह हर GeM विक्रेता के लिए अनिवार्य नहीं है।',
  ],
  [
    'Create GeM seller account',
    'GeM विक्रेता खाता बनाएँ',
    'Use the official portal and an authorised person’s details. Never share your OTP with an agent.',
    'आधिकारिक पोर्टल और अधिकृत व्यक्ति की जानकारी इस्तेमाल करें। OTP किसी एजेंट को न दें।',
  ],
  [
    'Publish your catalogue',
    'अपनी कैटलॉग प्रकाशित करें',
    'Match the category specifications, accurate photos, delivery area and tax-inclusive offer requirements.',
    'सही श्रेणी, फोटो, डिलीवरी क्षेत्र और कर सहित मूल्य आवश्यकताओं की जाँच करें।',
  ],
  [
    'Review applicable deposits',
    'लागू जमा राशि जाँचें',
    'Check current seller assessment, deposit and bid-security requirements on the portal. Do not assume a fixed caution-money fee.',
    'पोर्टल पर वर्तमान मूल्यांकन, जमा और बोली सुरक्षा नियम जाँचें। निश्चित कॉशन मनी शुल्क न मानें।',
  ],
  [
    'Participate in a suitable bid',
    'उपयुक्त बोली में भाग लें',
    'Read buyer terms, delivery deadlines and payment conditions. Confirm you can fulfil before bidding.',
    'खरीदार की शर्तें, डिलीवरी और भुगतान नियम पढ़ें। बोली से पहले क्षमता की पुष्टि करें।',
  ],
  [
    'Fulfil your first order',
    'पहला ऑर्डर पूरा करें',
    'Track acceptance, invoices and payment. A self-reported order stays unverified until the research team checks evidence.',
    'स्वीकृति, चालान और भुगतान देखें। शोध टीम के प्रमाण जाँचने तक बताया गया ऑर्डर असत्यापित रहेगा।',
  ],
  [
    'Build your seller rating',
    'विक्रेता रेटिंग बनाएँ',
    'Deliver consistently, resolve issues and review your seller dashboard. Orders and ratings are never guaranteed.',
    'समय पर आपूर्ति करें, समस्याएँ सुलझाएँ और डैशबोर्ड देखें। ऑर्डर या रेटिंग की गारंटी नहीं है।',
  ],
];
