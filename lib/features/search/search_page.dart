import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../../data/sample_bids.dart';
import '../components.dart';
import 'bid_source.dart';
import 'search_content.dart';
import 'search_engine.dart';
import 'search_models.dart';
import 'search_result_card.dart';
import 'search_store.dart';

// ── Maximum items shown per group before the "See more" link appears ─────────
const _kGroupPreview = 3;

// ── Trending category IDs to surface on the empty-query screen ───────────────
const _kTrendingIds = ['cat-it', 'cat-office', 'cat-furniture', 'cat-cleaning'];

/// Universal search page. Route: `/search`.
class SearchPage extends StatefulWidget {
  final AppStore store;
  final SearchStore searchStore;
  final String? initialQuery;

  const SearchPage({
    super.key,
    required this.store,
    required this.searchStore,
    this.initialQuery,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  final _engine = SearchEngine();

  SearchScope _scope = SearchScope.all;
  SortOption _sort = SortOption.bestMatch;
  BidFilter _bidFilter = const BidFilter.empty();

  /// Full result set (scope = all) for the current query.
  List<SearchItem> _allResults = [];

  /// Filtered + sorted results for the current scope.
  List<SearchItem> _results = [];

  String _lastQuery = '';
  Timer? _debounce;

  /// Sections the user has tapped "See more" on.
  final Set<SearchType> _expandedSections = {};

  AppStore get _store => widget.store;
  bool get _isHi => _store.language == 'hi';
  bool get _hasQuery => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _focus = FocusNode();
    if (widget.initialQuery?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    }
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Search lifecycle ────────────────────────────────────────────────────────

  void _onTextChanged() {
    final q = _controller.text;
    if (q == _lastQuery) return;
    _lastQuery = q;
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _allResults = [];
        _results = [];
        _expandedSections.clear();
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), _runSearch);
  }

