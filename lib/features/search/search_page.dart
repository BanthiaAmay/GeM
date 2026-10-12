import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../../data/sample_bids.dart';
import '../components.dart';
import 'bid_source.dart';
import 'search_engine.dart';
import 'search_models.dart';
import 'search_result_card.dart';
import 'search_store.dart';

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
  List<SearchItem> _results = [];
  String _lastQuery = '';

  bool get _isHi => widget.store.language == 'hi';

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
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final q = _controller.text;
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.trim().length >= 2) {
      _runSearch();
    } else if (q.isEmpty) {
      setState(() => _results = []);
    }
  }

  void _runSearch() {
    final q = _controller.text.trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final r = _engine.query(q, scope: _scope, sort: _sort);
    setState(() => _results = r);
  }

  void _submit(String q) {
    if (q.trim().isEmpty) return;
    widget.searchStore.addRecent(q.trim());
    _runSearch();
    _focus.unfocus();
    // Analytics — length and count only, never raw query
    widget.store.event('search_performed', props: {
      'len': q.length,
      'results': _results.length,
      'scope': _scope.name,
    });
  }

  void _selectScope(SearchScope scope) {
    setState(() => _scope = scope);
    _runSearch();
  }

  void _openBidDetail(SampleBid bid) {
    widget.store.event('bid_detail_opened', props: {'id': bid.id});
    Navigator.pushNamed(context, '/bid-detail', arguments: bid.id);
  }

  void _openItem(SearchItem item) {
    widget.store.event('search_result_opened', props: {
      'type': item.type.name,
      'id': item.id,
    });
    if (item.type == SearchType.bid) {
      final bid = sampleBidSource.bids.firstWhere(
        (b) => b.id == item.routeArg,
        orElse: () => sampleBidSource.bids.first,
      );
      _openBidDetail(bid);
    } else {
      Navigator.pushNamed(context, '/${item.route}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHi = _isHi;
    final q = _controller.text.trim();
    final hasQuery = q.isNotEmpty;
    final isQuestion = hasQuery && SearchEngine.isQuestion(q);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: _SearchAppBar(
        controller: _controller,
        focus: _focus,
        isHindi: isHi,
        onSubmit: _submit,
        onClear: () {
          _controller.clear();
          setState(() => _results = []);
          _focus.requestFocus();
        },
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          // Scope tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.sm,
              AppSpace.xxl,
              0,
            ),
            child: AppSegmentedControl<SearchScope>(
              options: [
                for (final s in SearchScope.values)
                  (s, isHi ? s.labelHi : s.labelEn, null),
              ],
              value: _scope,
              onChanged: _selectScope,
              semanticLabel: isHi ? 'खोज दायरा' : 'Search scope',
            ),
          ),
          // Sort row
          if (hasQuery && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xxl,
                vertical: AppSpace.sm,
              ),
              child: Row(
                children: [
                  Text(
                    '${_results.length} ${isHi ? "परिणाम" : "results"}',
                    style: AppText.caption,
                  ),
                  const Spacer(),
                  AppDropdownChip<SortOption>(
                    options: [
                      for (final s in SortOption.values)
                        (s, isHi ? s.labelHi : s.labelEn),
                    ],
                    value: _sort,
                    onChanged: (s) {
                      setState(() => _sort = s);
                      _runSearch();
                    },
                    semanticLabel: isHi ? 'क्रम से लगाएँ' : 'Sort by',
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(child: _buildBody(hasQuery, isQuestion, isHi)),
        ],
      ),
    );
  }

  Widget _buildBody(bool hasQuery, bool isQuestion, bool isHi) {
    if (!hasQuery) {
      return _Suggestions(
        recent: widget.searchStore.recent,
        isHindi: isHi,
        onTap: (q) {
          _controller.text = q;
          _submit(q);
        },
      );
    }

    if (_results.isEmpty && _controller.text.trim().length >= 2) {
      if (isQuestion) {
        return _AskBizReady(query: _controller.text, isHindi: isHi);
      }
      return StateView(
        kind: StateKind.empty,
        title: isHi ? 'कोई परिणाम नहीं' : 'No results',
        message: isHi
            ? 'कोई अन्य शब्द आज़माएँ या Ask BizReady का उपयोग करें।'
            : 'Try different words or use Ask BizReady.',
        actionLabel: isHi ? 'Ask BizReady' : 'Ask BizReady',
        onAction: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/gem-check');
        },
      );
    }

    final bids = _results.where((r) => r.type == SearchType.bid).toList();
    final tools = _results.where((r) => r.type == SearchType.tool).toList();
    final others = _results
        .where((r) => r.type != SearchType.bid && r.type != SearchType.tool)
        .toList();

    return ListView(
      children: [
        if (bids.isNotEmpty) ...[
          _SectionLabel(isHi ? 'बोलियाँ' : 'Bids', isHindi: isHi),
          IllustrativeLabel(isHindi: isHi),
          for (var i = 0; i < bids.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpace.xxl),
            BidResultRow(
              bid: sampleBidSource.bids.firstWhere(
                (b) => b.id == bids[i].routeArg,
                orElse: () => sampleBidSource.bids.first,
              ),
              isHindi: isHi,
              onTap: () => _openItem(bids[i]),
            ),
          ],
        ],
        if (tools.isNotEmpty) ...[
          _SectionLabel(isHi ? 'टूल' : 'Tools', isHindi: isHi),
          for (var i = 0; i < tools.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpace.xxl),
            SearchResultRow(
              item: tools[i],
              isHindi: isHi,
              onTap: () => _openItem(tools[i]),
            ),
          ],
        ],
        if (others.isNotEmpty) ...[
          _SectionLabel(isHi ? 'अन्य' : 'Other', isHindi: isHi),
          for (var i = 0; i < others.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: AppSpace.xxl),
            SearchResultRow(
              item: others[i],
              isHindi: isHi,
              onTap: () => _openItem(others[i]),
            ),
          ],
        ],
        const SizedBox(height: AppSpace.huge),
      ],
    );
  }
}

