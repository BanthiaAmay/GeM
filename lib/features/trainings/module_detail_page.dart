import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../widgets.dart';
import '../youtube_video.dart';
import 'quiz_sheet.dart';
import 'training_data.dart';
import 'trainings_page.dart' show copyDeepLink;

/// Deep view of one training module — a scrollable list of videos, each
/// with a thumbnail (tap to play in-app), a "Mark as watched" tick and a
/// bookmark toggle. A "Quick quiz" panel is always visible at the end; the
/// Start Quiz button is enabled once at least one video has been watched.
/// Passing the quiz marks the module as "mastered".
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
                  _Header(store: s, module: module, done: done, total: total),
                  const SizedBox(height: AppSpace.xxl),
                  SectionHeader(s.t('Videos', 'वीडियो')),
                  for (final v in module.videos) ...[
                    _VideoRow(
                      store: s,
                      module: module,
                      video: v,
                      watched: watched.contains(v.videoId),
                      saved: saved.contains(v.videoId),
                      isLastWatched: s.trainingLastVideoId == v.videoId,
                    ),
                    const SizedBox(height: AppSpace.md),
                  ],
                  const SizedBox(height: AppSpace.lg),
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

class _Header extends StatelessWidget {
  final AppStore store;
  final TrainingModule module;
  final int done;
  final int total;
  const _Header({
    required this.store,
    required this.module,
    required this.done,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Panel(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppProgressRing(
            value: total == 0 ? 0 : done / total,
            label: '$done / $total',
            semanticLabel: s.t(
              '$done of $total videos watched',
              '$total में से $done वीडियो देखे',
            ),
          ),
          const SizedBox(width: AppSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(module.subtitleEn, module.subtitleHi),
                  style: AppText.body,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  s.t(
                    '$total videos · ~${module.totalMinutes} min',
                    '$total वीडियो · ~${module.totalMinutes} मिनट',
                  ),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoRow extends StatelessWidget {
  final AppStore store;
  final TrainingModule module;
  final TrainingVideo video;
  final bool watched;
  final bool saved;
  final bool isLastWatched;
  const _VideoRow({
    required this.store,
    required this.module,
    required this.video,
    required this.watched,
    required this.saved,
    required this.isLastWatched,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YouTubeVideoCard(videoId: video.videoId, store: s),
          const SizedBox(height: AppSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t(video.titleEn, video.titleHi), style: AppText.bodyStrong),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      s.t(
                        '~${video.minutes} min',
                        '~${video.minutes} मिनट',
                      ),
                      style: AppText.caption,
                    ),
                    if (isLastWatched) ...[
                      const SizedBox(height: AppSpace.xs),
                      StatusChip(
                        s.t('Last watched', 'अंतिम बार देखा'),
                        tone: StatusTone.info,
                        icon: Icons.history,
                      ),
                    ],
                  ],
                ),
              ),
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
          const SizedBox(height: AppSpace.sm),
          // Mark-as-watched row — a 48pt tap target by Material's own
          // CheckboxListTile defaults.
          Theme(
            // The checkbox inherits the ink colour from the app theme.
            // No raw colour overrides here.
            data: Theme.of(context),
            child: InkWell(
              onTap: () => watched
                  ? s.unmarkVideoWatched(video.videoId)
                  : s.markVideoWatched(video.videoId),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSize.tap),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.sm,
                    vertical: AppSpace.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        watched
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: watched
                            ? AppColors.brand
                            : AppColors.textHint,
                        size: AppIconSize.md,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        watched
                            ? s.t('Watched', 'देखा')
                            : s.t('Mark as watched', 'देखा के रूप में चिह्नित करें'),
                        style: AppText.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: watched ? AppColors.brand : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Panel(
      tone: passed ? AppCardTone.brand : AppCardTone.outlined,
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.emoji_events : Icons.quiz_outlined,
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
                            '3 questions on what you watched. Finish all videos for the full set to count.',
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
          title: s.t('That module could not be found.',
              'वह मॉड्यूल नहीं मिला।'),
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
