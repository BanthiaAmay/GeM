/// Local search engine: normalise → tokenise → synonym expand → prefix-match
/// → Damerau-Levenshtein fuzzy → rank.
///
/// Runs entirely on-device; no network calls.
library;

import 'search_index.dart';
import 'search_models.dart';
import 'search_synonyms.dart';

class SearchEngine {
  SearchEngine({SearchIndex? index}) : _index = index ?? SearchIndex.instance;

  final SearchIndex _index;

  /// Run a query and return ranked results, optionally filtered to [scope].
  List<SearchItem> query(
    String rawQuery, {
    SearchScope scope = SearchScope.all,
    BidFilter filter = const BidFilter.empty(),
    SortOption sort = SortOption.bestMatch,
  }) {
    final q = normalise(rawQuery);
    if (q.isEmpty) return [];

    final tokens = _expandTokens(_tokenise(q));
    if (tokens.isEmpty) return [];

    final results = <SearchItem>[];
    for (final item in _index.items) {
      if (scope.typeFilter != null && item.type != scope.typeFilter) continue;
      final score = _score(item, tokens);
      if (score > 0) {
        // clone with new score
        results.add(
          SearchItem(
            id: item.id,
            type: item.type,
            titleEn: item.titleEn,
            titleHi: item.titleHi,
            subtitleEn: item.subtitleEn,
            subtitleHi: item.subtitleHi,
            keywords: item.keywords,
            route: item.route,
            routeArg: item.routeArg,
            actionEn: item.actionEn,
            actionHi: item.actionHi,
            score: score,
          ),
        );
      }
    }

    _sortResults(results, sort);
    return results;
  }

  // ── Normalisation ─────────────────────────────────────────────────────────

  static String normalise(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\sऀ-ॿ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // ── Tokenisation ──────────────────────────────────────────────────────────

  static List<String> _tokenise(String normalised) =>
      normalised.split(' ').where((t) => t.length >= 2).toList();

  // ── Synonym expansion ─────────────────────────────────────────────────────

  static List<String> _expandTokens(List<String> tokens) {
    final expanded = <String>{};
    void addAll(Iterable<String> values) {
      for (final v in values) {
        // If a synonym value is a phrase, add each word separately.
        if (v.contains(' ')) {
          expanded.addAll(v.split(' ').where((w) => w.length >= 2));
        } else {
          expanded.add(v);
        }
      }
    }

    void lookup(String key) {
      final dev = kDevanagariMap[key];
      if (dev != null) addAll(dev);
      final hin = kHinglishMap[key];
      if (hin != null) addAll(hin);
      final syn = kSynonyms[key];
      if (syn != null) addAll(syn);
    }

    // Single-token lookups.
    for (final t in tokens) {
      expanded.add(t);
      lookup(t);
    }

    // Phrase lookups: bigrams and trigrams catch multi-word jargon like
    // "money before payment", "bijli ka saman", "loan for order".
    for (var i = 0; i < tokens.length - 1; i++) {
      lookup('${tokens[i]} ${tokens[i + 1]}');
      if (i < tokens.length - 2) {
        lookup('${tokens[i]} ${tokens[i + 1]} ${tokens[i + 2]}');
      }
    }

    return expanded.toList();
  }

  // ── Scoring ───────────────────────────────────────────────────────────────

  double _score(SearchItem item, List<String> tokens) {
    final indexTerms = _indexTerms(item);
    double total = 0;
    for (final token in tokens) {
      double best = 0;
      for (final term in indexTerms) {
        final s = _termScore(token, term);
        if (s > best) best = s;
      }
      total += best;
    }
    // Normalise: perfect match of all tokens = 100
    final norm = (total / tokens.length * 100).clamp(0.0, 100.0);
    return norm;
  }

  static List<String> _indexTerms(SearchItem item) {
    final terms = <String>[];
    terms.addAll(_tokenise(normalise(item.titleEn)));
    terms.addAll(_tokenise(normalise(item.titleHi)));
    for (final kw in item.keywords) {
      terms.addAll(_tokenise(normalise(kw)));
    }
    return terms;
  }

  /// Returns 0.0–1.0 for how well [query] matches a single index [term].
  static double _termScore(String query, String term) {
    if (term.isEmpty) return 0;
    // Exact match
    if (query == term) return 1.0;
    // Prefix match (query is a prefix of term)
    if (term.startsWith(query) && query.length >= 3) {
      return 0.85 + 0.15 * (query.length / term.length);
    }
    // Contains
    if (term.contains(query) && query.length >= 3) return 0.70;
    // Fuzzy: Damerau-Levenshtein
    if (query.length >= 4) {
      final dist = _dl(query, term);
      final maxLen = query.length > term.length ? query.length : term.length;
      final threshold = query.length >= 8 ? 2 : 1;
      if (dist <= threshold) {
        return (1 - dist / maxLen) * 0.75;
      }
    }
    return 0;
  }

  // ── Damerau-Levenshtein distance ──────────────────────────────────────────

  static int _dl(String a, String b) {
    final m = a.length, n = b.length;
    // Bail early on very long strings to avoid slow DP
    if ((m - n).abs() > 3) return 99;
    final d = List.generate(m + 1, (i) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = _min3(
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        );
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          d[i][j] = d[i][j] < d[i - 2][j - 2] + cost
              ? d[i][j]
              : d[i - 2][j - 2] + cost;
        }
      }
    }
    return d[m][n];
  }

  static int _min3(int a, int b, int c) {
    if (a < b) return a < c ? a : c;
    return b < c ? b : c;
  }

  // ── Sorting ───────────────────────────────────────────────────────────────

  static void _sortResults(List<SearchItem> results, SortOption sort) {
    switch (sort) {
      case SortOption.bestMatch:
        results.sort((a, b) => b.score.compareTo(a.score));
      case SortOption.closingSoon:
      case SortOption.highestValue:
      case SortOption.newest:
        // For non-bid items these fields don't exist; fall back to score.
        results.sort((a, b) => b.score.compareTo(a.score));
    }
  }

  // ── Ask-BizReady detection ────────────────────────────────────────────────

  /// True if the query looks like a question rather than a search.
  static bool isQuestion(String query) {
    final tokens = _tokenise(normalise(query));
    return tokens.any((t) => kQuestionTokens.contains(t)) ||
        query.contains('?');
  }

  // ── Match highlight ranges ────────────────────────────────────────────────

  /// Returns the byte-offset ranges of [tokens] found in [text].
  static List<(int start, int end)> highlightRanges(
    String text,
    List<String> tokens,
  ) {
    final lower = text.toLowerCase();
    final ranges = <(int, int)>[];
    for (final t in tokens) {
      if (t.length < 2) continue;
      var idx = lower.indexOf(t);
      while (idx != -1) {
        ranges.add((idx, idx + t.length));
        idx = lower.indexOf(t, idx + 1);
      }
    }
    // Sort and merge overlapping ranges
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    final merged = <(int, int)>[];
    for (final r in ranges) {
      if (merged.isEmpty || r.$1 > merged.last.$2) {
        merged.add(r);
      } else if (r.$2 > merged.last.$2) {
        merged[merged.length - 1] = (merged.last.$1, r.$2);
      }
    }
    return merged;
  }
}
