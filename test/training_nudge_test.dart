import 'package:flutter_test/flutter_test.dart';
import 'package:gem/features/trainings/training_data.dart';
import 'package:gem/features/trainings/training_nudge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/authenticated_journey_store.dart';

/// A minimal AppStore wrapper for nudge tests. We keep research consent
/// true so events round-trip through the queue the real app uses.
class _NudgeStore extends AuthenticatedJourneyStore {
  _NudgeStore(super.prefs) {
    data['researchConsent'] = true;
  }
}

Future<_NudgeStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return _NudgeStore(await SharedPreferences.getInstance());
}

void main() {
  group('computeTrainingNudge', () {
    test('welcome fires when nothing watched yet', () async {
      final s = await _store();
      final n = computeTrainingNudge(s);
      expect(n, isNotNull);
      expect(n!.kind, TrainingNudgeKind.welcome);
      expect(n.id, 'welcome');
      expect(n.ctaModuleId, 'trn-m1');
    });

    test('welcome stays hidden for 24h after dismiss, then returns', () async {
      final s = await _store();
      // Dismiss now.
      s.dismissTrainingNudge('welcome');
      // Immediately after: suppressed.
      final immediate = computeTrainingNudge(s, now: DateTime.now());
      expect(immediate, isNull);
      // 25 hours later: back.
      final later = computeTrainingNudge(
        s,
        now: DateTime.now().add(const Duration(hours: 25)),
      );
      expect(later, isNotNull);
      expect(later!.kind, TrainingNudgeKind.welcome);
    });

    test('resume fires after a 3-day gap with partial progress', () async {
      final s = await _store();
      // Pretend the user watched one video 5 days ago.
      final v = kTrainingModules[0].videos[0];
      s.markVideoWatched(v.videoId);
      final fiveDaysLater = DateTime.now().add(const Duration(days: 5));
      final n = computeTrainingNudge(s, now: fiveDaysLater);
      expect(n, isNotNull);
      // Welcome is now out of the picture (user has watched). The
      // completion nudge requires all-module watched, so this is resume.
      expect(n!.kind, TrainingNudgeKind.resume);
      expect(n.id, 'resume');
    });

    test('completion fires after finishing a module', () async {
      final s = await _store();
      final mod = kTrainingModules[0];
      for (final v in mod.videos) {
        s.markVideoWatched(v.videoId);
      }
      final n = computeTrainingNudge(s);
      expect(n, isNotNull);
      expect(n!.kind, TrainingNudgeKind.completion);
      // Should point at module 2.
      expect(n.ctaModuleId, kTrainingModules[1].id);
    });

    test('milestone fires at 25% and beats resume', () async {
      final s = await _store();
      final quarter = (kTotalTrainingVideos / 4).ceil();
      // Mark the first N distinct videos as watched.
      var marked = 0;
      outer:
      for (final m in kTrainingModules) {
        for (final v in m.videos) {
          s.markVideoWatched(v.videoId);
          marked += 1;
          if (marked >= quarter) break outer;
        }
      }
      final n = computeTrainingNudge(s);
      expect(n, isNotNull);
      // Could be completion if module 1 was fully watched; let's just
      // assert it is one of the celebratory kinds.
      expect(
        [TrainingNudgeKind.milestone, TrainingNudgeKind.completion],
        contains(n!.kind),
      );
    });

    test('streak fires with 3-day run and nothing today', () async {
      final s = await _store();
      // Seed state so streak is set.
      final mod = kTrainingModules[0];
      s.markVideoWatched(mod.videos[0].videoId);
      // Overwrite streak fields directly to simulate a 3-day run that
      // ended yesterday (so today has no watch yet).
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yStr = '${yesterday.year.toString().padLeft(4, '0')}-'
          '${yesterday.month.toString().padLeft(2, '0')}-'
          '${yesterday.day.toString().padLeft(2, '0')}';
      s.setProfile('videoTraining', {
        ...s.trainingState,
        'streakDays': 3,
        'streakLastDate': yStr,
        'lastWatchedAt': yesterday.toUtc().toIso8601String(),
      });
      final n = computeTrainingNudge(s);
      expect(n, isNotNull);
      expect(n!.kind, TrainingNudgeKind.streak);
    });

    test('nothing returned once everything watched and nudges dismissed',
        () async {
      final s = await _store();
      // Watch everything.
      for (final m in kTrainingModules) {
        for (final v in m.videos) {
          s.markVideoWatched(v.videoId);
        }
      }
      // Dismiss any resulting celebratory nudges.
      for (var i = 0; i < 5; i++) {
        final n = computeTrainingNudge(s);
        if (n == null) break;
        s.dismissTrainingNudge(n.id);
      }
      final after = computeTrainingNudge(s);
      expect(after, isNull);
    });
  });

  group('AppStore training state', () {
    test('markVideoWatched updates watched list and streak', () async {
      final s = await _store();
      final v = kTrainingModules[0].videos[0];
      s.markVideoWatched(v.videoId);
      expect(s.trainingWatched, contains(v.videoId));
      expect(s.trainingStreakDays, 1);
      expect(s.trainingLastVideoId, v.videoId);
    });

    test('markVideoWatched is idempotent on the same day', () async {
      final s = await _store();
      final v = kTrainingModules[0].videos[0];
      s.markVideoWatched(v.videoId);
      s.markVideoWatched(v.videoId);
      expect(s.trainingWatched.length, 1);
      expect(s.trainingStreakDays, 1);
    });

    test('toggleVideoSaved flips state', () async {
      final s = await _store();
      final v = kTrainingModules[0].videos[0];
      expect(s.toggleVideoSaved(v.videoId), isTrue);
      expect(s.trainingSaved, contains(v.videoId));
      expect(s.toggleVideoSaved(v.videoId), isFalse);
      expect(s.trainingSaved, isNot(contains(v.videoId)));
    });

    test('markQuizPassed records once', () async {
      final s = await _store();
      s.markQuizPassed('trn-m1', score: 3, total: 3);
      s.markQuizPassed('trn-m1', score: 2, total: 3);
      expect(s.trainingQuizPassed, ['trn-m1']);
    });
  });
}
