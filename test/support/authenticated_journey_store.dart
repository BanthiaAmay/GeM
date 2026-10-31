import 'package:gem/data/app_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Business-question tests start after app authentication. Auth routing itself
/// is covered with signed-out and verified sessions in auth_flow_test.dart.
class AuthenticatedJourneyStore extends AppStore {
  AuthenticatedJourneyStore(super.prefs);
  @override
  bool get signedIn => true;
  @override
  User get currentUser => User(
    id: 'journey-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '',
  );
  @override
  Future<void> initialize() async {}
  @override
  Future<void> sync() async {}
}