// ── Suggestions / recent searches ─────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  final List<String> recent;
  final bool isHindi;
  final ValueChanged<String> onTap;

  const _Suggestions({
    required this.recent,
    required this.isHindi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Text(
            isHindi
                ? 'बोलियाँ, टूल, या GST, MSME जैसे शब्द खोजें'
                : 'Search bids, tools, or terms like GST, MSME',
            style: AppText.secondary(AppText.body),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.xxl,
            vertical: AppSpace.sm,
          ),
          child: Text(
            isHindi ? 'हाल की खोजें' : 'Recent searches',
            style: AppText.overline,
          ),
        ),
        for (final q in recent)
          InkWell(
            onTap: () => onTap(q),
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
                  Expanded(child: Text(q, style: AppText.body)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Ask BizReady fallback ──────────────────────────────────────────────────────

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

// ── Search AppBar ─────────────────────────────────────────────────────────────

class _SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool isHindi;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;
  final VoidCallback onBack;

  const _SearchAppBar({
    required this.controller,
    required this.focus,
    required this.isHindi,
    required this.onSubmit,
    required this.onClear,
    required this.onBack,
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
      tooltip: isHindi ? 'वापस' : 'Back',
    ),
    title: TextField(
      controller: controller,
      focusNode: focus,
      autofocus: false,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: isHindi ? 'बोलियाँ, टूल खोजें…' : 'Search bids, tools…',
        border: InputBorder.none,
        hintStyle: AppText.body.copyWith(color: AppColors.textHint),
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      style: AppText.body,
      onSubmitted: onSubmit,
    ),
    actions: [
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, v, _) => v.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClear,
                tooltip: isHindi ? 'साफ़ करें' : 'Clear',
              )
            : const SizedBox.shrink(),
      ),
    ],
  );
}
