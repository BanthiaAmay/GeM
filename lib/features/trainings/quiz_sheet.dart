import 'package:flutter/material.dart';

import '../../core/tokens.dart';
import '../../data/app_store.dart';
import '../components.dart';
import 'training_data.dart';

/// A simple 3-question multiple-choice quiz. Shown as a modal bottom sheet
/// after a user has watched at least one video in a module.
///
/// Interaction: one question at a time → pick an option → see immediate
/// right/wrong feedback → tap Next. On the final question, the sheet
/// shows a results panel with pass (≥ 2/3) or try-again. A pass fires
/// [AppStore.markQuizPassed] and the module card updates on return.
class QuizSheet extends StatefulWidget {
  final AppStore store;
  final TrainingModule module;
  const QuizSheet({super.key, required this.store, required this.module});

  @override
  State<QuizSheet> createState() => _QuizSheetState();
}

class _QuizSheetState extends State<QuizSheet> {
  /// Index of the current question (0-based). When equal to the question
  /// count, the results screen is shown.
  int _step = 0;

  /// The option the user has tapped on the current question, or null if
  /// they haven't tapped yet.
  int? _picked;

  /// 0/1 per question — captured when the user hits Next.
  final List<int> _results = [];

  int get _total => widget.module.quiz.length;
  int get _score => _results.fold(0, (sum, r) => sum + r);
  bool get _showingResults => _step >= _total;
  bool get _passed => _score >= 2;

  void _next() {
    final q = widget.module.quiz[_step];
    final correct = _picked == q.correctIndex ? 1 : 0;
    setState(() {
      _results.add(correct);
      _picked = null;
      _step += 1;
    });
    if (_step >= _total && _passed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.store.markQuizPassed(
          widget.module.id,
          score: _score,
          total: _total,
        );
      });
    }
  }

  void _retake() {
    setState(() {
      _step = 0;
      _picked = null;
      _results.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.gutter,
          right: AppSpace.gutter,
          top: 0,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpace.lg,
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
                const SizedBox(height: AppSpace.md),
                Text(
                  s.t(widget.module.titleEn, widget.module.titleHi),
                  style: AppText.caption,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  _showingResults
                      ? s.t('Your result', 'आपका परिणाम')
                      : s.t(
                          'Question ${_step + 1} of $_total',
                          '$_total में से प्रश्न ${_step + 1}',
                        ),
                  style: AppText.h3,
                ),
                const SizedBox(height: AppSpace.md),
                if (!_showingResults) ...[
                  AppProgressBar(
                    value: _step / _total,
                    semanticLabel: s.t(
                      '$_step of $_total questions answered',
                      '$_total में से $_step उत्तर दिए',
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  _QuestionBody(
                    store: s,
                    question: widget.module.quiz[_step],
                    picked: _picked,
                    onPick: (idx) => setState(() => _picked = idx),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    children: [
                      AppButton(
                        label: s.t('Cancel', 'रद्द करें'),
                        onPressed: () => Navigator.of(context).pop(),
                        variant: AppButtonVariant.tertiary,
                        expand: false,
                      ),
                      const Spacer(),
                      AppButton(
                        label: _step == _total - 1
                            ? s.t('Finish', 'पूर्ण')
                            : s.t('Next', 'अगला'),
                        onPressed: _picked == null ? null : _next,
                        expand: false,
                        trailingIcon: Icons.arrow_forward,
                      ),
                    ],
                  ),
                ] else ...[
                  _ResultBody(
                    store: s,
                    score: _score,
                    total: _total,
                    passed: _passed,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  Row(
                    children: [
                      AppButton(
                        label: _passed
                            ? s.t('Done', 'पूर्ण')
                            : s.t('Try again', 'फिर से कोशिश'),
                        onPressed: _passed
                            ? () => Navigator.of(context).pop()
                            : _retake,
                        expand: false,
                        trailingIcon: _passed ? null : Icons.refresh,
                      ),
                      const SizedBox(width: AppSpace.md),
                      if (!_passed)
                        AppButton(
                          label: s.t('Close', 'बंद करें'),
                          onPressed: () => Navigator.of(context).pop(),
                          variant: AppButtonVariant.tertiary,
                          expand: false,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionBody extends StatelessWidget {
  final AppStore store;
  final TrainingQuizQuestion question;
  final int? picked;
  final ValueChanged<int> onPick;
  const _QuestionBody({
    required this.store,
    required this.question,
    required this.picked,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    final options = s.language == 'hi' ? question.optionsHi : question.optionsEn;
    final prompt = s.t(question.promptEn, question.promptHi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: AppText.title),
        const SizedBox(height: AppSpace.md),
        for (var i = 0; i < options.length; i++) ...[
          _OptionRow(
            label: options[i],
            isPicked: picked == i,
            isCorrect: picked == null ? null : i == question.correctIndex,
            isTheirPick: picked == i,
            onTap: picked == null ? () => onPick(i) : null,
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        if (picked != null) ...[
          const SizedBox(height: AppSpace.xs),
          Text(
            picked == question.correctIndex
                ? s.t('Correct.', 'सही।')
                : s.t(
                    'Not quite — the right answer is highlighted.',
                    'सही नहीं — सही उत्तर चिह्नित है।',
                  ),
            style: AppText.bodySmall.copyWith(
              color: picked == question.correctIndex
                  ? AppColors.brand
                  : AppColors.danger,
            ),
          ),
        ],
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final bool isPicked;

  /// Once the user has committed a pick (null until then):
  /// - true  → this row is the correct one
  /// - false → this row is not the correct one
  final bool? isCorrect;
  final bool isTheirPick;
  final VoidCallback? onTap;
  const _OptionRow({
    required this.label,
    required this.isPicked,
    required this.isCorrect,
    required this.isTheirPick,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final committed = isCorrect != null;
    final showCorrect = committed && isCorrect == true;
    final showWrong = committed && isTheirPick && isCorrect == false;
    final tone = showCorrect
        ? AppCardTone.brand
        : showWrong
            ? AppCardTone.muted
            : AppCardTone.outlined;
    return AppCard(
      tone: tone,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            showCorrect
                ? Icons.check_circle
                : showWrong
                    ? Icons.cancel
                    : isPicked
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
            color: showCorrect
                ? AppColors.brand
                : showWrong
                    ? AppColors.textSecondary
                    : AppColors.textHint,
            size: AppIconSize.md,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              label,
              style: AppText.body.copyWith(
                fontWeight: showCorrect ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBody extends StatelessWidget {
  final AppStore store;
  final int score;
  final int total;
  final bool passed;
  const _ResultBody({
    required this.store,
    required this.score,
    required this.total,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
              color: passed ? AppColors.brand : AppColors.warning,
              size: AppIconSize.lg,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    passed
                        ? s.t('Passed', 'पास')
                        : s.t('Not yet', 'अभी नहीं'),
                    style: AppText.h2,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    s.t(
                      '$score of $total correct',
                      '$total में से $score सही',
                    ),
                    style: AppText.body,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          passed
              ? s.t(
                  'Great recall. The module card now shows a mastered badge.',
                  'बढ़िया! मॉड्यूल कार्ड पर अब पूर्ण का चिह्न दिखेगा।',
                )
              : s.t(
                  'Have another look at the videos, then try the quiz again. Two correct answers out of three is a pass.',
                  'वीडियो दोबारा देखें और क्विज़ फिर से दें। 3 में से 2 सही उत्तर पास हैं।',
                ),
          style: AppText.bodySmall,
        ),
      ],
    );
  }
}
