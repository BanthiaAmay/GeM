import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../widgets.dart';
import '../youtube_video.dart';
import 'quiz_sheet.dart';
import 'training_data.dart';
import 'trainings_page.dart' show copyDeepLink;

/// Deep view of one training module — a slim hero with animated progress
/// dots, followed by a compact numbered video list. Each row shows a
/// thumbnail, title and duration. Long-press a row to mark it watched or
/// unwatched without opening the player.
class ModuleDetailPage extends StatelessWidget {
  final AppStore store;
  final String moduleId;
  const ModuleDetailPage({
    super.key,
    required this.store,
    required this.moduleId,
  });

  @override
  Widget build(BuildContext context) {
    final module = findTrainingModule(moduleId);
    if (module == null) return _UnknownModule(store: store);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => _ModuleBody(store: store, module: module),
    );
  }
}

class _ModuleBody extends StatelessWidget {
  final AppStore store;
  final TrainingModule module;
  const _ModuleBody({required this.store, required this.module});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final watched = s.trainingWatched.toSet();
    final saved = s.trainingSaved.toSet();
    final done = module.videos.where((v) => watched.contains(v.videoId)).length;
    final total = module.videos.length;
    final quizPassed = s.trainingQuizPassed.contains(module.id);
    final allWatched = done == total && total > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t(module.titleEn, module.titleHi)),
        actions: [
          AppIconButton(
            icon: Icons.ios_share_outlined,
            tooltip: s.t('Share this module', 'यह मॉड्यूल साझा करें'),
            onPressed: () => copyDeepLink(context, s, module.id),
          ),
        ],
        // Slim progress bar along the bottom of the AppBar for instant
        // visual feedback without occupying extra layout space.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: AppProgressBar(
            value: total == 0 ? 0.0 : done / total,
            height: 3,
            animated: true,
            semanticLabel: s.t(
              '$done of $total videos watched',
              '$total में से $done वीडियो देखे',
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.gutter),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ModuleHero(
                    store: s,
                    module: module,
                    watchedIds: watched,
                    done: done,
                    total: total,
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  SectionHeader(s.t('Videos', 'वीडियो')),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: DividedList(
                      children: [
                        for (var i = 0; i < module.videos.length; i++)
                          _VideoListTile(
                            store: s,
                            video: module.videos[i],
                            index: i + 1,
                            watched: watched.contains(module.videos[i].videoId),
                            saved: saved.contains(module.videos[i].videoId),
                            isLastWatched:
                                s.trainingLastVideoId == module.videos[i].videoId,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  _QuizPanel(
                    store: s,
                    module: module,
                    unlocked: done > 0,
                    allWatched: allWatched,
                    passed: quizPassed,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  YouTubeSourceNote(store: s),
                  const SizedBox(height: AppSpace.huge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Module description panel with animated progress dots replacing
/// the old AppProgressRing.
class _ModuleHero extends StatelessWidget {
  final AppStore store;
  final TrainingModule module;
  final Set<String> watchedIds;
  final int done;
  final int total;
  const _ModuleHero({
    required this.store,
    required this.module,
    required this.watchedIds,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Panel(
      tone: AppCardTone.muted,
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t(module.subtitleEn, module.subtitleHi), style: AppText.body),
          const SizedBox(height: AppSpace.sm),
          Text(
            s.t(
              '$total videos · ~${module.totalMinutes} min',
              '$total वीडियो · ~${module.totalMinutes} मिनट',
            ),
            style: AppText.caption,
          ),
          const SizedBox(height: AppSpace.md),
          // Progress dots — watched dots expand from 8px to 20px wide.
          Row(
            children: [
              for (final v in module.videos) ...[
                AnimatedContainer(
                  duration: Motion.fast,
                  width: watchedIds.contains(v.videoId) ? 20 : 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: watchedIds.contains(v.videoId)
                        ? AppColors.brand
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            s.t('$done of $total watched', '$total में से $done देखे'),
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

/// Compact numbered video row inside a DividedList.
/// Tap to open the player; long-press to toggle watched status.
class _VideoListTile extends StatelessWidget {
  final AppStore store;
  final TrainingVideo video;
  final int index;
  final bool watched;
  final bool saved;
  final bool isLastWatched;
  const _VideoListTile({
    required this.store,
    required this.video,
    required this.index,
    required this.watched,
    required this.saved,
    required this.isLastWatched,
  });

  void _openPlayer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => YouTubeVideoPage(videoId: video.videoId, store: store),
      ),
    );
  }

  void _showWatchOptions(BuildContext context) {
    final s = store;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            ListTile(
              leading: Icon(
                watched ? Icons.radio_button_unchecked : Icons.check_circle_outline,
                color: AppColors.brand,
              ),
              title: Text(
                watched
                    ? s.t('Mark as not watched', 'नहीं देखा के रूप में चिह्नित करें')
                    : s.t('Mark as watched', 'देखा के रूप में चिह्नित करें'),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                if (watched) {
                  s.unmarkVideoWatched(video.videoId);
                } else {
                  s.markVideoWatched(video.videoId);
                }
              },
            ),
            const SizedBox(height: AppSpace.md),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    return InkWell(
      onTap: () => _openPlayer(context),
      onLongPress: () => _showWatchOptions(context),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Number / check bubble — animates to green when watched.
            AnimatedContainer(
              duration: Motion.fast,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: watched ? AppColors.brandTint : AppColors.surfaceMuted,
              ),
              child: Center(
                child: watched
                    ? const Icon(Icons.check, color: AppColors.brand, size: 16)
                    : Text(
                        '$index',
                        style: AppText.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            // Thumbnail — small, rounded.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.network(
                'https://img.youtube.com/vi/${video.videoId}/mqdefault.jpg',
                width: 72,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 72,
                  height: 50,
                  color: AppColors.surfaceMuted,
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            // Title + duration.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t(video.titleEn, video.titleHi),
                    style: AppText.bodyStrong,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.t('~${video.minutes} min', '~${video.minutes} मिनट'),
                        style: AppText.caption,
                      ),
                      if (isLastWatched)
                        Text(
                          s.t('  ·  Last watched', '  ·  अंतिम देखा'),
                          style: AppText.caption.copyWith(
                            color: AppColors.brand,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            // Bookmark toggle.
            AppIconButton(
              icon: saved ? Icons.bookmark : Icons.bookmark_outline,
              tooltip: saved
                  ? s.t('Remove bookmark', 'बुकमार्क हटाएँ')
                  : s.t('Save for later', 'बाद के लिए सहेजें'),
              color: saved ? AppColors.brand : null,
              onPressed: () => s.toggleVideoSaved(video.videoId),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick quiz panel — visual refresh with workspace_premium icon.
class _QuizPanel extends StatelessWidget {
  final AppStore store;
  final TrainingModule module;
  final bool unlocked;
  final bool allWatched;
  final bool passed;
  const _QuizPanel({
    required this.store,
    required this.module,
    required this.unlocked,
    required this.allWatched,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return AppCard(
      tone: passed ? AppCardTone.brand : AppCardTone.outlined,
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed
                    ? Icons.workspace_premium_outlined
                    : Icons.quiz_outlined,
                color: passed ? AppColors.brand : AppColors.ink,
                size: AppIconSize.md,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  passed
                      ? s.t('Quiz passed — module mastered', 'क्विज़ पास — मॉड्यूल पूर्ण')
                      : s.t('Quick quiz', 'छोटा क्विज़'),
                  style: AppText.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            passed
                ? s.t(
                    'You answered the questions correctly. You can retake the quiz anytime.',
                    'आपने सही उत्तर दिए। आप क्विज़ दोबारा दे सकते हैं।',
                  )
                : allWatched
                    ? s.t(
                        '3 questions. 2 correct is a pass. Pass to mark this module mastered.',
                        '3 प्रश्न। 2 सही उत्तर = पास। पास करके इस मॉड्यूल को पूर्ण चिह्नित करें।',
                      )
                    : unlocked
                        ? s.t(
                            '3 questions on what you watched. Finish all videos to fully master the module.',
                            '3 प्रश्न आपने जो देखा उसी पर। सभी वीडियो देखें तो पूरा मॉड्यूल पूर्ण होगा।',
                          )
                        : s.t(
                            'Watch at least one video to unlock the quiz.',
                            'क्विज़ के लिए कम से कम एक वीडियो देखें।',
                          ),
            style: AppText.bodySmall,
          ),
          const SizedBox(height: AppSpace.md),
          AppButton(
            label: passed
                ? s.t('Retake quiz', 'क्विज़ फिर से दें')
                : s.t('Start quiz', 'क्विज़ शुरू करें'),
            onPressed: unlocked
                ? () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.xl),
                        ),
                      ),
                      builder: (_) => QuizSheet(store: s, module: module),
                    )
                : null,
            variant: passed
                ? AppButtonVariant.secondary
                : AppButtonVariant.primary,
            expand: false,
            trailingIcon: Icons.arrow_forward,
          ),
        ],
      ),
    );
  }
}

class _UnknownModule extends StatelessWidget {
  final AppStore store;
  const _UnknownModule({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('Module Trainings', 'मॉड्यूल प्रशिक्षण')),
      ),
      body: SafeArea(
        child: StateView(
          kind: StateKind.empty,
          title: s.t('That module could not be found.', 'वह मॉड्यूल नहीं मिला।'),
          message: s.t(
            'Open the Trainings page to see the full list.',
            'पूरी सूची के लिए प्रशिक्षण पृष्ठ खोलें।',
          ),
          actionLabel: s.t('Back to Trainings', 'प्रशिक्षण पर लौटें'),
          onAction: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}
