/// Persists recent and saved searches via SharedPreferences.
///
/// Queries are stored as opaque strings. Raw query text is never sent to any
/// server — this store is the only persistence layer.
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'search_engine.dart';

class SearchStore {
  SearchStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyRecent = 'search_recent';
  static const _keySaved = 'search_saved';
  static const _keyAlerts = 'search_alerts'; // List<String> unread query alerts
  static const _keyAlertCounts = 'search_alert_counts'; // JSON map {query: count}
  static const _maxRecent = 10;
  static const _maxSaved = 20;

  List<String> get recent =>
      List<String>.from(_prefs.getStringList(_keyRecent) ?? []);

  List<String> get saved =>
      List<String>.from(_prefs.getStringList(_keySaved) ?? []);

  Future<void> addRecent(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = recent..remove(q);
    list.insert(0, q);
    await _prefs.setStringList(_keyRecent, list.take(_maxRecent).toList());
  }

  Future<void> removeRecent(String query) async {
    final list = recent..remove(query);
    await _prefs.setStringList(_keyRecent, list);
  }

  Future<void> clearRecent() async => _prefs.remove(_keyRecent);

  Future<void> saveSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final list = saved..remove(q);
    list.insert(0, q);
    await _prefs.setStringList(_keySaved, list.take(_maxSaved).toList());
  }

  Future<void> removeSaved(String query) async {
    final list = saved..remove(query);
    await _prefs.setStringList(_keySaved, list);
  }

  /// Renames [oldQuery] to [newQuery] in the saved list, preserving order.
  Future<void> renameSaved(String oldQuery, String newQuery) async {
    final newQ = newQuery.trim();
    if (newQ.isEmpty || oldQuery == newQ) return;
    final list = saved;
    final idx = list.indexOf(oldQuery);
    if (idx < 0) return;
    list[idx] = newQ;
    await _prefs.setStringList(_keySaved, list);
    // Migrate the alert-count entry so alert tracking survives the rename.
    final raw = _prefs.getString(_keyAlertCounts);
    if (raw != null) {
      try {
        final counts = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        if (counts.containsKey(oldQuery)) {
          counts[newQ] = counts.remove(oldQuery);
          await _prefs.setString(_keyAlertCounts, jsonEncode(counts));
        }
      } catch (_) {}
    }
  }

  bool isSaved(String query) => saved.contains(query.trim());

  // ── Saved-search alerts ─────────────────────────────────────────────────────

  /// Queries with more matches now than at the last [checkAlerts] call.
  List<String> get unreadAlerts =>
      List<String>.from(_prefs.getStringList(_keyAlerts) ?? []);

  /// True when at least one saved search has new matches.
  bool get hasUnread => (_prefs.getStringList(_keyAlerts) ?? []).isNotEmpty;

  /// Re-runs every saved search using [engine]. Returns the queries whose
  /// match count increased since the last call (first call = always triggers
  /// for any search that has results). Writes the new counts and updates
  /// [unreadAlerts].
  Future<List<String>> checkAlerts(SearchEngine engine) async {
    final savedList = saved;
    if (savedList.isEmpty) return [];

    Map<String, int> counts;
    try {
      final raw = _prefs.getString(_keyAlertCounts);
      if (raw == null) {
        counts = {};
      } else {
        counts = Map<String, int>.from(
          (jsonDecode(raw) as Map).map(
            (k, v) => MapEntry(k as String, (v as num).toInt()),
          ),
        );
      }
    } catch (_) {
      counts = {};
    }

    final newAlerts = <String>[];
    for (final q in savedList) {
      final n = engine.query(q).length;
      final last = counts[q] ?? -1; // -1 = never checked → always alert
      if (n > last) newAlerts.add(q);
      counts[q] = n;
    }

    await _prefs.setString(_keyAlertCounts, jsonEncode(counts));

    if (newAlerts.isNotEmpty) {
      final existing = unreadAlerts;
      for (final q in newAlerts) {
        if (!existing.contains(q)) existing.add(q);
      }
      await _prefs.setStringList(_keyAlerts, existing);
    }

    return newAlerts;
  }

  /// Marks [query] as read (removes it from [unreadAlerts]).
  Future<void> clearAlert(String query) async {
    final list = unreadAlerts..remove(query);
    await _prefs.setStringList(_keyAlerts, list);
  }

  /// Clears all unread alerts.
  Future<void> clearAllAlerts() async => _prefs.remove(_keyAlerts);
}
