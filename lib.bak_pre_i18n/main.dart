import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'data/app_store.dart';
import 'features/language_page.dart';
import 'features/shell.dart';
import 'features/welcome_page.dart';

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
      locale: Locale(store.hi ? 'hi' : 'en'),
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: SplashGate(store: store),
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (context) {
              final page = (settings.name ?? '/').replaceFirst('/', '').split('?').first;
          return ListenableBuilder(
            listenable: store,
            builder: (context, _) => page.isEmpty || page == 'home'
                ? AppShell(store: store, page: '')
                : page == 'welcome'
                ? WelcomePage(store: store)
                : page == 'language'
                ? LanguagePage(store: store)
                : AppShell(store: store, page: page),
          );
        },
      ),
    ),
  );
}
