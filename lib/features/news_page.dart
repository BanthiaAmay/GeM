import 'dart:async';
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'youtube_video.dart';

/// GeM Weekly Bulletins saved by the server's Friday bulletin worker.
class NewsPage extends StatefulWidget {
  final AppStore store;
  const NewsPage({super.key, required this.store});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.store.loadBulletins());
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(title: Text(s.t('News', 'समाचार'))),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: s.loadBulletins,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpace.gutter),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          s.t('GeM Weekly Bulletin', 'GeM साप्ताहिक बुलेटिन'),
                        ),
                        Text(
                          s.t(
                            'Official GeM Weekly Bulletins, updated every Friday.',
                            'आधिकारिक GeM साप्ताहिक बुलेटिन, हर शुक्रवार अपडेट।',
                          ),
                          style: AppText.secondary(AppText.body),
                        ),
                        const SizedBox(height: AppSpace.lg),
                        ..._body(s),
                        const SizedBox(height: AppSpace.lg),
                        YouTubeSourceNote(store: s),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(AppStore s) {
    if (s.bulletins.isEmpty && s.bulletinsLoading) {
      return [
        StateView(
          kind: StateKind.loading,
          title: s.t('Loading news', 'समाचार लोड हो रहे हैं'),
        ),
      ];
    }
    if (s.bulletins.isEmpty && s.bulletinsFailed) {
      return [
        StateView(
          kind: StateKind.error,
          title: s.t('Could not load news', 'समाचार लोड नहीं हो सके'),
          actionLabel: s.t('Retry', 'फिर कोशिश करें'),
          onAction: s.loadBulletins,
        ),
      ];
    }
    if (s.bulletins.isEmpty) {
      return [
        StateView(
          kind: StateKind.empty,
          title: s.t('No bulletins yet', 'अभी कोई बुलेटिन नहीं'),
          message: s.t(
            'The new bulletin appears here every Friday.',
            'नया बुलेटिन हर शुक्रवार यहाँ दिखेगा।',
          ),
        ),
      ];
    }
    return [
      for (final bulletin in s.bulletins)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: BulletinCard(store: s, bulletin: bulletin),
        ),
    ];
  }
}
