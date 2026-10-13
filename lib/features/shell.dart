import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'brand_logo.dart';
import 'components.dart';
import 'widgets.dart';
import 'tools.dart';
import 'pages.dart';

class AppShell extends StatefulWidget {
  final AppStore store;
  final String page;
  const AppShell({super.key, required this.store, required this.page});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final watch = Stopwatch()..start();
  late Timer heartbeat;
  AppStore get s => widget.store;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    s.event('page_view', page: widget.page);
    if (['eligibility', 'revenue', 'pricing', 'roi'].contains(widget.page)) {
      s.event('tool_started', page: widget.page);
    }
    heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        s.event(
          'engagement',
          page: widget.page,
          props: {'seconds': watch.elapsed.inSeconds.clamp(0, 30)},
        );
        unawaited(s.sync());
      }
      watch.reset();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      watch.start();
      unawaited(s.sync());
    } else {
      watch.stop();
    }
  }

  @override
  void dispose() {
    heartbeat.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final nav = [
      ['', 'Home', 'होम'],
      ['learn', 'What is GeM?', 'GeM क्या है?'],
      ['tools', 'Explore tools', 'सभी टूल'],
      ['report', 'My report', 'मेरी रिपोर्ट'],
    ];
    Widget brand() => InkWell(
      onTap: () => go(context, s, ''),
      child: const BrandLogo(variant: BrandLogoVariant.lockup, width: 130),
    );
    return Scaffold(
      appBar: AppBar(
        // A translucent tint rather than a true backdrop blur: this
        // page's forms auto-scroll a focused field into view, which
        // can slide content up under a bar that extends behind it —
        // a real blur there would make an underlying control briefly
        // untappable. The onboarding flow's fixed GlassBar chrome
        // (lib/features/glass.dart) doesn't have that risk and keeps
        // the full frosted treatment.
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 82,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.only(left: wide ? 24 : 0),
          child: brand(),
        ),
        actions: [
          if (wide)
            ...nav.map(
              (n) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: TextButton(
                  onPressed: () => go(context, s, n[0]),
                  child: Text(
                    s.t(n[1], n[2]),
                    style: AppText.bodySmall.copyWith(
                      color: widget.page == n[0]
                          ? AppColors.brand
                          : AppColors.textSecondary,
                      fontWeight: widget.page == n[0]
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            initialValue: s.language,
            onSelected: s.setLanguage,
            itemBuilder: (context) => [
              for (final lang in supportedLanguages)
                PopupMenuItem(
                  value: lang[0],
                  child: Text(
                    lang[1],
                    style: TextStyle(
                      fontWeight: lang[0] == s.language
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                supportedLanguages.firstWhere(
                  (lang) => lang[0] == s.language,
                  orElse: () => supportedLanguages[0],
                )[1],
                style: AppText.secondary(AppText.bodySmall),
              ),
            ),
          ),
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 32, left: 12),
              child: AppButton(
                onPressed: () => go(context, s, 'account'),
                icon: s.signedIn
                    ? Icons.cloud_done_outlined
                    : Icons.bookmark_border,
                label: s.t('Save progress', 'प्रगति सहेजें'),
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                expand: false,
                haptic: false,
              ),
            ),
        ],
      ),
      body: SelectionArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 40 : 20,
                  wide ? 28 : 12,
                  wide ? 40 : 20,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.page.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AppButton(
                            onPressed: () => go(context, s, ''),
                            icon: Icons.arrow_back,
                            label: s.t('Back to home', 'होम पर वापस'),
                            variant: AppButtonVariant.tertiary,
                            size: AppButtonSize.sm,
                            expand: false,
                            haptic: false,
                          ),
                        ),
                      ),
                    switch (widget.page) {
                      'eligibility' ||
                      'revenue' ||
                      'pricing' ||
                      'roi' => ToolPage(store: s, kind: widget.page),
                      'tools' => ToolsPage(s),
                      'learn' => LearnPage(s),
                      'tracker' => TrackerPage(s),
                      'report' => ReportPage(s),
                      'register' => RegisterPage(s),
                      'support' => SupportPage(s),
                      _ => StateView(
                        kind: StateKind.empty,
                        title: s.t(
                          'This page is being rebuilt',
                          'यह पेज फिर से बनाया जा रहा है',
                        ),
                        message: s.t(
                          'Please check back soon.',
                          'कृपया जल्द ही दोबारा देखें।',
                        ),
                        actionLabel: s.t('Back to home', 'होम पर वापस'),
                        onAction: () => go(context, s, ''),
                      ),
                    },
                    const SizedBox(height: 48),
                    const Divider(),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        Text(
                          s.t(
                            'GeM BizReady  •  Small business. Bigger possibilities.',
                            'GeM BizReady  •  छोटा व्यवसाय। बड़ी संभावनाएँ।',
                          ),
                          style: AppText.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          s.t(
                            'Independent project · Not affiliated with GeM',
                            'स्वतंत्र परियोजना · GeM से संबद्ध नहीं',
                          ),
                          style: AppText.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      children: [
                        TextButton(
                          onPressed: () => go(context, s, 'account'),
                          child: Text(
                            s.t(
                              'Privacy & saved data',
                              'गोपनीयता और सहेजा डेटा',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => go(context, s, 'support'),
                          child: Text(
                            s.t('Workshops & help', 'कार्यशाला और सहायता'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
