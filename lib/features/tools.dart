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
    };
    for (final e in defaults.entries) {
      fields[e.key] = TextEditingController(text: '${saved[e.key] ?? e.value}');
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
                      const Icon(Icons.lightbulb_outline, color: AppColors.brand),
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
      number(
        'orderValue',
        'Expected value per order (₹)',
        'प्रति ऑर्डर अपेक्षित मूल्य (₹)',
      ),
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
    // Soft warning only — zero order value is valid (zero revenue is a real
    // outcome), but a value of exactly ₹0 is most likely a data-entry slip.
    if (k == 'revenue' && n('orderValue') == 0) {
      message(
        context,
        t(
          'Order value is zero — double-check if this is a data-entry slip.',
          'ऑर्डर मूल्य शून्य है — जाँचें कि यह प्रविष्टि त्रुटि तो नहीं।',
        ),
      );
      // Calculation continues: zero revenue is a valid planning scenario.
    }
    final out = <String, dynamic>{};
    if (k == 'eligibility') {
      out.addAll(values);
      out.addAll({'turnover': n('turnover'), 'investment': n('investment')});
    }
    if (k == 'revenue') {
      final r = RevenueResult.calculate(
        n('orderValue'),
        n('ordersLow'),
        n('ordersHigh'),
      );
      out.addAll({
        'category': values['category'],
        'city': values['city'],
        'orderValue': r.orderValue,
        'ordersLow': r.ordersLow,
        'ordersHigh': r.ordersHigh,
        'low': r.low,
        'high': r.high,
        'source': 'user_assumptions',
      });
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
                Text(
                  ' – ',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
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
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AnimatedMoney(value: (r['orderValue'] as num).toDouble()),
                Text(
                  ' × ${r['ordersLow']}–${r['ordersHigh']} ${t('orders per year', 'ऑर्डर प्रति वर्ष')}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            () {
              final low = (r['low'] as num).toDouble();
              final high = (r['high'] as num).toDouble();
              final ordersLow = (r['ordersLow'] as num).toDouble();
              final ordersHigh = (r['ordersHigh'] as num).toDouble();
              final orderValue = (r['orderValue'] as num).toDouble();
              final midOrders = (ordersLow + ordersHigh) / 2;
              final mid = orderValue * midOrders;
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
                        Text(' – '),
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
