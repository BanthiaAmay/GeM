import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../core/models.dart';
import '../core/phone.dart';

/// Device notifications for bid alerts. `PushService` (Firebase) implements it
/// in the app; it is absent in tests and in builds without Firebase setup.
abstract class PushBridge {
  /// Whether this build and platform can receive app notifications.
  bool get supported;

  /// Asks for notification permission if needed and registers this device
  /// for the signed-in user. Returns whether notifications are allowed.
  Future<bool> enable();

  /// Re-registers this device when permission was already given (after
  /// sign-in or a language change, so alerts arrive in the right language).
  Future<void> refresh();

  /// Stops alerts for the signed-in user on this device (before sign-out).
  Future<void> detach();

  /// The screen to open for the notification that launched the app, once.
  String? takeLaunchRoute();
}

class AppStore extends ChangeNotifier {
  final SharedPreferences prefs;
  final SupabaseClient? client;
  PushBridge? push;
  Map<String, dynamic> data = {};
  List<Map<String, dynamic>> queue = [];
  List<Map<String, dynamic>> benchmarks = [];
  List<Map<String, dynamic>> outcomes = [];
  Map<String, dynamic> alertPreferences = {};
  List<Map<String, dynamic>> bidNotifications = [];
  String? alertsError;
  bool? googleAvailable;
  bool? emailAvailable;
  String? authError;
  String status = '';

  /// Date range (7, 30 or 90 days) shared by every Insights screen. Not
  /// persisted — a fresh session starts on 30 days.
  int insightsDays = 30;
  bool syncing = false;
  bool _loadedCloud = false;
  bool _syncAgain = false;
  bool _deleting = false;
  Completer<void>? _syncDone;
  StreamSubscription<AuthState>? _authSubscription;
  bool _handlingAuth = false;
  Future<void>? _authReady;
  final sessionId = const Uuid().v4();
  AppStore(this.prefs, {this.client}) {
    _read();
  }
  String get storageKey =>
      'saathi.v1.${client?.auth.currentUser?.id ?? 'guest'}';
  bool get hi => data['language'] == 'hi';
  String get language => data['language'] as String? ?? 'en';
  bool get consent => data['researchConsent'] == true;

  /// Whether this device has ever completed the welcome/language
  /// onboarding flow. Device-scoped (not per-account) so a returning
  /// user never sees the "Get started" welcome screen again.
  bool get hasOnboarded => prefs.getBool('saathi.v1.onboarded') ?? false;

  /// Whether this device has already played the language screen's
  /// multilingual greeting tour (see LanguagePage). Device-scoped, like
  /// [hasOnboarded]: a fresh "Start onboarding again" plays it once more,
  /// but simply navigating back and forth within one run does not.
  bool get hasSeenGreetingIntro =>
      prefs.getBool('saathi.v1.seenGreetingIntro') ?? false;

  Future<void> markGreetingIntroSeen() async {
    if (hasSeenGreetingIntro) return;
    await prefs.setBool('saathi.v1.seenGreetingIntro', true);
  }

  bool get signedIn => client?.auth.currentUser != null;
  bool get configured => client != null;
  User? get currentUser => client?.auth.currentUser;
  bool get hasContactDetails =>
      normalizeWhatsapp(alertPreferences['whatsapp_number'] as String? ?? '') !=
      null;
  int get unreadAlerts =>
      bidNotifications.where((n) => n['read_at'] == null).length;
  bool get pushSupported => push?.supported ?? false;

  /// What the business sells, as bid-matching keywords. The saved alert
  /// preferences win; the onboarding copy covers a save still pending.
  List<String> get bidKeywords => List<String>.from(
    alertPreferences.containsKey('keywords')
        ? alertPreferences['keywords'] ?? const []
        : profile['bidKeywords'] ?? const [],
  );
  Map<String, dynamic> section(String key) =>
      Map<String, dynamic>.from(data[key] as Map? ?? {});
  List<String> get completed => List<String>.from(data['completed'] ?? []);
  List<bool> get checklist =>
      List<bool>.from(data['checklist'] ?? List.filled(steps.length, false));
  String t(String en, String hindi, {Map<String, String>? vars}) {
    var out = tr(language, en, hindi);
    if (vars != null) {
      for (final entry in vars.entries) {
        out = out.replaceAll('{${entry.key}}', entry.value);
      }
    }
    return out;
  }

