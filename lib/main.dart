import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/models.dart';
import 'core/theme.dart';
import 'data/app_store.dart';
import 'features/gem_check_page.dart';
import 'features/language_page.dart';
import 'features/onboarding_flow_1.dart';
import 'features/onboarding_flow_2.dart';
import 'features/onboarding_flow_3.dart';
import 'features/onboarding_flow_4.dart';
import 'features/shell.dart';
import 'features/welcome_page.dart';

/// The 15-step "not yet on GeM" readiness walkthrough, keyed by route
/// name. Kept as a lookup table rather than another long ternary chain.
final Map<String, Widget Function(AppStore)> flowPages = {
  'flow-name': (s) => FlowFullNamePage(store: s),
  'flow-phone': (s) => FlowPhonePage(store: s),
  'flow-otp': (s) => FlowOtpPage(store: s),
  'flow-location': (s) => FlowLocationPage(store: s),
  'flow-bizname': (s) => FlowBusinessNamePage(store: s),
  'flow-bizform': (s) => FlowBusinessFormPage(store: s),
  'flow-sector': (s) => FlowSectorPage(store: s),
  'flow-role': (s) => FlowRolePage(store: s),
  'flow-authorised': (s) => FlowAuthorisedPage(store: s),
  'flow-privacy': (s) => FlowPrivacyPage(store: s),
  'flow-records': (s) => FlowRecordsPage(store: s),
  'flow-pan': (s) => FlowPanPage(store: s),
  'flow-checklist': (s) => FlowChecklistPage(store: s),
  'flow-video': (s) => FlowVideoPage(store: s),
  'flow-redirect': (s) => FlowRedirectPage(store: s),
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  SupabaseClient? client;
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      client = Supabase.instance.client;
    } catch (_) {
      /* Local tools stay available if configuration is invalid. */
    }
  }
  final store = AppStore(await SharedPreferences.getInstance(), client: client);
  runApp(SaathiApp(store: store));
  unawaited(store.initialize());
}

class SplashGate extends StatefulWidget {
  final AppStore store;
  const SplashGate({super.key, required this.store});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    // Shown for a beat, then hands off to onboarding (new user) or
    // straight into the app (returning user) — never shown again itself.
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        widget.store.hasOnboarded ? '/home' : '/welcome',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image(
          image: AssetImage('assets/splash_screen.png'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class SaathiApp extends StatelessWidget {
  final AppStore store;
  const SaathiApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => MaterialApp(
      title: 'GeM BizReady',
      debugShowCheckedModeBanner: false,
      theme: saathiTheme(),
      locale: Locale(store.language),
      supportedLocales: [
        for (final lang in supportedLanguages) Locale(lang[0]),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: SplashGate(store: store),
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (context) {
              final page = (settings.name ?? '/').replaceFirst('/', '').split('?').first;
          return ListenableBuilder(
            listenable: store,
            builder: (context, _) => flowPages.containsKey(page)
                ? flowPages[page]!(store)
                : page.isEmpty || page == 'home'
                ? AppShell(store: store, page: '')
                : page == 'welcome'
                ? WelcomePage(store: store)
                : page == 'language'
                ? LanguagePage(store: store)
                : page == 'gem-check'
                ? GemCheckPage(store: store)
                : AppShell(store: store, page: page),
          );
        },
      ),
    ),
  );
}
