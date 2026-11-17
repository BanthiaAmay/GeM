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

http.Response _signedInTokenResponse(http.Request request) => http.Response(
  jsonEncode({
    'access_token': 'test-access-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'test-refresh-token',
    'user': {
      'id': 'seller-1',
      'aud': 'authenticated',
      'email': 'seller@example.com',
      'created_at': '2026-11-05T00:00:00Z',
      'app_metadata': {},
      'user_metadata': {},
    },
  }),
  200,
  request: request,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Phase 3B: getAnalyticsDatum unit tests
  // ---------------------------------------------------------------------------
  group('getAnalyticsDatum', () {
    late SharedPreferences prefs;
    late AppStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = AppStore(prefs, client: null);
    });

    tearDown(() => store.dispose());

    test('returns empty map when no data exists for sourceId', () {
      final result = store.getAnalyticsDatum('GEM/NONEXISTENT');
      expect(result, isEmpty);
      expect(result, isA<Map<String, dynamic>>());
    });

    test('merges correctly when partial data saved twice', () async {
      await store.saveAnalyticsDatum('GEM/MERGE', {'procurement_cost': 100});
      await store.saveAnalyticsDatum('GEM/MERGE', {'selling_price': 500});
      final result = store.getAnalyticsDatum('GEM/MERGE');
      // Both keys should be present after two separate saves
      expect(result['procurement_cost'], 100);
      expect(result['selling_price'], 500);
    });

    test('later save overwrites same key', () async {
      await store.saveAnalyticsDatum('GEM/OVERWRITE', {'procurement_cost': 100});
      await store.saveAnalyticsDatum('GEM/OVERWRITE', {'procurement_cost': 999});
      final result = store.getAnalyticsDatum('GEM/OVERWRITE');
      expect(result['procurement_cost'], 999);
    });
  });

  // ---------------------------------------------------------------------------
  // Original persistence tests
  // ---------------------------------------------------------------------------

  group('saveAnalyticsDatum — not signed in', () {
    late SharedPreferences prefs;
    late AppStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      store = AppStore(prefs, client: null);
    });

    tearDown(() => store.dispose());

    test(
      'updates in-memory data and marks status local, returns false',
      () async {
        final ok = await store.saveAnalyticsDatum('GEM/1', {
          'procurement_cost': 100,
          'selling_price': 500,
        });
        expect(ok, isFalse);
        expect(store.analyticsSyncStatus['GEM/1'], AnalyticsSyncStatus.local);
        expect(store.getAnalyticsDatum('GEM/1')['procurement_cost'], 100);
        expect(store.getAnalyticsDatum('GEM/1')['selling_price'], 500);
      },
    );

    test(
      'data saved while not signed in survives a later read (simulated '
      'tab switch / rebuild) without any network round trip',
      () async {
        await store.saveAnalyticsDatum('GEM/2', {'procurement_cost': 42});
        // Simulate the Financial tab widget being disposed and recreated
        // (e.g. switching tabs) by just reading the store fresh, exactly
        // as _fillControllersFromStore does on initState.
        final reread = store.getAnalyticsDatum('GEM/2');
        expect(reread['procurement_cost'], 42);
      },
    );
  });

  group('saveAnalyticsDatum — signed in', () {
    late SharedPreferences prefs;
    late SupabaseClient client;
    late AppStore store;
    bool failUpsert = false;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      failUpsert = false;
      client = SupabaseClient(
        'https://auth-test.example',
        'test-public-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: MemoryAuthStorage(),
        ),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/token')) {
            return _signedInTokenResponse(request);
          }
          if (request.url.path.contains('tender_analytics_data')) {
            if (failUpsert) {
              return http.Response(
                jsonEncode({'message': 'simulated upsert failure'}),
                500,
                request: request,
              );
            }
            return http.Response('[]', 201, request: request);
          }
          return http.Response('{}', 200, request: request);
        }),
      );
      store = AppStore(prefs, client: client);
      await store.signInWithPassword('seller@example.com', 'password123');
      expect(store.signedIn, isTrue);
    });

    tearDown(() async {
      store.dispose();
      await client.dispose();
    });

    test('successful upsert returns true and marks status synced', () async {
      final ok = await store.saveAnalyticsDatum('GEM/3', {
        'procurement_cost': 200,
      });
      expect(ok, isTrue);
      expect(store.analyticsSyncStatus['GEM/3'], AnalyticsSyncStatus.synced);
      expect(store.getAnalyticsDatum('GEM/3')['procurement_cost'], 200);
    });

    test(
      'failed upsert returns false, marks status failed, and preserves '
      'the in-memory data instead of reverting it',
      () async {
        failUpsert = true;
        final ok = await store.saveAnalyticsDatum('GEM/4', {
          'procurement_cost': 300,
          'selling_price': 900,
        });
        expect(ok, isFalse);
        expect(store.analyticsSyncStatus['GEM/4'], AnalyticsSyncStatus.failed);
        // The data the user entered is still there — a failed cloud
        // write must never erase what's on the device.
        expect(store.getAnalyticsDatum('GEM/4')['procurement_cost'], 300);
        expect(store.getAnalyticsDatum('GEM/4')['selling_price'], 900);
      },
    );

    test(
      'a retry after a transient failure can still succeed and update '
      'status to synced without losing the original values',
      () async {
        failUpsert = true;
        var ok = await store.saveAnalyticsDatum('GEM/5', {
          'procurement_cost': 150,
        });
        expect(ok, isFalse);
        expect(store.analyticsSyncStatus['GEM/5'], AnalyticsSyncStatus.failed);

        failUpsert = false;
        ok = await store.saveAnalyticsDatum('GEM/5', {'procurement_cost': 150});
        expect(ok, isTrue);
        expect(store.analyticsSyncStatus['GEM/5'], AnalyticsSyncStatus.synced);
        expect(store.getAnalyticsDatum('GEM/5')['procurement_cost'], 150);
      },
    );
  });
}
