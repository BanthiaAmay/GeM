/// Persists recent and saved searches via SharedPreferences.
///
/// Queries are stored as opaque strings. Raw query text is never sent to any
/// server — this store is the only persistence layer.
library;

import 'package:shared_preferences/shared_preferences.dart';

class SearchStore {
  SearchStore(this._prefs);

  final SharedPreferences _prefs;

  static const _keyRecent = 'search_recent';
  static const _keySaved = 'search_saved';
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

  bool isSaved(String query) => saved.contains(query.trim());
}