  void _read() {
    try {
      data = Map<String, dynamic>.from(
        jsonDecode(prefs.getString(storageKey) ?? '{}'),
      );
      queue = List<Map<String, dynamic>>.from(
        (jsonDecode(prefs.getString('$storageKey.events') ?? '[]') as List).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );
    } catch (_) {
      data = {};
      queue = [];
      status = 'local_recovery';
    }
  }

  Future<void> initialize() async {
    if (client != null) {
      _authSubscription ??= client!.auth.onAuthStateChange.listen(
        (change) {
          if (change.event == AuthChangeEvent.signedIn &&
              change.session != null) {
            unawaited(_adoptAuthenticatedSession());
          } else if (change.event == AuthChangeEvent.signedOut) {
            _loadedCloud = false;
            outcomes = [];
            alertPreferences = {};
            bidNotifications = [];
            _read();
            notifyListeners();
          }
        },
        onError: (Object error) {
          authError = 'Sign-in could not be completed. Please try again.';
          notifyListeners();
        },
      );
      unawaited(checkAuthProviders());
    }
    final ref = Uri.base.queryParameters['ref'];
    if (ref != null && RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(ref)) {
      data['referral'] ??= ref;
    }
    if (signedIn) {
      await restoreCloud();
      await loadAlerts();
    }
    event('page_view', page: 'home');
    await persist();
    if (client != null) {
      try {
        benchmarks = List<Map<String, dynamic>>.from(
          await client!.from('benchmarks').select().eq('published', true),
        );
        notifyListeners();
      } catch (_) {
        /* No invented fallback benchmarks. */
      }
    }
  }

  Future<void> persist() async {
    await prefs.setString(storageKey, jsonEncode(data));
    await prefs.setString('$storageKey.events', jsonEncode(queue));
  }

  void setInsightsDays(int days) {
    if (insightsDays == days) return;
    insightsDays = days;
    notifyListeners();
  }

  void setLanguage(String value) {
    data['language'] = value;
    unawaited(persist());
    notifyListeners();
    // Notifications are written in the device's registered language.
    if (signedIn) unawaited(push?.refresh());
  }

  /// Whether the seller says their business is already listed on GeM —
  /// asked once during onboarding, right after language. Informational
  /// only for now; nothing downstream branches on it yet.
  bool get alreadyOnGem => data['alreadyOnGem'] == true;

  void setAlreadyOnGem(bool value) {
    data['alreadyOnGem'] = value;
    unawaited(persist());
    notifyListeners();
  }

  /// Free-form answers collected across the "not yet on GeM" onboarding
  /// walkthrough (name, business details, readiness checks). One bag
  /// rather than a field per screen — this is preparation input, not
  /// verified identity data (no PAN/Aadhaar numbers are ever asked for).
  ///
  /// Onboarding step 13 (FlowExperienceDetailPage) stores
  ///   profile['pastOrderCount']      — raw String, e.g. "5"
  ///   profile['pastOrderValueRange'] — turnover-band key, e.g. 'under10L'
  ///                                    (a TOTAL-value band, not per-order ₹)
  // TODO(prefill-revenue-prior-orders): Wire the Revenue form's
  // priorOrdersCount/priorOrdersValue prefill once onboarding stores
  // pastOrderCount as an int and pastOrderValueRange as a per-order rupee
  // amount.  The current band-key format is incompatible with RevenueResult's
  // int/double fields and must not be mapped by guessing a midpoint.
  Map<String, dynamic> get profile =>
      Map<String, dynamic>.from(data['profile'] as Map? ?? {});

  void setProfile(String key, dynamic value) {
    data['profile'] = {...profile, key: value};
    save();
  }

  Future<void> completeOnboarding() async {
    await prefs.setBool('saathi.v1.onboarded', true);
    notifyListeners();
  }

  /// Lets a returning user step back through the welcome/language
  /// screens again (e.g. to review them, or switch language from
  /// scratch) without reinstalling the app.
  Future<void> resetOnboarding() async {
    await prefs.setBool('saathi.v1.onboarded', false);
    await prefs.setBool('saathi.v1.seenGreetingIntro', false);
    notifyListeners();
  }

