import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import '../widgets.dart';
import '../youtube_video.dart';
import 'training_data.dart';
import 'training_nudge.dart';

/// Entry page for Module Trainings — a "Learning hub" layout:
/// an optional resume hero, slim stat chips, and a 2-column module grid.
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
                    if (nudge != null) ...[
                      _NudgeBanner(store: s, nudge: nudge),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    // Slim 2-line header — tighter than the old Heading widget.
                    Text(
                      s.t('VIDEO LESSONS', 'वीडियो पाठ').toUpperCase(),
                      style: AppText.overline.copyWith(color: AppColors.brand),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      s.t('Module Trainings', 'मॉड्यूल प्रशिक्षण'),
                      style: AppText.h2,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    _ContinueHero(store: s, watchedIds: watched),
                    _ProgressStrip(
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
                    SectionHeader(s.t('Modules', 'मॉड्यूल')),
                    _ModuleGrid(store: s, watchedIds: watched),
                    const SizedBox(height: AppSpace.xxl),
                    ReassuranceNote(
                      s.t(
                        'Videos are in English. Each module carries a short Hindi description so you know what it covers.',
                        'वीडियो अंग्रेज़ी में हैं। हर मॉड्यूल के साथ हिंदी विवरण दिया गया है।',
                      ),
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
    },
  );
}

/// Dismissible nudge banner — kept identical to the original.
class _NudgeBanner extends StatelessWidget {
  final AppStore store;
  final TrainingNudge nudge;
  const _NudgeBanner({required this.store, required this.nudge});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final icon = switch (nudge.kind) {
      TrainingNudgeKind.welcome => Icons.waving_hand_outlined,
      TrainingNudgeKind.resume => Icons.play_circle_outline,
      TrainingNudgeKind.streak => Icons.local_fire_department_outlined,
      TrainingNudgeKind.completion => Icons.celebration_outlined,
      TrainingNudgeKind.milestone => Icons.emoji_events_outlined,
    };
    return AppCard(
      tone: AppCardTone.brand,
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

/// Hero card shown when the user has watched at least one video.
/// Surfaces the last watched video with a Play CTA.
class _ContinueHero extends StatelessWidget {
  final AppStore store;
  final Set<String> watchedIds;
  const _ContinueHero({required this.store, required this.watchedIds});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final lastId = s.trainingLastVideoId;
    // Show only when there is a last video and not all 34 are done.
    if (lastId == null || watchedIds.length >= kTotalTrainingVideos) {
      return const SizedBox.shrink();
    }
    final video = findTrainingVideo(lastId);
    final mod = moduleForVideo(lastId);
    if (video == null || mod == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: FadeSlideIn(
        child: Panel(
          tone: AppCardTone.brand,
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('RESUME', 'जारी रखें').toUpperCase(),
                      style: AppText.overline.copyWith(color: AppColors.brand),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      s.t(video.titleEn, video.titleHi),
                      style: AppText.bodyStrong,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      s.t(mod.titleEn, mod.titleHi),
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              AppButton(
                label: s.t('Play', 'चलाएं'),
                icon: Icons.play_arrow_outlined,
                onPressed: () {
                  s.event('cta_clicked', page: 'trainings', props: {
                    'destination': 'resume_video',
                    'videoId': lastId,
                  });
                  _openModule(context, s, mod.id, from: 'continue_hero');
                },
                size: AppButtonSize.sm,
                expand: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three horizontal stat chips: watched count, % done, streak.
class _ProgressStrip extends StatelessWidget {
  final AppStore store;
  final int watched;
  final int total;
  final int streak;
  const _ProgressStrip({
    required this.store,
    required this.watched,
    required this.total,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final pct = total == 0 ? 0 : (watched / total * 100).floor();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            icon: Icons.ondemand_video_outlined,
            label: s.t('$watched watched', '$watched देखे'),
          ),
          if (watched > 0) ...[
            const SizedBox(width: AppSpace.sm),
            _Chip(
              icon: Icons.bar_chart_outlined,
              label: s.t('$pct% done', '$pct% पूर्ण'),
            ),
          ],
          if (streak > 0) ...[
            const SizedBox(width: AppSpace.sm),
            _Chip(
              icon: Icons.local_fire_department_outlined,
              label: s.t('$streak-day streak', '$streak-दिन streak'),
              iconColor: AppColors.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  const _Chip({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor ?? AppColors.textSecondary),
        const SizedBox(width: AppSpace.xs),
        Text(label, style: AppText.label),
      ],
    ),
  );
}

/// 2-column grid of module cards.
class _ModuleGrid extends StatelessWidget {
  final AppStore store;
  final Set<String> watchedIds;
  const _ModuleGrid({required this.store, required this.watchedIds});

  // Accent colors per module slot — uses design system tints only.
  static const _tints = [
    AppColors.brandTint,
    AppColors.infoTint,
    AppColors.warningTint,
    AppColors.brandTint,
    AppColors.infoTint,
    AppColors.dangerTint,
  ];

  @override
  Widget build(BuildContext context) {
    final s = store;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpace.md,
        mainAxisSpacing: AppSpace.md,
        childAspectRatio: 0.88,
      ),
      itemCount: kTrainingModules.length,
      itemBuilder: (context, i) {
        final mod = kTrainingModules[i];
        final total = mod.videos.length;
        final done = mod.videos
            .where((v) => watchedIds.contains(v.videoId))
            .length;
        final allWatched = done == total;
        final quizPassed = s.trainingQuizPassed.contains(mod.id);
        final tint = _tints[i % _tints.length];
        return _ModuleGridCard(
          store: s,
          module: mod,
          index: i + 1,
          done: done,
          total: total,
          allWatched: allWatched,
          quizPassed: quizPassed,
          tint: tint,
        );
      },
    );
  }
}

class _ModuleGridCard extends StatelessWidget {
  final AppStore store;
  final TrainingModule module;
  final int index;
  final int done;
  final int total;
  final bool allWatched;
  final bool quizPassed;
  final Color tint;
  const _ModuleGridCard({
    required this.store,
    required this.module,
    required this.index,
    required this.done,
    required this.total,
    required this.allWatched,
    required this.quizPassed,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final numLabel = index.toString().padLeft(2, '0');
    return AppCard(
      onTap: () => _openModule(context, s, module.id, from: 'module_grid'),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(module.icon, color: AppColors.brand, size: 20),
              ),
              const Spacer(),
              if (quizPassed)
                const Icon(Icons.verified_outlined, size: 18, color: AppColors.brand)
              else if (allWatched)
                const Icon(Icons.check_circle_outline, size: 18, color: AppColors.brand)
              else if (done > 0)
                Text('$done/$total', style: AppText.tick),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(numLabel, style: AppText.overline),
          const SizedBox(height: AppSpace.xs),
          Text(
            s.t(module.titleEn, module.titleHi),
            style: AppText.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpace.xs),
          Text('$total videos', style: AppText.caption),
          const Spacer(),
          AppProgressBar(value: total == 0 ? 0.0 : done / total, height: 4),
          const SizedBox(height: AppSpace.xs),
          Text(
            s.t('$done of $total', '$total में से $done'),
            style: AppText.tick,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of bookmarked videos.
class _SavedStrip extends StatelessWidget {
  final AppStore store;
  final List<String> savedVideoIds;
  const _SavedStrip({required this.store, required this.savedVideoIds});

  @override
  Widget build(BuildContext context) {
    final s = store;
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
        SectionHeader(s.t('My saved videos', 'मेरे सहेजे गए वीडियो')),
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

/// Push the module detail page.
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
