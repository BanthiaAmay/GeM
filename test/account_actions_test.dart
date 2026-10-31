import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/features/home_page.dart';
import 'package:gem/features/scroll_hint.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/authenticated_journey_store.dart';

class AccountStore extends AuthenticatedJourneyStore {
  AccountStore(super.prefs);
  int signOuts = 0, deletions = 0;
  @override
  Future<void> signOut() async => signOuts++;
  @override
  Future<void> deleteAccount() async => deletions++;
}

void main() {
  ScrollMoreHint.debugDisableBounce = true;

  Future<AccountStore> openProfile(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final s = AccountStore(await SharedPreferences.getInstance());
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: HomePage(store: s),
        routes: {
          '/onboarding-auth': (_) => const Scaffold(body: Text('Sign-in screen')),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    return s;
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets('sign out asks first, then returns to sign-in', (tester) async {
    final s = await openProfile(tester);
    await tap(tester, 'Sign out');
    expect(find.text('Sign out?'), findsOneWidget);
    await tap(tester, 'Cancel');
    expect(s.signOuts, 0);
    await tap(tester, 'Sign out');
    await tap(tester, 'Sign out'); // The dialog's confirm button.
    expect(s.signOuts, 1);
    expect(find.text('Sign-in screen'), findsOneWidget);
  });

  testWidgets('delete account asks first, then returns to sign-in', (
    tester,
  ) async {
    final s = await openProfile(tester);
    await tap(tester, 'Delete my account');
    expect(find.text('Delete your account?'), findsOneWidget);
    await tap(tester, 'Delete account');
    expect(s.deletions, 1);
    expect(find.text('Sign-in screen'), findsOneWidget);
  });
}
