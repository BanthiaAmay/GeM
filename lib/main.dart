import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/models.dart';
import 'core/motion.dart';
import 'core/theme.dart';
import 'core/transitions.dart';
import 'data/app_store.dart';
import 'data/push_service.dart';
import 'features/brand_logo.dart';
import 'features/account_page.dart';
import 'features/alerts_page.dart';
import 'features/bid_feed.dart';
import 'features/saathi_page.dart';
import 'features/gem_guide_page.dart';
import 'features/gem_check_page.dart';
import 'features/home_page.dart';
import 'features/insights_page.dart';
import 'features/language_page.dart';
import 'features/onboarding_flow_1.dart';
import 'features/onboarding_flow_2.dart';
import 'features/onboarding_flow_3.dart';
import 'features/onboarding_flow_4.dart';
import 'features/onboarding_flow_5.dart';
import 'features/bid_docs/mii_certificate_page.dart';
import 'features/bid_docs/escalation_matrix_page.dart';
import 'features/bid_docs/bid_security_page.dart';
import 'features/bid_docs/financial_standing_page.dart';
import 'features/bid_docs/non_conviction_page.dart';
import 'features/bid_docs/non_relation_page.dart';
import 'features/bid_docs/non_blacklist_certificate_page.dart';
import 'features/bid_docs/atc_certificate_page.dart';
import 'features/bid_docs/land_border_declaration_page.dart';
import 'features/bid_docs/lowest_price_declaration_page.dart';
import 'features/bid_docs/mrp_declaration_page.dart';
import 'features/bid_docs/oem_authorization_page.dart';
import 'features/bid_docs/msme_emd_page.dart';
import 'features/bid_docs/msme_turnover_page.dart';
import 'features/bid_docs/warranty_declaration_page.dart';
import 'features/search/bid_detail_page.dart';
import 'features/search/search_page.dart';
import 'features/search/search_store.dart';
import 'features/shell.dart';
import 'features/welcome_page.dart';

/// The seller readiness walkthrough, keyed by route
/// name. Kept as a lookup table rather than another long ternary chain.
final Map<String, Widget Function(AppStore)> flowPages = {
  'flow-name': (s) => FlowFullNamePage(store: s),
  'flow-phone': (s) => FlowPhonePage(store: s),
  'flow-location': (s) => FlowLocationPage(store: s),
  'flow-bizname': (s) => FlowBusinessNamePage(store: s),
  'flow-bizform': (s) => FlowBusinessFormPage(store: s),
  'flow-sector': (s) => FlowSectorPage(store: s),
  'flow-products': (s) => FlowProductsPage(store: s),
  'flow-role': (s) => FlowRolePage(store: s),
  'flow-authorised': (s) => FlowAuthorisedPage(store: s),
  'flow-turnover': (s) => FlowTurnoverPage(store: s),
  'flow-turnover-history': (s) => FlowTurnoverHistoryPage(store: s),
  'flow-experience': (s) => FlowExperiencePage(store: s),
  'flow-experience-detail': (s) => FlowExperienceDetailPage(store: s),
  'flow-privacy': (s) => FlowPrivacyPage(store: s),
  'flow-records': (s) => FlowRecordsPage(store: s),
  'flow-pan': (s) => FlowPanPage(store: s),
  'flow-checklist': (s) => FlowChecklistPage(store: s),
  'flow-video': (s) => FlowVideoPage(store: s),
  'flow-redirect': (s) => FlowRedirectPage(store: s),
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  SupabaseClient? client;
  if (url.isEmpty || key.isEmpty) {
    // Plain `flutter run` passes no settings: say so instead of failing quietly.
    debugPrint(
      'Bid2Scale: Supabase is not configured, so sign-in and cloud saving are off. '
      'Run ./run (or flutter run --dart-define-from-file=config/env.json).',
    );
  }
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      client = Supabase.instance.client;
    } catch (_) {
      /* Local tools stay available if configuration is invalid. */
    }
  }
  final store = AppStore(await SharedPreferences.getInstance(), client: client);
  final navigator = GlobalKey<NavigatorState>();
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final push = PushService(store)
    ..onForeground = (message) {
      unawaited(store.loadAlerts());
      messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            message.notification?.title ??
                store.t('New matching GeM bid', 'नई मेल खाती GeM बोली'),
          ),
          action: SnackBarAction(
            label: store.t('View', 'देखें'),
            onPressed: () => navigator.currentState?.pushNamed('/alerts'),
          ),
        ),
      );
    }
    ..onOpened = (_) {
      unawaited(store.loadAlerts());
      navigator.currentState?.pushNamed('/alerts');
    };
  store.push = push;
  final ready = Future.wait([store.initialize(), push.init()]).then((_) {
    unawaited(push.refresh());
  });
  runApp(
    SaathiApp(
      store: store,
      ready: ready,
      navigatorKey: navigator,
      messengerKey: messenger,
    ),
  );
}

