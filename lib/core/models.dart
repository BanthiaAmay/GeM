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
  final double low, high, orderValue, ordersLow, ordersHigh;
  RevenueResult(this.orderValue, this.ordersLow, this.ordersHigh)
    : low = orderValue * ordersLow,
      high = orderValue * ordersHigh;
  factory RevenueResult.calculate(double value, double low, double high) {
    for (final n in [value, low, high]) {
      checkNumber(n);
    }
    if (low > high) {
      throw ArgumentError('Lower order count exceeds upper count');
    }
    return RevenueResult(value, low, high);
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
