import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';

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
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - 68),
            child: Column(
              children: [
                Image.asset(
                  'assets/brand_logo_notag.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),
                Image.asset(
                  'assets/welcome_illustration.png',
                  width: 280,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),
                Text(
                  store.t('A good place to begin.', 'शुरुआत के लिए अच्छी जगह।'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: sfProDisplay,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  store.t(
                    'Prepare your business for GeM, one step at a time.',
                    'एक-एक कदम में अपने व्यवसाय को GeM के लिए तैयार करें।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF737B84),
                  ),
                ),
                const SizedBox(height: 56),
                SizedBox(
                  width: double.infinity,
                  height: 66,
                  child: FilledButton(
                    onPressed: () => _goToLanguage(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF151515),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      store.t('Get started', 'शुरू करें'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
