import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../core/models.dart';

class AppStore extends ChangeNotifier {
  final SharedPreferences prefs;
  final SupabaseClient? client;
  Map<String, dynamic> data = {};
  List<Map<String, dynamic>> queue = [];
  List<Map<String, dynamic>> benchmarks = [];
  List<Map<String, dynamic>> outcomes = [];
  String status = '';
  bool syncing = false;
  bool _loadedCloud = false;
  bool _syncAgain = false;
  bool _deleting = false;
  Completer<void>? _syncDone;
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
  bool get signedIn => client?.auth.currentUser != null;
  bool get configured => client != null;
  Map<String, dynamic> section(String key) =>
      Map<String, dynamic>.from(data[key] as Map? ?? {});
  List<String> get completed => List<String>.from(data['completed'] ?? []);
  List<bool> get checklist =>
      List<bool>.from(data['checklist'] ?? List.filled(steps.length, false));
  String t(String en, String hindi) => tr(hi, en, hindi);
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
    final ref = Uri.base.queryParameters['ref'];
    if (ref != null && RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(ref)) {
      data['referral'] ??= ref;
    }
    if (signedIn) {
      await restoreCloud();
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

  void changeLanguage() {
    data['language'] = hi ? 'en' : 'hi';
    unawaited(persist());
    notifyListeners();
  }

  void setLanguage(String value) {
    data['language'] = value;
    unawaited(persist());
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await prefs.setBool('saathi.v1.onboarded', true);
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

  Future<void> sendOtp(String email) async {
    if (client == null) throw StateError('Supabase is not configured');
    await client!.auth.signInWithOtp(email: email);
  }

  Future<void> verifyOtp(String email, String token) async {
    final guest = Map<String, dynamic>.from(data);
    final guestQueue = List<Map<String, dynamic>>.from(queue);
    await client!.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    _read();
    if (data.isEmpty) {
      data = guest;
      queue = guestQueue;
    }
    _loadedCloud = false;
    await restoreCloud();
    await prefs.remove('saathi.v1.guest');
    await prefs.remove('saathi.v1.guest.events');
    await persist();
    await sync();
    notifyListeners();
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
    await client!.auth.signOut();
    _loadedCloud = false;
    outcomes = [];
    _read();
    notifyListeners();
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
      await persist();
      notifyListeners();
    } finally {
      _deleting = false;
    }
  }

  String report() {
    final b = StringBuffer(
      t('GeM BizReady • My business plan', 'GeM BizReady • मेरी व्यवसाय योजना'),
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
        b.writeln('${classificationName(r.enterprise, hi)} • ${r.verdict}');
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
      '\n${t('Your next action', 'आपका अगला कदम')}: ${steps[!c.contains(false) ? steps.length - 1 : c.indexOf(false)][hi ? 1 : 0]}',
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
    _ => key,
  };
}
