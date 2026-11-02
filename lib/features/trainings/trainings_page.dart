import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../widgets.dart';
import '../youtube_video.dart';
import 'training_data.dart';
import 'training_nudge.dart';

/// Entry page for Module Trainings.
///
/// A single scroll that mirrors the Registration Guide's layout — a hero
/// `Heading`, a dismissible in-app nudge banner, overall progress, 6
/// module cards, a "My Saved" filter and the YouTube channel attribution.
class TrainingsPage extends StatelessWidget {
  final AppStore store;
  const TrainingsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final s = store;
      final watched = s.trainingWatched.toSet();
      final total = kTotalTrainingVideos;
      final saved = s.trainingSaved;
      final nudge = computeTrainingNudge(s);
      return Scaffold(
        appBar: AppBar(
          title: Text(s.t('Module Trainings', 'मॉड्यूल प्रशिक्षण')),
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
                    Heading(
                      s.t('Video lessons', 'वीडियो पाठ'),
                      s.t('Module Trainings', 'मॉड्यूल प्रशिक्षण'),
                      s.t(
                        '34 official GeM videos in 6 modules — browse at your own pace.',
                        '34 आधिकारिक GeM वीडियो, 6 मॉड्यूल में — अपनी गति से देखें।',
                      ),
                    ),
                    if (nudge != null) ...[
                      _NudgeBanner(store: s, nudge: nudge),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    _OverallProgress(
                      store: s,
                      watched: watched.length,
                      total: total,
                      streak: s.trainingStreakDays,
                    ),
                    const SizedBox(height: AppSpace.xxl),
                    if (saved.isNotEmpty) ...[
                      _SavedStrip(store: s, savedVideoIds: saved),
                      const SizedBox(height: AppSpace.xxl),
                    ],
                    SectionHeader(s.t('Choose a module', 'मॉड्यूल चुनें')),
                    for (final mod in kTrainingModules) ...[
                      _ModuleCard(
                        store: s,
                        module: mod,
                        watchedIds: watched,
                        quizPassed: s.trainingQuizPassed.contains(mod.id),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    _VideoLanguageNote(store: s),
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
    },
  );
}

/// Dismissible nudge banner (welcome / resume / streak / completion /
/// milestone). The computation lives in [computeTrainingNudge]; this
/// widget only renders.
class _NudgeBanner extends StatelessWidget {
  final AppStore store;
  final TrainingNudge nudge;
  const _NudgeBanner({required this.store, required this.nudge});

  @override
  Widget build(BuildContext context) {
    final s = store;
    const tone = AppCardTone.brand;
    final icon = switch (nudge.kind) {
      TrainingNudgeKind.welcome => Icons.waving_hand_outlined,
      TrainingNudgeKind.resume => Icons.play_circle_outline,
      TrainingNudgeKind.streak => Icons.local_fire_department_outlined,
      TrainingNudgeKind.completion => Icons.celebration_outlined,
      TrainingNudgeKind.milestone => Icons.emoji_events_outlined,
    };
    return AppCard(
      tone: tone,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppIconSize.md, color: AppColors.brand),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nudge.title, style: AppText.bodyStrong),
                const SizedBox(height: AppSpace.xs),
                Text(nudge.body, style: AppText.bodySmall),
                if (nudge.ctaLabel != null && nudge.ctaModuleId != null) ...[
                  const SizedBox(height: AppSpace.md),
                  AppButton(
                    label: nudge.ctaLabel!,
                    onPressed: () => _openModule(
                      context,
                      s,
                      nudge.ctaModuleId!,
                      from: 'nudge:${nudge.id}',
                    ),
                    size: AppButtonSize.sm,
                    expand: false,
                    trailingIcon: Icons.arrow_forward,
                  ),
                ],
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.close,
            tooltip: s.t('Dismiss', 'बंद करें'),
            onPressed: () => s.dismissTrainingNudge(nudge.id),
          ),
        ],
      ),
    );
  }
}

