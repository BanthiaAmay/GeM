import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'widgets.dart';

const toolIcons = {
  'eligibility': Icons.fact_check_outlined,
  'revenue': Icons.trending_up,
  'pricing': Icons.calculate_outlined,
  'roi': Icons.donut_large_outlined,
  'tracker': Icons.route_outlined,
};

class HomePage extends StatelessWidget {
  final AppStore s;
  const HomePage(this.s, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Panel(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 24 : 40,
        ),
        color: const Color(0xFFEDF1E5),
        child: ResponsiveRow(
          breakpoint: 780,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(
                  s.t(
                    'BUILT FOR MAHARASHTRA’S SMALL BUSINESSES',
                    'महाराष्ट्र के छोटे व्यवसायों के लिए',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  s.t(
                    'Your business.\nA new buyer: the\ngovernment.',
                    'आपका व्यवसाय।\nनया खरीदार:\nसरकार।',
                  ),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: MediaQuery.sizeOf(context).width < 600 ? 36 : 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  s.t(
                    'Understand GeM, check your readiness and work out the numbers — one clear step at a time.',
                    'GeM समझें, अपनी तैयारी जाँचें और हिसाब लगाएँ — एक-एक स्पष्ट कदम के साथ।',
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: () => go(context, s, 'eligibility'),
                      label: Text(
                        s.t(
                          'Can I sell on GeM?',
                          'क्या मैं GeM पर बेच सकता/सकती हूँ?',
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                    ),
                    OutlinedButton(
                      onPressed: () => go(context, s, 'learn'),
                      child: Text(
                        s.t('Start with the basics', 'मूल बातें जानें'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  s.t(
                    'Free to use  ·  No login needed',
                    'मुफ़्त उपयोग  ·  लॉगिन ज़रूरी नहीं',
                  ),
                  style: const TextStyle(fontSize: 12, color: green),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.explore_outlined, color: green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s.t('YOUR PATH TO GeM', 'GeM तक आपका रास्ता'),
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    for (final row in [
                      [
                        '01',
                        'Understand your eligibility',
                        'अपनी पात्रता समझें',
                        'Know where you stand',
                        'अपनी स्थिति जानें',
                      ],
                      [
                        '02',
                        'Make the numbers work',
                        'हिसाब समझें',
                        'Revenue, margins and return',
                        'आय, मार्जिन और लाभ',
                      ],
                      [
                        '03',
                        'Take your next step',
                        'अगला कदम उठाएँ',
                        'A plan you can come back to',
                        'योजना जो फिर खोल सकते हैं',
                      ],
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 26),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: lime,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                row[0],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.t(row[1], row[2]),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(s.t(row[3], row[4])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                          color: green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.t(
                              'Clear assumptions. Official sources. Your decision.',
                              'स्पष्ट धारणाएँ। आधिकारिक स्रोत। आपका निर्णय।',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      if (s.completed.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Panel(
            color: lime,
            child: Row(
              children: [
                const Icon(Icons.bookmark_added_outlined, color: green),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.t(
                          'Welcome back. Your plan is right here.',
                          'वापसी पर स्वागत है। आपकी योजना यहीं है।',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        s.t(
                          '{n} of 4 calculators completed',
                          '4 में से {n} गणनाएँ पूरी',
                          vars: {'n': '${s.completed.length}'},
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => go(context, s, 'report'),
                  child: Text(s.t('Resume →', 'फिर शुरू करें →')),
                ),
              ],
            ),
          ),
        ),
      ResponsiveRow(
        children: [
          _intro(
            context,
            Icons.account_balance_outlined,
            s.t('A marketplace for government', 'सरकार का बाज़ार'),
            s.t(
              'Public buyers purchase products and services through GeM.',
              'सरकारी खरीदार GeM पर उत्पाद और सेवाएँ खरीदते हैं।',
            ),
          ),
          _intro(
            context,
            Icons.storefront_outlined,
            s.t('Built around your business', 'आपके व्यवसाय के अनुसार'),
            s.t(
              'From office supplies to services, start with your category.',
              'कार्यालय सामग्री से सेवाओं तक, अपनी श्रेणी से शुरू करें।',
            ),
          ),
          _intro(
            context,
            Icons.lock_outline,
            s.t('Your pace. Your information.', 'आपकी गति। आपकी जानकारी।'),
            s.t(
              'Use the tools privately. Choose whether to save online.',
              'टूल निजी तौर पर उपयोग करें। ऑनलाइन सहेजना आपकी पसंद है।',
            ),
          ),
        ],
      ),
      const SizedBox(height: 30),
      ToolsPage(s, embedded: true),
      const SizedBox(height: 30),
      Panel(
        color: ink,
        child: ResponsiveRow(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'A little help can make\nthe next step easier.',
                    'थोड़ी मदद से\nअगला कदम आसान।',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  s.t(
                    'Ask about a workshop or request guidance from a CA partner.',
                    'कार्यशाला के बारे में जानें या CA पार्टनर से मार्गदर्शन माँगें।',
                  ),
                  style: const TextStyle(color: Color(0xFFC4D4CD)),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: lime,
                  foregroundColor: ink,
                ),
                onPressed: () => go(context, s, 'support'),
                child: Text(s.t('Find support →', 'सहायता पाएँ →')),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _intro(BuildContext c, IconData icon, String title, String body) =>
      Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: green, size: 24),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body),
          ],
        ),
      );
}

class ToolsPage extends StatelessWidget {
  final AppStore s;
  final bool embedded;
  const ToolsPage(this.s, {super.key, this.embedded = false});
  @override
  Widget build(BuildContext context) {
    final desc = {
      'eligibility': s.t(
        'Can I sell? Find your classification and what you need to get started.',
        'क्या मैं बेच सकता/सकती हूँ? वर्गीकरण और तैयारी की आवश्यकताएँ जानें।',
      ),
      'revenue': s.t(
        'What is possible? Explore a range using your own sales assumptions.',
        'क्या संभव है? अपनी बिक्री की धारणाओं से आय का दायरा देखें।',
      ),
      'pricing': s.t(
        'What should I charge? Protect your margin before you quote.',
        'कितना मूल्य रखें? बोली से पहले अपना मार्जिन बचाएँ।',
      ),
      'roi': s.t(
        'Is it worth the effort? See costs, contribution and payback together.',
        'क्या प्रयास लाभदायक है? लागत, योगदान और लागत वसूली साथ देखें।',
      ),
      'tracker': s.t(
        'What do I do next? Turn your plan into a practical checklist.',
        'अगला कदम क्या है? योजना को काम की चेकलिस्ट में बदलें।',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(
          s.t('A TOOL FOR EVERY QUESTION', 'हर सवाल के लिए एक टूल'),
          s.t('Less guesswork. More clarity.', 'कम अनुमान। ज़्यादा स्पष्टता।'),
          s.t(
            'Follow the steps or jump into the tool you need.',
            'क्रम से चलें या सीधे अपने ज़रूरी टूल पर जाएँ।',
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 850
                ? 3
                : c.maxWidth > 560
                ? 2
                : 1;
            return Wrap(
              spacing: 18,
              runSpacing: 18,
              children: [
                for (final entry in desc.entries)
                  SizedBox(
                    width: (c.maxWidth - 18 * (cols - 1)) / cols,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0F4E9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  toolIcons[entry.key],
                                  color: green,
                                  size: 25,
                                ),
                              ),
                              Tag(
                                s.completed.contains(entry.key)
                                    ? s.t('Completed', 'पूरा हुआ')
                                    : '0${desc.keys.toList().indexOf(entry.key) + 1}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            s.toolName(entry.key),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(entry.value),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => go(context, s, entry.key),
                            child: Text(s.t('Open tool →', 'टूल खोलें →')),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class LearnPage extends StatelessWidget {
  final AppStore s;
  const LearnPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Heading(
        s.t('GeM 101', 'GeM परिचय'),
        s.t(
          'Meet your next kind of customer.',
          'अपने नए तरह के ग्राहक से मिलें।',
        ),
        s.t(
          'The Government e-Marketplace connects businesses with public buyers across India.',
          'सरकारी ई-मार्केटप्लेस भारत भर के सरकारी खरीदारों को व्यवसायों से जोड़ता है।',
        ),
      ),
      for (final row in [
        [
          '01',
          'What is GeM?',
          'GeM क्या है?',
          'GeM is an online platform for government procurement: departments and public organisations buy goods and services from registered sellers. It began in 2016.',
          'GeM सरकारी खरीद का ऑनलाइन प्लेटफ़ॉर्म है: विभाग और सार्वजनिक संगठन पंजीकृत विक्रेताओं से सामान और सेवाएँ खरीदते हैं। यह 2016 में शुरू हुआ।',
        ],
        [
          '02',
          'Could my business fit?',
          'क्या मेरा व्यवसाय उपयुक्त है?',
          'Businesses supply office products, furniture, IT, housekeeping and many other categories. Being small or new to government sales does not itself disqualify you. Category requirements still apply.',
          'व्यवसाय कार्यालय सामग्री, फर्नीचर, आईटी, सफाई और कई अन्य श्रेणियों में आपूर्ति करते हैं। छोटा या नया होने से आप स्वतः अपात्र नहीं होते। श्रेणी की शर्तें लागू रहती हैं।',
        ],
        [
          '03',
          'How does selling work?',
          'बिक्री कैसे होती है?',
          'Create your seller account, publish a catalogue (your product or service listing), and respond to suitable opportunities. Some purchases are direct; others use bids or reverse auctions. Eligibility, technical compliance and buyer terms matter alongside price.',
          'विक्रेता खाता बनाएँ, कैटलॉग (उत्पाद या सेवा सूची) प्रकाशित करें और उपयुक्त अवसरों में भाग लें। कुछ खरीद सीधे और कुछ बोली या रिवर्स नीलामी से होती हैं। मूल्य के साथ पात्रता और खरीदार की शर्तें भी महत्त्वपूर्ण हैं।',
        ],
        [
          '04',
          'What should I prepare?',
          'क्या तैयारी करूँ?',
          'Keep business identity, authorised-person information and bank details ready. Check GST applicability and category-specific documents. Udyam is MSME registration; it helps establish eligibility for applicable MSE benefits.',
          'व्यवसाय पहचान, अधिकृत व्यक्ति और बैंक जानकारी तैयार रखें। GST की आवश्यकता और श्रेणी-विशिष्ट दस्तावेज़ जाँचें। उद्यम MSME पंजीकरण है; यह लागू MSE लाभों की पात्रता स्थापित करने में मदद करता है।',
        ],
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(row[0]),
                const SizedBox(height: 12),
                Text(
                  s.t(row[1], row[2]),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(s.t(row[3], row[4])),
              ],
            ),
          ),
        ),
      SourceNote(
        s,
        s.t(
          'GeM overview · PIB, 21 Sep 2024',
          'GeM परिचय · PIB, 21 सितम्बर 2024',
        ),
        feeSource,
      ),
      SourceNote(
        s,
        s.t(
          'National and state metrics: open the live official GeM statistics dashboard',
          'राष्ट्रीय और राज्य आँकड़े: आधिकारिक लाइव GeM डैशबोर्ड खोलें',
        ),
        'https://gem.gov.in/statistics',
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () {
          s.event('module_completed', page: 'learn');
          go(context, s, 'eligibility');
        },
        icon: const Icon(Icons.arrow_forward),
        label: Text(
          s.t(
            'I understand — check my eligibility',
            'समझ गया/गई — मेरी पात्रता जाँचें',
          ),
        ),
      ),
    ],
  );
}

class TrackerPage extends StatelessWidget {
  final AppStore s;
  const TrackerPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = s.checklist;
    final done = c.where((e) => e).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(
          s.t('YOUR ACTION PLAN', 'आपकी कार्य योजना'),
          s.t(
            'One step closer to your first order.',
            'अपने पहले ऑर्डर की ओर एक कदम।',
          ),
          s.t(
            'Your document answers are carried forward. Mark each task when complete, or confirm it is not applicable.',
            'आपके दस्तावेज़ उत्तर यहाँ शामिल हैं। पूरा होने पर या लागू न होने की पुष्टि पर चिह्न लगाएँ।',
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t(
                  '{done} of {total} steps resolved',
                  '{done} / {total} कदम पूरे',
                  vars: {'done': '$done', 'total': '${steps.length}'},
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: done / steps.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: line,
              ),
              const SizedBox(height: 12),
              Text(
                s.t(
                  'Saved on this device. Sign in to resume on another device.',
                  'इस डिवाइस पर सहेजा गया। दूसरे डिवाइस पर जारी रखने के लिए साइन इन करें।',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              padding: const EdgeInsets.all(12),
              color: c[i] ? const Color(0xFFF0F5E9) : null,
              child: ExpansionTile(
                key: ValueKey('step_$i'),
                initiallyExpanded: i == c.indexOf(false),
                shape: const Border(),
                leading: Checkbox(
                  value: c[i],
                  onChanged: (v) => s.check(i, v ?? false),
                ),
                title: Text(
                  tr(s.language, steps[i][0], steps[i][1]),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  c[i]
                      ? s.t(
                          'Complete / checked as not applicable',
                          'पूरा / लागू नहीं जाँचा गया',
                        )
                      : i == c.indexOf(false)
                      ? s.t('YOUR NEXT STEP', 'आपका अगला कदम')
                      : s.t('Upcoming', 'आगे'),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(s.language, steps[i][2], steps[i][3])),
                        const SizedBox(height: 8),
                        Text(
                          s.t(
                            'Timing varies. Set aside time to check the current requirements; local completion-time evidence is pending.',
                            'समय अलग-अलग हो सकता है। वर्तमान आवश्यकताएँ जाँचें; स्थानीय समय संबंधी प्रमाण अभी उपलब्ध नहीं हैं।',
                          ),
                        ),
                        SourceNote(
                          s,
                          s.t(
                            'Open official guidance',
                            'आधिकारिक मार्गदर्शन खोलें',
                          ),
                          i == 2 ? udyamSource : gemSource,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        NextActions(s, 'register'),
      ],
    );
  }
}

class ReportPage extends StatelessWidget {
  final AppStore s;
  const ReportPage(this.s, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Heading(
        s.t('MY PERSONALIZED REPORT', 'मेरी व्यक्तिगत रिपोर्ट'),
        s.t('Your business. Your next move.', 'आपका व्यवसाय। आपका अगला कदम।'),
        s.t(
          'Everything you have worked out, together in one place.',
          'आपकी सारी गणनाएँ, एक जगह।',
        ),
      ),
      if (s.completed.isEmpty)
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description_outlined, size: 40, color: green),
              const SizedBox(height: 16),
              Text(
                s.t(
                  'Your report starts with one answer.',
                  'एक उत्तर से आपकी रिपोर्ट शुरू होती है।',
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                s.t(
                  'Complete any calculator and its result will appear here.',
                  'कोई भी गणना पूरी करें, उसका परिणाम यहाँ दिखेगा।',
                ),
              ),
              NextActions(s, 'eligibility'),
            ],
          ),
        )
      else ...[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: s.report()));
                s.event('report_copied', page: 'report');
                if (context.mounted) {
                  message(context, s.t('Report copied', 'रिपोर्ट कॉपी हुई'));
                }
              },
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: Text(s.t('Copy report', 'रिपोर्ट कॉपी करें')),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [
                        XFile.fromData(
                          Uint8List.fromList(utf8.encode(s.report())),
                          mimeType: 'text/plain',
                        ),
                      ],
                      fileNameOverrides: ['gem-saathi-report.txt'],
                      subject: 'GeM BizReady report',
                    ),
                  );
                  s.event('report_exported', page: 'report');
                } catch (_) {
                  if (context.mounted) {
                    message(
                      context,
                      s.t(
                        'Sharing unavailable. Use Copy report.',
                        'साझा करना उपलब्ध नहीं। रिपोर्ट कॉपी करें।',
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(s.t('Download / share', 'डाउनलोड / साझा करें')),
            ),
            OutlinedButton(
              onPressed: () => openLink(
                context,
                s,
                'https://wa.me/?text=${Uri.encodeComponent(s.report())}',
              ),
              child: Text(s.t('WhatsApp', 'व्हाट्सऐप')),
            ),
            OutlinedButton(
              onPressed: () => go(context, s, 'account'),
              child: Text(s.t('Save online', 'ऑनलाइन सहेजें')),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (final k in s.completed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(toolIcons[k], color: green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s.toolName(k),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () => go(context, s, k),
                        child: Text(s.t('Edit', 'बदलें')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    summary(k),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.t(
                      'Calculated: ${s.section(k)['calculatedAt']?.toString().split('T').first ?? 'today'} · $ruleVersion',
                      'गणना: ${s.section(k)['calculatedAt']?.toString().split('T').first ?? 'आज'} · $ruleVersion',
                    ),
                  ),
                  if (k == 'revenue' || k == 'roi')
                    Text(
                      s.t(
                        'Scenario based on your assumptions. Not a promise of earnings.',
                        'आपकी धारणाओं पर परिदृश्य। कमाई का वादा नहीं।',
                      ),
                    ),
                ],
              ),
            ),
          ),
        Panel(
          color: lime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('Your next action', 'आपका अगला कदम'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                (() {
                  final row =
                      steps[!s.checklist.contains(false)
                          ? steps.length - 1
                          : s.checklist.indexOf(false)];
                  return tr(s.language, row[0], row[1]);
                })(),
              ),
              NextActions(s, s.nextTool),
            ],
          ),
        ),
        SourceNote(
          s,
          s.t(
            'Classification: Udyam · effective 1 Apr 2025',
            'वर्गीकरण: उद्यम · लागू 1 अप्रैल 2025',
          ),
          udyamSource,
        ),
        SourceNote(
          s,
          s.t(
            'Transaction-fee model: PIB · 21 Sep 2024',
            'लेनदेन शुल्क मॉडल: PIB · 21 सितम्बर 2024',
          ),
          feeSource,
        ),
      ],
    ],
  );
  String summary(String k) {
    final r = s.section(k);
    return switch (k) {
      'eligibility' =>
        '${classificationName(Eligibility.evaluate(r).enterprise, s.language)} · ${switch (Eligibility.evaluate(r).verdict) {
          'yes' => s.t('Ready to explore', 'आगे बढ़ने के लिए तैयार'),
          'choice' => s.t('Not pursuing now', 'अभी आगे नहीं बढ़ना'),
          _ => s.t('Some details to resolve', 'कुछ जानकारी पूरी करनी है'),
        }}',
      'revenue' =>
        '${money(r['low'])} – ${money(r['high'])} / ${s.t('year, gross', 'वर्ष, सकल')}',
      'pricing' =>
        '${money(r['price'])} / ${s.t('unit', 'इकाई')} · ${r['margin']}% ${s.t('gross margin', 'सकल मार्जिन')}',
      'roi' =>
        '${s.t('Net contribution', 'शुद्ध योगदान')}: ${money(r['firstYear'])} (${s.t('1 year', '1 वर्ष')}) / ${money(r['threeYear'])} (${s.t('3 years', '3 वर्ष')})',
      _ => '',
    };
  }
}

class RegisterPage extends StatefulWidget {
  final AppStore s;
  const RegisterPage(this.s, {super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final reference = TextEditingController();
  String stage = 'registration';
  bool busy = false;
  @override
  void dispose() {
    reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(
          s.t('MAKE YOUR NEXT MOVE', 'अपना अगला कदम उठाएँ'),
          s.t('Ready to register on GeM?', 'GeM पर पंजीकरण के लिए तैयार?'),
          s.t(
            'Registration takes place on the official GeM portal. Keep this checklist beside you.',
            'पंजीकरण आधिकारिक GeM पोर्टल पर होता है। यह चेकलिस्ट अपने पास रखें।',
          ),
        ),
        ResponsiveRow(
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Before you open the portal', 'पोर्टल खोलने से पहले'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  for (int i = 0; i < 3; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        s.checklist[i]
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: green,
                      ),
                      title: Text(tr(s.language, steps[i][0], steps[i][1])),
                    ),
                  Text(
                    s.t(
                      'On GeM, choose Sign up → Seller, read the prerequisites and create your account with your own contact details. Then complete the seller profile and catalogue.',
                      'GeM पर Sign up → Seller चुनें, आवश्यकताएँ पढ़ें और अपनी संपर्क जानकारी से खाता बनाएँ। फिर विक्रेता प्रोफ़ाइल और कैटलॉग पूरा करें।',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      s.event('registration_intent', page: 'register');
                      openLink(context, s, gemSource);
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(
                      s.t(
                        'Open official GeM portal',
                        'आधिकारिक GeM पोर्टल खोलें',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => go(context, s, 'tracker'),
                    child: Text(
                      s.t(
                        'Review my full checklist →',
                        'पूरी चेकलिस्ट देखें →',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Tell us how it went', 'बताएँ कैसा रहा'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t(
                      'Optional research follow-up. Claims remain self-reported until independently verified. Do not enter PAN, Aadhaar, passwords or OTPs.',
                      'वैकल्पिक शोध फॉलो-अप। स्वतंत्र सत्यापन तक दावे स्वयं बताए गए रहेंगे। PAN, आधार, पासवर्ड या OTP न डालें।',
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: stage,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: 'registration',
                        child: Text(
                          s.t('I have registered', 'मैंने पंजीकरण कर लिया'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'first_order',
                        child: Text(
                          s.t(
                            'I received my first order',
                            'मुझे पहला ऑर्डर मिला',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => stage = v!),
                    decoration: InputDecoration(
                      labelText: s.t('Milestone', 'उपलब्धि'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reference,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: s.t(
                        'Seller / order reference',
                        'विक्रेता / ऑर्डर संदर्भ',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!s.signedIn) {
                              go(context, s, 'account');
                              return;
                            }
                            if (reference.text.trim().isEmpty) {
                              message(
                                context,
                                s.t(
                                  'Add a reference for verification.',
                                  'सत्यापन के लिए संदर्भ दें।',
                                ),
                              );
                              return;
                            }
                            setState(() => busy = true);
                            try {
                              await s.claimOutcome(
                                stage,
                                reference.text.trim(),
                              );
                              if (context.mounted) {
                                message(
                                  context,
                                  s.t(
                                    'Saved as self-reported; verification pending.',
                                    'स्वयं बताया गया सहेजा; सत्यापन बाकी।',
                                  ),
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                message(
                                  context,
                                  s.t(
                                    'Could not submit. Check your connection and try again.',
                                    'भेज नहीं पाए। कनेक्शन जाँचकर फिर कोशिश करें।',
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: Text(
                      s.t(
                        s.signedIn
                            ? 'Submit for verification'
                            : 'Sign in to report progress',
                        s.signedIn
                            ? 'सत्यापन के लिए भेजें'
                            : 'प्रगति बताने के लिए साइन इन करें',
                      ),
                    ),
                  ),
                  for (final o in s.outcomes)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Tag('${o['stage']} · ${o['status']}'),
                    ),
                ],
              ),
            ),
          ],
        ),
        NextActions(s, 'support'),
      ],
    );
  }
}

class AccountPage extends StatefulWidget {
  final AppStore s;
  const AccountPage(this.s, {super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final email = TextEditingController(), code = TextEditingController();
  bool sent = false, busy = false;
  String? sentEmail;
  @override
  void dispose() {
    email.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> act(Future<void> Function() action, String success) async {
    setState(() => busy = true);
    try {
      await action();
      if (mounted) message(context, success);
    } catch (_) {
      if (mounted) {
        message(
          context,
          widget.s.t(
            'Could not complete this action. Check your connection and code, then try again.',
            'यह कार्य पूरा नहीं हुआ। कनेक्शन और कोड जाँचकर फिर कोशिश करें।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(
          s.t('SAVE & PRIVACY', 'सहेजें और गोपनीयता'),
          s.t('Come back to a clear next step.', 'स्पष्ट अगले कदम पर लौटें।'),
          s.t(
            'Your tools work without an account. Sign in by email to keep your report across devices.',
            'टूल बिना खाते के काम करते हैं। अलग डिवाइस पर रिपोर्ट रखने के लिए ईमेल से साइन इन करें।',
          ),
        ),
        ResponsiveRow(
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_outlined, color: green, size: 32),
                  const SizedBox(height: 16),
                  Text(
                    s.t('Save your plan online', 'अपनी योजना ऑनलाइन सहेजें'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (!s.configured)
                    Text(
                      s.t(
                        'Online saving is not connected yet. Your plan is saved on this device; use the report’s download or copy options to keep a portable copy.',
                        'ऑनलाइन सहेजना अभी जुड़ा नहीं है। आपकी योजना इस डिवाइस पर है; रिपोर्ट डाउनलोड या कॉपी करके अपने पास रखें।',
                      ),
                    )
                  else if (s.signedIn) ...[
                    Text('${s.client!.auth.currentUser!.email}'),
                    const SizedBox(height: 12),
                    Tag(
                      s.syncing
                          ? s.t('Syncing…', 'सिंक हो रहा है…')
                          : s.status == 'synced'
                          ? s.t('Saved online', 'ऑनलाइन सहेजा')
                          : s.t(
                              'Saved here · sync pending',
                              'यहाँ सहेजा · सिंक बाकी',
                            ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton(
                          onPressed: busy || s.syncing ? null : () => s.sync(),
                          child: Text(s.t('Sync now', 'अभी सिंक करें')),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => act(
                                  s.signOut,
                                  s.t('Signed out', 'साइन आउट हुआ'),
                                ),
                          child: Text(s.t('Sign out', 'साइन आउट')),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      s.t(
                        'We send a one-time code. Signing in stores your tool inputs and checklist in your private account.',
                        'हम एक बार इस्तेमाल का कोड भेजते हैं। साइन इन करने से टूल इनपुट और चेकलिस्ट आपके निजी खाते में सहेजे जाते हैं।',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: email,
                      enabled: !sent,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: s.t('Email address', 'ईमेल पता'),
                      ),
                    ),
                    if (sent) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: code,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: InputDecoration(
                          labelText: s.t(
                            'Email verification code',
                            'ईमेल सत्यापन कोड',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (sent) {
                                if (code.text.trim().isEmpty) return;
                                await act(
                                  () =>
                                      s.verifyOtp(sentEmail!, code.text.trim()),
                                  s.t(
                                    'Signed in. Your saved plan is ready.',
                                    'साइन इन हुआ। सहेजी योजना तैयार है।',
                                  ),
                                );
                              } else {
                                final e = email.text.trim();
                                if (!RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(e)) {
                                  message(
                                    context,
                                    s.t(
                                      'Enter a valid email address',
                                      'सही ईमेल पता दें',
                                    ),
                                  );
                                  return;
                                }
                                await act(
                                  () async {
                                    await s.sendOtp(e);
                                    sentEmail = e;
                                    setState(() => sent = true);
                                  },
                                  s.t(
                                    'Check your email for the code.',
                                    'कोड के लिए ईमेल देखें।',
                                  ),
                                );
                              }
                            },
                      child: Text(
                        busy
                            ? s.t('Please wait…', 'कृपया प्रतीक्षा करें…')
                            : sent
                            ? s.t(
                                'Verify & restore my plan',
                                'सत्यापित कर योजना खोलें',
                              )
                            : s.t('Send sign-in code', 'साइन इन कोड भेजें'),
                      ),
                    ),
                    if (sent)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => sent = false),
                        child: Text(
                          s.t(
                            'Change email / request a new code',
                            'ईमेल बदलें / नया कोड माँगें',
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => go(context, s, 'report'),
                    child: Text(
                      s.t('Open my report →', 'मेरी रिपोर्ट खोलें →'),
                    ),
                  ),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t(
                      'You control what you share',
                      'क्या साझा हो, आप तय करें',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t(
                      'We save calculator answers and progress locally. If you sign in, they are saved in Supabase under your account. We do not ask for document scans, Aadhaar or PAN numbers.',
                      'हम गणना के उत्तर और प्रगति स्थानीय तौर पर सहेजते हैं। साइन इन पर वे आपके Supabase खाते में सहेजे जाते हैं। हम दस्तावेज़ स्कैन, आधार या PAN नंबर नहीं माँगते।',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: s.consent,
                    onChanged: s.setConsent,
                    title: Text(
                      s.t(
                        'Help improve this research project',
                        'इस शोध परियोजना को बेहतर बनाने में मदद करें',
                      ),
                    ),
                    subtitle: Text(
                      s.t(
                        'Optional: record tool usage, active time, referral source and funnel steps. Uploaded only when signed in. No financial inputs in event properties.',
                        'वैकल्पिक: टूल उपयोग, सक्रिय समय, रेफ़रल स्रोत और प्रगति रिकॉर्ड करें। केवल साइन इन पर अपलोड। इवेंट में वित्तीय इनपुट नहीं।',
                      ),
                    ),
                  ),
                  Text(
                    s.t(
                      'Turning this off stops new research events and clears unsent events. Previously uploaded events remain until you delete your project data. CA sharing requires separate consent in a support request.',
                      'बंद करने से नए शोध इवेंट रुकते और न भेजे इवेंट मिटते हैं। पुराने अपलोड किए इवेंट परियोजना डेटा मिटाने तक रहते हैं। CA को साझा करने के लिए सहायता अनुरोध में अलग सहमति है।',
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  s.t(
                                    'Delete your project data?',
                                    'अपना परियोजना डेटा मिटाएँ?',
                                  ),
                                ),
                                content: Text(
                                  s.t(
                                    'This removes this account’s plan, research events, support requests and outcomes from the project, plus this device’s saved plan. Your sign-in account remains. This cannot be undone.',
                                    'इससे परियोजना से योजना, शोध इवेंट, सहायता अनुरोध और परिणाम तथा इस डिवाइस की योजना मिटेगी। साइन इन खाता रहेगा। इसे वापस नहीं लाया जा सकता।',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(s.t('Cancel', 'रद्द करें')),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(
                                      s.t('Delete data', 'डेटा मिटाएँ'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await act(
                                s.deleteData,
                                s.t(
                                  'Project data deleted',
                                  'परियोजना डेटा मिटाया गया',
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(
                      s.t(
                        'Delete my project data',
                        'मेरा परियोजना डेटा मिटाएँ',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t(
                      'Shared device? Download your report, then delete local data before leaving.',
                      'साझा डिवाइस? रिपोर्ट डाउनलोड कर जाने से पहले स्थानीय डेटा मिटाएँ।',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.replay_outlined, color: green, size: 32),
              const SizedBox(height: 16),
              Text(
                s.t('Revisit the welcome screens', 'वेलकम स्क्रीन फिर देखें'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                s.t(
                  'Go back through the "Get started" and language screens again. Your saved tools and progress are not affected.',
                  '"शुरू करें" और भाषा वाली स्क्रीन फिर से देखें। आपके सेव किए टूल और प्रगति पर कोई असर नहीं होगा।',
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await s.resetOnboarding();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/welcome', (route) => false);
                  }
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  s.t('Go to welcome screen', 'वेलकम स्क्रीन पर जाएँ'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SupportPage extends StatefulWidget {
  final AppStore s;
  const SupportPage(this.s, {super.key});
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final note = TextEditingController();
  String kind = 'workshop';
  bool consent = false, busy = false;
  String? submitted;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Heading(
          s.t(
            'YOU DON’T HAVE TO FIGURE IT OUT ALONE',
            'सब कुछ अकेले समझना ज़रूरी नहीं',
          ),
          s.t('A helping hand for the next step.', 'अगले कदम के लिए मदद।'),
          s.t(
            'Express interest in a Pune workshop or ask for onboarding guidance.',
            'पुणे कार्यशाला में रुचि बताएँ या पंजीकरण मार्गदर्शन माँगें।',
          ),
        ),
        ResponsiveRow(
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Request support', 'सहायता का अनुरोध'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: s.t('I would like…', 'मुझे चाहिए…'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'workshop',
                        child: Text(
                          s.t('Workshop updates', 'कार्यशाला की जानकारी'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'ca_referral',
                        child: Text(
                          s.t('A CA partner referral', 'CA पार्टनर से संपर्क'),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'guidance',
                        child: Text(
                          s.t('Help with my next step', 'अगले कदम में मदद'),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => kind = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: note,
                    maxLength: 1000,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: s.t('How can we help?', 'हम कैसे मदद करें?'),
                      hintText: s.t(
                        'Your category, city and the step you are stuck on. No sensitive documents.',
                        'श्रेणी, शहर और जहाँ आप अटके हैं। संवेदनशील दस्तावेज़ न दें।',
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: (v) => setState(() => consent = v ?? false),
                    title: Text(
                      s.t(
                        'The project may contact me about this request. For a CA referral, it may share my email and this note with a partner.',
                        'परियोजना इस अनुरोध पर मुझसे संपर्क कर सकती है। CA रेफ़रल के लिए मेरी ईमेल और यह नोट पार्टनर से साझा हो सकता है।',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!s.signedIn) {
                              go(context, s, 'account');
                              return;
                            }
                            if (!consent || note.text.trim().isEmpty) {
                              message(
                                context,
                                s.t(
                                  'Add a short note and consent to follow-up.',
                                  'छोटा नोट और संपर्क की सहमति दें।',
                                ),
                              );
                              return;
                            }
                            setState(() => busy = true);
                            try {
                              await s.requestHelp(
                                kind,
                                note.text.trim(),
                                consent,
                              );
                              setState(
                                () => submitted = s.t(
                                  'Request received. No workshop date or partner appointment is confirmed yet.',
                                  'अनुरोध मिला। कार्यशाला तिथि या पार्टनर नियुक्ति अभी तय नहीं है।',
                                ),
                              );
                            } catch (_) {
                              if (context.mounted) {
                                message(
                                  context,
                                  s.t(
                                    'Request not sent. Please retry when connected.',
                                    'अनुरोध नहीं भेजा गया। कनेक्शन होने पर फिर कोशिश करें।',
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: Text(
                      s.t(
                        s.signedIn
                            ? 'Submit request'
                            : 'Sign in to request support',
                        s.signedIn
                            ? 'अनुरोध भेजें'
                            : 'सहायता के लिए साइन इन करें',
                      ),
                    ),
                  ),
                  if (submitted != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        submitted!,
                        style: const TextStyle(
                          color: green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Panel(
              color: const Color(0xFFEEF2E6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t(
                      'Useful official starting points',
                      'उपयोगी आधिकारिक स्रोत',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SourceNote(
                    s,
                    s.t('GeM seller portal', 'GeM विक्रेता पोर्टल'),
                    gemSource,
                  ),
                  SourceNote(
                    s,
                    s.t(
                      'Udyam: free official MSME registration',
                      'उद्यम: मुफ़्त आधिकारिक MSME पंजीकरण',
                    ),
                    udyamSource,
                  ),
                  SourceNote(
                    s,
                    s.t(
                      'MSME CHAMPIONS: assistance and guidance',
                      'MSME CHAMPIONS: सहायता और मार्गदर्शन',
                    ),
                    'https://champions.gov.in/',
                  ),
                  const SizedBox(height: 20),
                  Text(
                    s.t(
                      'Workshops and CA availability will be confirmed by the project team. Submitting interest does not book a place or guarantee an order.',
                      'कार्यशाला और CA उपलब्धता परियोजना टीम तय करेगी। रुचि भेजने से सीट बुक या ऑर्डर की गारंटी नहीं होती।',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        NextActions(s, s.nextTool),
      ],
    );
  }
}
