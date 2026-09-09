import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import 'widgets.dart';
import 'pages.dart';
import 'tools.dart';

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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.handshake_outlined,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'GeM ',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: ink,
              ),
            ),
            const Text(
              'Saathi',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 22,
                color: green,
              ),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
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
                    style: TextStyle(
                      color: widget.page == n[0] ? green : muted,
                      fontWeight: widget.page == n[0]
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          TextButton(
            onPressed: s.changeLanguage,
            child: Text(s.hi ? 'English' : 'हिंदी'),
          ),
          if (wide)
            Padding(
              padding: const EdgeInsets.only(right: 32, left: 12),
              child: OutlinedButton.icon(
                onPressed: () => go(context, s, 'account'),
                icon: Icon(
                  s.signedIn
                      ? Icons.cloud_done_outlined
                      : Icons.bookmark_border,
                  size: 17,
                ),
                label: Text(s.t('Save progress', 'प्रगति सहेजें')),
              ),
            )
          else
            Builder(
              builder: (context) => IconButton(
                tooltip: s.t('Menu', 'मेन्यू'),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              Padding(padding: const EdgeInsets.all(24), child: brand()),
              for (final n in [
                ...nav,
                ['tracker', 'Readiness tracker', 'तैयारी ट्रैकर'],
                ['register', 'Register on GeM', 'GeM पर पंजीकरण'],
                ['support', 'Get support', 'सहायता लें'],
                ['account', 'Save & privacy', 'सहेजें और गोपनीयता'],
                ['about', 'About the project', 'परियोजना के बारे में'],
              ])
                ListTile(
                  title: Text(s.t(n[1], n[2])),
                  onTap: () {
                    Navigator.pop(context);
                    go(context, s, n[0]);
                  },
                ),
            ],
          ),
        ),
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
                        child: TextButton.icon(
                          onPressed: () => go(context, s, ''),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: Text(s.t('Back to home', 'होम पर वापस')),
                        ),
                      ),
                    switch (widget.page) {
                      '' => HomePage(s),
                      'tools' => ToolsPage(s),
                      'learn' => LearnPage(s),
                      'eligibility' ||
                      'revenue' ||
                      'pricing' ||
                      'roi' => ToolPage(store: s, kind: widget.page),
                      'tracker' => TrackerPage(s),
                      'report' => ReportPage(s),
                      'register' => RegisterPage(s),
                      'account' => AccountPage(s),
                      'support' => SupportPage(s),
                      'about' => AboutPage(s),
                      _ => Column(
                        children: [
                          Text(s.t('Page not found', 'पेज नहीं मिला')),
                          NextActions(s, s.nextTool),
                        ],
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
                            'GeM Saathi  •  Small business. Bigger possibilities.',
                            'GeM साथी  •  छोटा व्यवसाय। बड़ी संभावनाएँ।',
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                        Text(
                          s.t(
                            'Independent project · Not affiliated with GeM',
                            'स्वतंत्र परियोजना · GeM से संबद्ध नहीं',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      children: [
                        TextButton(
                          onPressed: () => go(context, s, 'about'),
                          child: Text(s.t('About & sources', 'परिचय और स्रोत')),
                        ),
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
