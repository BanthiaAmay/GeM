import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/phone.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/account_page.dart';
import 'package:gem/features/alerts_page.dart';
import 'package:gem/features/gem_guide_page.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:gem/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthTestStore extends AppStore {
  AuthTestStore(super.prefs);
  bool authenticated = false;
  int otpRequests = 0;
  bool? createsUser;
  String? verifiedCode;
  bool? savedConsent;
  bool failContactSave = false;
  @override
  bool get configured => true;
  @override
  bool get signedIn => authenticated;
  @override
  User? get currentUser => authenticated
      ? User(
          id: 'test-user',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '',
          email: 'seller@example.com',
        )
      : null;
  @override
  Future<void> sendOtp(String email, {bool shouldCreateUser = true}) async {
    otpRequests++;
    createsUser = shouldCreateUser;
  }

  @override
  Future<void> verifyOtp(String email, String token) async {
    verifiedCode = token;
    authenticated = true;
    notifyListeners();
  }

  @override
  Future<void> saveAlertPreferences({
    required String phone,
    required bool whatsapp,
    bool inApp = true,
    List<String> keywords = const [],
    List<String> states = const [],
  }) async {
    if (failContactSave) throw StateError('Alert setup is not deployed');
    savedConsent = whatsapp;
    alertPreferences = {
      'whatsapp_number': normalizeWhatsapp(phone),
      'whatsapp_opt_in': whatsapp,
      'in_app_enabled': inApp,
      'keywords': keywords,
      'states': states,
    };
    notifyListeners();
  }

  @override
  Future<void> loadAlerts() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ScrollMoreHint.debugDisableBounce = true;
  late AuthTestStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = AuthTestStore(await SharedPreferences.getInstance());
  });
  Future<void> boot(WidgetTester tester, {bool entry = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        routes: {
          '/language': (_) => const Scaffold(body: Text('GeM preparation')),
        },
        home: AccountPage(store: store, entry: entry),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'welcome and language lead to app signup before the GeM question',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      store.failContactSave = true;
      await tester.pumpWidget(SaathiApp(store: store, ready: Future.value()));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tap(tester, 'Get started');
      await tap(tester, 'Continue');
      expect(find.text('Your next chapter\nstarts on GeM.'), findsOneWidget);
      expect(find.text('Is your business already on GeM?'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).first,
        'seller@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('whatsapp-number')),
        '9876543210',
      );
      await tap(tester, 'Email me a code');
      await tester.enterText(find.byType(TextField).last, '123456');
      await tap(tester, 'Verify and sign in');
      expect(store.authenticated, isTrue);
      expect(find.text('Is your business already on GeM?'), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
      await tap(tester, 'Continue');
      await tester.enterText(find.byType(TextField).first, 'Vijay Kumar');
      await tester.pumpAndSettle();
      await tap(tester, 'Continue');
      expect(find.text('Where is your business based?'), findsOneWidget);
      expect(find.text('Enter your code'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('direct GeM routes require app authentication', (tester) async {
    await tester.pumpWidget(SaathiApp(store: store, ready: Future.value()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushNamed('/gem-check');
    await tester.pumpAndSettle();
    expect(find.text('Email me a code'), findsOneWidget);
    expect(find.text('Is your business already on GeM?'), findsNothing);
  });

  testWidgets('returning signed-out users sign in before reopening Home', (
    tester,
  ) async {
    await store.completeOnboarding();
    await tester.pumpWidget(SaathiApp(store: store, ready: Future.value()));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Email me a code'), findsOneWidget);
    await tap(tester, 'Log in');
    await tester.enterText(
      find.byType(TextFormField).first,
      'seller@example.com',
    );
    await tap(tester, 'Email me a code');
    await tester.enterText(find.byType(TextField).last, '123456');
    await tap(tester, 'Verify and sign in');
    expect(find.text('Hello.'), findsOneWidget);
    expect(find.text('Is your business already on GeM?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('WhatsApp numbers normalize without claiming verification', () {
    expect(normalizeWhatsapp('98765 43210'), '+919876543210');
    expect(normalizeWhatsapp('+91 (98765) 43210'), '+919876543210');
    for (final v in [
      '1234567890',
      '+1 9876543210',
      '98765432100',
      '98765hello43210',
      '',
    ]) {
      expect(normalizeWhatsapp(v), isNull, reason: v);
    }
  });

  testWidgets(
    'signup validates phone, supports longer OTP and saves consent off',
    (tester) async {
      await boot(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        'seller@example.com',
      );
      await tap(tester, 'Email me a code');
      expect(store.otpRequests, 0);
      await tester.enterText(
        find.byKey(const ValueKey('whatsapp-number')),
        '9876543210',
      );
      await tap(tester, 'Email me a code');
      expect(store.createsUser, isTrue);
      await tester.enterText(find.byType(TextField).last, '12345678');
      await tap(tester, 'Verify and sign in');
      expect(store.verifiedCode, '12345678');
      expect(store.alertPreferences['whatsapp_number'], '+919876543210');
      expect(store.savedConsent, isFalse);
      expect(find.text('GeM preparation'), findsNothing);
      expect(find.text('Sync now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'login requests an existing account without a signup phone field',
    (tester) async {
      await boot(tester, entry: false);
      expect(find.byKey(const ValueKey('whatsapp-number')), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).first,
        'seller@example.com',
      );
      await tap(tester, 'Email me a code');
      expect(store.createsUser, isFalse);
    },
  );

  testWidgets('Google signup is hidden while email signup remains available', (
    tester,
  ) async {
    store.googleAvailable = true;
    await boot(tester);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Email me a code'), findsOneWidget);
    expect(store.authenticated, isFalse);
  });

  testWidgets(
    'email sign-in succeeds even when WhatsApp storage is unavailable',
    (tester) async {
      store.failContactSave = true;
      await boot(tester);
      await tester.enterText(
        find.byType(TextFormField).first,
        'seller@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('whatsapp-number')),
        '9876543210',
      );
      await tap(tester, 'Email me a code');
      await tester.enterText(find.byType(TextField).last, '123456');
      await tap(tester, 'Verify and sign in');
      expect(store.authenticated, isTrue);
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.text('Where should we reach you?'), findsNothing);
      expect(find.text('GeM preparation'), findsNothing);
      expect(store.profile['whatsappNumber'], '+919876543210');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('existing email users do not have a mandatory contact step', (
    tester,
  ) async {
    store.authenticated = true;
    await boot(tester, entry: false);
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Where should we reach you?'), findsNothing);
    expect(find.text('GeM preparation'), findsNothing);
  });

  testWidgets('auth fits a narrow phone at large text size', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AccountPage(store: store, entry: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Email me a code'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('GeM guide resumes checks without official registration claims', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: GemGuidePage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Get your details ready');
    expect(store.profile['gemGuide'][0], isTrue);
    expect(find.text('1 of 5 steps checked by you'), findsOneWidget);
    expect(store.alreadyOnGem, isFalse);
  });

  testWidgets('Updates shows no fabricated matches for a guest', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: AlertsPage(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to set alerts'), findsOneWidget);
    expect(find.text('Office stationery supplies'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