  void setConsent(bool value) {
    data['researchConsent'] = value;
    data['consentVersion'] = '2026-09-09';
    if (!value) queue.clear();
    event('consent_granted');
    save();
  }

  void event(
    String name, {
    String? page,
    Map<String, dynamic> props = const {},
  }) {
    if (!consent) return;
    queue.add({
      'id': const Uuid().v4(),
      'session_id': sessionId,
      'event_name': name,
      'page': page,
      'referral_code': data['referral'],
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'properties': props,
      'rule_version': ruleVersion,
    });
    if (queue.length > 1000) queue.removeAt(0);
    unawaited(persist());
  }

  void save() {
    data['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    unawaited(persist());
    notifyListeners();
    unawaited(sync());
  }

  void complete(String key, Map<String, dynamic> values) {
    data[key] = {
      ...values,
      'calculatedAt': DateTime.now().toUtc().toIso8601String(),
      'ruleVersion': ruleVersion,
    };
    data['completed'] = {...completed, key}.toList();
    if (key == 'eligibility') {
      final c = checklist;
      c[0] = values['pan'] == true && values['bank'] == true;
      c[1] = values['gst'] == 'yes';
      c[2] = values['udyam'] == true;
      data['checklist'] = c;
    }
    // Dependent projections must be recalculated after an upstream edit.
    if (['eligibility', 'revenue', 'pricing'].contains(key)) {
      data.remove('roi');
      data['completed'] = completed.where((e) => e != 'roi').toList();
    }
    event('tool_completed', page: key);
    if (key == 'eligibility' && values['interested'] == false) {
      event('disqualified_by_choice', page: key);
    }
    save();
  }

  void check(int index, bool value) {
    final c = checklist;
    c[index] = value;
    data['checklist'] = c;
    event(
      'tracker_updated',
      page: 'tracker',
      props: {'step': index, 'done': value},
    );
    save();
  }

  String get nextTool {
    for (final key in ['eligibility', 'revenue', 'pricing', 'roi']) {
      if (!completed.contains(key)) return key;
    }
    return 'tracker';
  }

  Future<void> checkAuthProviders() async {
    if (client == null) return;
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty || key.isEmpty) return;
    try {
      final response = await http
          .get(Uri.parse('$url/auth/v1/settings'), headers: {'apikey': key})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final settings = jsonDecode(response.body) as Map;
        final providers = settings['external'] as Map? ?? {};
        googleAvailable = providers['google'] == true;
        emailAvailable = providers['email'] == true;
        notifyListeners();
      }
    } catch (_) {
      // An unavailable preflight never implies that a provider is disabled.
    }
  }

  Future<void> sendOtp(String email, {bool shouldCreateUser = true}) async {
    if (client == null) throw StateError('Supabase is not configured');
    await _stashGuestState();
    await client!.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: shouldCreateUser,
    );
  }

  Future<void> verifyOtp(String email, String token) async {
    if (client == null) throw StateError('Supabase is not configured');
    await client!.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.email,
    );
    await _adoptAuthenticatedSession();
  }

  /// Starts Supabase's Google OAuth flow. Web returns to the current origin;
  /// Android returns through the app-owned custom scheme declared in the
  /// manifest. Supabase uses PKCE and restores the resulting session.
  Future<bool> signInWithGoogle() async {
    if (client == null) throw StateError('Supabase is not configured');
    if (googleAvailable == false) {
      throw StateError('Google sign-in is not enabled');
    }
    await _stashGuestState();
    return client!.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb
          ? Uri.base.replace(query: '', fragment: '/auth').toString()
          : 'com.bid2scale.app://login-callback/',
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  Future<void> _stashGuestState() async {
    if (signedIn) return;
    await prefs.setString(
      'saathi.auth.pending_guest',
      jsonEncode({'data': data, 'queue': queue}),
    );
  }

  Future<void> _adoptAuthenticatedSession() async {
    if (!signedIn) return;
    if (_handlingAuth) return _authReady;
    final done = Completer<void>();
    _authReady = done.future;
    _handlingAuth = true;
    try {
      Map<String, dynamic> guest = {};
      List<Map<String, dynamic>> guestQueue = [];
      final pending = prefs.getString('saathi.auth.pending_guest');
      if (pending != null) {
        try {
          final decoded = Map<String, dynamic>.from(jsonDecode(pending));
          guest = Map<String, dynamic>.from(decoded['data'] as Map? ?? {});
          guestQueue = List<Map<String, dynamic>>.from(
            (decoded['queue'] as List? ?? []).map(
              (e) => Map<String, dynamic>.from(e as Map),
            ),
          );
        } catch (_) {
          // A malformed hand-off is ignored; account/cloud state still loads.
        }
      }
      _read();
      if (data.isEmpty && guest.isNotEmpty) {
        data = guest;
        queue = guestQueue;
      }
      _loadedCloud = false;
      await restoreCloud();
      await loadAlerts();
      // A device keeps its token across accounts; point it at this one.
      unawaited(push?.refresh());
      await prefs.remove('saathi.auth.pending_guest');
      await prefs.remove('saathi.v1.guest');
      await prefs.remove('saathi.v1.guest.events');
      await persist();
      await sync();
      notifyListeners();
    } finally {
      _handlingAuth = false;
      done.complete();
    }
  }

  Future<void> restoreCloud() async {
    if (!signedIn) return;
    try {
      final row = await client!
          .from('profiles')
          .select('state')
          .eq('id', client!.auth.currentUser!.id)
          .maybeSingle();
      final remote = Map<String, dynamic>.from(row?['state'] ?? {});
      if (remote.isNotEmpty &&
          (remote['updatedAt'] as String? ?? '').compareTo(
                data['updatedAt'] as String? ?? '',
              ) >
              0) {
        data = remote;
      }
      _loadedCloud = true;
      outcomes = List<Map<String, dynamic>>.from(
        await client!.from('outcomes').select(),
      );
      await persist();
    } catch (_) {
      status = 'offline';
    }
    notifyListeners();
  }

  Future<void> sync() async {
    if (!signedIn || _deleting) return;
    if (syncing) {
      _syncAgain = true;
      return _syncDone!.future;
    }
    syncing = true;
    _syncDone = Completer<void>();
    notifyListeners();
    try {
      if (!_loadedCloud) {
        await restoreCloud();
        if (!_loadedCloud) return;
      }
      do {
        _syncAgain = false;
        final id = client!.auth.currentUser!.id;
        final snapshot = jsonDecode(jsonEncode(data));
        await client!.from('profiles').upsert({
          'id': id,
          'state': snapshot,
          'research_consent': consent,
        });
        if (consent && queue.isNotEmpty) {
          final batch = queue.take(100).toList();
          await client!
              .from('funnel_events')
              .upsert(
                batch.map((e) => {...e, 'user_id': id}).toList(),
                onConflict: 'id',
                ignoreDuplicates: true,
              );
          final sent = batch.map((e) => e['id']).toSet();
          queue.removeWhere((e) => sent.contains(e['id']));
          if (queue.isNotEmpty) _syncAgain = true;
        }
        status = 'synced';
        await persist();
      } while (_syncAgain && !_deleting);
    } catch (_) {
      status = 'offline';
    } finally {
      syncing = false;
      _syncDone!.complete();
      notifyListeners();
    }
  }

  Future<void> requestHelp(
    String kind,
    String note,
    bool partnerConsent,
  ) async {
    if (!signedIn) throw StateError('sign_in_required');
    await client!.from('support_requests').insert({
      'user_id': client!.auth.currentUser!.id,
      'kind': kind,
      'note': note,
      'partner_consent': partnerConsent,
    });
    event('support_requested', page: 'support', props: {'kind': kind});
    await sync();
  }

  Future<void> claimOutcome(String stage, String reference) async {
    if (!signedIn) throw StateError('sign_in_required');
    await client!.from('outcomes').upsert({
      'user_id': client!.auth.currentUser!.id,
      'stage': stage,
      'reference': reference,
    }, onConflict: 'user_id,stage');
    event('${stage}_self_reported', page: 'register');
    await restoreCloud();
    await sync();
  }

  Future<void> signOut() async {
    await sync();
    await _detachPush();
    await client!.auth.signOut();
    _loadedCloud = false;
    outcomes = [];
    alertPreferences = {};
    bidNotifications = [];
    _read();
    notifyListeners();
  }

  /// Deletes the authenticated Supabase identity and its cascade-owned app
  /// rows through the no-argument, auth.uid()-scoped database function.
  Future<void> deleteAccount() async {
    if (!signedIn) throw StateError('sign_in_required');
    _deleting = true;
    try {
      if (syncing) await _syncDone!.future;
      final accountStorageKey = storageKey;
      await _detachPush();
      await client!.rpc('delete_my_account');
      await client!.auth.signOut(scope: SignOutScope.local);
      data = {};
      queue = [];
      outcomes = [];
      alertPreferences = {};
      bidNotifications = [];
      _loadedCloud = false;
      await prefs.remove('saathi.auth.pending_guest');
      await prefs.remove(accountStorageKey);
      await prefs.remove('$accountStorageKey.events');
      _read();
      notifyListeners();
    } finally {
      _deleting = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> deleteData() async {
    _deleting = true;
    try {
      if (syncing) await _syncDone!.future;
      if (signedIn) {
        await client!.rpc('delete_my_data');
      }
      data = {};
      queue = [];
      outcomes = [];
      alertPreferences = {};
      bidNotifications = [];
      await persist();
      notifyListeners();
    } finally {
      _deleting = false;
    }
  }

  Future<void> loadAlerts() async {
    if (!signedIn) return;
    final userId = currentUser!.id;
    try {
      var preferences = await client!
          .from('bid_alert_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      // Retry an onboarding answer that could not be saved at the time.
      final pending = List<String>.from(profile['bidKeywords'] ?? const []);
      if (preferences == null && pending.isNotEmpty) {
        preferences = Map<String, dynamic>.from(
          await client!.rpc(
                'save_bid_interests',
                params: {'p_keywords': pending},
              )
              as Map,
        );
      }
      final notifications = await client!
          .from('bid_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      if (currentUser?.id != userId) return;
      alertPreferences = Map<String, dynamic>.from(preferences ?? {});
      bidNotifications = List<Map<String, dynamic>>.from(notifications);
      alertsError = null;
    } catch (_) {
      if (currentUser?.id != userId) return;
      alertsError = 'Could not load alerts. Check your connection and retry.';
    }
    notifyListeners();
  }

  Future<void> saveAlertPreferences({
    required String phone,
    required bool whatsapp,
    bool inApp = true,
    List<String> keywords = const [],
    List<String> states = const [],
  }) async {
    if (!signedIn) throw StateError('sign_in_required');
    final normalized = normalizeWhatsapp(phone);
    if (normalized == null) throw ArgumentError('Invalid WhatsApp number');
    final userId = currentUser!.id;
    final result = await client!.rpc(
      'save_bid_alert_preferences',
      params: {
        'p_phone': normalized,
        'p_whatsapp': whatsapp,
        'p_in_app': inApp,
        'p_keywords': keywords,
        'p_states': states,
      },
    );
    if (currentUser?.id != userId) {
      throw StateError('Account changed during save');
    }
    alertPreferences = Map<String, dynamic>.from(result as Map);
    // Reuse the number in the seller preparation form, without a second entry.
    data['profile'] = {
      ...profile,
      'mobile': normalized.substring(3),
      'bidKeywords': keywords,
    };
    await persist();
    notifyListeners();
  }

  /// Saves the products or services the business supplies (onboarding's
  /// "What do you sell?"). Kept in the profile first, so an offline save is
  /// retried by [loadAlerts]; contact and channel choices are untouched.
  Future<void> saveBidInterests(List<String> keywords) async {
    data['profile'] = {...profile, 'bidKeywords': keywords};
    save();
    if (!signedIn || client == null) return;
    final userId = currentUser!.id;
    final result = await client!.rpc(
      'save_bid_interests',
      params: {'p_keywords': keywords},
    );
    if (currentUser?.id != userId) return;
    alertPreferences = Map<String, dynamic>.from(result as Map);
    notifyListeners();
  }

  /// Daily-ish email digest of matching bids, sent to the sign-in address.
  bool get emailAlerts => alertPreferences['email_enabled'] != false;

  Future<void> setEmailAlerts(bool enabled) async {
    if (!signedIn || client == null) return;
    final userId = currentUser!.id;
    final result = await client!.rpc(
      'set_email_alerts',
      params: {'p_enabled': enabled},
    );
    if (currentUser?.id != userId) return;
    alertPreferences = Map<String, dynamic>.from(result as Map);
    notifyListeners();
  }

  Future<void> registerPushDevice(String token, String platform) async {
    if (!signedIn || client == null) return;
    await client!.rpc(
      'register_push_device',
      params: {
        'p_token': token,
        'p_platform': platform,
        'p_language': language,
      },
    );
  }

  Future<void> unregisterPushDevice(String token) async {
    if (!signedIn || client == null) return;
    await client!.rpc('unregister_push_device', params: {'p_token': token});
  }

  Future<void> _detachPush() async {
    try {
      await push?.detach();
    } catch (_) {
      // Signing out or deleting must never be blocked by the push service.
    }
  }

  Future<void> markAlertRead(String id) async {
    if (!signedIn) throw StateError('sign_in_required');
    await client!.rpc('mark_bid_notification_read', params: {'p_id': id});
    await loadAlerts();
  }

  String report() {
    final b = StringBuffer(
      t('Bid2Scale • My business plan', 'Bid2Scale • मेरी व्यवसाय योजना'),
    );
    b.writeln(
      '\n${DateFormat('dd MMM yyyy').format(DateTime.now())} | $ruleVersion',
    );
    b.writeln(
      t(
        'Planning guidance, not GeM approval or guaranteed income.',
        'यह योजना मार्गदर्शन है, GeM की मंजूरी या आय की गारंटी नहीं।',
      ),
    );
    for (final key in completed) {
      final s = section(key);
      b.writeln('\n${toolName(key)}');
      if (key == 'eligibility') {
        final r = Eligibility.evaluate(s);
        b.writeln(
          '${classificationName(r.enterprise, language)} • ${r.verdict}',
        );
      }
      if (key == 'revenue') {
        b.writeln(
          '${money(s['low'])} – ${money(s['high'])} / ${t('year', 'वर्ष')}',
        );
        b.writeln(
          t(
            'User-entered scenario; not observed seller revenue.',
            'उपयोगकर्ता का परिदृश्य; वास्तविक विक्रेता आय नहीं।',
          ),
        );
      }
      if (key == 'pricing') {
        b.writeln(
          '${t('Target price', 'लक्षित मूल्य')}: ${money(s['price'])} | ${s['margin']}%',
        );
      }
      if (key == 'roi') {
        b.writeln(
          '${t('1-year net contribution', '1-वर्ष शुद्ध योगदान')}: ${money(s['firstYear'])}\n${t('3-year net contribution', '3-वर्ष शुद्ध योगदान')}: ${money(s['threeYear'])}',
        );
      }
      b.writeln(
        '${t('Inputs and calculation', 'इनपुट और गणना')}: ${jsonEncode(s)}',
      );
    }
    final c = checklist;
    b.writeln(
      '\n${t('Your next action', 'आपका अगला कदम')}: ${(() {
        final row = steps[!c.contains(false) ? steps.length - 1 : c.indexOf(false)];
        return tr(language, row[0], row[1]);
      })()}',
    );
    b.writeln(
      '\n${t('Sources', 'स्रोत')}:\n$udyamSource\n$feeSource\n$gemSource',
    );
    return b.toString();
  }

  String toolName(String key) => switch (key) {
    'eligibility' => t('Eligibility checker', 'पात्रता जाँच'),
    'revenue' => t('Revenue estimator', 'आय अनुमान'),
    'pricing' => t('Pricing & margin', 'मूल्य और मार्जिन'),
    'roi' => t('ROI & effort', 'लाभ और प्रयास'),
    'tracker' => t('Readiness tracker', 'तैयारी ट्रैकर'),
    'workingCapital' => t('Working capital', 'कार्यशील पूँजी'),
    'emd' => t('EMD', 'EMD'),
    'unitEconomics' => t('Unit economics', 'यूनिट अर्थशास्त्र'),
    'gstCalc' => t('GST calculator', 'GST कैलकुलेटर'),
    'netCash' => t('Net cash receivable', 'वास्तविक प्राप्त नकद'),
    'raWalkaway' => t(
      'Reverse auction walk-away price',
      'रिवर्स ऑक्शन वॉक-अवे मूल्य',
    ),
    _ => key,
  };
}