  void _runSearch() {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() {
        _allResults = [];
        _results = [];
      });
      return;
    }
    final all = _engine.query(q, sort: _sort);
    setState(() {
      _allResults = all;
      _results = _applySortToBids(_filterForScope(all));
      _expandedSections.clear();
    });
  }

  List<SearchItem> _filterForScope(List<SearchItem> all) {
    final f = _scope.typeFilter;
    var filtered = f == null ? all : all.where((r) => r.type == f).toList();
    if (_scope == SearchScope.bids && _bidFilter.hasAny) {
      filtered = filtered.where((item) {
        final found = sampleBidSource.bids.where((b) => b.id == item.routeArg);
        if (found.isEmpty) return false;
        return _bidFilter.matches(found.first);
      }).toList();
    }
    return filtered;
  }

  List<SearchItem> _applySortToBids(List<SearchItem> items) {
    if (_sort == SortOption.bestMatch) return items;
    final bids = <SearchItem>[];
    final others = <SearchItem>[];
    for (final item in items) {
      (item.type == SearchType.bid ? bids : others).add(item);
    }
    SampleBid? lookup(SearchItem item) {
      final found = sampleBidSource.bids.where((b) => b.id == item.routeArg);
      return found.isEmpty ? null : found.first;
    }
    bids.sort((a, b) {
      final ba = lookup(a);
      final bb = lookup(b);
      return switch (_sort) {
        SortOption.closingSoon =>
          (ba?.closesInDays ?? 999).compareTo(bb?.closesInDays ?? 999),
        SortOption.highestValue =>
          (bb?.valueRs ?? 0).compareTo(ba?.valueRs ?? 0),
        SortOption.newest =>
          (ba?.postedDaysAgo ?? 999).compareTo(bb?.postedDaysAgo ?? 999),
        SortOption.bestMatch => 0,
      };
    });
    return [...bids, ...others];
  }

  void _updateFilter(BidFilter f) {
    setState(() => _bidFilter = f);
    _runSearch();
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _SortSheet(
        current: _sort,
        isHindi: _isHi,
        store: _store,
        onApply: (s) {
          setState(() => _sort = s);
          _runSearch();
        },
      ),
    );
  }

  void _submit(String q) {
    _debounce?.cancel();
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    // Ensure the field reflects the submitted query (e.g. from a recent tap)
    if (_controller.text != trimmed) {
      _controller.text = trimmed;
      _controller.selection = TextSelection.collapsed(offset: trimmed.length);
    }
    widget.searchStore.addRecent(trimmed);
    _runSearch();
    _focus.unfocus();
    _store.event('search_performed', props: {
      'len': trimmed.length,
      'results': _results.length,
      'scope': _scope.name,
    });
  }

  void _clearRecent() {
    widget.searchStore.clearRecent();
    setState(() {}); // trigger rebuild so recents list disappears
  }

  void _selectScope(SearchScope scope) {
    setState(() {
      _scope = scope;
      _results = _filterForScope(_allResults);
    });
  }

  void _fillField(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _focus.requestFocus();
  }

  // ── Save / saved-search management ──────────────────────────────────────────

  void _toggleSave(String q) {
    if (widget.searchStore.isSaved(q)) {
      unawaited(widget.searchStore.removeSaved(q));
      _store.event('search_saved', props: {'action': 'remove'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_store.t('Search removed', 'खोज हटाई गई')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      unawaited(widget.searchStore.saveSearch(q));
      _store.event('search_saved', props: {'action': 'save'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_store.t('Search saved', 'खोज सेव हुई')),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: _store.t('Manage', 'प्रबंधित करें'),
              onPressed: _showSavedSearches,
            ),
          ),
        );
      }
    }
    setState(() {});
  }

  void _showSavedSearches() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _SavedSearchesSheet(
        searchStore: widget.searchStore,
        store: _store,
        onSearch: (q) {
          Navigator.pop(context);
          _fillField(q);
          _submit(q);
        },
      ),
    );
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  void _openItem(SearchItem item) {
    _store.event('search_result_opened', props: {
      'type': item.type.name,
      'id': item.id,
    });
    if (item.type == SearchType.bid) {
      final bid = sampleBidSource.bids.firstWhere(
        (b) => b.id == item.routeArg,
        orElse: () => sampleBidSource.bids.first,
      );
      _store.event('bid_detail_opened', props: {'id': bid.id});
      Navigator.pushNamed(context, '/bid-detail', arguments: bid.id);
    } else {
      Navigator.pushNamed(context, '/${item.route}');
    }
  }

  // ── Scope tab label with count ───────────────────────────────────────────────

  String _scopeLabel(SearchScope s) {
    final label = _store.t(s.labelEn, s.labelHi);
    if (!_hasQuery || _allResults.isEmpty) return label;
    final count = s.typeFilter == null
        ? _allResults.length
        : _allResults.where((r) => r.type == s.typeFilter).length;
    return count > 0 ? '$label $count' : label;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isHi = _isHi;
    final q = _controller.text.trim();
    final hasQuery = q.isNotEmpty;
    final isQuestion = hasQuery && SearchEngine.isQuestion(q);
    final isSaved = hasQuery && widget.searchStore.isSaved(q);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _SearchHeader(
        isHindi: isHi,
        store: _store,
        onBack: () => Navigator.pop(context),
        hasSaved: widget.searchStore.saved.isNotEmpty,
        onSavedSearches: _showSavedSearches,
      ),
      body: Column(
        children: [
          // ── Autofocused search field ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.sm,
            ),
            child: AppSearchField(
              controller: _controller,
              hint: _store.t('Search bids, tools…', 'बोलियाँ, टूल खोजें…'),
              onChanged: (_) {}, // handled by listener
              onSubmitted: _submit,
              focusNode: _focus,
              autofocus: widget.initialQuery?.isNotEmpty != true,
            ),
          ),
          // ── Scope segmented control with counts ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.sm,
            ),
            child: AppSegmentedControl<SearchScope>(
              options: [
                for (final s in SearchScope.values)
                  (s, _scopeLabel(s), null),
              ],
              value: _scope,
              onChanged: _selectScope,
              semanticLabel: _store.t('Search scope', 'खोज दायरा'),
            ),
          ),
          // ── Count + sort row ───────────────────────────────────────────────
          if (hasQuery && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: AppSpace.sm,
              ),
              child: Row(
                children: [
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    '${_results.length} ${_store.t('matches', 'परिणाम')}',
                    style: AppText.caption,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: AppIconSize.md,
                      color: isSaved ? AppColors.brand : AppColors.textSecondary,
                    ),
                    tooltip: isSaved
                        ? _store.t('Remove saved search', 'सेव की गई खोज हटाएँ')
                        : _store.t('Save this search', 'यह खोज सेव करें'),
                    onPressed: () => _toggleSave(q),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  GestureDetector(
                    onTap: _showSortSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.borderStrong),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${_store.t('Sort', 'क्रम')}: ${isHi ? _sort.labelHi : _sort.labelEn}',
                            style: AppText.label.copyWith(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ── Bid filter chip row (Bids scope only) ─────────────────────────
          if (hasQuery && _scope == SearchScope.bids)
            _BidFilterRow(
              filter: _bidFilter,
              onUpdate: _updateFilter,
              store: _store,
            ),
          const Divider(height: 1),
          Expanded(child: _buildBody(hasQuery, isQuestion, q)),
        ],
      ),
    );
  }

  Widget _buildBody(bool hasQuery, bool isQuestion, String q) {
    if (!hasQuery) {
      return _EmptyQueryBody(
        store: _store,
        searchStore: widget.searchStore,
        onTap: _submit,
        onFill: _fillField,
        onClearAll: _clearRecent,
      );
    }

    if (_results.isEmpty && _controller.text.trim().length >= 2) {
      if (isQuestion) {
        return _AskBizReady(query: _controller.text, isHindi: _isHi);
      }
      return _NoResultsBody(store: _store, onSuggestion: _fillField);
    }

    final weakResults = _results.isNotEmpty && _results.first.score < 35;
    final askCardQuery = (isQuestion || weakResults) ? q : null;

    return _GroupedResults(
      results: _results,
      allQuery: q,
      askCardQuery: askCardQuery,
      expandedSections: _expandedSections,
      isHindi: _isHi,
      onExpand: (type) => setState(() => _expandedSections.add(type)),
      onTap: _openItem,
      store: _store,
    );
  }
}

