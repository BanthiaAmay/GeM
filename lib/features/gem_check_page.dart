import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'components.dart';
import 'glass.dart';
import 'onboarding_widgets.dart';
import 'scroll_hint.dart';

/// Onboarding step shown right after language selection: a quick check
/// on whether the seller's business is already listed on GeM. Purely
/// informational today — it just records [AppStore.alreadyOnGem] — but
/// nothing else in the flow branches on the answer yet.
class GemCheckPage extends StatefulWidget {
  final AppStore store;
  const GemCheckPage({super.key, required this.store});

  @override
  State<GemCheckPage> createState() => _GemCheckPageState();
}

class _GemCheckPageState extends State<GemCheckPage> {
  late bool selected = widget.store.alreadyOnGem;

  void back() => Navigator.of(context).canPop()
      ? Navigator.of(context).pop()
      : Navigator.of(context).pushReplacementNamed('/language');

  void continueToApp() {
    widget.store.setAlreadyOnGem(selected);
    // Both answers share the first 11 steps (name through business
    // documentation). Already-on-GeM users stop there; not-yet users
    // continue on into PAN check, the readiness checklist, the video
    // guide, and the redirect — see FlowRecordsPage's onContinue.
    Navigator.of(context).pushNamed('/flow-name');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            GlassBar.top(
              child: Row(
                children: [
                  AppIconButton(
                    onPressed: back,
                    icon: Icons.arrow_back_ios_new,
                    tooltip: s.t('Back', 'वापस'),
                  ),
                  const Expanded(
                    child: Center(
                      child: BrandLogo(
                        variant: BrandLogoVariant.lockup,
                        width: 150,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ScrollMoreHint(
                builder: (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.xl,
                    AppSpace.gutter,
                    60,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppProgressBar(value: 0.55),
                      const SizedBox(height: 28),
                      Text(
                        s.t('Your business', 'आपका व्यवसाय'),
                        style: AppText.secondary(AppText.bodySmall),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        s.t('ONE QUICK CHECK', 'एक जल्दी जाँच'),
                        style: AppText.overline,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.t(
                          'Is your business already on GeM?',
                          'क्या आपका व्यवसाय पहले से GeM पर है?',
                        ),
                        style: AppText.h1,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s.t(
                          'We’ll guide you to the right next step.',
                          'हम आपको सही अगले कदम तक मार्गदर्शन देंगे।',
                        ),
                        style: AppText.secondary(AppText.body),
                      ),
                      const SizedBox(height: 32),
                      _CheckOption(
                        asset: 'check_no',
                        slot: 84,
                        trailingIcon: Icons.circle_outlined,
                        label: s.t('No', 'नहीं'),
                        selected: !selected,
                        onTap: () => setState(() => selected = false),
                      ),
                      const SizedBox(height: 14),
                      _CheckOption(
                        asset: 'check_yes',
                        slot: 114,
                        trailingIcon: Icons.check_circle_outline,
                        label: s.t('Yes', 'हाँ'),
                        selected: selected,
                        onTap: () => setState(() => selected = true),
                      ),
                      const OnboardingArt('gemcheck', topGap: 40),
                    ],
                  ),
                ),
              ),
            ),
            GlassBar.bottom(
              child: AppButton(
                label: s.t('Continue', 'जारी रखें'),
                onPressed: continueToApp,
                size: AppButtonSize.lg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckOption extends StatelessWidget {
  final String asset;
  final double slot;
  final IconData trailingIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CheckOption({
    required this.asset,
    required this.slot,
    required this.trailingIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? AppColors.ink : AppColors.borderStrong,
          width: selected ? 1.4 : 1,
        ),
        borderRadius: AppRadius.input,
        color: selected ? AppColors.surfaceMuted : AppColors.surface,
      ),
      child: Row(
        children: [
          OnboardingIcon(icon: null, asset: asset, slot: slot),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.h3)),
          Icon(
            trailingIcon,
            size: 24,
            color: selected ? AppColors.ink : AppColors.borderStrong,
          ),
        ],
      ),
    ),
  );
}
