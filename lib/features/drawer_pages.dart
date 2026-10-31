import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'glass.dart';
import 'scroll_hint.dart';
import 'widgets.dart' show openLink;
import '../core/models.dart' show gemSource;

/// Six reference screens reached from the hamburger drawer rather than
/// the bottom nav — each a short, static explainer (not a calculator
/// or a live feed), so a single shared shell is enough: back button,
/// centred title, scrollable body capped at the same reading width
/// used by [InsightsPage]-style full screens.
class _DrawerPageScaffold extends StatelessWidget {
  final AppStore store;
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _DrawerPageScaffold({
    required this.store,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            GlassBar.top(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.sm,
                AppSpace.sm,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_ios_new,
                    tooltip: s.t('Back', 'वापस'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppText.title,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSize.tap),
                ],
              ),
            ),
            Expanded(
              child: ScrollMoreHint(
                builder: (context, controller) => SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.lg,
                    AppSpace.gutter,
                    80,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subtitle,
                            style: AppText.secondary(AppText.body),
                          ),
                          const SizedBox(height: AppSpace.xxl),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card of plain, non-interactive explainer rows (no checklist state,
/// no chevron) — used for the ordered "how this works" lists on these
/// pages, as distinct from the actionable [StatusItem] checklist in
/// [DocumentChecklistCard].
class _InfoList extends StatelessWidget {
  final List<(IconData, String, String)> rows;
  const _InfoList({required this.rows});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
    child: DividedList(
      children: [
        for (final (icon, title, subtitle) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
            child: AppListTile(icon: icon, title: title, subtitle: subtitle),
          ),
      ],
    ),
  );
}

/// The document-readiness checklist, shared between the GeM 101 tab and
/// its own drawer destination so the two don't drift apart.
class DocumentChecklistCard extends StatelessWidget {
  final AppStore store;
  const DocumentChecklistCard({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          tone: AppCardTone.muted,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: DividedList(
            children: [
              StatusItem(
                label: s.t('Identity & PAN', 'पहचान और PAN'),
                state: ItemState.done,
                trailing: s.t('Have', 'उपलब्ध'),
              ),
              StatusItem(
                label: s.t('Bank account details', 'बैंक खाता विवरण'),
                state: ItemState.attention,
                trailing: s.t('Needed', 'ज़रूरी'),
              ),
              StatusItem(
                label: s.t('GST registration', 'GST पंजीकरण'),
                state: ItemState.pending,
                trailing: s.t('Confirm', 'पुष्टि करें'),
              ),
              StatusItem(
                label: s.t('Udyam registration', 'उद्यम पंजीकरण'),
                state: ItemState.pending,
                trailing: s.t('Optional', 'वैकल्पिक'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          s.t(
            'Requirements vary by category and order value. Always verify the exact list for your case on the official GeM portal.',
            'आवश्यकताएँ श्रेणी और ऑर्डर मूल्य के अनुसार अलग होती हैं। अपने मामले के लिए सटीक सूची आधिकारिक GeM पोर्टल पर ज़रूर जाँचें।',
          ),
          style: AppText.caption,
        ),
        const SizedBox(height: AppSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: s.t('Open official GeM portal', 'आधिकारिक GeM पोर्टल खोलें'),
            onPressed: () => openLink(context, s, gemSource),
            variant: AppButtonVariant.tertiary,
            trailingIcon: Icons.open_in_new,
            expand: false,
            haptic: false,
          ),
        ),
      ],
    );
  }
}

class DocumentationsPage extends StatelessWidget {
  final AppStore store;
  const DocumentationsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return _DrawerPageScaffold(
      store: s,
      title: s.t('Documentations', 'दस्तावेज़'),
      subtitle: s.t(
        'What you typically need to register and start bidding.',
        'रजिस्टर करने और बोली शुरू करने के लिए आमतौर पर जो चाहिए।',
      ),
      children: [DocumentChecklistCard(store: s)],
    );
  }
}

class BidPreparationAssistancePage extends StatelessWidget {
  final AppStore store;
  const BidPreparationAssistancePage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return _DrawerPageScaffold(
      store: s,
      title: s.t('Bid Preparation Assistance', 'बोली तैयारी सहायता'),
      subtitle: s.t(
        'What to check before you apply for a bid.',
        'बोली लगाने से पहले क्या जाँचें।',
      ),
      children: [
        _InfoList(
          rows: [
            (
              Icons.rule_outlined,
              s.t('Eligibility & specifications', 'पात्रता और विनिर्देश'),
              s.t(
                'Match your offering to the exact technical specification and quantity.',
                'अपनी पेशकश को सटीक तकनीकी विनिर्देश और मात्रा से मिलाएँ।',
              ),
            ),
            (
              Icons.verified_outlined,
              s.t('Required certificates', 'आवश्यक प्रमाणपत्र'),
              s.t(
                'OEM authorisation, quality certificates or test reports the bid may ask for.',
                'OEM प्राधिकरण, गुणवत्ता प्रमाणपत्र या टेस्ट रिपोर्ट जो बोली माँग सकती है।',
              ),
            ),
            (
              Icons.account_balance_wallet_outlined,
              s.t('EMD / bid security', 'EMD / बोली प्रतिभूति'),
              s.t(
                'Check whether an earnest money deposit applies and how it is paid.',
                'जाँचें कि क्या बयाना राशि जमा लागू होती है और वह कैसे जमा होती है।',
              ),
            ),
            (
              Icons.local_shipping_outlined,
              s.t('Delivery timeline', 'डिलिवरी समयसीमा'),
              s.t(
                'Confirm you can meet the delivery period before you submit.',
                'सबमिट करने से पहले पुष्टि करें कि आप डिलिवरी अवधि पूरी कर सकते हैं।',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: AppListTile(
            icon: Icons.chat_bubble_outline,
            title: s.t('Ask BizReady', 'BizReady से पूछें'),
            subtitle: s.t(
              'Get clear answers about preparing for GeM.',
              'GeM की तैयारी के बारे में स्पष्ट जवाब पाएं।',
            ),
          ),
        ),
      ],
    );
  }
}

class BidCyclePage extends StatelessWidget {
  final AppStore store;
  const BidCyclePage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return _DrawerPageScaffold(
      store: s,
      title: s.t('Bid Cycle', 'बोली चक्र'),
      subtitle: s.t(
        'How a GeM bid moves from publish to award.',
        'एक GeM बोली प्रकाशन से अवार्ड तक कैसे बढ़ती है।',
      ),
      children: [
        _InfoList(
          rows: [
            (
              Icons.campaign_outlined,
              s.t('Bid published', 'बोली प्रकाशित'),
              s.t(
                'Buyer lists specifications, quantity and the last date to bid.',
                'खरीदार विनिर्देश, मात्रा और बोली की अंतिम तिथि सूचीबद्ध करता है।',
              ),
            ),
            (
              Icons.help_outline,
              s.t('Pre-bid queries', 'बोली-पूर्व प्रश्न'),
              s.t(
                'Sellers may ask clarifying questions before the deadline.',
                'विक्रेता अंतिम तिथि से पहले स्पष्टीकरण प्रश्न पूछ सकते हैं।',
              ),
            ),
            (
              Icons.upload_file_outlined,
              s.t('Bid submission', 'बोली प्रस्तुति'),
              s.t(
                'You submit your techno-commercial offer online before closing.',
                'आप बंद होने से पहले अपनी तकनीकी-वाणिज्यिक पेशकश ऑनलाइन जमा करते हैं।',
              ),
            ),
            (
              Icons.fact_check_outlined,
              s.t('Evaluation', 'मूल्यांकन'),
              s.t(
                'The buyer checks eligibility and compares the lowest eligible offer (L1).',
                'खरीदार पात्रता जाँचता है और सबसे कम योग्य पेशकश (L1) की तुलना करता है।',
              ),
            ),
            (
              Icons.emoji_events_outlined,
              s.t('Award', 'अवार्ड'),
              s.t(
                'The buyer places the order with the selected seller.',
                'खरीदार चयनित विक्रेता को ऑर्डर देता है।',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ExecutionPage extends StatelessWidget {
  final AppStore store;
  const ExecutionPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return _DrawerPageScaffold(
      store: s,
      title: s.t('Execution', 'निष्पादन'),
      subtitle: s.t(
        'What happens after you win an order.',
        'ऑर्डर जीतने के बाद क्या होता है।',
      ),
      children: [
        _InfoList(
          rows: [
            (
              Icons.description_outlined,
              s.t('Contract generation', 'अनुबंध निर्माण'),
              s.t(
                'A contract is generated automatically once the order is placed.',
                'ऑर्डर देने के बाद अनुबंध स्वतः बन जाता है।',
              ),
            ),
            (
              Icons.local_shipping_outlined,
              s.t('Supply & delivery', 'आपूर्ति और डिलिवरी'),
              s.t(
                'Supply the goods or services within the agreed timeline.',
                'सहमत समयसीमा के भीतर सामान या सेवाएँ आपूर्ति करें।',
              ),
            ),
            (
              Icons.search_outlined,
              s.t('Inspection', 'निरीक्षण'),
              s.t(
                'Some orders require a quality inspection before acceptance.',
                'कुछ ऑर्डरों में स्वीकृति से पहले गुणवत्ता निरीक्षण आवश्यक होता है।',
              ),
            ),
            (
              Icons.receipt_long_outlined,
              s.t('Invoice & receipt', 'इनवॉइस और रसीद'),
              s.t(
                'Raise the invoice and get the consignee receipt confirmed.',
                'इनवॉइस बनाएं और प्राप्तकर्ता की रसीद की पुष्टि कराएँ।',
              ),
            ),
            (
              Icons.payments_outlined,
              s.t('Payment release', 'भुगतान जारी'),
              s.t(
                'Payment is released after delivery and acceptance are confirmed.',
                'डिलिवरी और स्वीकृति की पुष्टि के बाद भुगतान जारी होता है।',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class EarningsDynamicsPage extends StatelessWidget {
  final AppStore store;
  const EarningsDynamicsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return _DrawerPageScaffold(
      store: s,
      title: s.t('Earnings Dynamics', 'कमाई गतिशीलता'),
      subtitle: s.t(
        'How revenue, margin and contribution relate on a GeM order.',
        'GeM ऑर्डर पर राजस्व, मार्जिन और योगदान का संबंध।',
      ),
      children: [
        _InfoList(
          rows: [
            (
              Icons.bar_chart_outlined,
              s.t('Revenue vs. margin', 'राजस्व बनाम मार्जिन'),
              s.t(
                'Revenue is the order value; margin is what remains after your cost of goods.',
                'राजस्व ऑर्डर मूल्य है; मार्जिन वह है जो आपकी वस्तु लागत के बाद बचता है।',
              ),
            ),
            (
              Icons.calculate_outlined,
              s.t('Contribution, not profit', 'योगदान, लाभ नहीं'),
              s.t(
                'Contribution subtracts fees and delivery cost, but not overheads, tax or financing cost.',
                'योगदान में फीस और डिलिवरी लागत घटाई जाती है, पर ओवरहेड, कर या वित्तपोषण लागत नहीं।',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          s.t(
            'See your own numbers in the Finance tab\'s ROI calculator.',
            'फाइनेंस टैब के ROI कैलकुलेटर में अपने आँकड़े देखें।',
          ),
          style: AppText.bodySmall,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          s.t(
            'Estimates are illustrative only — payment delay, financing cost, and tax are not modelled.',
            'अनुमान केवल उदाहरण के लिए हैं — भुगतान में देरी, वित्तपोषण लागत और कर शामिल नहीं हैं।',
          ),
          style: AppText.caption,
        ),
      ],
    );
  }
}

class FinancingPage extends StatelessWidget {
  final AppStore store;
  const FinancingPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return _DrawerPageScaffold(
      store: s,
      title: s.t('Financing', 'वित्तपोषण'),
      subtitle: s.t(
        'Planning the cash-flow side of a government order.',
        'सरकारी ऑर्डर के नकदी-प्रवाह पक्ष की योजना बनाना।',
      ),
      children: [
        _InfoList(
          rows: [
            (
              Icons.schedule_outlined,
              s.t('Payment timing', 'भुगतान समय'),
              s.t(
                'GeM payments are typically released after delivery and inspection are confirmed — not on order date.',
                'GeM भुगतान आमतौर पर डिलिवरी और निरीक्षण की पुष्टि के बाद जारी होता है — ऑर्डर की तारीख पर नहीं।',
              ),
            ),
            (
              Icons.account_balance_wallet_outlined,
              s.t('Working capital gap', 'कार्यशील पूंजी अंतर'),
              s.t(
                'Budget for the cost of goods and delivery before payment arrives.',
                'भुगतान आने से पहले वस्तु और डिलिवरी लागत के लिए बजट बनाएं।',
              ),
            ),
            (
              Icons.savings_outlined,
              s.t('Government schemes', 'सरकारी योजनाएं'),
              s.t(
                'MSEs can explore schemes like CGTMSE collateral-free credit; eligibility and terms are set by the scheme, not by this app.',
                'MSE CGTMSE जैसी बिना गारंटी वाली ऋण योजनाएँ देख सकते हैं; पात्रता और शर्तें योजना द्वारा तय होती हैं, इस ऐप द्वारा नहीं।',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          s.t(
            'Confirm current scheme terms with your bank or the scheme administrator.',
            'वर्तमान योजना शर्तों की पुष्टि अपने बैंक या योजना प्रशासक से करें।',
          ),
          style: AppText.caption,
        ),
      ],
    );
  }
}