// ── Grouped results ───────────────────────────────────────────────────────────

class _GroupedResults extends StatelessWidget {
  final List<SearchItem> results;
  final String allQuery;
  final String? askCardQuery;
  final Set<SearchType> expandedSections;
  final bool isHindi;
  final ValueChanged<SearchType> onExpand;
  final ValueChanged<SearchItem> onTap;
  final AppStore store;

  const _GroupedResults({
    required this.results,
    required this.allQuery,
    this.askCardQuery,
    required this.expandedSections,
    required this.isHindi,
    required this.onExpand,
    required this.onTap,
    required this.store,
  });

  static const _order = [
    SearchType.bid,
    SearchType.tool,
    SearchType.lesson,
    SearchType.finance,
    SearchType.calculator,
    SearchType.category,
    SearchType.faq,
    SearchType.document,
    SearchType.myData,
  ];

  static String _groupLabel(SearchType t, AppStore s) => switch (t) {
    SearchType.bid => s.t('Bids', 'बोलियाँ'),
    SearchType.tool => s.t('Tools', 'टूल'),
    SearchType.lesson => s.t('Learn', 'सीखें'),
    SearchType.finance => s.t('Finance', 'वित्त'),
    SearchType.calculator => s.t('Calculators', 'कैलकुलेटर'),
    SearchType.category => s.t('Categories', 'श्रेणियाँ'),
    SearchType.faq => s.t('FAQs', 'अक्सर पूछे जाने वाले प्रश्न'),
    SearchType.document => s.t('Documents', 'दस्तावेज़'),
    SearchType.myData => s.t('My data', 'मेरा डेटा'),
  };

