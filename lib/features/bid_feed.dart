import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/models.dart' show money;
import '../core/motion.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'bid_compare.dart' show CompareBar, CompareToggleButton;
import 'bid_filter.dart';
import 'components.dart';
import 'onboarding_widgets.dart' show StaggeredEntrance;
import 'widgets.dart' show openLink;

enum _FeedView { matching, latest }

/// Reads published server records. Bid collection never runs on the device.
class BidFeed extends StatefulWidget {
  final AppStore store;
  const BidFeed({super.key, required this.store});
  @override
  State<BidFeed> createState() => _BidFeedState();
}

class _BidFeedState extends State<BidFeed> {
  List<Map<String, dynamic>> bids = [];
  bool loading = true;
  String? error;
  late _FeedView view = _hasPersonalProfile(widget.store)
      ? _FeedView.matching
      : _FeedView.latest;

  static bool _hasPersonalProfile(AppStore s) =>
      (s.gemCategoryName ?? '').isNotEmpty || (s.gemIndustry ?? '').isNotEmpty;

  // Splits a name into meaningful lowercase tokens (≥3 chars, no stop words).
  static List<String> _tokens(String s) {
    const stop = {
      'and', 'of', 'for', 'the', 'in', 'at', 'to', 'a', 'an', 'or', 'by',
      'on', 'as', 'is', 'are', 'with', 'from', 'its', 'this', 'that', 'per',
    };
    return s
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 3 && !stop.contains(w))
        .toList();
  }

  // Bids whose title matches the user's GeM category.
  List<Map<String, dynamic>> get _categoryBids {
    final cat = widget.store.gemCategoryName ?? '';
    if (cat.isEmpty) return [];
    final catLower = cat.toLowerCase();
    final tokens = _tokens(cat);
    return bids.where((bid) {
      final title = (bid['title'] as String? ?? '').toLowerCase();
      if (title.contains(catLower)) return true;
      final hits = tokens.where(title.contains).length;
      return hits >= (tokens.length >= 3 ? 2 : 1);
    }).toList();
  }

  // Bids whose title matches the user's industry (excluding category matches).
  List<Map<String, dynamic>> get _industryBids {
    final industry = widget.store.gemIndustry ?? '';
    if (industry.isEmpty) return [];
    final tokens = _tokens(industry);
    final catIds = _categoryBids.map((b) => b['source_id']).toSet();
    return bids.where((bid) {
      if (catIds.contains(bid['source_id'])) return false;
      final title = (bid['title'] as String? ?? '').toLowerCase();
      return tokens.any(title.contains);
    }).toList();
  }

  // Independent filter states per tab
  BidFilterState _forYouFilter = BidFilterState.empty;
  BidFilterState _latestFilter = BidFilterState.empty;
  final _searchCtrl = TextEditingController();

  BidFilterState get _currentFilter =>
      view == _FeedView.matching ? _forYouFilter : _latestFilter;

  void _setCurrentFilter(BidFilterState f) {
    setState(() {
      if (view == _FeedView.matching) {
        _forYouFilter = f;
      } else {
        _latestFilter = f;
      }
    });
  }

  List<Map<String, dynamic>> get _displayBids =>
      BidFilterLogic.apply(bids, _currentFilter);

  Future<void> _openFilter() async {
    final result = await showBidFilterSheet(
      context: context,
      store: widget.store,
      current: _currentFilter,
      allBids: bids,
    );
    if (result != null && mounted) _setCurrentFilter(result);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  Future<void> refresh() async {
    final s = widget.store;
    if (s.client == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      List<dynamic> result;
      // For "For you": fetch a larger pool so the client-side category/industry
      // filter has enough bids to work with. For "Latest": standard 50.
      final limit = view == _FeedView.matching ? 200 : 50;
      result = await s.client!
          .from('gem_bids')
          .select()
          .eq('published', true)
          .gt('closes_at', DateTime.now().toUtc().toIso8601String())
          .order('starts_at', ascending: false, nullsFirst: false)
          .limit(limit);
      if (mounted) {
        setState(
          () => bids = [
            for (final row in result) Map<String, dynamic>.from(row as Map),
          ],
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = s.t(
            'The bid feed could not be loaded. Please retry.',
            'बोली सूची लोड नहीं हुई। फिर कोशिश करें।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _empty(AppStore s) {
    if (view == _FeedView.latest) {
      return StateView(
        kind: StateKind.empty,
        title: s.t('No bids yet', 'अभी कोई बोली नहीं'),
        message: s.t(
          'No live bids are available here yet. Browse the official GeM bid list while the feed is being connected.',
          'यहाँ अभी लाइव बोलियाँ उपलब्ध नहीं हैं। स्रोत जुड़ने तक आधिकारिक GeM बोली सूची देखें।',
        ),
      );
    }
    if (!_hasPersonalProfile(s)) {
      return StateView(
        kind: StateKind.empty,
        title: s.t('Complete your profile', 'अपनी प्रोफ़ाइल पूरी करें'),
        message: s.t(
          'Set your GeM category and industry during sign-up to see bids matched to your business.',
          'अपने व्यवसाय से मेल खाती बोलियाँ देखने के लिए साइन-अप में GeM श्रेणी और उद्योग चुनें।',
        ),
      );
    }
    return StateView(
      kind: StateKind.empty,
      title: s.t('No matching open bids yet', 'अभी कोई मेल खाती खुली बोली नहीं'),
      message: s.t(
        'No live bids matched your category or industry in the latest 200 bids. Try again later.',
        'नवीनतम 200 बोलियों में आपकी श्रेणी या उद्योग से कोई मेल नहीं मिला। बाद में पुनः प्रयास करें।',
      ),
    );
  }

  // Renders a labeled section of bid cards for the "For you" tab.
  Widget _bidSection(
    AppStore s,
    String label,
    String labelHi,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm, vertical: AppSpace.xs + 2),
          decoration: BoxDecoration(
            color: AppColors.brandTint,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            s.t(label, labelHi),
            style: AppText.overline.copyWith(color: AppColors.brand),
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        for (final (i, bid) in items.indexed)
          StaggeredEntrance(
            key: ValueKey('fy-${bid['source_id'] ?? i}'),
            index: i.clamp(0, 8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.lg),
              child: _BidCard(store: s, bid: bid),
            ),
          ),
      ],
    );
  }

  Widget _buildForYouContent(AppStore s) {
    final catBids = _categoryBids;
    final indBids = _industryBids;
    final cat = s.gemCategoryName ?? '';
    final industry = s.gemIndustry ?? '';

    if (catBids.isEmpty && indBids.isEmpty) {
      return _empty(s);
    }

    return Column(
      key: const ValueKey('for-you-inner'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (catBids.isNotEmpty)
          _bidSection(
            s,
            cat.isNotEmpty ? '$cat Bids' : 'Category Bids',
            cat.isNotEmpty ? '$cat बोलियाँ' : 'श्रेणी बोलियाँ',
            catBids,
          ),
        if (catBids.isNotEmpty && indBids.isNotEmpty)
          const SizedBox(height: AppSpace.lg),
        if (indBids.isNotEmpty)
          _bidSection(
            s,
            industry.isNotEmpty ? '$industry Bids' : 'Industry Bids',
            industry.isNotEmpty ? '$industry बोलियाँ' : 'उद्योग बोलियाँ',
            indBids,
          ),
      ],
    );
  }

  /// Crossfades between loading/error/empty/content. The 'content' key
  /// stays stable across filter changes (only its inner list differs),
  /// so filtering never disposes/replays the cards' own entrance state —
  /// only a genuine state-kind change (e.g. loading finishing) animates.
  Widget _buildStateBody(BuildContext context, AppStore s) {
    final String stateKey;
    final Widget body;
    if (loading) {
      stateKey = 'loading';
      body = StateView(
        kind: StateKind.loading,
        title: s.t('Loading bids', 'बोलियाँ लोड हो रही हैं'),
      );
    } else if (error != null) {
      stateKey = 'error';
      body = StateView(
        kind: StateKind.error,
        title: error!,
        actionLabel: s.t('Retry', 'फिर कोशिश करें'),
        onAction: refresh,
      );
    } else if (bids.isEmpty) {
      stateKey = 'empty';
      body = _empty(s);
    } else if (view == _FeedView.matching) {
      stateKey = 'for-you';
      body = _buildForYouContent(s);
    } else {
      stateKey = 'content';
      body = Column(
        key: const ValueKey('content-inner'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result count when filters are active
          if (_currentFilter.hasAny) ...[
            Builder(
              builder: (_) {
                final shown = _displayBids.length;
                final total = bids.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Text(
                    s.t(
                      'Showing $shown of $total bids',
                      '$total में से $shown बोलियाँ दिख रही हैं',
                    ),
                    style: AppText.caption.copyWith(color: AppColors.textHint),
                  ),
                );
              },
            ),
          ],
          if (_displayBids.isEmpty && bids.isNotEmpty)
            StateView(
              kind: StateKind.empty,
              title: s.t(
                'No bids match your filters',
                'कोई बोली फ़िल्टर से नहीं मिली',
              ),
              message: s.t(
                'Try removing some filters or clearing all.',
                'कुछ फ़िल्टर हटाएँ या सब हटाएँ।',
              ),
              actionLabel: s.t('Clear filters', 'फ़िल्टर हटाएँ'),
              onAction: () => _setCurrentFilter(BidFilterState.empty),
            ),
          for (final (i, bid) in _displayBids.indexed)
            StaggeredEntrance(
              key: ValueKey(bid['source_id'] as String? ?? i),
              index: i.clamp(0, 8),
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.lg),
                child: _BidCard(store: s, bid: bid),
              ),
            ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.normal),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: ValueKey(stateKey), child: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Page intro ─────────────────────────────────────────────────────
        Text(
          s.t('Find your next opportunity.', 'अपना अगला अवसर खोजें।'),
          style: AppText.h1,
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          s.t(
            'Live bids from GeM. Confirm details on GeM before bidding.',
            'GeM से लाइव बोलियाँ। बोली देने से पहले GeM पर जाँचें।',
          ),
          style: AppText.caption,
        ),
        const SizedBox(height: AppSpace.lg),

        // ── Tab + controls row ──────────────────────────────────────────────
        AppSegmentedControl<_FeedView>(
          options: [
            (_FeedView.matching, s.t('For you', 'आपके लिए'), null),
            (_FeedView.latest, s.t('Latest', 'नवीनतम'), null),
          ],
          value: view,
          semanticLabel: s.t('Bids to show', 'दिखाई जाने वाली बोलियाँ'),
          onChanged: (v) {
            setState(() => view = v);
            unawaited(refresh());
          },
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            _ActionChip(
              icon: Icons.refresh,
              label: s.t('Refresh', 'ताज़ा करें'),
              onTap: loading ? null : refresh,
            ),
            _ActionChip(
              icon: Icons.filter_list,
              label: _currentFilter.activeCount > 0
                  ? '${s.t('Filter', 'फ़िल्टर')} (${_currentFilter.activeCount})'
                  : s.t('Filter', 'फ़िल्टर'),
              onTap: bids.isEmpty ? null : _openFilter,
              active: _currentFilter.activeCount > 0,
            ),
            _ActionChip(
              icon: Icons.tune_outlined,
              label: s.t('Set alerts', 'अलर्ट चुनें'),
              onTap: () => Navigator.pushNamed(context, '/alerts'),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        // ── Search field ────────────────────────────────────────────────────
        _SearchBar(
          store: s,
          controller: _searchCtrl,
          onChanged: (q) {
            final f = _currentFilter.copyWith(searchQuery: q);
            _setCurrentFilter(f);
          },
        ),
        const SizedBox(height: AppSpace.sm),
        // ── Active filter chips ─────────────────────────────────────────────
        if (_currentFilter.activeCount > 0) ...[
          ActiveFilterChips(
            filter: _currentFilter,
            store: s,
            onChanged: _setCurrentFilter,
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        const SizedBox(height: AppSpace.sm),

        // ── Compare bar (shown when ≥1 bid selected) ────────────────────────
        ListenableBuilder(
          listenable: s,
          builder: (context, _) => CompareBar(store: s),
        ),

        // ── Content ─────────────────────────────────────────────────────────
        _buildStateBody(context, s),
        const SizedBox(height: AppSpace.xxl),
        AppButton(
          label: s.t('Browse official GeM bids', 'आधिकारिक GeM बोलियाँ देखें'),
          variant: AppButtonVariant.secondary,
          trailingIcon: Icons.open_in_new,
          onPressed: () =>
              openLink(context, s, 'https://bidplus.gem.gov.in/all-bids'),
        ),
      ],
    );
  }
}

// ── Small action chip for the top controls row ──────────────────────────────
class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const _ActionChip({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = disabled
        ? AppColors.surfaceMuted
        : active
        ? AppColors.brand
        : AppColors.brandTint;
    final fg = disabled
        ? AppColors.textHint
        : active
        ? AppColors.surface
        : AppColors.brand;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: AppSpace.xs),
            Text(label, style: AppText.label.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}

// ── Search bar below the action chips ────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final AppStore store;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({
    required this.store,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppText.body,
      decoration: InputDecoration(
        hintText: s.t('Search bids, ID, buyer…', 'बोली, ID, खरीदार खोजें…'),
        hintStyle: AppText.caption.copyWith(color: AppColors.textHint),
        prefixIcon: const Icon(
          Icons.search,
          size: AppIconSize.sm,
          color: AppColors.textHint,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: const Icon(
                  Icons.close,
                  size: AppIconSize.sm,
                  color: AppColors.textHint,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
    );
  }
}

// ── Individual bid card ─────────────────────────────────────────────────────
class _BidCard extends StatelessWidget {
  final AppStore store;
  final Map<String, dynamic> bid;
  const _BidCard({required this.store, required this.bid});

  static String _text(Object? value) => (value as String? ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final s = store;
    final details = Map<String, dynamic>.from(bid['details'] as Map? ?? {});

    // Buyer + location
    final buyer = [
      bid['organisation'],
      bid['buyer'],
      bid['ministry'],
    ].map(_text).firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final state = _text(bid['state']);
    final whereStr = [buyer, state].where((v) => v.isNotEmpty).join(' · ');

    // Close date + urgency
    final closesAt = DateTime.tryParse(bid['closes_at'] as String? ?? '');
    final daysLeft = closesAt?.toLocal().difference(DateTime.now()).inDays;
    final closesDisplay = closesAt != null
        ? DateFormat('d MMM yyyy, h:mm a').format(closesAt.toLocal())
        : '—';

    Color badgeBg = AppColors.brandTint;
    Color badgeFg = AppColors.brand;
    if (daysLeft != null) {
      if (daysLeft <= 3) {
        badgeBg = AppColors.dangerTint;
        badgeFg = AppColors.danger;
      } else if (daysLeft <= 7) {
        badgeBg = AppColors.warningTint;
        badgeFg = AppColors.warning;
      }
    }

    // Metrics
    final emdAmount = num.tryParse(_text(details['emd_amount']));
    final emd = emdAmount != null
        ? money(emdAmount)
        : details['emd_required'] == 'No'
        ? s.t('Not required', 'आवश्यक नहीं')
        : null;
    final quantity = bid['quantity'];
    final experience = _text(details['experience']);
    final documents = List<String>.from(details['documents_required'] ?? []);

    // "Last collected" timestamp
    String? updatedStr;
    final fetchedRaw = bid['fetched_at'] as String?;
    if (fetchedRaw != null) {
      final dt = DateTime.tryParse(fetchedRaw);
      if (dt != null) {
        updatedStr =
            '${s.t('Updated', 'अपडेट')} '
            '${DateFormat('d MMM, h:mm a').format(dt.toLocal())}';
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.card,
        boxShadow: AppShadow.card,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: GEM ID pill + days-left badge ──────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      bid['source_id'] as String? ?? '',
                      style: AppText.overline.copyWith(
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (daysLeft != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        daysLeft <= 0
                            ? s.t('Closing today', 'आज बंद')
                            : s.t('$daysLeft days left', '$daysLeft दिन शेष'),
                        style: AppText.label.copyWith(color: badgeFg),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.md),

              // ── Title (3 lines max) ─────────────────────────────────────
              Text(
                bid['title'] as String? ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.title,
              ),
              const SizedBox(height: AppSpace.sm),

              // ── Buyer + State ───────────────────────────────────────────
              if (whereStr.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 13,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Flexible(
                      child: Text(
                        whereStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpace.lg),

              // ── Close date block ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.event_outlined,
                          size: 18,
                          color: badgeFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('CLOSES', 'अंतिम समय'),
                          style: AppText.overline,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          closesDisplay,
                          style: AppText.bodyStrong.copyWith(fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.sm),

              // ── Metrics: Quantity + EMD ─────────────────────────────────
              if (quantity != null || emd != null)
                Row(
                  children: [
                    if (quantity != null)
                      Expanded(
                        child: _MetricCell(
                          label: s.t('Quantity', 'मात्रा'),
                          value: '$quantity',
                        ),
                      ),
                    if (quantity != null && emd != null)
                      const SizedBox(width: AppSpace.sm),
                    if (emd != null)
                      Expanded(
                        child: _MetricCell(label: 'EMD', value: emd),
                      ),
                  ],
                ),

              // ── Experience (if present) ─────────────────────────────────
              if (experience.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                _MetricCell(
                  label: s.t('Experience', 'अनुभव'),
                  value: experience,
                  fullWidth: true,
                ),
                const SizedBox(height: AppSpace.sm),
                AppCard(
                  tone: AppCardTone.muted,
                  padding: const EdgeInsets.all(AppSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 15, color: AppColors.warning),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(
                        child: Text(
                          s.t(
                            'Experience Certificate Disclaimer: Experience certificates must meet the specific bid requirements. Where government/PSU experience is explicitly required, certificates from private companies or MNCs alone may not be accepted. Always verify the bid\'s Past Experience Criteria before applying.',
                            'अनुभव प्रमाणपत्र अस्वीकरण: अनुभव प्रमाणपत्र बोली की विशिष्ट आवश्यकताओं को पूरा करना चाहिए। जहाँ सरकार/PSU अनुभव अनिवार्य हो, निजी कंपनी या MNC के प्रमाणपत्र अकेले मान्य नहीं हो सकते। आवेदन से पहले बोली की पिछले अनुभव की शर्तें सत्यापित करें।',
                          ),
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Documents chips ─────────────────────────────────────────
              if (documents.isNotEmpty) ...[
                const SizedBox(height: AppSpace.sm),
                _DocChips(documents: documents, store: s),
              ],

              // ── Opportunity indicators ──────────────────────────────────
              BidOpportunityIndicators(bid: bid, store: s),

              // ── Timestamp ───────────────────────────────────────────────
              if (updatedStr != null) ...[
                const SizedBox(height: AppSpace.md),
                Text(
                  updatedStr,
                  style: AppText.caption.copyWith(color: AppColors.textHint),
                ),
              ],
              const SizedBox(height: AppSpace.md),

              // ── Action row: Compare + Bookmark ─────────────────────────
              ListenableBuilder(
                listenable: s,
                builder: (context, _) => Row(
                  children: [
                    CompareToggleButton(store: s, bid: bid),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => s.toggleSavedBid(bid),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                          vertical: AppSpace.xs,
                        ),
                        child: Icon(
                          s.isSaved(bid)
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                          size: 22,
                          color: s.isSaved(bid)
                              ? AppColors.brand
                              : AppColors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              AppButton(
                label: s.t('Check eligibility', 'पात्रता जाँचें'),
                variant: AppButtonVariant.secondary,
                icon: Icons.checklist_outlined,
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/eligibility-checker',
                  arguments: bid['source_id'] as String,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              AppButton(
                label: s.t('View on GeM', 'GeM पर देखें'),
                variant: AppButtonVariant.tertiary,
                trailingIcon: Icons.open_in_new,
                onPressed: () =>
                    openLink(context, s, bid['source_url'] as String),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Metric cell: label + value in a surfaceMuted box ────────────────────────
class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;
  const _MetricCell({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: fullWidth ? double.infinity : null,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpace.md,
      vertical: AppSpace.sm,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.overline),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodyStrong,
        ),
      ],
    ),
  );
}

// ── Document chips with "+N more" overflow ───────────────────────────────────
class _DocChips extends StatelessWidget {
  final List<String> documents;
  final AppStore store;
  const _DocChips({required this.documents, required this.store});

  static const _maxShow = 2;

  String _clean(String doc) => doc
      .replaceAll(RegExp(r'\s*\(Requested in ATC\)', caseSensitive: false), '')
      .trim();

  String _shorten(String doc) {
    final clean = _clean(doc);
    return clean.length > 24 ? '${clean.substring(0, 22)}…' : clean;
  }

  void _showAllDocs(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.lg,
            AppSpace.gutter,
            AppSpace.gutter,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.t('Documents Required', 'आवश्यक दस्तावेज़'),
                style: AppText.h3,
              ),
              const SizedBox(height: AppSpace.md),
              ...documents.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.description_outlined,
                          size: 15,
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(child: Text(_clean(doc), style: AppText.body)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = documents.take(_maxShow).toList();
    final extra = documents.length - _maxShow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(store.t('Documents', 'दस्तावेज़'), style: AppText.overline),
        const SizedBox(height: AppSpace.xs),
        Wrap(
          spacing: AppSpace.xs,
          runSpacing: AppSpace.xs,
          children: [
            for (final doc in shown)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  _shorten(doc),
                  style: AppText.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (extra > 0)
              GestureDetector(
                onTap: () => _showAllDocs(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.infoTint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '+$extra',
                    style: AppText.label.copyWith(color: AppColors.info),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The live bid feed as its own screen (reached from Home and the menu).
class BidsPage extends StatelessWidget {
  final AppStore store;
  const BidsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    appBar: AppBar(title: Text(store.t('Live GeM bids', 'लाइव GeM बोलियाँ'))),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: BidFeed(store: store),
          ),
        ),
      ),
    ),
  );
}
