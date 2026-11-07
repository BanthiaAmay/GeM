import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../core/transitions.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'components.dart';
import 'oem/oem_page.dart';
import 'search/search_engine.dart';
import 'search/search_store.dart';
import 'tools_hub/tool_card.dart';
import 'glass.dart';
import 'onboarding_flow_4.dart' show gemRegistrationUrl;
import 'onboarding_widgets.dart' show StaggeredEntrance;
import 'scroll_hint.dart';
import 'widgets.dart';
import 'youtube_video.dart' show openYouTubeVideo;

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

/// The floating "Ask Saathi" button's height.
const _saathiHeight = 52.0;

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
    unawaited(widget.store.loadGemVideos());
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
                        // Clears the Saathi button too, so the last card
                        // can always scroll fully into view.
                        isWide
                            ? 60 + _saathiHeight
                            : _navBottom(insets) +
                                  _navHeight +
                                  _saathiHeight +
                                  AppSpace.lg,
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
                // Saathi, always one tap away: floats above the tab capsule
                // (or the page corner on wide layouts) and tucks to an icon
                // while the page scrolls down.
                Positioned(
                  right: AppSpace.lg,
                  bottom: isWide
                      ? AppSpace.xl
                      : _navBottom(insets) + _navHeight + AppSpace.md,
                  child: ValueListenableBuilder<double>(
                    valueListenable: _headerShift,
                    builder: (context, shift, _) => _SaathiButton(
                      store: s,
                      expanded: shift < _headerHeight / 2,
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
              child: Center(
                child: BrandLogo(
                  variant: BrandLogoVariant.lockup,
                  width: 150,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.brand),
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
                Icons.newspaper_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('News', 'समाचार')),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/news');
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
                Icons.ondemand_video_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('Module Trainings', 'मॉड्यूल प्रशिक्षण')),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/trainings');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.business_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('OEM Database', 'OEM डेटाबेस')),
              onTap: () => openDrawerPage((_) => OemPage(store: s)),
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
        StaggeredEntrance(index: 0, child: _GreetingSection(store: s, name: name)),
        const SizedBox(height: AppSpace.xxxl),
        StaggeredEntrance(index: 1, child: _BidAlertsSection(store: s)),
        const SizedBox(height: AppSpace.xxxl),
        _QuickActionsSection(store: s, onNavigate: onNavigate),
        const SizedBox(height: AppSpace.xxxl),
        StaggeredEntrance(index: 3, child: _LearnSection(store: s)),
      ],
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
        _PageHeader(title: s.t('Finance', 'वित्त')),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.xxl,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.savings_outlined,
                    color: AppColors.brand,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandTint,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    s.t('Coming Soon', 'जल्द आ रहा है'),
                    style: AppText.overline.copyWith(color: AppColors.brand),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
            label: s.t(
              'Sign in or create account',
              'साइन इन करें या खाता बनाएँ',
            ),
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


// ── Helper ───────────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 30) return '${(d.inDays / 7).floor()}w';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()}mo';
  return '${(d.inDays / 365).floor()}y';
}

// ── Greeting ─────────────────────────────────────────────────────────────────