  @override
  Widget build(BuildContext context) {
    final grouped = <SearchType, List<SearchItem>>{};
    for (final r in results) {
      grouped.putIfAbsent(r.type, () => []).add(r);
    }

    final sections = _order.where((t) => grouped.containsKey(t)).toList();

    return ListView(
      children: [
        for (final type in sections) ...[
          _SectionLabel(_groupLabel(type, store), isHindi: isHindi),
          if (type == SearchType.bid) IllustrativeLabel(isHindi: isHindi),
          ..._buildSection(grouped[type]!, type, context),
        ],
        if (askCardQuery != null)
          _AskBizReadyCard(query: askCardQuery!, isHindi: isHindi),
        const SizedBox(height: AppSpace.huge),
      ],
    );
  }

  List<Widget> _buildSection(
    List<SearchItem> items,
    SearchType type,
    BuildContext context,
  ) {
    final expanded = expandedSections.contains(type);
    final visible = expanded ? items : items.take(_kGroupPreview).toList();
    final hidden = items.length - _kGroupPreview;

    return [
      for (var i = 0; i < visible.length; i++) ...[
        if (i > 0) const Divider(height: 1, indent: AppSpace.xxl),
        _resultRow(visible[i]),
      ],
      if (!expanded && hidden > 0)
        _SeeMoreRow(
          count: hidden,
          isHindi: isHindi,
          store: store,
          onTap: () => onExpand(type),
        ),
    ];
  }

  Widget _resultRow(SearchItem item) {
    if (item.type == SearchType.bid) {
      final bid = sampleBidSource.bids.firstWhere(
        (b) => b.id == item.routeArg,
        orElse: () => sampleBidSource.bids.first,
      );
      return BidResultRow(
        bid: bid,
        isHindi: isHindi,
        query: allQuery,
        store: store,
        onTap: () => onTap(item),
      );
    }
    return SearchResultRow(
      item: item,
      isHindi: isHindi,
      query: allQuery,
      onTap: () => onTap(item),
    );
  }
}

// ── Empty query screen ────────────────────────────────────────────────────────

class _EmptyQueryBody extends StatelessWidget {
  final AppStore store;
  final SearchStore searchStore;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onFill;
  final VoidCallback onClearAll;

  const _EmptyQueryBody({
    required this.store,
    required this.searchStore,
    required this.onTap,
    required this.onFill,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final recent = searchStore.recent.take(8).toList();
    final trending = kCategories
        .where((c) => _kTrendingIds.contains(c.id))
        .toList();
    final suggested = [...kNamedBids]
      ..sort((a, b) => b.effectiveScore.compareTo(a.effectiveScore));
    final top4 = suggested.take(4).toList();
    final isHi = store.language == 'hi';

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.huge),
      children: [
        // ── Recent searches ─────────────────────────────────────────────────
        if (recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.lg,
              AppSpace.xxl,
              AppSpace.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    store.t('Recent searches', 'हाल की खोजें'),
                    style: AppText.overline,
                  ),
                ),
                GestureDetector(
                  onTap: onClearAll,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                    child: Text(
                      store.t('Clear all', 'सभी हटाएँ'),
                      style: AppText.label.copyWith(color: AppColors.brand),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final q in recent) _RecentRow(query: q, store: store, onTap: onTap, onFill: onFill),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.huge,
              AppSpace.xxl,
              0,
            ),
            child: Text(
              isHi
                  ? 'बोलियाँ, टूल, या GST, MSME जैसे शब्द खोजें'
                  : 'Search bids, tools, or terms like GST, MSME',
              style: AppText.secondary(AppText.body),
              textAlign: TextAlign.center,
            ),
          ),

