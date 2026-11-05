// App side of the App Store screenshot run (tool/screenshots.sh).
//
// Starts the real app as a signed-in demo seller with live public data (GeM
// bids and videos from Supabase, read with the publishable key only). The
// host script asks for each screen by route name over flutter_driver and then
// takes a real simulator screenshot. Nothing is written to Supabase: the demo
// account exists only in this process and its cloud sync is switched off.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DemoStore extends AppStore {
  _DemoStore(super.prefs, {super.client});
  @override
  bool get signedIn => true;
  @override
  User get currentUser => User(
    id: '00000000-0000-0000-0000-000000000000',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '',
  );
  @override
  Future<void> initialize() async {}
  @override
  Future<void> sync() async {}
}

Future<void> main() async {
  final navigator = GlobalKey<NavigatorState>();
  enableFlutterDriverExtension(
    handler: (route) async {
      final nav = navigator.currentState!;
      nav.popUntil((r) => r.settings.name == '/home' || r.isFirst);
      if (route != null && route != '/home') unawaited(nav.pushNamed(route));
      return 'ok';
    },
  );
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  await Supabase.initialize(url: url, publishableKey: key);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('saathi.v1.onboarded', true);
  await prefs.setBool('saathi.v1.seenGreetingIntro', true);
  final store = _DemoStore(prefs, client: Supabase.instance.client);
  store.data = {
    ...store.data,
    'language': 'en',
    'profile': {
      ...store.profile,
      'fullName': 'Priya Sharma',
      'businessName': 'Sharma Office Supplies',
    },
  };
  runApp(
    SaathiApp(store: store, ready: Future.value(), navigatorKey: navigator),
  );
}