class _GreetingSection extends StatelessWidget {
  final AppStore store;
  final String name;
  const _GreetingSection({required this.store, required this.name});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return AppCard(
      tone: AppCardTone.hero,
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              name.isEmpty
                  ? s.t('Hello.', 'नमस्ते.')
                  : s.t('Hello, {name}', 'नमस्ते, {name}', vars: {'name': name}),
              style: AppText.h1.copyWith(color: AppColors.surface),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            s.t(
              'Your GeM journey, one bid at a time.',
              'आपकी GeM यात्रा, एक बोली एक कदम।',
            ),
            style: AppText.body.copyWith(
              color: AppColors.surface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: s.t('Alerts', 'अलर्ट'),
                  value: '${s.unreadAlerts}',
                  dark: true,
                  onTap: () => Navigator.of(context).pushNamed('/alerts'),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _MetricTile(
                  label: s.t('Active Bids', 'सक्रिय बोलियाँ'),
                  value: '0',
                  dark: true,
                  onTap: null,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _MetricTile(
                  label: s.t('Deadlines', 'समयसीमाएँ'),
                  value: '0',
                  dark: true,
                  onTap: null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool dark;
  const _MetricTile({
    required this.label,
    required this.value,
    this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = AppRadius.card;
    final bgColor = dark
        ? AppColors.surface.withValues(alpha: 0.14)
        : AppColors.surface;
    final borderColor = dark
        ? AppColors.surface.withValues(alpha: 0.2)
        : AppColors.border;
    final valueStyle = dark
        ? AppText.h2.copyWith(color: AppColors.surface)
        : AppText.h2.copyWith(color: AppColors.brand);
    final labelStyle = dark
        ? AppText.overline.copyWith(
            color: AppColors.surface.withValues(alpha: 0.72),
          )
        : AppText.overline.copyWith(color: AppColors.textSecondary);
    return Ink(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: r,
        border: Border.all(color: borderColor),
        boxShadow: dark ? null : AppShadow.card,
      ),
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: valueStyle),
              const SizedBox(height: AppSpace.xs),
              Text(label, style: labelStyle),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bid Alerts ───────────────────────────────────────────────────────────────

class _BidAlertsSection extends StatefulWidget {
  final AppStore store;
  const _BidAlertsSection({required this.store});

  @override
  State<_BidAlertsSection> createState() => _BidAlertsSectionState();
}

class _BidAlertsSectionState extends State<_BidAlertsSection> {
  bool _unreadOnly = false;
  AppStore get s => widget.store;

  List<Map<String, dynamic>> get _filtered {
    final all = s.bidNotifications;
    if (_unreadOnly) {
      return all.where((n) => n['read_at'] == null).take(3).toList();
    }
    return all.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.card,
      ),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            s.t('Bid Alerts', 'बोली अलर्ट'),
            actionLabel: s.t('See all', 'सभी देखें'),
            onAction: () => Navigator.of(context).pushNamed('/alerts'),
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              _FilterPill(
                label: s.t('All', 'सभी'),
                selected: !_unreadOnly,
                onTap: () => setState(() => _unreadOnly = false),
              ),
              const SizedBox(width: AppSpace.sm),
              _FilterPill(
                label: s.t('Unread', 'अपठित'),
                selected: _unreadOnly,
                onTap: () => setState(() => _unreadOnly = true),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          if (rows.isEmpty)
            AppCard(
              tone: AppCardTone.outlined,
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_none_outlined,
                    color: AppColors.textHint,
                    size: AppIconSize.md,
                  ),
                  const SizedBox(width: AppSpace.md),
                  Text(
                    _unreadOnly
                        ? s.t('No unread alerts', 'कोई अपठित अलर्ट नहीं')
                        : s.t('No alerts yet', 'अभी कोई अलर्ट नहीं'),
                    style: AppText.secondary(AppText.bodySmall),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: AppRadius.card,
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.border,
                        ),
                      _BidAlertRow(
                        alert: rows[i],
                        onTap: () =>
                            Navigator.of(context).pushNamed('/alerts'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs + 2,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.brand : AppColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.borderStrong,
        ),
      ),
      child: Text(
        label,
        style: AppText.bodySmall.copyWith(
          color: selected ? AppColors.surface : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _BidAlertRow extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback onTap;
  const _BidAlertRow({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = alert['read_at'] == null;
    final title = alert['title'] as String? ?? '';
    final dept = alert['dept'] as String? ?? '';
    final gemId = alert['gem_id'] as String? ?? '';
    final createdRaw = alert['created_at'];
    DateTime? created;
    if (createdRaw is String) {
      created = DateTime.tryParse(createdRaw);
    } else if (createdRaw is DateTime) {
      created = createdRaw;
    }
    final meta = [dept, gemId].where((v) => v.isNotEmpty).join(' · ');
    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      child: Row(
        children: [
          Icon(
            unread
                ? Icons.notifications_active
                : Icons.notifications_none_outlined,
            size: AppIconSize.md,
            color: unread ? AppColors.brand : AppColors.textHint,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: unread ? AppText.bodyStrong : AppText.bodySmall,
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.secondary(AppText.caption),
                  ),
              ],
            ),
          ),
          if (created != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.sm),
              child: Text(
                _timeAgo(created),
                style: AppText.caption.copyWith(color: AppColors.textHint),
              ),
            ),
        ],
      ),
    );
    // Unread rows get a branded left accent bar + subtle tint.
    if (unread) {
      return InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.brandTint.withValues(alpha: 0.5),
            border: const Border(
              left: BorderSide(color: AppColors.brand, width: 3),
            ),
          ),
          child: rowContent,
        ),
      );
    }
    return InkWell(onTap: onTap, child: rowContent);
  }
}


// ── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  final AppStore store;
  final ValueChanged<_Tab> onNavigate;
  const _QuickActionsSection({
    required this.store,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(s.t('Quick actions', 'त्वरित कार्य')),
        const SizedBox(height: AppSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _QuickActionTile(
              icon: Icons.bar_chart_outlined,
              label: s.t('ROI Calc', 'ROI कैल्क'),
              tileColor: AppColors.infoTint,
              iconColor: AppColors.info,
              onTap: () => onNavigate(_Tab.financialHub),
            ),
            _QuickActionTile(
              icon: Icons.chat_bubble_outline,
              label: s.t('Ask Saathi', 'साथी से पूछें'),
              tileColor: AppColors.brandTint,
              iconColor: AppColors.brand,
              onTap: () => Navigator.of(context).pushNamed('/saathi'),
            ),
            _QuickActionTile(
              icon: Icons.trending_up_outlined,
              label: s.t('Analytics', 'एनालिटिक्स'),
              tileColor: AppColors.warningTint,
              iconColor: AppColors.warning,
              onTap: () => Navigator.of(context).pushNamed('/insights'),
            ),
            _QuickActionTile(
              icon: Icons.gavel_outlined,
              label: s.t('Find Bids', 'बोलियाँ खोजें'),
              tileColor: AppColors.violetTint,
              iconColor: AppColors.violet,
              onTap: () => Navigator.of(context).pushNamed('/bids'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tileColor;
  final Color iconColor;
  final VoidCallback onTap;
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.tileColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSize.tap,
            height: AppSize.tap,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, size: AppIconSize.md, color: iconColor),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            label,
            style: AppText.caption,
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    ),
  );
}

// ── Learn & Stay Current ─────────────────────────────────────────────────────

class _LearnSection extends StatelessWidget {
  final AppStore store;
  const _LearnSection({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final bulletin = s.bulletins.isNotEmpty ? s.bulletins.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          s.t('Learn & Stay Current', 'सीखें और अपडेट रहें'),
          actionLabel: s.t('See all', 'सभी देखें'),
          onAction: () => Navigator.of(context).pushNamed('/news'),
        ),
        AppCard(
          tone: AppCardTone.brand,
          onTap: () => Navigator.of(context).pushNamed('/trainings'),
          child: Row(
            children: [
              const Icon(
                Icons.ondemand_video_outlined,
                size: AppIconSize.md,
                color: AppColors.brand,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('Module Trainings', 'मॉड्यूल प्रशिक्षण'),
                      style: AppText.bodyStrong,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      s.t('34 videos · 6 modules', '34 वीडियो · 6 मॉड्यूल'),
                      style: AppText.secondary(AppText.caption),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        AppCard(
          tone: AppCardTone.outlined,
          onTap: bulletin != null
              ? () {
                  final vid = bulletin['video_id'] as String?;
                  if (vid != null && vid.isNotEmpty) {
                    openYouTubeVideo(context, s, vid);
                  } else {
                    Navigator.of(context).pushNamed('/news');
                  }
                }
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('GEM WEEKLY', 'GEM साप्ताहिक'),
                style: AppText.overline.copyWith(color: AppColors.brand),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                bulletin != null
                    ? (bulletin['title'] as String? ?? '')
                    : s.t('Coming soon', 'जल्द आ रहा है'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySmall,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                s.t('Watch →', 'देखें →'),
                style: AppText.caption.copyWith(color: AppColors.brand),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

/// The floating entry to Saathi: an ink pill with a lifted sparkle and the
/// label, shrinking to a round icon button while the page scrolls down.
class _SaathiButton extends StatelessWidget {
  final AppStore store;
  final bool expanded;
  const _SaathiButton({required this.store, required this.expanded});

  @override
  Widget build(BuildContext context) {
    final label = store.t('Ask Saathi', 'साथी से पूछें');
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
            boxShadow: AppShadow.floating,
          ),
          child: Material(
            color: AppColors.ink,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).pushNamed('/saathi'),
              child: AnimatedSize(
                duration: Motion.of(context, Motion.fast),
                curve: Motion.enter,
                child: SizedBox(
                  height: _saathiHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: expanded ? AppSpace.lg : AppSpace.md + 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DepthIcon(
                          Icons.auto_awesome,
                          size: AppIconSize.md,
                          color: AppColors.surface,
                          lifted: true,
                        ),
                        if (expanded) ...[
                          const SizedBox(width: AppSpace.sm),
                          Text(
                            label,
                            style: AppText.button.copyWith(
                              color: AppColors.surface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
