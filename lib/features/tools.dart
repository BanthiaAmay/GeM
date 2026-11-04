import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'charts.dart';
import 'components.dart';
import 'widgets.dart';

class ToolPage extends StatefulWidget {
  final AppStore store;
  final String kind;
  const ToolPage({super.key, required this.store, required this.kind});
  @override
  State<ToolPage> createState() => _ToolPageState();
}

class _ToolPageState extends State<ToolPage> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final values = <String, dynamic>{};
  Map<String, dynamic>? result;

  // Revenue-only additional state — only read/written when k == 'revenue'.
  bool _orderValueVaries = false;
  String? _hasPriorOrders; // null = unanswered, 'yes', 'no'
  bool _hasSeasonal = false;
  final _seasonalMonths = <int>{};

  AppStore get s => widget.store;
  String get k => widget.kind;
  String t(String en, String hi, {Map<String, String>? vars}) =>
      s.t(en, hi, vars: vars);
  @override
  void initState() {
    super.initState();
    final saved = s.section(k);
    values.addAll({
      'business': 'proprietor',
      'gst': 'unknown',
      'udyam': false,
      'pan': false,
      'bank': false,
      'interested': true,
      'experience': false,
      'category': s.section('eligibility')['category'] ?? 'office',
      'city': 'Pune',
      'selfClass': 'unsure',
      'udyamExempt': false,
      'sameState': true,
      'isMse': true,
      ...saved,
    });
    final revenue = s.section('revenue');
    final pricing = s.section('pricing');
    final defaults = <String, dynamic>{
      'turnover': '',
      'investment': '',
      'orderValue': revenue['orderValue'] ?? 100000,
      'ordersLow': revenue['ordersLow'] ?? 2,
      'ordersHigh': revenue['ordersHigh'] ?? 6,
      // Varying order-value mode: default to single value if no prior saved range.
      'minOrderValue':
          revenue['minOrderValue'] ?? revenue['orderValue'] ?? 100000,
      'maxOrderValue':
          revenue['maxOrderValue'] ?? revenue['orderValue'] ?? 100000,
      // Optional prior-orders fields — blank string = "not provided".
      'priorOrdersCount': revenue['priorOrdersCount'] ?? '',
      'priorOrdersValue': revenue['priorOrdersValue'] ?? '',
      'inputs': 1000,
      'overhead': 150,
      'logistics': 100,
      'margin': pricing['margin'] ?? 17.5,
      'benchmark': 0,
      'annualOrders': revenue.isEmpty
          ? 4
          : ((revenue['ordersLow'] as num) + (revenue['ordersHigh'] as num)) /
                2,
      'cash': 0,
      'hours': 8,
      'hourlyRate': 250,
      'delay': 3,
      'recurring': 0,
      // Working capital
      'wcOrderValue': revenue['orderValue'] ?? 100000,
      'productionDays': 15,
      'delayDays': 30,
      'cashOnHand': 0,
      // EMD
      'tenderValue': revenue['orderValue'] ?? 100000,
      'emdPercent': 2,
      // Unit economics
      'fixedCosts': 20000,
      'variableCost': 500,
      'sellingPrice': pricing['price'] ?? 1000,
      // GST
      'saleValue': 100000,
      'gstRate': 18,
      // Net cash receivable
      'invoiceValue': revenue['orderValue'] ?? 100000,
      'incomeTaxTdsPercent': 0,
      'ldDeducted': 0,
      // Reverse auction walk-away price
      'landedCost': pricing['cost'] ?? 1000,
      'minMargin': pricing['margin'] ?? 17.5,
      'l1Price': 0,
    };
    for (final e in defaults.entries) {
      fields[e.key] = TextEditingController(text: '${saved[e.key] ?? e.value}');
    }
    if (k == 'revenue') {
      _orderValueVaries = saved['orderValueVaries'] == true;
      _hasPriorOrders = saved['hasPriorOrders'] as String?;
      _hasSeasonal = saved['hasSeasonal'] == true;
      final months = saved['seasonalMonths'];
      if (months is List) _seasonalMonths.addAll(months.cast<int>());
    }
    if (saved.isNotEmpty) result = saved;
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double n(String key) => double.parse(fields[key]!.text.trim());
  Widget number(
    String key,
    String en,
    String hi, {
    String? helper,
    double? max,
    bool integer = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: fields[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: t(en, hi),
        helperText: helper,
        helperMaxLines: 3,
      ),
      validator: (v) {
        final x = double.tryParse(v?.trim() ?? '');
        if (x == null || !x.isFinite || x < 0 || x > 1e12) {
          return t(
            'Enter a valid non-negative number',
            'शून्य या उससे अधिक सही संख्या दें',
          );
        }
        if (max != null && x > max) {
          return t(
            'Maximum is {max}',
            'अधिकतम {max} है',
            vars: {'max': '$max'},
          );
        }
        if (integer && x != x.roundToDouble()) {
          return t('Use whole orders', 'पूरे ऑर्डर की संख्या दें');
        }
        return null;
      },
      onChanged: (_) {
        if (result != null) setState(() => result = null);
      },
    ),
  );
  Widget dropdown(
    String key,
    String en,
    String hi,
    Map<String, List<String>> options,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: DropdownButtonFormField<String>(
      initialValue: values[key] as String,
      decoration: InputDecoration(labelText: t(en, hi)),
      isExpanded: true,
      items: options.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(
                t(e.value[0], e.value[1]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() {
        values[key] = v;
        result = null;
      }),
    ),
  );
  Widget toggle(String key, String en, String hi, {String? help}) =>
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: values[key] == true,
        title: Text(t(en, hi)),
        subtitle: help == null ? null : Text(help),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (v) => setState(() {
          values[key] = v;
          result = null;
        }),
      );

  /// A number field that accepts blank — blank is treated as "not provided"
  /// (returns null from [nOpt]).  Use only for optional inputs.
  Widget optionalNumber(String key, String en, String hi) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: fields[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: t(en, hi)),
      validator: (v) {
        final raw = v?.trim() ?? '';
        if (raw.isEmpty) return null;
        final x = double.tryParse(raw);
        if (x == null || !x.isFinite || x < 0 || x > 1e12) {
          return t(
            'Enter a valid number, or leave blank',
            'मान्य संख्या दें या खाली छोड़ें',
          );
        }
        return null;
      },
      onChanged: (_) {
        if (result != null) setState(() => result = null);
      },
    ),
  );

  /// Returns null when the optional field is blank; otherwise parses as double.
  double? nOpt(String key) {
    final raw = fields[key]?.text.trim() ?? '';
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  /// Month-picker chip row for the seasonality section.
  Widget _monthPickerRow() {
    const months = [
      (1, 'Jan', 'जन'),
      (2, 'Feb', 'फर'),
      (3, 'Mar', 'मार्च'),
      (4, 'Apr', 'अप्र'),
      (5, 'May', 'मई'),
      (6, 'Jun', 'जून'),
      (7, 'Jul', 'जुल'),
      (8, 'Aug', 'अग'),
      (9, 'Sep', 'सित'),
      (10, 'Oct', 'अक्ट'),
      (11, 'Nov', 'नव'),
      (12, 'Dec', 'दिस'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final m in months)
          FilterChip(
            label: Text(t(m.$2, m.$3)),
            selected: _seasonalMonths.contains(m.$1),
            onSelected: (v) => setState(() {
              v ? _seasonalMonths.add(m.$1) : _seasonalMonths.remove(m.$1);
              result = null;
            }),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final descriptions = {
      'eligibility': [
        t('01 / KNOW YOUR STARTING POINT', '01 / अपनी स्थिति जानें'),
        t(
          'Can your business sell on GeM?',
          'क्या आपका व्यवसाय GeM पर बेच सकता है?',
        ),
        t(
          'A few details. A clearer classification. A practical next step.',
          'कुछ जानकारी। स्पष्ट वर्गीकरण। अगला ठोस कदम।',
        ),
      ],
      'revenue': [
        t('02 / EXPLORE THE OPPORTUNITY', '02 / अवसर समझें'),
        t(
          'What could the opportunity look like?',
          'आपके लिए कितना अवसर हो सकता है?',
        ),
        t(
          'Build a revenue scenario around orders you could realistically fulfil.',
          'जिन ऑर्डर को आप पूरा कर सकते हैं, उनसे आय का परिदृश्य बनाएँ।',
        ),
      ],
      'pricing': [
        t('03 / PROTECT YOUR MARGIN', '03 / अपना मार्जिन बचाएँ'),
        t('Price with confidence.', 'भरोसे के साथ मूल्य तय करें।'),
        t(
          'Know your costs before you commit to a government order.',
          'सरकारी ऑर्डर लेने से पहले अपनी लागत जानें।',
        ),
      ],
      'roi': [
        t('04 / MAKE AN INFORMED DECISION', '04 / सोच-समझकर निर्णय लें'),
        t('Is the effort worth it?', 'क्या यह प्रयास लाभदायक है?'),
        t(
          'See the cost of your time, your contribution and the path to payback.',
          'अपने समय की लागत, योगदान और लागत वसूली की अवधि देखें।',
        ),
      ],
      'workingCapital': [
        t('05 / PLAN YOUR CASH', '05 / नकद योजना बनाएँ'),
        t(
          'Will you have enough cash to execute?',
          'क्या आपके पास पूरा करने के लिए पर्याप्त नकद होगा?',
        ),
        t(
          'See the gap between what the order needs and what you already have.',
          'ऑर्डर की आवश्यकता और आपके पास उपलब्ध नकद के बीच का अंतर देखें।',
        ),
      ],
      'emd': [
        t('06 / BEFORE YOU BID', '06 / बोली से पहले'),
        t(
          'What deposit does this bid need?',
          'इस बोली के लिए कितनी जमा राशि चाहिए?',
        ),
        t(
          'Check the Earnest Money Deposit payable, and whether Udyam registration exempts you.',
          'देय अर्नेस्ट मनी जमा जाँचें, और क्या उद्यम पंजीकरण आपको छूट देता है।',
        ),
      ],
      'unitEconomics': [
        t('07 / KNOW YOUR BREAK-EVEN', '07 / अपनी लागत वसूली जानें'),
        t(
          'How many units before you break even?',
          'लागत वसूली के लिए कितनी इकाइयाँ चाहिए?',
        ),
        t(
          'Find the minimum order size that covers your fixed costs.',
          'अपनी स्थिर लागत कवर करने वाला न्यूनतम ऑर्डर आकार जानें।',
        ),
      ],
      'gstCalc': [
        t('08 / QUICK GST CHECK', '08 / त्वरित GST जाँच'),
        t(
          'What GST applies to this sale?',
          'इस बिक्री पर कौन सा GST लागू होता है?',
        ),
        t(
          'A fast CGST/SGST or IGST breakup while you quote.',
          'बोली देते समय तुरंत CGST/SGST या IGST विभाजन।',
        ),
      ],
      'netCash': [
        t('09 / GETTING PAID', '09 / भुगतान प्राप्ति'),
        t(
          'What actually lands in your bank?',
          'वास्तव में आपके बैंक में कितना आता है?',
        ),
        t(
          'See the invoice value after GST-TDS, income-tax TDS, GeM fees and any penalty.',
          'GST-TDS, आयकर TDS, GeM शुल्क और किसी भी जुर्माने के बाद चालान मूल्य देखें।',
        ),
      ],
      'raWalkaway': [
        t('10 / BEFORE THE AUCTION', '10 / नीलामी से पहले'),
        t('What is your walk-away price?', 'आपका वॉक-अवे मूल्य क्या है?'),
        t(
          'Fix the lowest price you can safely bid before a reverse auction starts.',
          'रिवर्स ऑक्शन शुरू होने से पहले वह न्यूनतम मूल्य तय करें जिस पर आप सुरक्षित रूप से बोली लगा सकते हैं।',
        ),
      ],
    }[k]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(descriptions[0], descriptions[1], descriptions[2]),
        ResponsiveRow(
          children: [
            Panel(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Your business details', 'आपके व्यवसाय की जानकारी'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t(
                        'Your progress is saved on this device after calculating.',
                        'गणना के बाद आपकी प्रगति इस डिवाइस पर सहेजी जाएगी।',
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...inputFields(),
                    AppButton(
                      onPressed: calculate,
                      trailingIcon: Icons.arrow_forward,
                      label: t(
                        k == 'eligibility'
                            ? 'Check my eligibility'
                            : 'Calculate my result',
                        k == 'eligibility'
                            ? 'मेरी पात्रता जाँचें'
                            : 'मेरा परिणाम निकालें',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Panel(
                  tone: AppCardTone.muted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.brand,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t(
                          'A little clarity goes a long way',
                          'थोड़ी स्पष्टता, बड़ा बदलाव',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(contextNote()),
                      const SizedBox(height: 16),
                      Tag(t('No login needed', 'लॉगिन ज़रूरी नहीं')),
                      TextButton(
                        onPressed: () => go(context, s, 'learn'),
                        child: Text(
                          t(
                            'New to GeM? Start with the basics →',
                            'GeM नया है? मूल बातें जानें →',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (k == 'revenue') benchmarkPanel(),
                if (k == 'pricing')
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('What does L1 mean?', 'L1 क्या है?'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t(
                            'L1 is the lowest evaluated eligible offer. Eligible MSEs within L1 + 15% may get purchase preference by matching L1, subject to the tender and policy. It is not an automatic award.',
                            'L1 सबसे कम मूल्य वाली पात्र बोली है। L1 + 15% के भीतर पात्र MSE को L1 मूल्य मिलाने पर शर्तों के अनुसार वरीयता मिल सकती है। ऑर्डर स्वतः नहीं मिलता।',
                          ),
                        ),
                        SourceNote(
                          s,
                          t(
                            'MSME CHAMPIONS · reviewed 9 Sep 2026',
                            'MSME CHAMPIONS · जाँच 9 सितम्बर 2026',
                          ),
                          policySource,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (result != null) ...[
          const SizedBox(height: 28),
          FadeSlideIn(child: resultPanel()),
        ],
      ],
    );
  }

  List<Widget> inputFields() => switch (k) {
    'eligibility' => [
      dropdown('business', 'Business type', 'व्यवसाय का प्रकार', {
        'proprietor': ['Sole proprietor', 'एकल स्वामित्व'],
        'partnership': ['Partnership / LLP', 'साझेदारी / LLP'],
        'company': ['Company', 'कंपनी'],
        'other': ['Other organisation', 'अन्य संगठन'],
      }),
      dropdown('category', 'Product or service', 'उत्पाद या सेवा', categories),
      dropdown(
        'selfClass',
        'Your current MSME classification',
        'आपका वर्तमान MSME वर्गीकरण',
        {
          'unsure': ['Not sure', 'पता नहीं'],
          'micro': ['Micro', 'सूक्ष्म'],
          'small': ['Small', 'लघु'],
          'medium': ['Medium', 'मध्यम'],
          'other': ['Outside MSME', 'MSME से बाहर'],
        },
      ),
      number(
        'turnover',
        'Annual turnover (₹ lakh)',
        'वार्षिक कारोबार (₹ लाख)',
        helper: t(
          '₹100 lakh = ₹1 crore. Use your latest financial-year figures.',
          '₹100 लाख = ₹1 करोड़। नवीनतम वित्त-वर्ष के आँकड़े दें।',
        ),
      ),
      number(
        'investment',
        'Plant / equipment investment (₹ lakh)',
        'संयंत्र / उपकरण निवेश (₹ लाख)',
      ),
      dropdown('gst', 'GST status', 'GST स्थिति', {
        'yes': ['Registered', 'पंजीकृत'],
        'no': ['Not registered', 'पंजीकृत नहीं'],
        'exempt': ['I believe I am exempt', 'मुझे लगता है छूट है'],
        'unknown': ['Not sure', 'पता नहीं'],
      }),
      toggle(
        'pan',
        'I have the relevant PAN / identity details',
        'मेरे पास संबंधित PAN / पहचान विवरण है',
      ),
      toggle(
        'bank',
        'I have a business bank account',
        'मेरे पास व्यवसाय का बैंक खाता है',
      ),
      toggle(
        'udyam',
        'I have Udyam registration',
        'मेरे पास उद्यम पंजीकरण है',
        help: t(
          'Udyam identifies MSMEs; it is used to claim applicable MSE benefits.',
          'उद्यम MSME की पहचान है; लागू MSE लाभों के लिए उपयोग होता है।',
        ),
      ),
      toggle(
        'experience',
        'I have supplied to government before',
        'मैं पहले सरकार को आपूर्ति कर चुका/चुकी हूँ',
      ),
      toggle(
        'interested',
        'I want to explore government sales',
        'मैं सरकारी बिक्री के अवसर देखना चाहता/चाहती हूँ',
      ),
    ],
    'revenue' => [
      dropdown('category', 'Business category', 'व्यवसाय श्रेणी', categories),
      dropdown('city', 'Location', 'स्थान', {
        'Pune': ['Pune', 'पुणे'],
        'Mumbai': ['Mumbai', 'मुंबई'],
        'Nagpur': ['Nagpur', 'नागपुर'],
        'Maharashtra': ['Other Maharashtra', 'अन्य महाराष्ट्र'],
      }),
      Text(
        t(
          'These starting values are editable examples, not category averages. Include zero orders in your downside planning.',
          'शुरुआती मान बदलने योग्य उदाहरण हैं, श्रेणी के औसत नहीं। जोखिम आकलन में शून्य ऑर्डर भी रखें।',
        ),
      ),
      const SizedBox(height: 16),
      // ── Order value mode ──────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              label: Text(
                t('Same value every order', 'प्रति ऑर्डर समान मूल्य'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ButtonSegment(
              value: true,
              label: Text(
                t('Varies by order', 'ऑर्डर के अनुसार बदलता है'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          selected: {_orderValueVaries},
          onSelectionChanged: (selection) => setState(() {
            _orderValueVaries = selection.first;
            result = null;
          }),
        ),
      ),
      if (!_orderValueVaries)
        number(
          'orderValue',
          'Expected value per order (₹)',
          'प्रति ऑर्डर अपेक्षित मूल्य (₹)',
        ),
      if (_orderValueVaries) ...[
        number(
          'minOrderValue',
          'Minimum order value (₹)',
          'न्यूनतम ऑर्डर मूल्य (₹)',
        ),
        number(
          'maxOrderValue',
          'Maximum order value (₹)',
          'अधिकतम ऑर्डर मूल्य (₹)',
        ),
      ],
      number(
        'ordersLow',
        'Orders per year · cautious case',
        'प्रति वर्ष ऑर्डर · सावधान अनुमान',
        integer: true,
      ),
      number(
        'ordersHigh',
        'Orders per year · optimistic case',
        'प्रति वर्ष ऑर्डर · आशावादी अनुमान',
        integer: true,
      ),
      // ── Prior orders (optional) ───────────────────────────────────────
      const SizedBox(height: 8),
      Text(
        t(
          'Have you already won GeM orders this year?',
          'क्या आपने इस वर्ष GeM ऑर्डर जीते हैं?',
        ),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final opt in [('yes', 'Yes', 'हाँ'), ('no', 'No', 'नहीं')])
            ChoiceChip(
              label: Text(t(opt.$2, opt.$3)),
              selected: _hasPriorOrders == opt.$1,
              onSelected: (_) => setState(() {
                _hasPriorOrders = _hasPriorOrders == opt.$1 ? null : opt.$1;
                result = null;
              }),
            ),
        ],
      ),
      if (_hasPriorOrders == 'yes') ...[
        const SizedBox(height: 10),
        Text(
          t(
            'Ballpark is fine — this stays on your device only.',
            'अनुमान काफी है — यह केवल आपके डिवाइस पर है।',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        optionalNumber(
          'priorOrdersCount',
          'Orders already won (optional)',
          'जीते हुए ऑर्डर (वैकल्पिक)',
        ),
        optionalNumber(
          'priorOrdersValue',
          'Total value of prior orders (optional)',
          'पहले के ऑर्डर का कुल मूल्य (वैकल्पिक)',
        ),
      ],
      // ── Seasonality (optional) ────────────────────────────────────────
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _hasSeasonal,
        title: Text(
          t('Is this a seasonal business?', 'क्या यह मौसमी व्यवसाय है?'),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (v) => setState(() {
          _hasSeasonal = v ?? false;
          if (!_hasSeasonal) _seasonalMonths.clear();
          result = null;
        }),
      ),
      if (_hasSeasonal) ...[
        Text(
          t('Peak months (optional)', 'व्यस्त महीने (वैकल्पिक)'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        _monthPickerRow(),
        const SizedBox(height: 8),
      ],
    ],
    'pricing' => [
      number(
        'inputs',
        'Input / purchase cost per unit (₹)',
        'प्रति इकाई खरीद / इनपुट लागत (₹)',
      ),
      number(
        'overhead',
        'Allocated overhead per unit (₹)',
        'प्रति इकाई अन्य व्यवसाय लागत (₹)',
      ),
      number(
        'logistics',
        'Delivery & other costs per unit (₹)',
        'प्रति इकाई डिलीवरी और अन्य लागत (₹)',
      ),
      number(
        'margin',
        'Desired gross margin (%)',
        'वांछित सकल मार्जिन (%)',
        max: 99.9,
        helper: t(
          'Margin = profit ÷ selling price. This is not markup on cost.',
          'मार्जिन = लाभ ÷ बिक्री मूल्य। यह लागत पर मार्कअप नहीं है।',
        ),
      ),
      number(
        'benchmark',
        'Comparable quoted price (₹, optional; 0 to skip)',
        'तुलनीय बोली मूल्य (₹, वैकल्पिक; छोड़ने के लिए 0)',
        helper: t(
          'Enter a comparable price from a live listing. Use the same unit, specification and tax basis.',
          'लाइव सूची से समान इकाई, विनिर्देश और कर आधार वाला मूल्य दें।',
        ),
      ),
    ],
    'workingCapital' => [
      number('wcOrderValue', 'Order value (₹)', 'ऑर्डर मूल्य (₹)'),
      number(
        'productionDays',
        'Production / delivery cycle (days)',
        'उत्पादन / डिलीवरी चक्र (दिन)',
        integer: true,
      ),
      number(
        'delayDays',
        'Expected payment delay (days)',
        'अनुमानित भुगतान विलंब (दिन)',
        integer: true,
      ),
      number(
        'cashOnHand',
        'Cash currently on hand (₹)',
        'वर्तमान उपलब्ध नकद (₹)',
      ),
    ],
    'emd' => [
      number(
        'tenderValue',
        'Tender / bid value (₹)',
        'निविदा / बोली मूल्य (₹)',
      ),
      number(
        'emdPercent',
        'EMD % specified in the tender',
        'निविदा में निर्दिष्ट EMD %',
        max: 100,
      ),
      toggle(
        'udyamExempt',
        'I am Udyam-registered (MSE EMD exemption may apply)',
        'मैं उद्यम-पंजीकृत हूँ (MSE को EMD छूट मिल सकती है)',
      ),
    ],
    'unitEconomics' => [
      number('fixedCosts', 'Fixed costs (₹)', 'स्थिर लागत (₹)'),
      number(
        'variableCost',
        'Variable cost per unit (₹)',
        'प्रति इकाई परिवर्तनीय लागत (₹)',
      ),
      number(
        'sellingPrice',
        'Selling price per unit (₹)',
        'प्रति इकाई बिक्री मूल्य (₹)',
      ),
    ],
    'gstCalc' => [
      number('saleValue', 'Sale value (₹)', 'बिक्री मूल्य (₹)'),
      number('gstRate', 'GST rate (%)', 'GST दर (%)', max: 28),
      toggle(
        'sameState',
        'Buyer is in the same state as me (CGST+SGST, else IGST)',
        'खरीदार मेरे राज्य में है (CGST+SGST, अन्यथा IGST)',
      ),
    ],
    'netCash' => [
      number('invoiceValue', 'Invoice value (₹)', 'चालान मूल्य (₹)'),
      number('gstRate', 'GST rate (%)', 'GST दर (%)', max: 28),
      number(
        'incomeTaxTdsPercent',
        'Income-tax TDS, if applicable (%)',
        'आयकर TDS, यदि लागू हो (%)',
        max: 10,
        helper: t(
          'Leave at 0 if your buyer does not deduct income-tax TDS on this order.',
          'यदि खरीदार इस ऑर्डर पर आयकर TDS नहीं काटता तो 0 ही रहने दें।',
        ),
      ),
      number(
        'ldDeducted',
        'Liquidated-damages / penalty deducted, if any (₹)',
        'कोई भी LD / जुर्माना कटौती, यदि हो (₹)',
      ),
    ],
    'raWalkaway' => [
      number(
        'landedCost',
        'Landed cost per unit (₹)',
        'प्रति इकाई लैंडेड लागत (₹)',
      ),
      number(
        'minMargin',
        'Minimum acceptable margin (%)',
        'न्यूनतम स्वीकार्य मार्जिन (%)',
        max: 99.9,
      ),
      number(
        'l1Price',
        'Current L1 price per unit (₹, optional; 0 if unknown)',
        'वर्तमान L1 मूल्य प्रति इकाई (₹, वैकल्पिक; अज्ञात हो तो 0)',
      ),
      toggle(
        'isMse',
        'I am an eligible Micro/Small Enterprise (MSE)',
        'मैं एक पात्र सूक्ष्म/लघु उद्यम (MSE) हूँ',
      ),
    ],
    _ => [
      if (s.completed.contains('revenue'))
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Tag(
            t(
              'Pre-filled from your revenue scenario',
              'आपके आय परिदृश्य से भरा गया',
            ),
          ),
        ),
      number(
        'orderValue',
        'Typical order value (₹)',
        'सामान्य ऑर्डर मूल्य (₹)',
      ),
      number(
        'annualOrders',
        'Orders per full selling year',
        'पूर्ण बिक्री वर्ष में ऑर्डर',
      ),
      number(
        'margin',
        'Contribution margin before GeM fees (%)',
        'GeM शुल्क से पहले योगदान मार्जिन (%)',
        max: 99.9,
      ),
      number(
        'cash',
        'One-time cash outlay (₹)',
        'एकमुश्त नकद खर्च (₹)',
        helper: t(
          'Your estimate for preparation and assistance, not an official registration charge.',
          'तैयारी और सहायता का आपका अनुमान; आधिकारिक पंजीकरण शुल्क नहीं।',
        ),
      ),
      number('hours', 'Preparation effort (hours)', 'तैयारी का प्रयास (घंटे)'),
      number(
        'hourlyRate',
        'Value of your time (₹ / hour)',
        'आपके समय का मूल्य (₹ / घंटा)',
      ),
      number(
        'delay',
        'Assumed delay before sales (months)',
        'बिक्री शुरू होने की अनुमानित देरी (महीने)',
        max: 36,
      ),
      number(
        'recurring',
        'Additional annual operating cost (₹)',
        'अतिरिक्त वार्षिक संचालन लागत (₹)',
        helper: t(
          'Exclude costs already included in your margin.',
          'मार्जिन में शामिल लागत दोबारा न जोड़ें।',
        ),
      ),
    ],
  };
  String contextNote() => switch (k) {
    'eligibility' => t(
      'MSME classification uses both investment and turnover. Under the thresholds effective 1 April 2025, a micro enterprise can have turnover up to ₹10 crore and investment up to ₹2.5 crore. Your self-label does not decide eligibility.',
      'MSME वर्गीकरण निवेश और कारोबार दोनों पर आधारित है। 1 अप्रैल 2025 से सूक्ष्म उद्यम की कारोबार सीमा ₹10 करोड़ और निवेश सीमा ₹2.5 करोड़ है। आपकी धारणा पात्रता तय नहीं करती।',
    ),
    'revenue' => t(
      'Tender values are buyer demand, not seller earnings. Competition, capacity and delivery area affect your chances. We never infer your likely revenue from national GMV (total value traded).',
      'निविदा मूल्य खरीदार की माँग है, विक्रेता की कमाई नहीं। प्रतिस्पर्धा, क्षमता और डिलीवरी क्षेत्र अवसर प्रभावित करते हैं। राष्ट्रीय GMV (कुल कारोबार मूल्य) से आपकी आय नहीं निकाली जाती।',
    ),
    'pricing' => t(
      'The 17.5% starting margin is the median reported in the project brief’s 20-owner survey. It is an interview benchmark, not a GeM market price. Check taxes, financing and order-level fees separately.',
      '17.5% शुरुआती मार्जिन परियोजना विवरण के 20 मालिकों के सर्वेक्षण का माध्यिका है। यह साक्षात्कार का आँकड़ा है, GeM का बाजार मूल्य नहीं। कर, वित्तपोषण और ऑर्डर शुल्क अलग जाँचें।',
    ),
    'workingCapital' => t(
      'This is a simple planning estimate — it does not account for financing cost, interest, or partial payments during the cycle.',
      'यह एक सरल योजना अनुमान है — इसमें वित्तपोषण लागत, ब्याज या चक्र के दौरान आंशिक भुगतान शामिल नहीं हैं।',
    ),
    'emd' => t(
      'EMD rules vary by tender and buyer. Udyam-registered MSEs are commonly exempt, but always verify the specific bid document before assuming exemption.',
      'EMD नियम निविदा और खरीदार अनुसार भिन्न होते हैं। उद्यम-पंजीकृत MSE सामान्यतः मुक्त होते हैं, लेकिन छूट मानने से पहले विशिष्ट बोली दस्तावेज़ अवश्य जाँचें।',
    ),
    'unitEconomics' => t(
      'Break-even assumes a constant selling price and variable cost per unit. It excludes taxes, GeM fees, and payment delay.',
      'लागत वसूली प्रति इकाई स्थिर बिक्री मूल्य और परिवर्तनीय लागत मानती है। इसमें कर, GeM शुल्क और भुगतान विलंब शामिल नहीं हैं।',
    ),
    'gstCalc' => t(
      'A quick on-the-spot GST check while quoting. It does not replace invoice-level GST filing or your CA’s review.',
      'बोली लगाते समय त्वरित GST जाँच। यह चालान-स्तर GST फाइलिंग या आपके CA की समीक्षा का विकल्प नहीं है।',
    ),
    'netCash' => t(
      'GST-TDS applies at 2% once the contract value crosses ₹2.5 lakh — this is a planning estimate, not a substitute for your GSTR-7/26Q filings. Re-verify current thresholds and rates.',
      'अनुबंध मूल्य ₹2.5 लाख पार करने पर GST-TDS 2% पर लागू होता है — यह एक योजना अनुमान है, आपकी GSTR-7/26Q फाइलिंग का विकल्प नहीं। वर्तमान सीमा और दर पुनः जाँचें।',
    ),
    'raWalkaway' => t(
      'This is your own floor, not a bid recommendation. The MSE L1+15% preference is subject to the specific tender and policy — it is not an automatic award.',
      'यह आपकी अपनी सीमा है, बोली की सलाह नहीं। MSE L1+15% वरीयता संबंधित निविदा और नीति पर निर्भर है — यह स्वतः पुरस्कार नहीं है।',
    ),
    _ => t(
      'All time estimates are your assumptions until validated through Pune SME journeys. Payback uses contribution after GeM fees, not gross revenue. Working capital, taxes and payment delays can change the outcome.',
      'पुणे SME अनुभवों से सत्यापन तक समय अनुमान आपकी धारणाएँ हैं। लागत वसूली GeM शुल्क के बाद योगदान पर है, सकल आय पर नहीं। कार्यशील पूँजी, कर और भुगतान देरी परिणाम बदल सकते हैं।',
    ),
  };
  Widget benchmarkPanel() {
    final rows = s.benchmarks
        .where(
          (r) =>
              r['category'] == values['category'] &&
              r['city'] == values['city'],
        )
        .toList();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Procurement evidence', 'खरीद के प्रमाण'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              t(
                'No verified sample has been published for this category and city. Average order value, active buyer count and procurement frequency are unavailable. Your calculator still works as a planning scenario.',
                'इस श्रेणी और शहर का सत्यापित नमूना प्रकाशित नहीं है। औसत ऑर्डर मूल्य, सक्रिय खरीदार संख्या और खरीद आवृत्ति उपलब्ध नहीं हैं। कैलकुलेटर योजना परिदृश्य के रूप में काम करता है।',
              ),
            )
          else
            for (final r in rows) ...[
              Text(
                '${r['metric']}: ${r['value_low']} – ${r['value_high']} ${r['unit']}',
              ),
              SourceNote(
                s,
                '${r['source_title']} · ${r['as_of']} · n=${r['sample_size']}',
                r['source_url'] as String,
              ),
              Text('${r['methodology']}'),
            ],
        ],
      ),
    );
  }

  /// Compact label/value list shared by the simpler calculators
  /// (working capital, EMD, unit economics, GST) so each one's result
  /// panel is a short list of rows instead of a bespoke widget tree.
  Widget _simpleRows(List<(String, String)> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            children: [
              Text('${row.$1}: '),
              Text(row.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
    ],
  );

  void calculate() {
    if (!form.currentState!.validate()) return;
    if (k == 'revenue' && n('ordersLow') > n('ordersHigh')) {
      message(
        context,
        t(
          'The cautious count must not exceed the optimistic count.',
          'सावधान अनुमान आशावादी अनुमान से अधिक नहीं होना चाहिए।',
        ),
      );
      return;
    }
    if (k == 'revenue' &&
        _orderValueVaries &&
        n('minOrderValue') > n('maxOrderValue')) {
      message(
        context,
        t(
          'Minimum order value must not exceed maximum.',
          'न्यूनतम ऑर्डर मूल्य अधिकतम से अधिक नहीं होना चाहिए।',
        ),
      );
      return;
    }
    // Soft warnings only — neither blocks the calculation.
    if (k == 'revenue') {
      final zeroValue = _orderValueVaries
          ? (n('minOrderValue') == 0 && n('maxOrderValue') == 0)
          : n('orderValue') == 0;
      if (zeroValue) {
        message(
          context,
          t(
            'Order value is zero — double-check if this is a data-entry slip.',
            'ऑर्डर मूल्य शून्य है — जाँचें कि यह प्रविष्टि त्रुटि तो नहीं।',
          ),
        );
        // Zero revenue is a valid planning scenario; calculation continues.
      }
      // ₹5 crore per order is ~5× the highest value in sample bid data.
      // Warn in case the user entered an annual total instead of a per-order amount.
      const largeOrderThreshold = 5e7;
      final checkValue = _orderValueVaries
          ? n('maxOrderValue')
          : n('orderValue');
      if (checkValue > largeOrderThreshold) {
        message(
          context,
          t(
            'Order value looks unusually large — verify this is a single-order amount, not an annual total.',
            'ऑर्डर मूल्य असामान्य रूप से अधिक लग रहा है — जाँचें कि यह एकल ऑर्डर की राशि है, वार्षिक कुल नहीं।',
          ),
        );
        // Calculation continues: high-value contracts are a valid scenario.
      }
    }
    final out = <String, dynamic>{};
    if (k == 'eligibility') {
      out.addAll(values);
      out.addAll({'turnover': n('turnover'), 'investment': n('investment')});
    }
    if (k == 'revenue') {
      final priorCount = _hasPriorOrders == 'yes'
          ? nOpt('priorOrdersCount')?.round()
          : null;
      final priorValue = _hasPriorOrders == 'yes'
          ? nOpt('priorOrdersValue')
          : null;
      final months = _hasSeasonal && _seasonalMonths.isNotEmpty
          ? (_seasonalMonths.toList()..sort())
          : null;
      final RevenueResult r;
      if (_orderValueVaries) {
        r = RevenueResult.calculateVarying(
          minOrderValue: n('minOrderValue'),
          maxOrderValue: n('maxOrderValue'),
          ordersLow: n('ordersLow'),
          ordersHigh: n('ordersHigh'),
          priorOrdersCount: priorCount,
          priorOrdersValue: priorValue,
          hasSeasonality: _hasSeasonal,
          seasonalMonths: months,
        );
      } else {
        r = RevenueResult.calculate(
          n('orderValue'),
          n('ordersLow'),
          n('ordersHigh'),
          priorOrdersCount: priorCount,
          priorOrdersValue: priorValue,
          hasSeasonality: _hasSeasonal,
          seasonalMonths: months,
        );
      }
      out.addAll({
        'category': values['category'],
        'city': values['city'],
        'orderValueVaries': _orderValueVaries,
        'orderValue': r.orderValue,
        if (_orderValueVaries) 'minOrderValue': r.minOrderValue,
        if (_orderValueVaries) 'maxOrderValue': r.maxOrderValue,
        'ordersLow': r.ordersLow,
        'ordersHigh': r.ordersHigh,
        'low': r.low,
        'high': r.high,
        'typical': r.typical,
        'hasPriorOrders': _hasPriorOrders,
        if (r.priorOrdersCount != null) 'priorOrdersCount': r.priorOrdersCount,
        if (r.priorOrdersValue != null) 'priorOrdersValue': r.priorOrdersValue,
        'hasSeasonal': _hasSeasonal,
        'source': 'user_assumptions',
      });
      if (months != null) out['seasonalMonths'] = months;
    }
    if (k == 'pricing') {
      final r = PriceResult.calculate(
        n('inputs'),
        n('overhead'),
        n('logistics'),
        n('margin'),
        n('benchmark'),
      );
      out.addAll({
        for (final key in [
          'inputs',
          'overhead',
          'logistics',
          'margin',
          'benchmark',
        ])
          key: n(key),
        'cost': r.cost,
        'price': r.price,
        'profit': r.profit,
        'competitiveMargin': r.competitiveMargin,
      });
    }
    if (k == 'roi') {
      final r = RoiResult.calculate(
        orderValue: n('orderValue'),
        annualOrders: n('annualOrders'),
        margin: n('margin'),
        cash: n('cash'),
        hours: n('hours'),
        hourlyRate: n('hourlyRate'),
        delayMonths: n('delay'),
        recurring: n('recurring'),
      );
      out.addAll({
        for (final key in [
          'orderValue',
          'annualOrders',
          'margin',
          'cash',
          'hours',
          'hourlyRate',
          'delay',
          'recurring',
        ])
          key: n(key),
        'setup': r.setup,
        'annualRevenue': r.annualRevenue,
        'annualFees': r.annualFees,
        'annualContribution': r.annualContribution,
        'firstYear': r.firstYearNet,
        'threeYear': r.threeYearNet,
        'payback': r.paybackMonths,
      });
    }
    if (k == 'workingCapital') {
      final r = WorkingCapitalResult.calculate(
        n('wcOrderValue'),
        n('productionDays'),
        n('delayDays'),
        n('cashOnHand'),
      );
      out.addAll({
        'orderValue': r.orderValue,
        'cashOnHand': r.cashOnHand,
        'cycleDays': r.cycleDays,
        'gap': r.gap,
      });
    }
    if (k == 'emd') {
      final r = EmdResult.calculate(
        n('tenderValue'),
        n('emdPercent'),
        values['udyamExempt'] == true,
      );
      out.addAll({
        'tenderValue': r.tenderValue,
        'emdPercent': r.emdPercent,
        'udyamExempt': values['udyamExempt'] == true,
        'emdPayable': r.emdPayable,
        'exempt': r.exempt,
      });
    }
    if (k == 'unitEconomics') {
      final r = UnitEconomicsResult.calculate(
        n('fixedCosts'),
        n('variableCost'),
        n('sellingPrice'),
      );
      out.addAll({
        'contribution': r.contribution,
        'breakEvenUnits': r.breakEvenUnits,
        'breakEvenRevenue': r.breakEvenRevenue,
      });
    }
    if (k == 'gstCalc') {
      final r = GstResult.calculate(
        n('saleValue'),
        n('gstRate'),
        values['sameState'] == true,
      );
      out.addAll({
        'saleValue': r.saleValue,
        'sameState': values['sameState'] == true,
        'gstAmount': r.gstAmount,
        'cgst': r.cgst,
        'sgst': r.sgst,
        'igst': r.igst,
        'total': r.total,
      });
    }
    if (k == 'netCash') {
      final r = NetCashReceivableResult.calculate(
        invoiceValue: n('invoiceValue'),
        gstRate: n('gstRate'),
        incomeTaxTdsPercent: n('incomeTaxTdsPercent'),
        ldDeducted: n('ldDeducted'),
      );
      out.addAll({
        'invoiceValue': r.invoiceValue,
        'gstAmount': r.gstAmount,
        'gstTds': r.gstTds,
        'incomeTaxTds': r.incomeTaxTds,
        'transactionFeeAmount': r.transactionFeeAmount,
        'ldDeducted': r.ldDeducted,
        'netReceivable': r.netReceivable,
      });
    }
    if (k == 'raWalkaway') {
      final r = ReverseAuctionResult.calculate(
        landedCost: n('landedCost'),
        minMargin: n('minMargin'),
        l1Price: n('l1Price'),
        isMse: values['isMse'] == true,
      );
      out.addAll({
        'landedCost': r.landedCost,
        'minMargin': r.minMargin,
        'floorPrice': r.floorPrice,
        'l1Price': r.l1Price,
        'isMse': r.isMse,
        'headroomVsL1': r.headroomVsL1,
        'withinMsePreferenceBand': r.withinMsePreferenceBand,
      });
    }
    s.complete(k, out);
    setState(() => result = out);
    message(
      context,
      t(
        'Result saved. Scroll down to see your next step.',
        'परिणाम सहेजा गया। अगला कदम नीचे देखें।',
      ),
    );
  }

  Widget resultPanel() {
    final r = result!;
    final next = {
      'eligibility': 'revenue',
      'revenue': 'pricing',
      'pricing': 'roi',
      'roi': 'tracker',
      'workingCapital': 'tracker',
      'emd': 'tracker',
      'unitEconomics': 'pricing',
      'gstCalc': 'tracker',
      'netCash': 'tracker',
      'raWalkaway': 'tracker',
    }[k]!;
    return Panel(
      tone: AppCardTone.brand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tag(t('YOUR RESULT • SAVED', 'आपका परिणाम • सहेजा गया')),
          const SizedBox(height: 20),
          if (k == 'eligibility') ...eligibilityResult(r),
          if (k == 'revenue') ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AnimatedMoney(
                  value: (r['low'] as num).toDouble(),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(' – ', style: Theme.of(context).textTheme.headlineMedium),
                AnimatedMoney(
                  value: (r['high'] as num).toDouble(),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            Text(
              t(
                'Illustrative annual gross revenue, before costs and taxes',
                'लागत और कर से पहले उदाहरणात्मक वार्षिक सकल आय',
              ),
            ),
            const SizedBox(height: 20),
            RangeChart(
              low: (r['low'] as num).toDouble(),
              high: (r['high'] as num).toDouble(),
              lowLabel: t('Cautious', 'सावधान'),
              highLabel: t('Optimistic', 'आशावादी'),
            ),
            const SizedBox(height: 20),
            // In varying mode the typical is non-obvious; surface it next to the chart.
            if (r['orderValueVaries'] == true) ...[
              Text(
                '${t('Typical scenario', 'सामान्य परिदृश्य')}: ${money((r['typical'] as num).toDouble())}',
                style: AppText.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            () {
              final isVarying = r['orderValueVaries'] == true;
              final orderStr = isVarying
                  ? '${money((r['minOrderValue'] as num).toDouble())} – ${money((r['maxOrderValue'] as num).toDouble())}'
                  : money((r['orderValue'] as num).toDouble());
              return Text(
                '$orderStr × ${r['ordersLow']}–${r['ordersHigh']} ${t('orders per year', 'ऑर्डर प्रति वर्ष')}',
              );
            }(),
            const SizedBox(height: 20),
            () {
              final low = (r['low'] as num).toDouble();
              final high = (r['high'] as num).toDouble();
              final ordersLow = (r['ordersLow'] as num).toDouble();
              final ordersHigh = (r['ordersHigh'] as num).toDouble();
              final midOrders = (ordersLow + ordersHigh) / 2;
              final mid = r['typical'] != null
                  ? (r['typical'] as num).toDouble()
                  : (r['orderValue'] as num).toDouble() * midOrders;
              return ResponsiveRow(
                children: [
                  Stat(
                    t('Most likely scenario', 'सबसे संभावित परिदृश्य'),
                    AnimatedMoney(value: mid),
                    t(
                      '${midOrders % 1 == 0 ? midOrders.toInt() : midOrders} orders/yr · illustrative',
                      '${midOrders % 1 == 0 ? midOrders.toInt() : midOrders} ऑर्डर/वर्ष · उदाहरणात्मक',
                    ),
                  ),
                  Stat(
                    t('Monthly equivalent', 'मासिक समकक्ष'),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AnimatedMoney(value: low / 12),
                        const Text(' – '),
                        AnimatedMoney(value: high / 12),
                      ],
                    ),
                    t(
                      'Annual ÷ 12 · gross, before costs',
                      'वार्षिक ÷ 12 · सकल, लागत से पहले',
                    ),
                  ),
                ],
              );
            }(),
            const SizedBox(height: 12),
            Text(
              t(
                'Source: your inputs, calculated today. Not a forecast or observed category benchmark. Zero orders remains possible.',
                'स्रोत: आपके इनपुट, आज की गणना। यह पूर्वानुमान या वास्तविक श्रेणी का आँकड़ा नहीं है। शून्य ऑर्डर भी संभव है।',
              ),
            ),
            // Track record card — uses static text, not AnimatedMoney, so it
            // is visually distinct from the projected range above.
            if (r['hasPriorOrders'] == 'yes' &&
                (r['priorOrdersCount'] != null ||
                    r['priorOrdersValue'] != null)) ...[
              const SizedBox(height: 12),
              () {
                final count = r['priorOrdersCount'] as int?;
                final val = r['priorOrdersValue'] != null
                    ? (r['priorOrdersValue'] as num).toDouble()
                    : null;
                final summary = (count != null && val != null)
                    ? t(
                        '{amount} across {count} orders won',
                        '{amount} में {count} ऑर्डर जीते',
                        vars: {'amount': money(val), 'count': '$count'},
                      )
                    : val != null
                    ? t(
                        '{amount} in orders won this year',
                        '{amount} इस वर्ष जीते ऑर्डर में',
                        vars: {'amount': money(val)},
                      )
                    : t(
                        '{count} orders won this year',
                        'इस वर्ष {count} ऑर्डर जीते',
                        vars: {'count': '${count ?? 0}'},
                      );
                return Panel(
                  tone: AppCardTone.muted,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(
                          'YOUR TRACK RECORD THIS YEAR',
                          'इस वर्ष आपका ट्रैक रिकॉर्ड',
                        ),
                        style: AppText.caption,
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(summary, style: AppText.h3),
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        t(
                          'Not included in the range above — your own data, stored on device only.',
                          'ऊपर की सीमा में शामिल नहीं — आपका अपना डेटा, केवल डिवाइस पर।',
                        ),
                        style: AppText.caption,
                      ),
                    ],
                  ),
                );
              }(),
            ],
            // Seasonality note — informational only; revenue range is unchanged.
            if (r['hasSeasonal'] == true) ...[
              const SizedBox(height: 8),
              Text(
                t(
                  'Seasonal business — monthly revenue will vary.',
                  'मौसमी व्यवसाय — मासिक आय बदलती रहेगी।',
                ),
                style: AppText.bodySmall,
              ),
            ],
          ],
          if (k == 'pricing') ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AnimatedMoney(
                  value: (r['price'] as num).toDouble(),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  ' ${t('/ unit', '/ इकाई')}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            Text(
              t(
                'Selling price for your desired gross margin',
                'वांछित सकल मार्जिन के लिए बिक्री मूल्य',
              ),
            ),
            const SizedBox(height: 20),
            CompositionBar(
              slices: [
                ChartSlice(
                  t('Cost', 'लागत'),
                  (r['cost'] as num).toDouble(),
                  AppColors.chartCost,
                ),
                ChartSlice(
                  t('Profit', 'लाभ'),
                  (r['profit'] as num).toDouble(),
                  AppColors.chartPositive,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              children: [
                Text(
                  '${t('Break-even before order fees & taxes', 'ऑर्डर शुल्क और कर से पहले लागत वसूली मूल्य')}: ',
                ),
                AnimatedMoney(value: (r['cost'] as num).toDouble()),
              ],
            ),
            Wrap(
              children: [
                Text('${t('Contribution per unit', 'प्रति इकाई योगदान')}: '),
                AnimatedMoney(value: (r['profit'] as num).toDouble()),
              ],
            ),
            if ((r['benchmark'] as num) > 0)
              Wrap(
                children: [
                  Text(
                    '${t('Margin at your comparable price', 'आपके तुलनीय मूल्य पर मार्जिन')}: ',
                  ),
                  AnimatedPercent(
                    value: (r['competitiveMargin'] as num).toDouble(),
                  ),
                ],
              ),
            Text(
              t(
                'Your desired margin is ${((r['margin'] as num) - 17.5).abs().toStringAsFixed(1)} percentage points ${(r['margin'] as num) >= 17.5 ? 'above' : 'below'} the survey median (17.5%, n=20; survey date not supplied).',
                'आपका वांछित मार्जिन सर्वेक्षण माध्यिका (17.5%, n=20; सर्वेक्षण तिथि उपलब्ध नहीं) से ${((r['margin'] as num) - 17.5).abs().toStringAsFixed(1)} प्रतिशत अंक ${(r['margin'] as num) >= 17.5 ? 'ऊपर' : 'नीचे'} है।',
              ),
            ),
          ],
          if (k == 'roi') ...[
            r['payback'] == null
                ? Text(
                    t(
                      'No payback at these assumptions',
                      'इन धारणाओं पर लागत वसूली नहीं',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  )
                : Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${t('Illustrative payback', 'उदाहरणात्मक लागत वसूली')}: ',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      AnimatedNumber(
                        value: (r['payback'] as num).toDouble(),
                        format: (v) => v.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        ' ${t('months', 'महीने')}',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
            const SizedBox(height: 20),
            ValueBars(
              items: [
                ChartValue(
                  t('1-year net contribution', '1-वर्ष शुद्ध योगदान'),
                  (r['firstYear'] as num).toDouble(),
                ),
                ChartValue(
                  t('3-year net contribution', '3-वर्ष शुद्ध योगदान'),
                  (r['threeYear'] as num).toDouble(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ResponsiveRow(
              children: [
                Stat(
                  t('1-year net contribution', '1-वर्ष शुद्ध योगदान'),
                  AnimatedMoney(value: (r['firstYear'] as num).toDouble()),
                  t(
                    'After setup, assumed delay & platform fees',
                    'तैयारी, अनुमानित देरी और प्लेटफ़ॉर्म शुल्क के बाद',
                  ),
                ),
                Stat(
                  t('3-year net contribution', '3-वर्ष शुद्ध योगदान'),
                  AnimatedMoney(value: (r['threeYear'] as num).toDouble()),
                  t(
                    'Constant sales and margins; not discounted',
                    'स्थिर बिक्री और मार्जिन; वर्तमान मूल्य छूट शामिल नहीं',
                  ),
                ),
              ],
            ),
            Wrap(
              children: [
                Text('${t('Setup including time', 'समय सहित तैयारी')}: '),
                AnimatedMoney(value: (r['setup'] as num).toDouble()),
                Text(
                  ' · ${t('Annual GeM fees at full activity', 'पूरी गतिविधि पर वार्षिक GeM शुल्क')}: ',
                ),
                AnimatedMoney(value: (r['annualFees'] as num).toDouble()),
              ],
            ),
            Text(
              t(
                'Fee model: ₹0 on orders up to ₹10 lakh; 0.3% of total order value above ₹10 lakh, capped at ₹3 lakh per order. Excludes tax on fees. Confirm the current policy before bidding.',
                'शुल्क मॉडल: ₹10 लाख तक ऑर्डर पर ₹0; उससे ऊपर पूरे ऑर्डर मूल्य का 0.3%, अधिकतम ₹3 लाख प्रति ऑर्डर। शुल्क पर कर शामिल नहीं। बोली से पहले वर्तमान नीति जाँचें।',
              ),
            ),
            SourceNote(
              s,
              t(
                'PIB · 21 Sep 2024; effective 9 Aug 2024',
                'PIB · 21 सितम्बर 2024; लागू 9 अगस्त 2024',
              ),
              feeSource,
            ),
          ],
          if (k == 'workingCapital') ...[
            AnimatedMoney(
              value: (r['gap'] as num).toDouble(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              t(
                'Working-capital gap to cover this order',
                'इस ऑर्डर के लिए कार्यशील पूँजी की कमी',
              ),
            ),
            const SizedBox(height: 20),
            _simpleRows([
              (
                t('Order value', 'ऑर्डर मूल्य'),
                money((r['orderValue'] as num).toDouble()),
              ),
              (
                t('Cash on hand', 'उपलब्ध नकद'),
                money((r['cashOnHand'] as num).toDouble()),
              ),
              (
                t(
                  'Cycle length (production + payment delay)',
                  'चक्र अवधि (उत्पादन + भुगतान विलंब)',
                ),
                '${(r['cycleDays'] as num).toStringAsFixed(0)} ${t('days', 'दिन')}',
              ),
            ]),
            Text(
              t(
                'Illustrative only — does not include financing cost or interest.',
                'उदाहरणात्मक मात्र — वित्तपोषण लागत या ब्याज शामिल नहीं।',
              ),
            ),
          ],
          if (k == 'emd') ...[
            AnimatedMoney(
              value: (r['emdPayable'] as num).toDouble(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              r['exempt'] == true
                  ? t(
                      '₹0 — Udyam-registered MSEs are typically EMD-exempt',
                      '₹0 — उद्यम-पंजीकृत MSE सामान्यतः EMD से मुक्त होते हैं',
                    )
                  : t(
                      'Earnest Money Deposit payable on this tender',
                      'इस निविदा पर देय अर्नेस्ट मनी जमा',
                    ),
            ),
            const SizedBox(height: 20),
            _simpleRows([
              (
                t('Tender value', 'निविदा मूल्य'),
                money((r['tenderValue'] as num).toDouble()),
              ),
              (
                t('EMD rate', 'EMD दर'),
                '${(r['emdPercent'] as num).toStringAsFixed(2)}%',
              ),
            ]),
            Text(
              t(
                'Always confirm the EMD/exemption clause in the specific bid document — policy varies by tender.',
                'विशिष्ट बोली दस्तावेज़ में EMD/छूट खंड अवश्य जाँचें — नीति निविदा अनुसार भिन्न होती है।',
              ),
            ),
          ],
          if (k == 'unitEconomics') ...[
            r['breakEvenUnits'] == null
                ? Text(
                    t(
                      'No break-even at this price — selling price does not cover variable cost',
                      'इस मूल्य पर लागत वसूली नहीं — बिक्री मूल्य परिवर्तनीय लागत को कवर नहीं करता',
                    ),
                    style: Theme.of(context).textTheme.headlineMedium,
                  )
                : Text(
                    '${(r['breakEvenUnits'] as num).toStringAsFixed(1)} ${t('units', 'इकाइयाँ')}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
            Text(
              t(
                'Units needed to cover fixed costs',
                'स्थिर लागत कवर करने के लिए आवश्यक इकाइयाँ',
              ),
            ),
            const SizedBox(height: 20),
            _simpleRows([
              (
                t('Contribution per unit', 'प्रति इकाई योगदान'),
                money((r['contribution'] as num).toDouble()),
              ),
              if (r['breakEvenRevenue'] != null)
                (
                  t('Break-even revenue', 'लागत वसूली आय'),
                  money((r['breakEvenRevenue'] as num).toDouble()),
                ),
            ]),
          ],
          if (k == 'gstCalc') ...[
            AnimatedMoney(
              value: (r['total'] as num).toDouble(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(t('Total payable including GST', 'GST सहित कुल देय राशि')),
            const SizedBox(height: 20),
            _simpleRows([
              (
                t('Sale value', 'बिक्री मूल्य'),
                money((r['saleValue'] as num).toDouble()),
              ),
              (
                t('GST amount', 'GST राशि'),
                money((r['gstAmount'] as num).toDouble()),
              ),
              if ((r['cgst'] as num) > 0)
                (t('CGST', 'CGST'), money((r['cgst'] as num).toDouble())),
              if ((r['sgst'] as num) > 0)
                (t('SGST', 'SGST'), money((r['sgst'] as num).toDouble())),
              if ((r['igst'] as num) > 0)
                (t('IGST', 'IGST'), money((r['igst'] as num).toDouble())),
            ]),
          ],
          if (k == 'netCash') ...[
            AnimatedMoney(
              value: (r['netReceivable'] as num).toDouble(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              t(
                'Estimated amount credited to your bank',
                'आपके बैंक में जमा होने वाली अनुमानित राशि',
              ),
            ),
            const SizedBox(height: 20),
            _simpleRows([
              (
                t('Invoice value', 'चालान मूल्य'),
                money((r['invoiceValue'] as num).toDouble()),
              ),
              (t('+ GST', '+ GST'), money((r['gstAmount'] as num).toDouble())),
              (
                t('− GST-TDS', '− GST-TDS'),
                money((r['gstTds'] as num).toDouble()),
              ),
              if ((r['incomeTaxTds'] as num) > 0)
                (
                  t('− Income-tax TDS', '− आयकर TDS'),
                  money((r['incomeTaxTds'] as num).toDouble()),
                ),
              (
                t('− GeM transaction fee', '− GeM लेनदेन शुल्क'),
                money((r['transactionFeeAmount'] as num).toDouble()),
              ),
              if ((r['ldDeducted'] as num) > 0)
                (
                  t('− LD / penalty', '− LD / जुर्माना'),
                  money((r['ldDeducted'] as num).toDouble()),
                ),
            ]),
            Text(
              t(
                'Illustrative only — confirm the applicable GST-TDS threshold, TDS rate and current GeM fee policy for your order.',
                'उदाहरणात्मक मात्र — अपने ऑर्डर के लिए लागू GST-TDS सीमा, TDS दर और वर्तमान GeM शुल्क नीति की पुष्टि करें।',
              ),
            ),
          ],
          if (k == 'raWalkaway') ...[
            AnimatedMoney(
              value: (r['floorPrice'] as num).toDouble(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              t(
                'Your walk-away price — do not bid below this',
                'आपका वॉक-अवे मूल्य — इससे नीचे बोली न लगाएँ',
              ),
            ),
            const SizedBox(height: 20),
            _simpleRows([
              (
                t('Landed cost per unit', 'प्रति इकाई लैंडेड लागत'),
                money((r['landedCost'] as num).toDouble()),
              ),
              if (r['headroomVsL1'] != null)
                (
                  (r['headroomVsL1'] as num) >= 0
                      ? t('Above current L1 by', 'वर्तमान L1 से अधिक')
                      : t('Below current L1 by', 'वर्तमान L1 से कम'),
                  money((r['headroomVsL1'] as num).abs().toDouble()),
                ),
            ]),
            if (r['withinMsePreferenceBand'] != null)
              Text(
                r['withinMsePreferenceBand'] == true
                    ? t(
                        'Within the MSE L1 + 15% purchase-preference band — you may be able to match L1, subject to the tender.',
                        'MSE L1 + 15% खरीद वरीयता सीमा के भीतर — निविदा के अनुसार आप L1 मूल्य मिला सकते हैं।',
                      )
                    : t(
                        'Outside the MSE L1 + 15% purchase-preference band at this floor price.',
                        'इस वॉक-अवे मूल्य पर MSE L1 + 15% खरीद वरीयता सीमा से बाहर।',
                      ),
              ),
            if ((r['l1Price'] as num) == 0)
              Text(
                t(
                  'Enter the current L1 price to see your headroom and MSE-preference eligibility.',
                  'अपनी स्थिति और MSE वरीयता पात्रता देखने के लिए वर्तमान L1 मूल्य दर्ज करें।',
                ),
              ),
          ],
          NextActions(
            s,
            k == 'eligibility' && r['interested'] == false ? 'support' : next,
          ),
        ],
      ),
    );
  }

  List<Widget> eligibilityResult(Map<String, dynamic> r) {
    final e = Eligibility.evaluate(r);
    final verdict = switch (e.verdict) {
      'yes' => t(
        'Yes — ready to explore registration',
        'हाँ — पंजीकरण आगे बढ़ा सकते हैं',
      ),
      'choice' => t(
        'Government sales aren’t your priority right now',
        'अभी सरकारी बिक्री आपकी प्राथमिकता नहीं है',
      ),
      _ => t(
        'Partial — a few details to resolve',
        'आंशिक — कुछ जानकारी पूरी करें',
      ),
    };
    final gaps = {
      'pan': t(
        'Prepare the relevant PAN and authorised-person identity details. Confirm the accepted route on GeM.',
        'संबंधित PAN और अधिकृत व्यक्ति की पहचान जानकारी तैयार करें। GeM पर स्वीकार्य तरीका जाँचें।',
      ),
      'bank': t(
        'Prepare business bank details and confirm account requirements with your bank.',
        'व्यवसाय बैंक विवरण तैयार करें और बैंक से आवश्यकताएँ जाँचें।',
      ),
      'gst': t(
        'Confirm GST applicability or exemption with your CA and the official portal before proceeding.',
        'आगे बढ़ने से पहले CA और आधिकारिक पोर्टल से GST आवश्यकता या छूट की पुष्टि करें।',
      ),
      'category': t(
        'Find the closest permitted category and its catalogue requirements on GeM.',
        'GeM पर उपयुक्त अनुमत श्रेणी और कैटलॉग आवश्यकताएँ ढूँढें।',
      ),
    };
    return [
      Text(verdict, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 12),
      Text(
        classificationName(e.enterprise, s.language),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (r['selfClass'] != 'unsure' && r['selfClass'] != e.enterprise.name)
        Text(
          t(
            'This differs from your selected classification. Both investment and turnover limits must be satisfied.',
            'यह आपके चुने वर्गीकरण से अलग है। निवेश और कारोबार दोनों सीमाएँ पूरी होनी चाहिए।',
          ),
        ),
      const SizedBox(height: 12),
      for (final gap in e.gaps)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('• ${gaps[gap]}'),
        ),
      if (r['udyam'] != true)
        Text(
          t(
            'Udyam is worth exploring for MSE benefits; missing Udyam alone does not make you ineligible for GeM.',
            'MSE लाभ के लिए उद्यम देखें; केवल उद्यम न होने से आप GeM के लिए अपात्र नहीं होते।',
          ),
        ),
      Text(
        t(
          'This is a preliminary readiness assessment. The portal, category and buyer requirements decide actual acceptance. Time to resolve gaps varies; no validated Pune timing sample is available yet.',
          'यह प्रारंभिक तैयारी जाँच है। वास्तविक स्वीकृति पोर्टल, श्रेणी और खरीदार की शर्तों पर निर्भर है। कमियाँ दूर करने का समय बदलता है; पुणे का सत्यापित समय नमूना अभी उपलब्ध नहीं है।',
        ),
      ),
      SourceNote(
        s,
        t(
          'Udyam · thresholds effective 1 Apr 2025; reviewed 9 Sep 2026',
          'उद्यम · सीमा लागू 1 अप्रैल 2025; जाँच 9 सितम्बर 2026',
        ),
        udyamSource,
      ),
      SourceNote(
        s,
        t(
          'Check official seller requirements on GeM',
          'GeM पर आधिकारिक विक्रेता आवश्यकताएँ जाँचें',
        ),
        gemSource,
      ),
    ];
  }
}
