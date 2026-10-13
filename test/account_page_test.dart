import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gem/core/theme.dart';
import 'package:gem/data/app_store.dart';
import 'package:gem/features/account_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('account page explains when Supabase config is absent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      MaterialApp(
        theme: saathiTheme(),
        home: AccountPage(store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Save your progress'), findsOneWidget);
    expect(find.text('Sign-in is not configured'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
