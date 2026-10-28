import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'alerts_page.dart';
import 'bid_feed.dart';
import 'components.dart';
import 'glass.dart';
import 'onboarding_flow_4.dart' show gemRegistrationUrl;
import 'onboarding_widgets.dart' show StaggeredEntrance;
import 'scroll_hint.dart';
import 'widgets.dart';

/// The five destinations in the persistent bottom nav. Each is its own
/// full page body — switching tabs swaps only the middle scrollable
/// area; the top bar and nav bar stay fixed, exactly like a native
/// iOS tab bar. Dashboard lives inside the Home tab as its "My
/// Dashboard" card rather than as a separate destination.
enum _Tab { home, updates, bids, tools, profile }

/// Shared (tab, outlined icon, filled icon, label) definitions for both
/// the phone bottom nav ([_HomeNav]) and the wide-layout [NavigationRail],
/// so the two stay in lockstep instead of drifting apart.
List<(_Tab, IconData, IconData, String)> _navItems(AppStore s) => [
  (_Tab.home, Icons.home_outlined, Icons.home, s.t('Home', 'होम')),
  (
    _Tab.updates,
    Icons.notifications_outlined,
    Icons.notifications,
    s.t('Updates', 'सूचनाएं'),
  ),
  (
    _Tab.bids,
    Icons.description_outlined,
    Icons.description,
    s.t('Bids', 'बोलियाँ'),
  ),
  (_Tab.tools, Icons.build_outlined, Icons.build, s.t('Tools', 'टूल')),
  (
    _Tab.profile,
    Icons.person_outline,
    Icons.person,
    s.t('Profile', 'प्रोफ़ाइल'),
  ),
];

/// The screen a returning user lands on after onboarding — everything
/// here is illustrative/demo content (a sample bid, a static
/// readiness score) consistent with the rest of this prototype app,
/// not live GeM data.
class HomePage extends StatefulWidget {
  final AppStore store;
  const HomePage({super.key, required this.store});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// Header row height below the status bar: one row of 48pt tap targets.
const _headerHeight = 48.0;

/// Room left under the content so its end scrolls clear of the nav capsule.
const _navClearance = 104.0;

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  _Tab _tab = _Tab.home;
  void _go(_Tab tab) {
    _showHeader();
    setState(() => _tab = tab);
  }

  /// How far the header row has slid up under the status bar: 0 shows it,
  /// [_headerHeight] hides it. Scrolling down tucks it away so content gets
  /// the room; any scroll up brings it straight back.
  final _headerShift = ValueNotifier<double>(0);
  late final _snap = AnimationController(vsync: this);
  double _snapFrom = 0, _snapTo = 0;

  @override
  void initState() {
    super.initState();
    _snap.addListener(
      () => _headerShift.value =
          _snapFrom +
          (_snapTo - _snapFrom) * Motion.enter.transform(_snap.value),
    );
  }

  @override
  void dispose() {
    _snap.dispose();
    _headerShift.dispose();
    super.dispose();
  }

  void _snapHeader(double to) {
    if (_headerShift.value == to) return;
    _snapFrom = _headerShift.value;
    _snapTo = to;
    _snap
      ..duration = Motion.of(context, Motion.fast)
      ..forward(from: 0);
  }

