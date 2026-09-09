import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'data/app_store.dart';
import 'features/shell.dart';

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

class SaathiApp extends StatelessWidget {
  final AppStore store;
  const SaathiApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => MaterialApp(
      title: 'GeM Saathi',
      debugShowCheckedModeBanner: false,
      theme: saathiTheme(),
      locale: Locale(store.hi ? 'hi' : 'en'),
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: '/',
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (context) => ListenableBuilder(
          listenable: store,
          builder: (context, _) => AppShell(
            store: store,
            page: (settings.name ?? '/').replaceFirst('/', '').split('?').first,
          ),
        ),
      ),
    ),
  );
}
