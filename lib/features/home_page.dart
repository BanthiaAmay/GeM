import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'components.dart';
import 'drawer_pages.dart';
import 'search/search_engine.dart';
import 'search/search_store.dart';
import 'tools_hub/tool_card.dart';
import 'glass.dart';
import 'onboarding_flow_4.dart' show gemRegistrationUrl;
import 'onboarding_widgets.dart' show StaggeredEntrance;
import 'scroll_hint.dart';
import 'widgets.dart';

/// The five destinations in the persistent bottom nav. Each is its own
/// full page body — switching tabs swaps only the middle scrollable
/// area; the top bar and nav bar stay fixed, exactly like a native
/// iOS tab bar. Dashboard, notifications and the bid feed all live
/// inside the Home tab, and the document checklist lives inside GeM
/// 101, rather than each being its own destination.
enum _Tab { home, tools, calculators, financialHub, profile }

/// Shared (tab, outlined icon, filled icon, label) definitions for both
/// the phone bottom nav ([_HomeNav]) and the wide-layout [NavigationRail],
/// so the two stay in lockstep instead of drifting apart.
List<(_Tab, IconData, IconData, String)> _navItems(AppStore s) => [
  (_Tab.home, Icons.home_outlined, Icons.home, s.t('Home', 'होम')),
  (_Tab.tools, Icons.build_outlined, Icons.build, s.t('Tools', 'टूल')),
  (
    _Tab.calculators,
    Icons.calculate_outlined,
    Icons.calculate,
    s.t('Calculators', 'कैलकुलेटर'),
  ),
  (
    // Short form in the nav bar so the label never wraps next to
    // "GeM 101" and "Profile" at phone width; the tab's own page
    // header still reads the full "Financial Hub".
    _Tab.financialHub,
    Icons.account_balance_outlined,
    Icons.account_balance,
    s.t('Finance', 'वित्त'),
  ),
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

/// The floating tab capsule's height (two 6pt paddings + a 48pt+ tab).
const _navHeight = 66.0;

/// Gap between the capsule and the screen's bottom edge: tucked into the
/// home-indicator area on notched phones, a small margin elsewhere.
double _navBottom(EdgeInsets insets) =>
    insets.bottom > AppSpace.lg ? insets.bottom - AppSpace.md : AppSpace.md;

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  _Tab _tab = _Tab.home;
  void _go(_Tab tab) {
    _showHeader();
    setState(() => _tab = tab);
  }

  SearchStore? _searchStore;
  List<String> _searchAlerts = [];

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
    _initAlerts();
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

  Future<void> _initAlerts() async {
    final store = SearchStore(widget.store.prefs);
    final engine = SearchEngine();
    final alerts = await store.checkAlerts(engine);
    if (!mounted) return;
    setState(() {
      _searchStore = store;
      _searchAlerts = alerts;
    });
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
                // Opens the real bid-alert inbox (server matches).
                _NotificationBell(
                  store: s,
                  hasUnread:
                      s.unreadAlerts > 0 ||
                      _searchAlerts.isNotEmpty ||
                      (_searchStore?.hasUnread ?? false),
                  onTap: () => Navigator.of(context).pushNamed('/alerts'),
                ),
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
                        searchAlerts: _searchAlerts,
                      ),
                      _Tab.tools => _ToolsTab(store: s),
                      _Tab.calculators => _CalculatorsTab(store: s),
                      _Tab.financialHub => _FinancialHubTab(store: s),
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
                        isWide
                            ? 60
                            : _navBottom(insets) + _navHeight + AppSpace.md,
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
                    bottom: _navBottom(insets),
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
    void openDrawerPage(Widget Function(BuildContext) builder) {
      Navigator.of(context).pop();
      Navigator.of(
        context,
      ).push(SoftRoute(settings: const RouteSettings(), builder: builder));
    }

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: ListView(
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
                Icons.person_outline,
                color: AppColors.brand,
              ),
              title: Text(s.t('Account', 'खाता')),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/account');
              },
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined, color: AppColors.brand),
              title: Text(s.t('Live GeM bids', 'लाइव GeM बोलियाँ')),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/bids');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.notifications_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('Bid alerts', 'बोली अलर्ट')),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/alerts');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.description_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('Documentations', 'दस्तावेज़')),
              onTap: () => openDrawerPage((_) => DocumentationsPage(store: s)),
            ),
            ListTile(
              leading: const Icon(
                Icons.fact_check_outlined,
                color: AppColors.brand,
              ),
              title: Text(
                s.t('Bid Preparation Assistance', 'बोली तैयारी सहायता'),
              ),
              onTap: () =>
                  openDrawerPage((_) => BidPreparationAssistancePage(store: s)),
            ),
            ListTile(
              leading: const Icon(Icons.sync_outlined, color: AppColors.brand),
              title: Text(s.t('Bid Cycle', 'बोली चक्र')),
              onTap: () => openDrawerPage((_) => BidCyclePage(store: s)),
            ),
            ListTile(
              leading: const Icon(
                Icons.task_alt_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('Execution', 'निष्पादन')),
              onTap: () => openDrawerPage((_) => ExecutionPage(store: s)),
            ),
            ListTile(
              leading: const Icon(
                Icons.trending_up_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('Earnings Dynamics', 'कमाई गतिशीलता')),
              onTap: () =>
                  openDrawerPage((_) => EarningsDynamicsPage(store: s)),
            ),
            ListTile(
              leading: const Icon(
                Icons.payments_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('Financing', 'वित्तपोषण')),
              onTap: () => openDrawerPage((_) => FinancingPage(store: s)),
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
  final List<String> searchAlerts;
  const _HomeTab({
    required this.store,
    required this.name,
    required this.onNavigate,
    this.searchAlerts = const [],
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
            '2 new opportunities match your business',
            'आपके व्यवसाय से मेल खाने वाले 2 नए अवसर',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: AppSpace.lg),
        StaggeredEntrance(
          index: 1,
          child: _NotificationsSection(store: s, searchAlerts: searchAlerts),
        ),
        const SizedBox(height: AppSpace.xxxl),
        SectionHeader(s.t('Bids for you', 'आपके लिए बोलियाँ')),
        StaggeredEntrance(
          index: 2,
          child: _FeaturedBid(
            store: s,
            onTap: () => Navigator.of(context).pushNamed('/bids'),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(
          s.t(
            'This is a sample opportunity for preview. Confirm eligibility, specifications, and closing dates on the official GeM portal.',
            'यह एक नमूना अवसर है। पात्रता, विनिर्देश और अंतिम तिथियाँ आधिकारिक GeM पोर्टल पर देखें।',
          ),
          style: AppText.caption,
        ),
        const SizedBox(height: AppSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: s.t('Open official GeM portal', 'आधिकारिक GeM पोर्टल खोलें'),
            onPressed: () => openLink(context, s, gemSource),
            variant: AppButtonVariant.tertiary,
            trailingIcon: Icons.open_in_new,
            expand: false,
            haptic: false,
          ),
        ),
        const SizedBox(height: AppSpace.xxxl),
        SectionHeader(s.t('Quick actions', 'त्वरित कार्य')),
        Row(
          children: [
            Expanded(
              child: StaggeredEntrance(
                index: 3,
                child: _QuickAction(
                  icon: Icons.bar_chart_outlined,
                  label: s.t('ROI\ncalculator', 'ROI\nकैलकुलेटर'),
                  onTap: () => onNavigate(_Tab.financialHub),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: StaggeredEntrance(
                index: 4,
                child: _QuickAction(
                  icon: Icons.chat_bubble_outline,
                  label: s.t('Ask\nBid2Scale', 'Bid2Scale\nसे पूछें'),
                  onTap: () => Navigator.of(context).pushNamed('/saathi'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        StaggeredEntrance(
          index: 5,
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

/// The notification list folded into the Home tab's scroll (previously
/// its own "Updates" destination). Rows are informational only — the
/// matching bid is already shown in the "Bids for you" section right
/// below on the same page, so there is nowhere else for a tap to go.
class _NotificationsSection extends StatelessWidget {
  final AppStore store;
  final List<String> searchAlerts;
  const _NotificationsSection({
    required this.store,
    this.searchAlerts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(s.t('Notifications', 'सूचनाएं')),
        // Dynamic saved-search alerts take priority when present.
        if (searchAlerts.isNotEmpty) ...[
          for (var i = 0; i < searchAlerts.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.md),
            _NotificationRow(
              title: searchAlerts[i],
              subtitle: s.t('New bid match', 'नया बोली मैच'),
            ),
          ],
        ] else ...[
          _NotificationRow(
            title: s.t('Office stationery supplies', 'ऑफिस स्टेशनरी सामग्री'),
            subtitle: s.t('New bid match', 'नया बोली मैच'),
          ),
          const SizedBox(height: AppSpace.md),
          _NotificationRow(
            title: s.t('IT hardware procurement', 'IT हार्डवेयर खरीद'),
            subtitle: s.t('New bid match', 'नया बोली मैच'),
          ),
        ],
      ],
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final String title;
  final String subtitle;
  const _NotificationRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpace.lg),
    child: AppListTile(
      icon: Icons.notifications_outlined,
      title: title,
      subtitle: subtitle,
    ),
  );
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
        _PageHeader(
          title: s.t('Tools', 'टूल'),
          subtitle: s.t(
            'Find and prepare the documents your tender requires.',
            'अपनी निविदा के लिए आवश्यक दस्तावेज़ खोजें और तैयार करें।',
          ),
        ),
        ToolsHub(store: s),
      ],
    );
  }
}

class _CalculatorsTab extends StatelessWidget {
  final AppStore store;
  const _CalculatorsTab({required this.store});

  // (route key, icon, title en/hi, caption en/hi) — one line per
  // calculator. Add a new tool here and it appears in the grid; no
  // other change is needed to surface it on this tab.
  static const _calcs = <(String, IconData, String, String, String, String)>[
    (
      'eligibility',
      Icons.fact_check_outlined,
      'Eligibility',
      'पात्रता',
      'Can your business sell on GeM?',
      'क्या आपका व्यवसाय GeM पर बेच सकता है?',
    ),
    (
      'revenue',
      Icons.trending_up,
      'Revenue',
      'आय',
      'What could you realistically earn?',
      'आप वास्तव में कितना कमा सकते हैं?',
    ),
    (
      'pricing',
      Icons.sell_outlined,
      'Pricing & margin',
      'मूल्य और मार्जिन',
      'Price with confidence.',
      'भरोसे के साथ मूल्य तय करें।',
    ),
    (
      'roi',
      Icons.bar_chart_outlined,
      'ROI & payback',
      'ROI और लागत वसूली',
      'Is the effort worth it?',
      'क्या यह प्रयास लाभदायक है?',
    ),
    (
      'workingCapital',
      Icons.account_balance_wallet_outlined,
      'Working capital',
      'कार्यशील पूँजी',
      'Will you have enough cash to execute?',
      'क्या पर्याप्त नकद होगा?',
    ),
    (
      'emd',
      Icons.verified_outlined,
      'EMD',
      'EMD',
      'What deposit does this bid need?',
      'इस बोली के लिए जमा राशि?',
    ),
    (
      'unitEconomics',
      Icons.pie_chart_outline,
      'Unit economics',
      'यूनिट अर्थशास्त्र',
      'How many units before you break even?',
      'लागत वसूली के लिए कितनी इकाइयाँ?',
    ),
    (
      'gstCalc',
      Icons.receipt_long_outlined,
      'GST',
      'GST',
      'What GST applies to this sale?',
      'इस बिक्री पर कौन सा GST?',
    ),
    (
      'netCash',
      Icons.account_balance_outlined,
      'Net cash receivable',
      'वास्तविक प्राप्त नकद',
      'What actually lands in your bank?',
      'वास्तव में आपके बैंक में कितना आता है?',
    ),
    (
      'raWalkaway',
      Icons.gavel_outlined,
      'Reverse auction floor',
      'रिवर्स ऑक्शन सीमा',
      'What is your walk-away price?',
      'आपका वॉक-अवे मूल्य क्या है?',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: s.t('Calculators', 'कैलकुलेटर'),
          subtitle: s.t(
            'Plan the money side of GeM selling, one quick tool at a time.',
            'GeM पर बिक्री के वित्तीय पक्ष की योजना, एक-एक त्वरित टूल से।',
          ),
        ),
        ToolGrid(
          children: [
            for (final c in _calcs)
              AppCard(
                padding: const EdgeInsets.all(AppSpace.lg),
                semanticLabel: '${s.t(c.$3, c.$4)}. ${s.t(c.$5, c.$6)}',
                onTap: () => go(context, s, c.$1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(c.$2, size: AppIconSize.md, color: AppColors.brand),
                    const SizedBox(height: AppSpace.md),
                    Text(s.t(c.$3, c.$4), style: AppText.title),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      s.t(c.$5, c.$6),
                      style: AppText.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FinancialHubTab extends StatelessWidget {
  final AppStore store;
  const _FinancialHubTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: s.t('Financial Hub', 'वित्तीय केंद्र'),
          subtitle: s.t(
            'Plan the money side of a bid before you commit to it.',
            'प्रतिबद्ध होने से पहले बोली के वित्तीय पक्ष की योजना बनाएं।',
          ),
        ),
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
          onTap: () => Navigator.of(context).pushNamed('/saathi'),
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
      ],
    );
  }
}

class _ToolSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String body;
  final VoidCallback? onTap;
  const _ToolSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.body,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(AppSpace.lg),
    onTap: onTap,
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
          label: s.t('Start onboarding again', 'फिर से शुरुआत करें'),
          onPressed: () => _confirmStartOver(context, s),
          variant: AppButtonVariant.secondary,
        ),
        const SizedBox(height: AppSpace.xxxl),
        _AccountSection(store: s),
      ],
    );
  }
}

/// Who is signed in, plus sign out and permanent account deletion. Both
/// actions confirm first, then return to the sign-in screen.
class _AccountSection extends StatefulWidget {
  final AppStore store;
  const _AccountSection({required this.store});
  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  bool busy = false;
  String? error;
  AppStore get s => widget.store;

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actionsPadding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            0,
            AppSpace.xl,
            AppSpace.lg,
          ),
          actions: [
            AppButton(
              label: s.t('Cancel', 'रद्द करें'),
              onPressed: () => Navigator.of(context).pop(false),
              variant: AppButtonVariant.secondary,
              size: AppButtonSize.sm,
              expand: false,
              haptic: false,
            ),
            AppButton(
              label: action,
              danger: true,
              size: AppButtonSize.sm,
              expand: false,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/onboarding-auth', (route) => false);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = s.t(
            'That didn’t work. Check your connection and try again.',
            'यह नहीं हुआ। इंटरनेट जाँचकर फिर कोशिश करें।',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = s.currentUser?.email ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(s.t('Account', 'खाता')),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          onTap: () => Navigator.of(context).pushNamed('/account'),
          child: AppListTile(
            icon: Icons.person_outline,
            title: s.signedIn
                ? (email.isEmpty ? s.t('Signed in', 'साइन इन') : email)
                : s.t('Not signed in', 'साइन इन नहीं है'),
            subtitle: s.t(
              'Account, sync and privacy settings',
              'खाता, सिंक और गोपनीयता सेटिंग',
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        if (s.signedIn) ...[
          AppButton(
            label: s.t('Sign out', 'साइन आउट करें'),
            icon: Icons.logout,
            variant: AppButtonVariant.secondary,
            loading: busy,
            onPressed: busy
                ? null
                : () async {
                    if (await _confirm(
                      s.t('Sign out?', 'साइन आउट करें?'),
                      s.t(
                        'Your work stays saved to your account. Sign back in any time with a code sent to your email.',
                        'आपका काम खाते में सहेजा रहेगा। ईमेल पर आए कोड से कभी भी फिर साइन इन करें।',
                      ),
                      s.t('Sign out', 'साइन आउट करें'),
                    )) {
                      await _run(s.signOut);
                    }
                  },
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(
            label: s.t('Delete my account', 'मेरा खाता मिटाएँ'),
            icon: Icons.delete_outline,
            variant: AppButtonVariant.secondary,
            danger: true,
            onPressed: busy
                ? null
                : () async {
                    if (await _confirm(
                      s.t('Delete your account?', 'अपना खाता मिटाएँ?'),
                      s.t(
                        'This permanently deletes your account and all your Bid2Scale data: business answers, bid alerts, notification settings and saved progress. This cannot be undone.',
                        'इससे आपका खाता और Bid2Scale का सारा डेटा स्थायी रूप से मिट जाएगा: व्यवसाय के उत्तर, बोली अलर्ट, सूचना सेटिंग और सहेजी प्रगति। इसे वापस नहीं किया जा सकता।',
                      ),
                      s.t('Delete account', 'खाता मिटाएँ'),
                    )) {
                      await _run(s.deleteAccount);
                    }
                  },
          ),
        ] else
          AppButton(
            label: s.t('Sign in or create account', 'साइन इन करें या खाता बनाएँ'),
            icon: Icons.login,
            onPressed: () => Navigator.of(context).pushNamed('/auth'),
          ),
        if (error != null) ...[
          const SizedBox(height: AppSpace.md),
          Text(
            error!,
            style: AppText.bodySmall.copyWith(color: AppColors.danger),
          ),
        ],
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
  final bool hasUnread;
  final VoidCallback onTap;
  const _NotificationBell({
    required this.store,
    required this.onTap,
    this.hasUnread = true,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: store.t('Notifications', 'सूचनाएं'),
    icon: Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_outlined),
        if (hasUnread)
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
            s.t('Bids for you', 'आपके लिए बोलियाँ').toUpperCase(),
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
                      'Office stationery\nsupplies',
                      'ऑफिस स्टेशनरी\nसामग्री',
                    ),
                    style: AppText.h2,
                  ),
                ),
                const Icon(Icons.chevron_right, size: AppIconSize.lg),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md + 2),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              StatusChip(
                s.t('Department of Education', 'शिक्षा विभाग'),
                icon: Icons.apartment_outlined,
              ),
              StatusChip(
                s.t('Closes 25 Sep 2026', '25 सितंबर 2026 को बंद'),
                icon: Icons.calendar_today_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          AppButton(label: s.t('View bid', 'बोली देखें'), onPressed: onTap),
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
                                  size: AppIconSize.md,
                                  lifted: tab == current,
                                  color: tab == current
                                      ? AppColors.brand
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpace.xs),
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