/// A short brand reveal — the mark appears first, then the wordmark
/// fades and rises in beside/below it — before handing off to
/// welcome and language, then app registration before the GeM questions.
class SplashGate extends StatefulWidget {
  final AppStore store;

  /// The app's one-time startup work (restoring cloud state, fetching
  /// benchmarks, etc.) — [main] fires this exactly once and hands the
  /// same [Future] down here so the splash can wait for it instead of
  /// racing it.
  final Future<void> ready;

  const SplashGate({super.key, required this.store, required this.ready});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  // The two reveal beats, both measured from splash start: the mark
  // fades/scales in over the first 600ms; the wordmark starts 250ms
  // in and finishes at 750ms. The controller's own duration only
  // needs to span the later of the two.
  static const _markEnd = Duration(milliseconds: 600);
  static const _wordmarkStart = Duration(milliseconds: 250);
  static const _wordmarkEnd = Duration(milliseconds: 750);
  static const _holdUntil = Duration(milliseconds: 1200);
  static const _reducedHold = Duration(milliseconds: 600);
  static const _maxTotal = Duration(milliseconds: 2500);
  static const _fullWidth = 280.0;
  // Both PNGs' icon glyph occupies identical pixel dimensions in
  // their own canvases (measured: rows 26–281 either way), just on
  // canvases of different overall width (mark 305px, full 597px) —
  // so scaling the mark to this fraction of the full logo's own
  // width makes the two icons land at the same size and position
  // when stacked and top-center-aligned, with no manual offsets.
  static const _markWidth = _fullWidth * 305 / 597;