        // ── Trending categories ─────────────────────────────────────────────
        if (trending.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.xl,
              AppSpace.xxl,
              AppSpace.sm,
            ),
            child: Text(
              store.t('Trending categories', 'लोकप्रिय श्रेणियाँ'),
              style: AppText.overline,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.sm,
              children: [
                for (final cat in trending)
                  _TrendingChip(
                    label: isHi ? cat.titleHi : cat.titleEn,
                    onTap: () => onTap(cat.titleEn),
                  ),
              ],
            ),
          ),
        ],

        // ── Suggested for you ───────────────────────────────────────────────
        if (top4.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.xl,
              AppSpace.xxl,
              AppSpace.sm,
            ),
            child: Text(
              store.t('Suggested for you', 'आपके लिए सुझाव'),
              style: AppText.overline,
            ),
          ),
          IllustrativeLabel(isHindi: isHi),
          for (var i = 0; i < top4.length; i += 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                0,
                AppSpace.lg,
                AppSpace.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SuggestedBidCard(
                      bid: top4[i],
                      isHindi: isHi,
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/bid-detail',
                        arguments: top4[i].id,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: i + 1 < top4.length
                        ? _SuggestedBidCard(
                            bid: top4[i + 1],
                            isHindi: isHi,
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/bid-detail',
                              arguments: top4[i + 1].id,
                            ),
                          )
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

// ── No results screen ─────────────────────────────────────────────────────────

class _NoResultsBody extends StatelessWidget {
  final AppStore store;
  final ValueChanged<String> onSuggestion;

  const _NoResultsBody({required this.store, required this.onSuggestion});

  static const _suggestions = ['tender', 'stationery', 'OD'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.huge),
      children: [
        StateView(
          kind: StateKind.empty,
          title: store.t('No results found', 'कोई परिणाम नहीं मिला'),
          message: store.t(
            'Try different words or use Ask BizReady.',
            'अलग शब्द आज़माएँ या Ask BizReady का उपयोग करें।',
          ),
          actionLabel: 'Ask BizReady',
          onAction: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/gem-check');
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              Text(
                store.t('Try:', 'आज़माएँ:'),
                style: AppText.caption,
              ),
              for (final s in _suggestions)
                _TrendingChip(
                  label: s,
                  onTap: () => onSuggestion(s),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _RecentRow extends StatelessWidget {
  final String query;
  final AppStore store;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onFill;

  const _RecentRow({
    required this.query,
    required this.store,
    required this.onTap,
    required this.onFill,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => onTap(query),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xxl,
        vertical: AppSpace.md,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history,
            size: AppIconSize.sm,
            color: AppColors.textHint,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(query, style: AppText.body)),
          // ↖ fills the field without running the search
          GestureDetector(
            onTap: () => onFill(query),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpace.sm,
                vertical: AppSpace.xs,
              ),
              child: Icon(
                Icons.north_west,
                size: AppIconSize.sm,
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TrendingChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TrendingChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: AppText.label.copyWith(fontSize: 13)),
    ),
  );
}

class _SeeMoreRow extends StatelessWidget {
  final int count;
  final bool isHindi;
  final AppStore store;
  final VoidCallback onTap;

  const _SeeMoreRow({
    required this.count,
    required this.isHindi,
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.xxl,
        vertical: AppSpace.md,
      ),
      child: Row(
        children: [
          Text(
            isHindi ? 'और $count देखें' : 'See $count more',
            style: AppText.label.copyWith(color: AppColors.brand),
          ),
          const SizedBox(width: AppSpace.xs),
          const Icon(
            Icons.keyboard_arrow_down,
            size: AppIconSize.sm + 2,
            color: AppColors.brand,
          ),
        ],
      ),
    ),
  );
}

class _SuggestedBidCard extends StatelessWidget {
  final SampleBid bid;
  final bool isHindi;
  final VoidCallback onTap;

  const _SuggestedBidCard({
    required this.bid,
    required this.isHindi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHindi ? (bid.titleHi ?? bid.displayTitle) : bid.displayTitle,
              style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpace.xs),
            StatusChip(
              '${bid.effectiveScore}%',
              tone: StatusTone.success,
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Ask BizReady fallback ─────────────────────────────────────────────────────

class _AskBizReady extends StatelessWidget {
  final String query;
  final bool isHindi;

  const _AskBizReady({required this.query, required this.isHindi});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpace.xxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpace.huge),
        const Icon(
          Icons.support_agent_outlined,
          size: AppIconSize.lg + 8,
          color: AppColors.brand,
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          isHindi ? 'Ask BizReady से पूछें' : 'Ask BizReady',
          style: AppText.h3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          isHindi
              ? 'यह प्रश्न की तरह लग रहा है। BizReady सहायक को खोलें।'
              : 'This looks like a question. Open the BizReady assistant.',
          style: AppText.secondary(AppText.body),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpace.xl),
        AppButton(
          label: isHindi ? 'Ask BizReady खोलें' : 'Open Ask BizReady',
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/gem-check');
          },
          expand: false,
        ),
      ],
    ),
  );
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isHindi;
  const _SectionLabel(this.label, {required this.isHindi});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.xxl,
      AppSpace.lg,
      AppSpace.xxl,
      AppSpace.xs,
    ),
    child: Text(label, style: AppText.overline),
  );
}

