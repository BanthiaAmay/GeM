import 'dart:async';
import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'youtube_video.dart';

/// Official GeM videos saved by the server's video sync (every few hours):
/// the weekly bulletin, success stories and earlier bulletins.
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
    unawaited(widget.store.loadGemVideos());
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
            onRefresh: s.loadGemVideos,
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
                            'Official GeM Weekly Bulletin, added here within hours of its release.',
                            'आधिकारिक GeM साप्ताहिक बुलेटिन, जारी होने के कुछ घंटों में यहाँ।',
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
    final stories = s.gemVideosOf(const {'story'});
    return [
      if (s.bulletins.isEmpty)
        _bulletinState(s)
      else
        BulletinCard(store: s, bulletin: s.bulletins.first),
      if (stories.isNotEmpty) ...[
        const SizedBox(height: AppSpace.xxl),
        SectionHeader(s.t('Success stories', 'सफलता की कहानियाँ')),
        for (final video in stories.take(6)) _tile(s, video),
      ],
      if (s.bulletins.length > 1) ...[
        const SizedBox(height: AppSpace.xxl),
        SectionHeader(s.t('Earlier bulletins', 'पिछले बुलेटिन')),
        for (final video in s.bulletins.skip(1)) _tile(s, video),
      ],
    ];
  }

  Widget _tile(AppStore s, Map<String, dynamic> video) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.sm),
    child: GemVideoTile(store: s, video: video),
  );

  Widget _bulletinState(AppStore s) {
    if (s.gemVideosLoading) {
      return StateView(
        kind: StateKind.loading,
        title: s.t('Loading news', 'समाचार लोड हो रहे हैं'),
      );
    }
    if (s.gemVideosFailed) {
      return StateView(
        kind: StateKind.error,
        title: s.t('Could not load news', 'समाचार लोड नहीं हो सके'),
        actionLabel: s.t('Retry', 'फिर कोशिश करें'),
        onAction: s.loadGemVideos,
      );
    }
    return StateView(
      kind: StateKind.empty,
      title: s.t('No bulletins yet', 'अभी कोई बुलेटिन नहीं'),
      message: s.t(
        'New bulletins appear here within hours of release.',
        'नए बुलेटिन जारी होने के कुछ घंटों में यहाँ दिखेंगे।',
      ),
    );
  }
}