  void _showHeader() {
    _snap.stop();
    _headerShift.value = 0;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollUpdateNotification) {
      _snap.stop();
      _headerShift.value = n.metrics.pixels <= 0
          ? 0
          : (_headerShift.value + (n.scrollDelta ?? 0)).clamp(
              0.0,
              _headerHeight,
            );
    } else if (n is ScrollEndNotification) {
      // Settle fully shown or fully hidden, never half-way.
      _snapHeader(
        _headerShift.value > _headerHeight / 2 &&
                n.metrics.pixels > _headerHeight
            ? _headerHeight
            : 0,
      );
    }
    return false;
  }

  String get _firstName {
    final full = (widget.store.profile['fullName'] as String? ?? '').trim();
    if (full.isEmpty) return '';
    return full.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      endDrawer: _HomeDrawer(store: s),
      // Bars float over the content, so only the sides are inset here; the
      // header pads itself below the status bar and the nav above the home
      // indicator, while scrolling content passes (blurred) behind both.
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > AppSize.wide;

            final headerRow = Row(
              children: [
                // The lockup is nearly square, so it is sized to fill the
                // 48pt row (68 x 48) rather than by a wider width.
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BrandLogo(
                      variant: BrandLogoVariant.lockup,
                      width: 68,
                    ),
                  ),
                ),
                _LanguageChip(store: s),
                const SizedBox(width: 6),
                _NotificationBell(store: s, onTap: () => _go(_Tab.updates)),
                AppIconButton(
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                  icon: Icons.menu,
                  tooltip: s.t('Menu', 'मेनू'),
                ),
              ],
            );
            // The glass always covers the status bar; the row below it
            // shrinks away as the header tucks under while scrolling.
            final topBar = ValueListenableBuilder<double>(
              valueListenable: _headerShift,
              child: headerRow,
              builder: (context, shift, row) => GlassBar.top(
                padding: EdgeInsets.fromLTRB(
                  AppSpace.lg,
                  insets.top,
                  AppSpace.md,
                  0,
                ),
                child: SizedBox(
                  height: _headerHeight - shift,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.bottomCenter,
                      minHeight: _headerHeight,
                      maxHeight: _headerHeight,
                      child: Opacity(
                        opacity: (1 - shift / _headerHeight).clamp(0.0, 1.0),
                        child: row,
                      ),
                    ),
                  ),
                ),
              ),
            );

            final scrollArea = Expanded(
              child: ScrollMoreHint(
                enabled: isWide,
                builder: (context, scrollController) {
                  // RepaintBoundary carries the tab's ValueKey itself
                  // (replacing a separate KeyedSubtree) so each tab's
                  // fairly complex body gets both a stable identity
                  // for AnimatedSwitcher to key off, and its own
                  // compositing layer that isn't re-rasterized by the
                  // fade transition around it.
                  final currentBody = RepaintBoundary(
                    key: ValueKey(_tab),
                    child: switch (_tab) {
                      _Tab.home => _HomeTab(
                        store: s,
                        name: _firstName,
                        onNavigate: _go,
                      ),
                      _Tab.updates => AlertsBody(
                        key: ValueKey(s.currentUser?.id),
                        store: s,
                      ),
                      _Tab.bids => BidFeed(store: s),
                      _Tab.tools => _ToolsTab(store: s),
                      _Tab.profile => _ProfileTab(store: s),
                    },
                  );
                  return NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(
                        AppSpace.xl,
                        insets.top + _headerHeight + AppSpace.md,
                        AppSpace.xl,
                        isWide ? 60 : insets.bottom + _navClearance,
                      ),
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.normal),
                        switchInCurve: Motion.enter,
                        switchOutCurve: Motion.exit,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: currentBody,
                      ),
                    ),
                  );
                },
              ),
            );

            final mainColumn = Stack(
              children: [
                Positioned.fill(child: Column(children: [scrollArea])),
                Positioned(top: 0, left: 0, right: 0, child: topBar),
                // The floating tab capsule is a phone pattern only — wide
                // layouts get a NavigationRail on the side instead.
                if (!isWide)
                  Positioned(
                    left: AppSpace.lg,
                    right: AppSpace.lg,
                    bottom: insets.bottom + AppSpace.md,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: GlassCapsule(
                          child: _HomeNav(
                            store: s,
                            current: _tab,
                            onSelect: _go,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );

            if (!isWide) return mainColumn;

            final items = _navItems(s);
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _Tab.values.indexOf(_tab),
                  onDestinationSelected: (index) => _go(items[index].$1),
                  labelType: NavigationRailLabelType.all,
                  useIndicator: false,
                  selectedLabelTextStyle: AppText.label.copyWith(
                    color: AppColors.brand,
                  ),
                  unselectedLabelTextStyle: AppText.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                  destinations: [
                    for (final (_, outlinedIcon, filledIcon, label) in items)
                      NavigationRailDestination(
                        icon: Icon(outlinedIcon),
                        selectedIcon: Icon(filledIcon),
                        label: Text(label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: mainColumn),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The slide-out menu for destinations that sit outside the five
/// bottom-nav tabs. Kept intentionally small — only wired to actions
/// that already exist elsewhere in the app (the language sheet, the
/// GeM registration link, and restarting onboarding) rather than
/// pointing at pages that don't exist yet.
class _HomeDrawer extends StatelessWidget {
  final AppStore store;
  const _HomeDrawer({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.xxl,
                AppSpace.xl,
                AppSpace.lg,
              ),
              child: BrandLogo(variant: BrandLogoVariant.lockup, width: 150),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.storefront_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('Register on GeM', 'GeM पर रजिस्टर करें')),
              onTap: () {
                Navigator.of(context).pop();
                openLink(context, s, gemRegistrationUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language, color: AppColors.brand),
              title: Text(s.t('Language', 'भाषा')),
              onTap: () {
                Navigator.of(context).pop();
                _showLanguageSheet(context, s);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt, color: AppColors.brand),
              title: Text(s.t('Start onboarding again', 'फिर से शुरुआत करें')),
              onTap: () {
                Navigator.of(context).pop();
                _confirmStartOver(context, s);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _PageHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: AppText.h2)),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(subtitle!, style: AppText.secondary(AppText.body)),
        ],
      ],
    ),
  );
}

class _HomeTab extends StatelessWidget {
  final AppStore store;
  final String name;
  final ValueChanged<_Tab> onNavigate;
  const _HomeTab({
    required this.store,
    required this.name,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredEntrance(index: 0, child: _DashboardCard(store: s)),
        const SizedBox(height: AppSpace.xxxl),
        Semantics(
          header: true,
          child: Text(
            name.isEmpty
                ? s.t('Hello.', 'नमस्ते.')
                : s.t('Hello, {name}', 'नमस्ते, {name}', vars: {'name': name}),
            style: AppText.h1,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          s.t(
            'Your GeM guide, bid feed and alerts in one place.',
            'आपकी GeM गाइड, बोली सूची और अलर्ट एक ही जगह।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: AppSpace.xxl),
        StaggeredEntrance(
          index: 1,
          child: _FeaturedBid(store: s, onTap: () => onNavigate(_Tab.bids)),
        ),
        const SizedBox(height: AppSpace.xxxl),
        SectionHeader(s.t('Quick actions', 'त्वरित कार्य')),
        Row(
          children: [
            Expanded(
              child: StaggeredEntrance(
                index: 2,
                child: _QuickAction(
                  icon: Icons.bar_chart_outlined,
                  label: s.t('ROI\ncalculator', 'ROI\nकैलकुलेटर'),
                  onTap: () => onNavigate(_Tab.tools),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: StaggeredEntrance(
                index: 3,
                child: _QuickAction(
                  icon: Icons.chat_bubble_outline,
                  label: s.t('Ask\nBid2Scale', 'Bid2Scale\nसे पूछें'),
                  onTap: () => onNavigate(_Tab.tools),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        StaggeredEntrance(
          index: 4,
          child: AppCard(
            padding: const EdgeInsets.all(AppSpace.lg),
            onTap: () => Navigator.of(context).pushNamed('/insights'),
            child: AppListTile(
              icon: Icons.insights,
              title: s.t('Insights & analytics', 'इनसाइट्स और विश्लेषण'),
              subtitle: s.t(
                'Trends, categories and bid fit',
                'रुझान, श्रेणियाँ और बोली उपयुक्तता',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final AppStore store;
  const _DashboardCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return AppCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageHeader(
            title: s.t('My Dashboard', 'मेरा डैशबोर्ड'),
            subtitle: s.t(
              'You have completed 7 of 9 preparation steps.',
              'आपने 9 में से 7 तैयारी चरण पूरे कर लिए हैं।',
            ),
          ),
          Center(
            child: AppProgressRing(
              value: 0.78,
              label: s.t('78% complete', '78% पूर्ण'),
              size: 104,
            ),
          ),
          const SizedBox(height: AppSpace.xxl),
          AppCard(
            tone: AppCardTone.muted,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: DividedList(
              children: [
                StatusItem(
                  label: s.t('Profile', 'प्रोफ़ाइल'),
                  state: ItemState.done,
                  trailing: s.t('Complete', 'पूर्ण'),
                ),
                StatusItem(
                  label: s.t('Business details', 'व्यवसाय विवरण'),
                  state: ItemState.done,
                  trailing: s.t('Complete', 'पूर्ण'),
                ),
                StatusItem(
                  label: s.t('Bank details', 'बैंक विवरण'),
                  state: ItemState.attention,
                  trailing: s.t('Next step', 'अगला कदम'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            s.t(
              'Complete your business profile to apply for more bids.',
              'अधिक बोलियों के लिए अपनी व्यवसाय प्रोफ़ाइल पूरी करें।',
            ),
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            label: s.t('Continue setup', 'सेटअप जारी रखें'),
            onPressed: () {},
            variant: AppButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}

class _ToolsTab extends StatelessWidget {
  final AppStore store;
  const _ToolsTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(title: s.t('Tools', 'टूल')),
        _ToolSection(
          icon: Icons.bar_chart_outlined,
          title: s.t('ROI calculator', 'ROI कैलकुलेटर'),
          description: s.t(
            'Estimate bid costs, working capital, and potential return.',
            'बोली लागत, कार्यशील पूंजी और संभावित रिटर्न का अनुमान लगाएँ।',
          ),
          body: s.t(
            'Use a simple estimate before bidding: include purchase cost, delivery, taxes, fees, and the time before payment.',
            'बोली लगाने से पहले एक सरल अनुमान लगाएँ: खरीद लागत, डिलिवरी, कर, फीस और भुगतान से पहले का समय शामिल करें।',
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        _ToolSection(
          icon: Icons.chat_bubble_outline,
          title: s.t('Ask Bid2Scale', 'Bid2Scale से पूछें'),
          description: s.t(
            'Get clear answers about preparing for GeM.',
            'GeM की तैयारी के बारे में स्पष्ट जवाब पाएं।',
          ),
          body: s.t(
            'Try asking: "Which documents should I prepare before I apply for this bid?"',
            'पूछकर देखें: "इस बोली के लिए आवेदन करने से पहले मुझे कौन से दस्तावेज़ तैयार करने चाहिए?"',
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          onTap: () => Navigator.of(context).pushNamed('/insights'),
          child: AppListTile(
            icon: Icons.insights,
            title: s.t('Insights & analytics', 'इनसाइट्स और विश्लेषण'),
            subtitle: s.t(
              'Trends, categories and bid fit',
              'रुझान, श्रेणियाँ और बोली उपयुक्तता',
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        _LearnRow(store: s),
      ],
    );
  }
}

class _ToolSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String body;
  const _ToolSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: AppIconSize.md, color: AppColors.brand),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Text(title, style: AppText.title)),
          ],
        ),
        const SizedBox(height: AppSpace.xs),
        Text(description, style: AppText.caption),
        const SizedBox(height: AppSpace.md),
        Text(body, style: AppText.bodySmall),
      ],
    ),
  );
}

class _ProfileTab extends StatelessWidget {
  final AppStore store;
  const _ProfileTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final p = s.profile;
    String field(String key) => (p[key] as String? ?? '').trim();
    final rows = <(String, String)>[
      (s.t('Full name', 'पूरा नाम'), field('fullName')),
      (s.t('Business name', 'व्यवसाय का नाम'), field('businessName')),
      (
        s.t('Location', 'स्थान'),
        [
          field('district'),
          field('state'),
        ].where((v) => v.isNotEmpty).join(', '),
      ),
      (s.t('Sector', 'क्षेत्र'), field('sector')),
      (s.t('Role', 'भूमिका'), field('role')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(title: s.t('Profile', 'प्रोफ़ाइल')),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: DividedList(
            children: [for (final r in rows) KeyValueRow(r.$1, r.$2)],
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          onTap: () => _showLanguageSheet(context, s),
          child: AppListTile(
            icon: Icons.language,
            title: s.t('Language', 'भाषा'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  supportedLanguages.firstWhere(
                    (lang) => lang[0] == s.language,
                    orElse: () => supportedLanguages[0],
                  )[1],
                  style: AppText.caption,
                ),
                const SizedBox(width: AppSpace.xs),
                const Icon(Icons.chevron_right, size: AppIconSize.md),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xxxl),
        AppButton(
          label: s.t('GeM registration guide', 'GeM पंजीकरण गाइड'),
          onPressed: () => Navigator.pushNamed(context, '/gem-guide'),
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpace.md),
        AppButton(
          label: s.t('Start onboarding again', 'फिर से शुरुआत करें'),
          onPressed: () => _confirmStartOver(context, s),
          variant: AppButtonVariant.secondary,
        ),
      ],
    );
  }
}

void _confirmStartOver(BuildContext context, AppStore s) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(s.t('Start onboarding again?', 'फिर से शुरुआत करें?')),
      content: Text(
        s.t(
          'You\'ll go back to the welcome screen. Your saved answers stay filled in if you go through it again.',
          'आप वापस स्वागत स्क्रीन पर जाएँगे। दोबारा जाने पर आपके भरे उत्तर सुरक्षित रहेंगे।',
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        0,
        AppSpace.xl,
        AppSpace.lg,
      ),
      actions: [
        AppButton(
          label: s.t('Cancel', 'रद्द करें'),
          onPressed: () => Navigator.of(context).pop(),
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          expand: false,
          haptic: false,
        ),
        AppButton(
          label: s.t('Start over', 'फिर से शुरू करें'),
          danger: true,
          size: AppButtonSize.sm,
          expand: false,
          onPressed: () async {
            Navigator.of(context).pop();
            await s.resetOnboarding();
            if (context.mounted) {
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/welcome', (route) => false);
            }
          },
        ),
      ],
    ),
  );
}

class _LanguageChip extends StatelessWidget {
  final AppStore store;
  const _LanguageChip({required this.store});

  @override
  Widget build(BuildContext context) {
    final current = supportedLanguages.firstWhere(
      (lang) => lang[0] == store.language,
      orElse: () => supportedLanguages[0],
    );
    return Tooltip(
      message: store.t('Change language', 'भाषा बदलें'),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () => _showLanguageSheet(context, store),
        child: Semantics(
          button: true,
          label: store.t(
            'Language: {name}',
            'भाषा: {name}',
            vars: {'name': current[2]},
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(store.language.toUpperCase(), style: AppText.label),
                const Icon(Icons.keyboard_arrow_down, size: AppIconSize.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showLanguageSheet(BuildContext context, AppStore store) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.of(context, Motion.slow),
      reverseDuration: Motion.of(context, Motion.normal),
      curve: Motion.enter,
    ),
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              0,
              AppSpace.xxl,
              AppSpace.xxxl,
            ),
            children: [
              const SheetHandle(),
              Text(
                store.t('Choose your language', 'अपनी भाषा चुनें'),
                style: AppText.h3,
              ),
              const SizedBox(height: AppSpace.md),
              for (final lang in supportedLanguages)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(lang[1], style: AppText.body),
                  subtitle: Text(lang[2], style: AppText.caption),
                  trailing: store.language == lang[0]
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    store.setLanguage(lang[0]);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _NotificationBell extends StatelessWidget {
  final AppStore store;
  final VoidCallback onTap;
  const _NotificationBell({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: store.t('Notifications', 'सूचनाएं'),
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        if (store.unreadAlerts > 0)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );
}

class _FeaturedBid extends StatelessWidget {
  final AppStore store;
  final VoidCallback onTap;
  const _FeaturedBid({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return AppCard(
      tone: AppCardTone.brand,
      radius: AppRadius.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('Your next opportunity', 'आपका अगला अवसर').toUpperCase(),
            style: AppText.overline.copyWith(color: AppColors.brand),
          ),
          const SizedBox(height: AppSpace.md),
          InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.t(
                      'Find bids for\nyour business.',
                      'अपने व्यवसाय के लिए\nबोलियाँ खोजें।',
                    ),
                    style: AppText.h2,
                  ),
                ),
                const Icon(Icons.chevron_right, size: AppIconSize.lg),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md + 2),
          Text(
            s.t(
              'Browse collected bids or choose the products and delivery states you want alerts for.',
              'एकत्रित बोलियाँ देखें या अलर्ट के लिए उत्पाद और वितरण राज्य चुनें।',
            ),
            style: AppText.body,
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(
            label: s.t('Browse bids', 'बोलियाँ देखें'),
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(
      vertical: AppSpace.lg,
      horizontal: AppSpace.sm,
    ),
    child: Column(
      children: [
        DepthIcon(icon, size: AppIconSize.lg - 4, color: AppColors.brand),
        const SizedBox(height: AppSpace.sm),
        Text(label, textAlign: TextAlign.center, style: AppText.bodySmall),
      ],
    ),
  );
}

class _LearnRow extends StatelessWidget {
  final AppStore store;
  const _LearnRow({required this.store});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpace.lg),
    child: AppListTile(
      icon: Icons.play_circle_outline,
      title: store.t('Learn how bidding works', 'बोली प्रक्रिया सीखें'),
      subtitle: store.t('3 min video', '3 मिनट का वीडियो'),
      trailing: const Icon(Icons.chevron_right, size: AppIconSize.md),
    ),
  );
}

class _HomeNav extends StatelessWidget {
  final AppStore store;
  final _Tab current;
  final ValueChanged<_Tab> onSelect;
  const _HomeNav({
    required this.store,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final items = _navItems(s);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final (tab, outlinedIcon, filledIcon, label) in items)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: tab == current,
                  label: label,
                  child: InkWell(
                    onTap: () => onSelect(tab),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSize.tap,
                        minWidth: AppSize.tap,
                      ),
                      child: Center(
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: Motion.of(context, Motion.fast),
                                curve: Motion.enter,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.md,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tab == current
                                      ? AppColors.brandTint
                                      : AppColors.brandTint.withValues(
                                          alpha: 0,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: DepthIcon(
                                  tab == current ? filledIcon : outlinedIcon,
                                  lifted: tab == current,
                                  color: tab == current
                                      ? AppColors.brand
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                label,
                                style: AppText.label.copyWith(
                                  fontWeight: tab == current
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: tab == current
                                      ? AppColors.brand
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
