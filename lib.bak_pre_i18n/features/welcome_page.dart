import 'package:flutter/material.dart';
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
                  'assets/brand_logo.png',
                  width: 260,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 64),
                Text(
                  store.t(
                    'A clearer path to GeM.',
                    'GeM के लिए एक स्पष्ट रास्ता।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  store.t(
                    'Learn, prepare, and move forward with confidence.',
                    'सीखें, तैयारी करें, और आत्मविश्वास के साथ आगे बढ़ें।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    color: Color(0xFF737B84),
                  ),
                ),
                const SizedBox(height: 96),
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
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => _goToLanguage(context),
                  child: Text(
                    store.t('Choose language', 'भाषा चुनें'),
                    style: const TextStyle(
                      fontSize: 17,
                      color: Colors.black,
                      decoration: TextDecoration.underline,
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
