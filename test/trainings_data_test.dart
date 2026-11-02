import 'package:flutter_test/flutter_test.dart';
import 'package:gem/features/trainings/training_data.dart';

/// Catalogue-level invariants: every video is addressable (11-char YouTube
/// id), modules carry at least one video and the catalogue is unique. These
/// are compile-time constants, so the test is quick and runs headless.
void main() {
  group('kTrainingModules invariants', () {
    test('has six modules', () {
      expect(kTrainingModules.length, 6);
    });

    test('every module has a stable id and at least one video', () {
      final ids = <String>{};
      for (final m in kTrainingModules) {
        expect(m.id, isNotEmpty, reason: '${m.titleEn}: id is empty');
        expect(
          ids.add(m.id),
          isTrue,
          reason: '${m.id}: duplicate module id',
        );
        expect(m.videos, isNotEmpty, reason: '${m.id}: no videos');
      }
    });

    test('every video id is 11 chars (YouTube id length)', () {
      final idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
      for (final m in kTrainingModules) {
        for (final v in m.videos) {
          expect(
            idPattern.hasMatch(v.videoId),
            isTrue,
            reason: 'bad videoId ${v.videoId} in ${m.id}',
          );
        }
      }
    });

    test('no video id appears in more than one module', () {
      final seen = <String, String>{};
      for (final m in kTrainingModules) {
        for (final v in m.videos) {
          final prev = seen[v.videoId];
          expect(
            prev,
            isNull,
            reason: '${v.videoId} is in ${prev ?? ''} and ${m.id}',
          );
          seen[v.videoId] = m.id;
        }
      }
    });

    test('kTotalTrainingVideos matches the summed video count', () {
      final sum = kTrainingModules.fold<int>(
        0,
        (s, m) => s + m.videos.length,
      );
      expect(kTotalTrainingVideos, sum);
      expect(kTotalTrainingVideos, 34);
    });

    test('every module has a 3-question quiz with a valid correct index', () {
      for (final m in kTrainingModules) {
        expect(m.quiz.length, 3, reason: '${m.id}: quiz is not 3 questions');
        for (var i = 0; i < m.quiz.length; i++) {
          final q = m.quiz[i];
          expect(q.optionsEn.length, 3, reason: '${m.id} q${i + 1}: options');
          expect(q.optionsHi.length, 3, reason: '${m.id} q${i + 1}: options');
          expect(
            q.correctIndex >= 0 && q.correctIndex < q.optionsEn.length,
            isTrue,
            reason: '${m.id} q${i + 1}: bad correctIndex',
          );
        }
      }
    });

    test('bilingual strings are populated for every module and video', () {
      for (final m in kTrainingModules) {
        expect(m.titleEn, isNotEmpty);
        expect(m.titleHi, isNotEmpty);
        expect(m.subtitleEn, isNotEmpty);
        expect(m.subtitleHi, isNotEmpty);
        for (final v in m.videos) {
          expect(v.titleEn, isNotEmpty);
          expect(v.titleHi, isNotEmpty);
          expect(v.minutes, greaterThan(0));
        }
      }
    });
  });

  group('lookups', () {
    test('findTrainingModule returns the right module', () {
      expect(findTrainingModule('trn-m1')?.id, 'trn-m1');
      expect(findTrainingModule('unknown'), isNull);
    });

    test('moduleForVideo locates the owner', () {
      final v = kTrainingModules.first.videos.first;
      final owner = moduleForVideo(v.videoId);
      expect(owner, isNotNull);
      expect(owner!.id, kTrainingModules.first.id);
      expect(moduleForVideo('nonexistent'), isNull);
    });

    test('findTrainingVideo round-trips every id', () {
      for (final m in kTrainingModules) {
        for (final v in m.videos) {
          expect(findTrainingVideo(v.videoId), isNotNull);
        }
      }
      expect(findTrainingVideo('nonexistent'), isNull);
    });
  });
}
