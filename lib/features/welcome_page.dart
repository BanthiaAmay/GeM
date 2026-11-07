import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'components.dart';
import 'fact_deck.dart';
import 'glass.dart';
import 'scroll_hint.dart';

/// Shown once, right after the splash screen, only for a user who has
/// never completed onboarding on this device. Returning users skip
/// straight past this (see [AppStore.hasOnboarded] and `SplashGate`).
class WelcomePage extends StatelessWidget {
  final AppStore store;
  const WelcomePage({super.key, required this.store});

  void _goToLanguage(BuildContext context) =>
      // Pushed (not replaced) so the language page's back button has
      // this welcome screen to return to.
      Navigator.of(context).pushNamed('/language');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ScrollMoreHint(
                builder: (context, scrollController) => SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.sm,
                    AppSpace.gutter,
                    AppSpace.gutter,
                  ),
                  child: Column(
                    children: [
                      const Hero(
                        tag: 'brand-logo',
                        child: BrandLogo(
                          variant: BrandLogoVariant.full,
                          width: 170,
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      FactDeck(store: store),
                      const SizedBox(height: AppSpace.xxl),
                      Text(
                        store.t(
                          'Your shop.\nNationwide.',
                          'आपकी दुकान।\nपूरे देश में।',
                        ),
                        textAlign: TextAlign.center,
                        style: AppText.display,
                      ),
                      const SizedBox(height: AppSpace.md),
                      Text(
                        store.t(
                          'Get your business ready for GeM—and reach buyers across India.',
                          'अपने व्यवसाय को GeM के लिए तैयार करें—और पूरे भारत में खरीदारों तक पहुँचें।',
                        ),
                        textAlign: TextAlign.center,
                        style: AppText.lead,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            FloatingActionArea(
              child: AppButton(
                label: store.t('Get started', 'शुरू करें'),
                trailingIcon: Icons.arrow_forward,
                onPressed: () => _goToLanguage(context),
                size: AppButtonSize.lg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
