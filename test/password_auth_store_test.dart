import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gem/data/app_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryAuthStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late SupabaseClient client;
  late AppStore store;
  late List<http.Request> requests;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    requests = [];
    client = SupabaseClient(
      'https://auth-test.example',
      'test-public-key',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryAuthStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/token')) {
          return http.Response(
            jsonEncode({
              'code': 'invalid_credentials',
              'msg': 'Invalid login credentials',
            }),
            400,
            headers: {'x-supabase-api-version': '2024-01-01'},
          );
        }
        if (request.url.path.endsWith('/signup')) {
          return http.Response(
            jsonEncode({
              'id': 'test-user',
              'aud': 'authenticated',
              'email': 'seller@example.com',
              'created_at': '2026-11-05T00:00:00Z',
              'app_metadata': {},
              'user_metadata': {},
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );
    store = AppStore(prefs, client: client);
  });

  tearDown(() async {
    store.dispose();
    await client.dispose();
  });

  test(
    'password signup awaits confirmation and never persists the password',
    () async {
      const password = ' Secret-password1! ';
      expect(
        await store.signUpWithPassword(' seller@example.com ', password),
        isTrue,
      );
      expect(store.signedIn, isFalse);
      final request = requests.single;
      expect(request.url.path, '/auth/v1/signup');
      final body = jsonDecode(request.body) as Map;
      expect(body['email'], 'seller@example.com');
      expect(body['password'], password); // Preserve intentional spaces.
      await store.persist();
      for (final key in prefs.getKeys()) {
        expect(prefs.get(key).toString(), isNot(contains(password)));
      }
    },
  );

  test(
    'password login uses the password grant and preserves auth errors',
    () async {
      await expectLater(
        store.signInWithPassword(' seller@example.com ', 'old-password'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
      final request = requests.single;
      expect(request.url.queryParameters['grant_type'], 'password');
      final body = jsonDecode(request.body) as Map;
      expect(body['email'], 'seller@example.com');
      expect(body['password'], 'old-password');
      expect(store.signedIn, isFalse);
    },
  );

  test(
    'password recovery cannot create an account and signup resend uses signup type',
    () async {
      await store.sendPasswordReset(' seller@example.com ');
      var body = jsonDecode(requests.single.body) as Map;
      expect(requests.single.url.path, '/auth/v1/otp');
      expect(body['create_user'], isFalse);
      expect(body['email'], 'seller@example.com');
      requests.clear();
      await store.resendSignupCode(' seller@example.com ');
      body = jsonDecode(requests.single.body) as Map;
      expect(requests.single.url.path, '/auth/v1/resend');
      expect(body['type'], 'signup');
    },
  );
}
