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
enum _Tab { home, tools, gem101, financialHub, profile }

/// Shared (tab, outlined icon, filled icon, label) definitions for both
/// the phone bottom nav ([_HomeNav]) and the wide-layout [NavigationRail],
/// so the two stay in lockstep instead of drifting apart.
List<(_Tab, IconData, IconData, String)> _navItems(AppStore s) => [
  (_Tab.home, Icons.home_outlined, Icons.home, s.t('Home', 'होम')),
  (_Tab.tools, Icons.build_outlined, Icons.build, s.t('Tools', 'टूल')),
  (
    _Tab.gem101,
    Icons.school_outlined,
    Icons.school,
    s.t('GeM 101', 'GeM 101'),
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

class _HomePageState extends State<HomePage> {
  _Tab _tab = _Tab.home;
  void _go(_Tab tab) => setState(() => _tab = tab);

  SearchStore? _searchStore;
  List<String> _searchAlerts = [];

  @override
  void initState() {
    super.initState();
    _initAlerts();
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      endDrawer: _HomeDrawer(store: s),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > AppSize.wide;

            final topBar = GlassBar.top(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, 10, AppSpace.lg, 10),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const BrandLogo(
                        variant: BrandLogoVariant.lockup,
                        width: 96,
                      ),
                    ),
                  ),
                  _LanguageChip(store: s),
                  const SizedBox(width: 6),
                  AppIconButton(
                    onPressed: () => Navigator.of(context).pushNamed('/search'),
                    icon: Icons.search,
                    tooltip: s.t('Search', 'खोजें'),
                  ),
                  _NotificationBell(
                    store: s,
                    hasUnread: _searchAlerts.isNotEmpty ||
                        (_searchStore?.hasUnread ?? false),
                    onTap: () => _go(_Tab.home),
                  ),
                  AppIconButton(
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    icon: Icons.menu,
                    tooltip: s.t('Menu', 'मेनू'),
                  ),
                ],
              ),
            );

            final scrollArea = Expanded(
              child: ScrollMoreHint(
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
                      _Tab.gem101 => _Gem101Tab(store: s),
                      _Tab.financialHub => _FinancialHubTab(store: s),
                      _Tab.profile => _ProfileTab(store: s),
                    },
                  );
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl,
                      AppSpace.xl,
                      AppSpace.xl,
                      60,
                    ),
                    child: AnimatedSwitcher(
                      duration: Motion.of(context, Motion.normal),
                      switchInCurve: Motion.enter,
                      switchOutCurve: Motion.exit,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: currentBody,
                    ),
                  );
                },
              ),
            );

            final searchBar = _PersistentSearchBar(store: s);

            final mainColumn = Column(
              children: [
                topBar,
                searchBar,
                const Divider(height: 1),
                scrollArea,
                // The bottom tab bar is a phone pattern only — wide
                // layouts get a NavigationRail on the side instead.
                if (!isWide)
                  GlassBar.bottom(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.sm,
                      AppSpace.md,
                      AppSpace.sm,
                      AppSpace.md,
                    ),
                    child: _HomeNav(store: s, current: _tab, onSelect: _go),
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
      Navigator.of(context).push(
        SoftRoute(
          settings: const RouteSettings(),
          builder: builder,
        ),
      );
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
                Icons.description_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('Documentations', 'दस्तावेज़')),
              onTap: () => openDrawerPage(
                (_) => DocumentationsPage(store: s),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.fact_check_outlined,
                color: AppColors.brand,
              ),
              title: Text(
                s.t('Bid Preparation Assistance', 'बोली तैयारी सहायता'),
              ),
              onTap: () => openDrawerPage(
                (_) => BidPreparationAssistancePage(store: s),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sync_outlined, color: AppColors.brand),
              title: Text(s.t('Bid Cycle', 'बोली चक्र')),
              onTap: () => openDrawerPage((_) => BidCyclePage(store: s)),
            ),
            ListTile(
              leading: const Icon(Icons.task_alt_outlined, color: AppColors.brand),
              title: Text(s.t('Execution', 'निष्पादन')),
              onTap: () => openDrawerPage((_) => ExecutionPage(store: s)),
            ),
            ListTile(
              leading: const Icon(
                Icons.trending_up_outlined,
                color: AppColors.brand,
              ),
              title: Text(s.t('Earnings Dynamics', 'कमाई गतिशीलता')),
              onTap: () => openDrawerPage(
                (_) => EarningsDynamicsPage(store: s),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined, color: AppColors.brand),
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
              title: Text(
                s.t('Start onboarding again', 'फिर से शुरुआत करें'),
              ),
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
                : s.t(
                    'Hello, {name}',
                    'नमस्ते, {name}',
                    vars: {'name': name},
                  ),
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
            onTap: () => openLink(context, s, gemSource),
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
                  label: s.t('Ask\nBizReady', 'BizReady\nसे पूछें'),
                  onTap: () => onNavigate(_Tab.tools),
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

/// Persistent search bar that sits between the top glass bar and the tab
/// content — always visible regardless of which tab is active or how far
/// the user has scrolled. Tapping opens the universal search page.
class _PersistentSearchBar extends StatelessWidget {
  final AppStore store;
  const _PersistentSearchBar({required this.store});

  @override
  Widget build(BuildContext context) {
    final hint = store.t('Search bids, tools…', 'बोलियाँ, टूल खोजें…');
    return Semantics(
      button: true,
      label: hint,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/search'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.sm,
          ),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  size: AppIconSize.md,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    hint,
                    style: AppText.body.copyWith(color: AppColors.textHint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

class _Gem101Tab extends StatelessWidget {
  final AppStore store;
  const _Gem101Tab({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PageHeader(
          title: s.t('GeM 101', 'GeM 101'),
          subtitle: s.t(
            'The basics of selling on the Government e Marketplace.',
            'सरकारी ई-मार्केटप्लेस पर बिक्री की बुनियादी बातें।',
          ),
        ),
        _ToolSection(
          icon: Icons.storefront_outlined,
          title: s.t('What is GeM?', 'GeM क्या है?'),
          description: s.t(
            'India\'s official online marketplace for government buyers.',
            'सरकारी खरीदारों के लिए भारत का आधिकारिक ऑनलाइन बाज़ार।',
          ),
          body: s.t(
            'Departments, PSUs, and other government bodies buy goods and services here. Sellers list products and bid for orders; the lowest eligible bid usually wins.',
            'विभाग, PSU और अन्य सरकारी संस्थाएँ यहाँ से सामान और सेवाएँ खरीदते हैं। विक्रेता उत्पाद सूचीबद्ध करते हैं और ऑर्डर के लिए बोली लगाते हैं; आमतौर पर सबसे कम योग्य बोली जीतती है।',
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        _ToolSection(
          icon: Icons.flag_outlined,
          title: s.t('The nine steps to your first order', 'पहले ऑर्डर तक के नौ चरण'),
          description: s.t(
            'Identity, GST, Udyam, account, catalogue, deposits, bids, fulfilment, ratings.',
            'पहचान, GST, उद्यम, खाता, सूची, जमा, बोली, पूर्ति, रेटिंग।',
          ),
          body: s.t(
            'Your readiness dashboard on the Home tab tracks these in order, but you can confirm a step as done or not applicable without following the sequence strictly.',
            'होम टैब पर आपका तैयारी डैशबोर्ड इन्हें क्रम से ट्रैक करता है, पर आप सख्त क्रम का पालन किए बिना किसी चरण को पूर्ण या लागू नहीं के रूप में पुष्टि कर सकते हैं।',
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        _LearnRow(store: s),
        const SizedBox(height: AppSpace.xxxl),
        SectionHeader(s.t('Documentations', 'दस्तावेज़')),
        Text(
          s.t(
            'What you typically need to register and start bidding.',
            'रजिस्टर करने और बोली शुरू करने के लिए आमतौर पर जो चाहिए।',
          ),
          style: AppText.secondary(AppText.body),
        ),
        const SizedBox(height: AppSpace.md),
        DocumentChecklistCard(store: s),
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
        Text(
          s.t(
            'Estimates are illustrative only — payment delay, financing cost, and tax are not modelled.',
            'अनुमान केवल उदाहरण के लिए हैं — भुगतान में देरी, वित्तपोषण लागत और कर शामिल नहीं हैं।',
          ),
          style: AppText.caption,
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
        [field('district'), field('state')].where((v) => v.isNotEmpty).join(', '),
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
                  supportedLanguages
                      .firstWhere(
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
                    s.t('Office stationery\nsupplies', 'ऑफिस स्टेशनरी\nसामग्री'),
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
          AppButton(
            label: s.t('View bid', 'बोली देखें'),
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
        Icon(icon, size: AppIconSize.lg - 4, color: AppColors.brand),
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
                    borderRadius: BorderRadius.circular(AppRadius.sm),
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
                              AnimatedScale(
                                scale: tab == current ? 1.08 : 1.0,
                                duration: Motion.of(context, Motion.fast),
                                curve: Motion.enter,
                                child: Icon(
                                  tab == current ? filledIcon : outlinedIcon,
                                  size: AppIconSize.md,
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