  late final AnimationController _controller;
  late final Animation<double> _markOpacity;
  late final Animation<double> _markScale;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkOffset;
  bool _reduced = false;
  bool _decided = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _wordmarkEnd);
    _markOpacity = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        0,
        _markEnd.inMilliseconds / _wordmarkEnd.inMilliseconds,
        curve: Motion.enter,
      ),
    );
    _markScale = _markOpacity.drive(Tween<double>(begin: 0.96, end: 1));
    _wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        _wordmarkStart.inMilliseconds / _wordmarkEnd.inMilliseconds,
        1,
        curve: Motion.enter,
      ),
    );
    _wordmarkOffset = _wordmarkOpacity.drive(
      Tween<Offset>(begin: const Offset(0, 8), end: Offset.zero),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    _reduced = Motion.reduced(context);
    if (_reduced) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
    unawaited(_scheduleNavigation());
  }

  Future<void> _scheduleNavigation() async {
    final hold = Future<void>.delayed(_reduced ? _reducedHold : _holdUntil);
    await Future.any([
      Future.wait([hold, widget.ready]),
      Future<void>.delayed(_maxTotal),
    ]);
    if (!mounted) return;
    final home = widget.store.hasOnboarded && widget.store.signedIn;
    final navigator = Navigator.of(context);
    navigator.pushReplacementNamed(
      widget.store.hasOnboarded
          ? (widget.store.signedIn ? '/home' : '/onboarding-auth')
          : '/welcome',
      arguments: fadeOnlyTransition,
    );
    // Opened from a bid-alert notification: show the inbox over Home.
    final launchRoute = home ? widget.store.push?.takeLaunchRoute() : null;
    if (launchRoute != null) unawaited(navigator.pushNamed(launchRoute));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // FadeTransition rather than a raw Opacity in
            // AnimatedBuilder: at controller value 1 (including the
            // reduced-motion jump-to-end) the curves below already
            // evaluate to opacity 1 / scale 1 / offset zero on their
            // own, so no `_reduced ? ... :` branch is needed here.
            FadeTransition(
              opacity: _markOpacity,
              child: AnimatedBuilder(
                animation: _markScale,
                child: const BrandLogo(
                  variant: BrandLogoVariant.mark,
                  depth: false,
                  width: _markWidth,
                ),
                builder: (context, child) =>
                    Transform.scale(scale: _markScale.value, child: child),
              ),
            ),
            Hero(
              tag: 'brand-logo',
              child: FadeTransition(
                opacity: _wordmarkOpacity,
                child: AnimatedBuilder(
                  animation: _wordmarkOffset,
                  child: const BrandLogo(
                    variant: BrandLogoVariant.full,
                    width: _fullWidth,
                  ),
                  builder: (context, child) => Transform.translate(
                    offset: _wordmarkOffset.value,
                    child: child,
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

class SaathiApp extends StatelessWidget {
  final AppStore store;
  final Future<void> ready;

  /// Let notification taps and foreground alerts reach the app from outside
  /// the widget tree.
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;
  const SaathiApp({
    super.key,
    required this.store,
    required this.ready,
    this.navigatorKey,
    this.messengerKey,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) => MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      title: 'Bid2Scale',
      debugShowCheckedModeBanner: false,
      theme: saathiTheme(),
      locale: Locale(store.language),
      supportedLocales: [
        for (final lang in supportedLanguages) Locale(lang[0]),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: SplashGate(store: store, ready: ready),
      onGenerateRoute: (settings) {
        Widget builder(BuildContext context) {
          final page = (settings.name ?? '/')
              .replaceFirst('/', '')
              .split('?')
              .first;
          final requiresAccount =
              flowPages.containsKey(page) ||
              {'', 'home', 'gem-check', 'gem-guide', 'register'}.contains(page);
          return ListenableBuilder(
            listenable: store,
            builder: (context, _) => requiresAccount && !store.signedIn
                ? AccountPage(
                    store: store,
                    entry: true,
                    continueTo: page.isEmpty ? '/home' : '/$page',
                  )
                : page == 'onboarding-auth'
                ? AccountPage(
                    store: store,
                    entry: true,
                    continueTo: store.hasOnboarded ? '/home' : '/gem-check',
                  )
                : flowPages.containsKey(page)
                ? flowPages[page]!(store)
                : page.isEmpty || page == 'home'
                ? HomePage(store: store)
                : page == 'welcome'
                ? WelcomePage(store: store)
                : page == 'language'
                ? LanguagePage(store: store)
                : page == 'gem-check'
                ? GemCheckPage(store: store)
                : page == 'account' || page == 'auth'
                ? AccountPage(store: store, entry: page == 'auth')
                : page == 'alerts'
                ? AlertsPage(store: store)
                : page == 'bids'
                ? BidsPage(store: store)
                : page == 'saathi'
                ? SaathiPage(store: store)
                : page == 'gem-guide'
                ? GemGuidePage(store: store)
                : page == 'insights'
                ? InsightsPage(store: store)
                : page == 'insights-trends'
                ? InsightsTrendsPage(store: store)
                : page == 'insights-categories'
                ? InsightsCategoriesPage(store: store)
                : page == 'insights-fit'
                ? InsightsFitPage(store: store)
                : page == 'tool-mii'
                ? MiiCertificatePage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-escalation'
                ? EscalationMatrixPage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-bid-security'
                ? BidSecurityPage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-financial-standing'
                ? FinancialStandingPage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-non-conviction'
                ? NonConvictionPage(store: store)
                : page == 'tool-non-relation'
                ? NonRelationPage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-atc-certificate'
                ? AtcCertificatePage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-msme-turnover'
                ? MsmeTurnoverPage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-msme-emd'
                ? MsmeEmdPage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-warranty-declaration'
                ? WarrantyDeclarationPage(store: store)
                : page == 'tool-nbc'
                ? NonBlacklistCertificatePage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-lowest-price-declaration'
                ? LowestPriceDeclarationPage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-oem-authorization'
                ? OemAuthorizationPage(
                    store: store,
                    tenderNo: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'tool-land-border-declaration'
                ? LandBorderDeclarationPage(store: store)
                : page == 'tool-mrp-declaration'
                ? MrpDeclarationPage(store: store)
                : page == 'search'
                ? SearchPage(
                    store: store,
                    searchStore: SearchStore(store.prefs),
                    initialQuery: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : page == 'bid-detail'
                ? BidDetailPage(
                    store: store,
                    bidId: settings.arguments is String
                        ? settings.arguments as String
                        : null,
                  )
                : AppShell(store: store, page: page),
          );
        }

        return settings.arguments == fadeOnlyTransition
            ? FadeRoute(settings: settings, builder: builder)
            : SoftRoute(settings: settings, builder: builder);
      },
    ),
  );
}