/// Overall progress ring + streak chip.
class _OverallProgress extends StatelessWidget {
  final AppStore store;
  final int watched;
  final int total;
  final int streak;
  const _OverallProgress({
    required this.store,
    required this.watched,
    required this.total,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final pct = total == 0 ? 0.0 : watched / total;
    return Panel(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Row(
        children: [
          AppProgressRing(
            value: pct,
            label: '$watched / $total',
            semanticLabel: s.t(
              '$watched of $total videos watched',
              '$total में से $watched वीडियो देखे',
            ),
          ),
          const SizedBox(width: AppSpace.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('Your training', 'आपका प्रशिक्षण'),
                  style: AppText.caption,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  s.t(
                    '$watched of $total videos watched',
                    '$total में से $watched वीडियो देखे',
                  ),
                  style: AppText.title,
                ),
                const SizedBox(height: AppSpace.sm),
                if (streak > 0)
                  StatusChip(
                    s.t(
                      '$streak-day streak',
                      '$streak-दिन streak',
                    ),
                    tone: StatusTone.success,
                    icon: Icons.local_fire_department_outlined,
                  )
                else
                  Text(
                    s.t(
                      'Watch one video to start a streak.',
                      'streak शुरू करने के लिए एक वीडियो देखें।',
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

/// A single module tile.
class _ModuleCard extends StatelessWidget {
  final AppStore store;
  final TrainingModule module;
  final Set<String> watchedIds;
  final bool quizPassed;
  const _ModuleCard({
    required this.store,
    required this.module,
    required this.watchedIds,
    required this.quizPassed,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final total = module.videos.length;
    final done = module.videos.where((v) => watchedIds.contains(v.videoId)).length;
    final allWatched = done == total;
    return AppCard(
      onTap: () => _openModule(context, s, module.id, from: 'module_card'),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              module.icon,
              color: AppColors.brand,
              size: AppIconSize.md,
            ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.t(module.titleEn, module.titleHi),
                        style: AppText.title,
                      ),
                    ),
                    if (allWatched) ...[
                      const SizedBox(width: AppSpace.sm),
                      StatusChip(
                        quizPassed
                            ? s.t('Mastered', 'पूरा दक्ष')
                            : s.t('Watched', 'देखा'),
                        tone: StatusTone.success,
                        icon: quizPassed
                            ? Icons.emoji_events_outlined
                            : Icons.check_circle_outline,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  s.t(module.subtitleEn, module.subtitleHi),
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                AppProgressBar(
                  value: total == 0 ? 0.0 : done / total,
                  semanticLabel: s.t(
                    '$done of $total videos watched',
                    '$total में से $done वीडियो देखे',
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  s.t(
                    '$done of $total videos · ~${module.totalMinutes} min',
                    '$total में से $done वीडियो · ~${module.totalMinutes} मिनट',
                  ),
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textHint,
            size: AppIconSize.md,
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of bookmarked videos; opens the owning module.
class _SavedStrip extends StatelessWidget {
  final AppStore store;
  final List<String> savedVideoIds;
  const _SavedStrip({required this.store, required this.savedVideoIds});

  @override
  Widget build(BuildContext context) {
    final s = store;
    // Resolve ids to concrete videos, dropping any that no longer exist.
    final rows = <(TrainingVideo, TrainingModule)>[];
    for (final id in savedVideoIds) {
      final v = findTrainingVideo(id);
      final m = v == null ? null : moduleForVideo(id);
      if (v != null && m != null) rows.add((v, m));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          s.t('My saved videos', 'मेरे सहेजे गए वीडियो'),
        ),
        for (final (v, m) in rows) ...[
          AppListTile(
            icon: Icons.bookmark_outlined,
            title: s.t(v.titleEn, v.titleHi),
            subtitle: s.t(
              '${s.t(m.titleEn, m.titleHi)} · ~${v.minutes} min',
              '${s.t(m.titleEn, m.titleHi)} · ~${v.minutes} मिनट',
            ),
            onTap: () => _openModule(context, s, m.id, from: 'saved_strip'),
          ),
          const SizedBox(height: AppSpace.xs),
        ],
      ],
    );
  }
}

/// Caveat about the video language (playlist is English-only).
class _VideoLanguageNote extends StatelessWidget {
  final AppStore store;
  const _VideoLanguageNote({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline,
          size: AppIconSize.sm,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(
          child: Text(
            s.t(
              'The official videos are in English. Each module here carries a short Hindi description so you know what each one covers.',
              'आधिकारिक वीडियो अंग्रेज़ी में हैं। हर मॉड्यूल के साथ हिंदी में संक्षिप्त विवरण दिया गया है।',
            ),
            style: AppText.caption,
          ),
        ),
      ],
    );
  }
}

/// Push the module detail page and fire the standard `cta_clicked` event.
void _openModule(
  BuildContext context,
  AppStore store,
  String moduleId, {
  required String from,
}) {
  store.event(
    'cta_clicked',
    page: 'trainings',
    props: {'destination': 'training-module', 'moduleId': moduleId, 'from': from},
  );
  Navigator.of(context).pushNamed('/training-module', arguments: moduleId);
}

/// Clipboard write for the Share action (invoked from the detail page).
Future<void> copyDeepLink(
  BuildContext context,
  AppStore store,
  String moduleId,
) async {
  const base = 'https://bid2scale.app';
  await Clipboard.setData(
    ClipboardData(text: '$base/training-module?id=$moduleId'),
  );
  if (context.mounted) {
    message(
      context,
      store.t(
        'Link copied — share it with a friend.',
        'लिंक कॉपी हो गया — किसी से साझा करें।',
      ),
    );
  }
  store.event('cta_clicked', page: 'training-module', props: {
    'destination': 'copy_link',
    'moduleId': moduleId,
  });
}