// ── Bid filter chip row ───────────────────────────────────────────────────────

class _BidFilterRow extends StatelessWidget {
  final BidFilter filter;
  final ValueChanged<BidFilter> onUpdate;
  final AppStore store;

  const _BidFilterRow({
    required this.filter,
    required this.onUpdate,
    required this.store,
  });

  static const _valueOptions = [
    (100000, '< ₹1L'),
    (500000, '< ₹5L'),
    (2500000, '< ₹25L'),
    (10000000, '< ₹1Cr'),
  ];

  static const _closingOptions = [
    (3, '≤3d'),
    (7, '≤7d'),
    (30, '≤30d'),
  ];

  @override
  Widget build(BuildContext context) {
    final isHi = store.language == 'hi';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.xs,
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
          // Reset button first so it's always visible when any filter is active
          if (filter.hasAny) ...[
            _BidFilterChip(
              label: store.t('Reset filters', 'फ़िल्टर रीसेट करें'),
              active: false,
              onTap: () => onUpdate(const BidFilter.empty()),
            ),
            const SizedBox(width: AppSpace.md),
          ],
          _BidFilterChip(
            label: filter.state != null
                ? (isHi ? _stateHi(filter.state!) : filter.state!)
                : store.t('State', 'राज्य'),
            active: filter.state != null,
            onTap: () => _showStatePicker(context),
          ),
          const SizedBox(width: AppSpace.sm),
          for (final (val, label) in _valueOptions) ...[
            _BidFilterChip(
              label: label,
              active: filter.maxValueRs == val,
              onTap: () => onUpdate(
                filter.copyWith(maxValueRs: filter.maxValueRs == val ? null : val),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
          ],
          for (final (days, label) in _closingOptions) ...[
            _BidFilterChip(
              label: label,
              active: filter.closingInDays == days,
              onTap: () => onUpdate(
                filter.copyWith(
                  closingInDays: filter.closingInDays == days ? null : days,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
          ],
          _BidFilterChip(
            label: 'MSE',
            active: filter.mseRelaxation == true,
            onTap: () => onUpdate(
              filter.copyWith(
                mseRelaxation: filter.mseRelaxation == true ? null : true,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          _BidFilterChip(
            label: store.t('Startup', 'स्टार्टअप'),
            active: filter.startupRelaxation == true,
            onTap: () => onUpdate(
              filter.copyWith(
                startupRelaxation: filter.startupRelaxation == true ? null : true,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          _BidFilterChip(
            label: store.t('EMD free', 'EMD मुक्त'),
            active: filter.emdExemption == true,
            onTap: () => onUpdate(
              filter.copyWith(
                emdExemption: filter.emdExemption == true ? null : true,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _stateHi(String state) {
    return const {
      'Delhi': 'दिल्ली',
      'Maharashtra': 'महाराष्ट्र',
      'Pan India': 'सर्व भारत',
    }[state] ?? state;
  }

  void _showStatePicker(BuildContext context) {
    final states = kNamedBids
        .map((b) => b.state)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _StatePickerSheet(
        states: states,
        selected: filter.state,
        store: store,
        onSelect: (state) {
          onUpdate(filter.copyWith(state: state));
          Navigator.pop(context);
        },
        onClear: () {
          onUpdate(filter.copyWith(state: null));
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ── Bid filter chip ───────────────────────────────────────────────────────────

class _BidFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BidFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: 5),
      decoration: BoxDecoration(
        color: active ? AppColors.ink : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: active ? AppColors.ink : AppColors.borderStrong,
        ),
      ),
      child: Text(
        label,
        style: AppText.label.copyWith(
          fontSize: 12,
          color: active ? AppColors.surface : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

// ── State picker sheet ────────────────────────────────────────────────────────

class _StatePickerSheet extends StatelessWidget {
  final List<String> states;
  final String? selected;
  final AppStore store;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;

  const _StatePickerSheet({
    required this.states,
    required this.selected,
    required this.store,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.xl,
              AppSpace.xxl,
              AppSpace.sm,
            ),
            child: Text(
              store.t('State', 'राज्य'),
              style: AppText.h3,
            ),
          ),
          for (final state in states)
            ListTile(
              title: Text(state, style: AppText.body),
              trailing: selected == state
                  ? const Icon(Icons.check, color: AppColors.ink)
                  : null,
              onTap: () => onSelect(state),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xxl,
              ),
            ),
          if (selected != null)
            ListTile(
              title: Text(
                store.t('Any state', 'कोई भी राज्य'),
                style: AppText.body.copyWith(color: AppColors.brand),
              ),
              onTap: onClear,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xxl,
              ),
            ),
          const SizedBox(height: AppSpace.md),
        ],
      ),
    );
  }
}

// ── Sort bottom sheet ─────────────────────────────────────────────────────────

class _SortSheet extends StatefulWidget {
  final SortOption current;
  final bool isHindi;
  final AppStore store;
  final ValueChanged<SortOption> onApply;

  const _SortSheet({
    required this.current,
    required this.isHindi,
    required this.store,
    required this.onApply,
  });

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late SortOption _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.xl,
              AppSpace.xxl,
              AppSpace.sm,
            ),
            child: Text(s.t('Sort', 'क्रम'), style: AppText.h3),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: RadioGroup<SortOption>(
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v!),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final opt in SortOption.values)
                      RadioListTile<SortOption>(
                        value: opt,
                        title: Text(
                          widget.isHindi ? opt.labelHi : opt.labelEn,
                          style: AppText.body,
                        ),
                        activeColor: AppColors.ink,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.xxl,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: s.t('Reset', 'रीसेट'),
                    variant: AppButtonVariant.secondary,
                    onPressed: () => setState(
                      () => _selected = SortOption.bestMatch,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: AppButton(
                    label: s.t('Done', 'हो गया'),
                    onPressed: () {
                      widget.onApply(_selected);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search header (AppBar with plain "Search" title) ─────────────────────────

class _SearchHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool isHindi;
  final AppStore store;
  final VoidCallback onBack;
  final bool hasSaved;
  final VoidCallback? onSavedSearches;

  const _SearchHeader({
    required this.isHindi,
    required this.store,
    required this.onBack,
    this.hasSaved = false,
    this.onSavedSearches,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: AppColors.surface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: onBack,
      tooltip: store.t('Back', 'वापस'),
    ),
    title: Text(
      store.t('Search', 'खोजें'),
      style: AppText.title,
    ),
    centerTitle: false,
    actions: [
      if (hasSaved)
        IconButton(
          icon: const Icon(Icons.bookmarks_outlined),
          onPressed: onSavedSearches,
          tooltip: store.t('Saved searches', 'सेव की गई खोजें'),
        ),
    ],
  );
}

// ── Saved searches bottom sheet ───────────────────────────────────────────────

class _SavedSearchesSheet extends StatefulWidget {
  final SearchStore searchStore;
  final AppStore store;
  final ValueChanged<String> onSearch;

  const _SavedSearchesSheet({
    required this.searchStore,
    required this.store,
    required this.onSearch,
  });

  @override
  State<_SavedSearchesSheet> createState() => _SavedSearchesSheetState();
}

class _SavedSearchesSheetState extends State<_SavedSearchesSheet> {
  late List<String> _saved;

  @override
  void initState() {
    super.initState();
    _saved = widget.searchStore.saved;
  }

  void _delete(String q) async {
    await widget.searchStore.removeSaved(q);
    if (mounted) setState(() => _saved = widget.searchStore.saved);
  }

  void _showRenameDialog(String q) {
    final controller = TextEditingController(text: q);
    final s = widget.store;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('Rename', 'नाम बदलें')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: s.t('New name', 'नया नाम'),
          ),
          onSubmitted: (_) => Navigator.pop(ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.t('Cancel', 'रद्द करें')),
          ),
          TextButton(
            onPressed: () async {
              final newQ = controller.text.trim();
              if (newQ.isNotEmpty && newQ != q) {
                await widget.searchStore.renameSaved(q, newQ);
                if (mounted) {
                  setState(() => _saved = widget.searchStore.saved);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(s.t('Save', 'सेव करें')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.xl,
              AppSpace.xxl,
              AppSpace.sm,
            ),
            child: Text(s.t('Saved searches', 'सेव की गई खोजें'), style: AppText.h3),
          ),
          if (_saved.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xxl,
                AppSpace.lg,
                AppSpace.xxl,
                AppSpace.xl,
              ),
              child: Text(
                s.t('No saved searches yet', 'अभी कोई सेव की गई खोज नहीं'),
                style: AppText.secondary(AppText.body),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _saved.length,
                separatorBuilder: (context, i) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final q = _saved[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.bookmark_outline,
                      color: AppColors.textSecondary,
                    ),
                    title: Text(q, style: AppText.body),
                    onTap: () => widget.onSearch(q),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.xxl,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: AppIconSize.sm,
                            color: AppColors.textHint,
                          ),
                          tooltip: s.t('Rename', 'नाम बदलें'),
                          onPressed: () => _showRenameDialog(q),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: AppIconSize.sm,
                            color: AppColors.textHint,
                          ),
                          tooltip: s.t('Remove saved search', 'सेव की गई खोज हटाएँ'),
                          onPressed: () => _delete(q),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  }
}

// ── Ask BizReady inline card ──────────────────────────────────────────────────

class _AskBizReadyCard extends StatelessWidget {
  final String query;
  final bool isHindi;

  const _AskBizReadyCard({required this.query, required this.isHindi});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Navigator.pop(context);
      Navigator.pushNamed(context, '/gem-check');
    },
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xxl,
        AppSpace.lg,
        AppSpace.xxl,
        AppSpace.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.brandTint,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            children: [
              const Icon(
                Icons.support_agent_outlined,
                color: AppColors.brand,
                size: AppIconSize.md,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'Ask BizReady से पूछें' : 'Ask BizReady',
                      style: AppText.label.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      isHindi
                          ? 'इस सवाल के लिए BizReady सहायक खोलें'
                          : 'Open the BizReady assistant for this question',
                      style: AppText.secondary(AppText.bodySmall),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              const Icon(
                Icons.arrow_forward_ios,
                size: AppIconSize.sm,
                color: AppColors.brand,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
