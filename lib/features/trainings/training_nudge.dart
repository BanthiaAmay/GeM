import 'package:flutter/foundation.dart' show immutable;
import '../../data/app_store.dart';
import 'training_data.dart';

/// Which nudge to show, if any. Kinds are ordered by priority: the first
/// one whose condition holds is the one surfaced. Each kind carries its
/// own copy and (optional) cta.
enum TrainingNudgeKind { welcome, resume, streak, completion, milestone }

/// A computed, localised nudge ready to render in `_NudgeBanner`.
@immutable
class TrainingNudge {
  /// Stable id used for 24h dismiss tracking in
  /// `AppStore.trainingState['dismissedNudges']`.
  final String id;
  final TrainingNudgeKind kind;
  final String title;
  final String body;

  /// Optional CTA label and the moduleId it opens. When null, the banner
  /// shows no CTA — just the text and a dismiss button.
  final String? ctaLabel;
  final String? ctaModuleId;

  const TrainingNudge({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.ctaModuleId,
  });
}

/// How long a dismissed nudge stays hidden before it may show again.
const Duration kNudgeDismissWindow = Duration(hours: 24);

/// Compute the single highest-priority nudge for the current state, or
/// null if nothing to show. Pure — no side effects, no analytics; the
/// banner widget fires its own `page_view` / `nudge_shown` events if it
/// wants to.
///
/// The caller passes in [now] in tests; production uses the default.
TrainingNudge? computeTrainingNudge(AppStore s, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final state = s.trainingState;
  final watched = List<String>.from(state['watched'] as List? ?? const []);
  final total = kTotalTrainingVideos;

  bool stillSuppressed(String id) {
    final at = s.trainingNudgeDismissedAt(id);
    if (at == null) return false;
    if (at.isAfter(clock)) return false; // clock rolled back; treat as not dismissed
    return clock.difference(at) < kNudgeDismissWindow;
  }

  // ── welcome: user hasn't watched anything yet ───────────────────────
  if (watched.isEmpty && !stillSuppressed('welcome')) {
    final m1 = kTrainingModules.first;
    return TrainingNudge(
      id: 'welcome',
      kind: TrainingNudgeKind.welcome,
      title: s.t('New here?', 'पहली बार?'),
      body: s.t(
        'Start with Module 1 — ${m1.videos.length} short videos, about ${m1.totalMinutes} min total.',
        'मॉड्यूल 1 से शुरू करें — ${m1.videos.length} छोटे वीडियो, लगभग ${m1.totalMinutes} मिनट।',
      ),
      ctaLabel: s.t('Start Module 1', 'मॉड्यूल 1 शुरू करें'),
      ctaModuleId: m1.id,
    );
  }

  // ── milestone: just crossed a quartile ──────────────────────────────
  // Shown before resume so a 50% milestone message beats a "pick up"
  // message right after the user completed half the catalogue.
  if (watched.isNotEmpty && total > 0) {
    final pct = (watched.length / total * 100).floor();
    String? band;
    if (pct >= 100) {
      band = 'all';
    } else if (pct >= 75) {
      band = '75';
    } else if (pct >= 50) {
      band = '50';
    } else if (pct >= 25) {
      band = '25';
    }
    if (band != null && !stillSuppressed('milestone-$band')) {
      // Only show when the user crossed this band recently (last 2 days),
      // so we don't nag someone who has sat at 50% for weeks.
      final lastWatchedAt = DateTime.tryParse(
        state['lastWatchedAt'] as String? ?? '',
      );
      if (lastWatchedAt != null &&
          clock.difference(lastWatchedAt).inHours <= 48) {
        final title = band == 'all'
            ? s.t('All 34 videos — done.', 'सभी 34 वीडियो — पूरे।')
            : s.t('Milestone unlocked', 'मील का पत्थर');
        final body = band == 'all'
            ? s.t(
                'You finished every module. Your streak is ${s.trainingStreakDays} days.',
                'आपने सभी मॉड्यूल पूरे किए। आपकी streak ${s.trainingStreakDays} दिन है।',
              )
            : s.t(
                '$band% of the catalogue — ${watched.length} of $total videos watched.',
                '$band% पूरा — $total में से ${watched.length} वीडियो देखे।',
              );
        return TrainingNudge(
          id: 'milestone-$band',
          kind: TrainingNudgeKind.milestone,
          title: title,
          body: body,
          // Milestones have no CTA — they're celebratory, not action-y.
        );
      }
    }
  }

  // ── completion: last watched video completed a module ───────────────
  final lastVideoId = state['lastVideoId'] as String?;
  if (lastVideoId != null) {
    final mod = moduleForVideo(lastVideoId);
    if (mod != null) {
      final allWatched = mod.videos.every(
        (v) => watched.contains(v.videoId),
      );
      final completionId = 'completion-${mod.id}';
      if (allWatched && !stillSuppressed(completionId)) {
        // Only within 2 days of the finishing watch, same reason as above.
        final lastWatchedAt = DateTime.tryParse(
          state['lastWatchedAt'] as String? ?? '',
        );
        if (lastWatchedAt != null &&
            clock.difference(lastWatchedAt).inHours <= 48) {
          // Point to the next module, if there is one.
          final nextIdx = kTrainingModules.indexOf(mod) + 1;
          final next = nextIdx < kTrainingModules.length
              ? kTrainingModules[nextIdx]
              : null;
          return TrainingNudge(
            id: completionId,
            kind: TrainingNudgeKind.completion,
            title: s.t(
              'Module complete!',
              'मॉड्यूल पूरा!',
            ),
            body: s.t(
              'You finished ${s.t(mod.titleEn, mod.titleHi)}. '
                  '${next == null ? 'That\'s the full set — well done.' : 'Jump to the next one?'}',
              'आपने ${s.t(mod.titleEn, mod.titleHi)} पूरा किया। '
                  '${next == null ? 'यह अंतिम था — बहुत बढ़िया!' : 'अगला मॉड्यूल शुरू करें?'}',
            ),
            ctaLabel: next == null
                ? null
                : s.t(
                    'Open ${s.t(next.titleEn, next.titleHi)}',
                    '${s.t(next.titleEn, next.titleHi)} खोलें',
                  ),
            ctaModuleId: next?.id,
          );
        }
      }
    }
  }

  // ── resume: 3+ days since the last video, with some progress ────────
  final lastWatchedAt = DateTime.tryParse(
    state['lastWatchedAt'] as String? ?? '',
  );
  if (lastWatchedAt != null &&
      watched.isNotEmpty &&
      watched.length < total &&
      clock.difference(lastWatchedAt).inDays >= 3 &&
      !stillSuppressed('resume')) {
    final v = lastVideoId == null ? null : findTrainingVideo(lastVideoId);
    final mod = lastVideoId == null ? null : moduleForVideo(lastVideoId);
    return TrainingNudge(
      id: 'resume',
      kind: TrainingNudgeKind.resume,
      title: s.t('Pick up where you left off', 'फिर से शुरू करें'),
      body: v == null
          ? s.t(
              'You have ${total - watched.length} videos left in your training.',
              'अभी $total में से ${total - watched.length} वीडियो बाकी हैं।',
            )
          : s.t(
              'Last watched: ${v.titleEn}',
              'अंतिम बार देखा: ${s.t(v.titleEn, v.titleHi)}',
            ),
      ctaLabel: mod == null
          ? null
          : s.t('Open ${s.t(mod.titleEn, mod.titleHi)}',
              '${s.t(mod.titleEn, mod.titleHi)} खोलें'),
      ctaModuleId: mod?.id,
    );
  }

  // ── streak: 3+ day run and nothing watched today ────────────────────
  final streakDays = (state['streakDays'] as int?) ?? 0;
  final streakLast = state['streakLastDate'] as String?;
  if (streakDays >= 3 && streakLast != null && !stillSuppressed('streak')) {
    final today = _todayLocalIsoDate(clock);
    if (streakLast != today) {
      return TrainingNudge(
        id: 'streak',
        kind: TrainingNudgeKind.streak,
        title: s.t(
          '$streakDays-day streak — keep it going.',
          '$streakDays-दिन की streak — जारी रखें।',
        ),
        body: s.t(
          'Watch one video today to keep your streak alive.',
          'streak बनाए रखने के लिए आज एक वीडियो देखें।',
        ),
      );
    }
  }

  return null;
}

String _todayLocalIsoDate(DateTime clock) =>
    '${clock.year.toString().padLeft(4, '0')}-'
    '${clock.month.toString().padLeft(2, '0')}-'
    '${clock.day.toString().padLeft(2, '0')}';
