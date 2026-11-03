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

