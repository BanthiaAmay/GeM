import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/tokens.dart';
import '../data/app_store.dart';
import 'components.dart';
import 'widgets.dart' show openLink;

const gemYoutubeChannel = 'https://www.youtube.com/@GovernmenteMarketplace';

/// A YouTube thumbnail with a play button; tapping plays the video in-app.
class YouTubeVideoCard extends StatelessWidget {
  final String videoId;
  final AppStore store;
  const YouTubeVideoCard({
    super.key,
    required this.videoId,
    required this.store,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: store.t('Play video', 'वीडियो चलाएँ'),
    child: GestureDetector(
      onTap: () => openYouTubeVideo(context, store, videoId),
      child: ClipRRect(
        borderRadius: AppRadius.card,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.disabled,
                  child: Icon(Icons.video_library_outlined, size: 48),
                ),
              ),
              const ColoredBox(color: AppColors.scrim),
              const Center(child: _PlayButton()),
            ],
          ),
        ),
      ),
    ),
  );
}

void openYouTubeVideo(BuildContext context, AppStore store, String videoId) =>
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YouTubeVideoPage(videoId: videoId, store: store),
      ),
    );

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 64,
    decoration: const BoxDecoration(
      color: AppColors.videoPlay,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.play_arrow_rounded,
      color: AppColors.surface,
      size: 38,
    ),
  );
}

/// Full-screen in-app player. Loads YouTube's own watch page rather than an
/// embed, so it also works for channels that disable embedding.
class YouTubeVideoPage extends StatefulWidget {
  final String videoId;
  final AppStore store;
  const YouTubeVideoPage({
    super.key,
    required this.videoId,
    required this.store,
  });

  @override
  State<YouTubeVideoPage> createState() => _YouTubeVideoPageState();
}

class _YouTubeVideoPageState extends State<YouTubeVideoPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://m.youtube.com/watch?v=${widget.videoId}'),
      );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: s.t('Close', 'बंद करें'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.t('Video Guide', 'वीडियो गाइड'),
          style: AppText.bodyStrong.copyWith(color: AppColors.surface),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.surface),
            ),
        ],
      ),
    );
  }
}

/// "Source: Government e-Marketplace on YouTube", linking to the channel.
class YouTubeSourceNote extends StatelessWidget {
  final AppStore store;
  const YouTubeSourceNote({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return GestureDetector(
      onTap: () => openLink(context, s, gemYoutubeChannel),
      child: Row(
        children: [
          const Icon(
            Icons.ondemand_video_outlined,
            size: 14,
            color: AppColors.ink,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: s.t('Source: ', 'स्रोत: '),
                style: AppText.caption,
                children: [
                  TextSpan(
                    text: s.t(
                      'Government e-Marketplace on YouTube',
                      'YouTube पर Government e-Marketplace',
                    ),
                    style: AppText.caption.copyWith(
                      color: AppColors.brand,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One GeM Weekly Bulletin row from `gem_bulletins`: video, title and date.
class BulletinCard extends StatelessWidget {
  final AppStore store;
  final Map<String, dynamic> bulletin;
  const BulletinCard({super.key, required this.store, required this.bulletin});

  @override
  Widget build(BuildContext context) {
    final published = DateTime.tryParse(
      bulletin['published_at'] as String? ?? '',
    );
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YouTubeVideoCard(
            videoId: bulletin['video_id'] as String,
            store: store,
          ),
          const SizedBox(height: AppSpace.md),
          Text(bulletin['title'] as String? ?? '', style: AppText.bodyStrong),
          if (published != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              DateFormat('d MMM yyyy').format(published.toLocal()),
              style: AppText.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact row for one saved GeM video: thumbnail, title, date and length.
/// Tapping plays it in-app.
class GemVideoTile extends StatelessWidget {
  final AppStore store;
  final Map<String, dynamic> video;
  const GemVideoTile({super.key, required this.store, required this.video});

  static String _length(int seconds) {
    final h = seconds ~/ 3600, m = seconds % 3600 ~/ 60, sec = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
  }

  @override
  Widget build(BuildContext context) {
    final videoId = video['video_id'] as String;
    final published = DateTime.tryParse(video['published_at'] as String? ?? '');
    final seconds = video['duration_seconds'] as int?;
    final details = [
      if (published != null)
        DateFormat('d MMM yyyy').format(published.toLocal()),
      if (seconds != null && seconds > 0) _length(seconds),
    ].join(' · ');
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.sm),
      onTap: () => openYouTubeVideo(context, store, videoId),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              width: 128,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: AppColors.disabled,
                        child: Icon(Icons.video_library_outlined),
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: AppIconSize.md,
                        color: AppColors.surface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video['title'] as String? ?? '',
                  style: AppText.bodyStrong,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(details, style: AppText.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
