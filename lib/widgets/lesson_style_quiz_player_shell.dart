import 'package:flutter/material.dart';

import '../domain/quiz_sheet_player_navigation.dart';
import '../models/quiz_question.dart';
import '../theme/quiz_player_density.dart';
import '../theme/quiz_player_visual_tokens.dart';
import 'nautical_answer_marker.dart';
import 'quiz_answer_result_chip.dart';
import 'quiz_lesson_sheet_progress_panel.dart';
import 'quiz_player_answer_tile.dart';
import 'quiz_question_progress_strip.dart';
import 'quiz_question_prompt_panel.dart';

/// Shell condiviso Scheda lezione / Multischeda (area domanda + progress + footer).
///
/// Unica fonte del layout visuale "lesson style". Exam resta separato.
class LessonStyleQuizPlayerShell extends StatelessWidget {
  const LessonStyleQuizPlayerShell({
    super.key,
    required this.appBar,
    required this.questions,
    required this.userAnswers,
    required this.currentIndex,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.onSelectAnswer,
    required this.onGoBack,
    required this.onGoForward,
    required this.onPrimaryAction,
    required this.canPop,
    required this.onPopInvoked,
    this.progressHeader,
  });

  final PreferredSizeWidget appBar;
  final List<QuizQuestion> questions;
  final List<QuizAnswerOption?> userAnswers;
  final int currentIndex;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final ValueChanged<QuizAnswerOption> onSelectAnswer;
  final VoidCallback? onGoBack;
  final VoidCallback? onGoForward;
  final VoidCallback onPrimaryAction;
  final bool canPop;
  final PopInvokedWithResultCallback<Object?> onPopInvoked;

  /// Solo Multischeda (es. "Scheda 2 di 13"). Null nella Scheda lezione.
  final String? progressHeader;

  static const Color _primaryColor = QuizPlayerVisual.accent;
  static const Color _backgroundColor = QuizPlayerVisual.pageBackground;
  static const Color _cardColor = QuizPlayerVisual.cardSurface;
  static const Color _textPrimaryColor = QuizPlayerVisual.ink;
  static const Color _neutralColor = QuizPlayerVisual.cardBorder;
  static const Color _correctColor = QuizPlayerVisual.correctBorder;
  static const Color _wrongColor = QuizPlayerVisual.wrongBorder;
  static const Color _correctBg = QuizPlayerVisual.correctFill;
  static const Color _wrongBg = QuizPlayerVisual.wrongFill;

  QuizQuestion get _question => questions[currentIndex];

  QuizAnswerOption? get _selected =>
      currentIndex >= 0 && currentIndex < userAnswers.length
      ? userAnswers[currentIndex]
      : null;

  bool get _revealed => _selected != null;

  @override
  Widget build(BuildContext context) {
    final question = _question;
    final selected = _selected;
    final revealed = _revealed;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: onPopInvoked,
      child: Scaffold(
        key: const Key('lesson_style_quiz_player_shell'),
        backgroundColor: _backgroundColor,
        appBar: appBar,
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: QuizPlayerVisual.lessonSheetContentMaxWidth,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  QuizLessonSheetProgressPanel(
                    currentIndex: currentIndex,
                    total: questions.length,
                    isAnswered: (index) =>
                        QuizSheetPlayerNavigation.isQuestionAnswered(
                          userAnswers,
                          index,
                        ),
                    cellTone: (index) {
                      final answer = userAnswers[index];
                      if (answer == null) {
                        return QuizProgressCellTone.unanswered;
                      }
                      return answer == questions[index].correctOption
                          ? QuizProgressCellTone.correct
                          : QuizProgressCellTone.wrong;
                    },
                    correctCount: correctCount,
                    wrongCount: wrongCount,
                    unansweredCount: unansweredCount,
                    header: progressHeader,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, contentConstraints) {
                        final compact = QuizPlayerVisual.isCompact(context);
                        final density = QuizPlayerDensity.resolve(
                          context: context,
                          prompt: question.prompt,
                          answers: [
                            for (final option in question.options)
                              question.textForOption(option),
                          ],
                          contentWidth: contentConstraints.maxWidth,
                        );
                        final dense = density == QuizPlayerContentDensity.dense;

                        return SingleChildScrollView(
                          padding: QuizPlayerVisual.lessonSheetBodyPadding,
                          child: Column(
                            key: QuizPlayerDensity.densityKey(density),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                key: const Key('lesson_style_question_card'),
                                padding: EdgeInsets.all(
                                  QuizPlayerDensity.cardPadding(density),
                                ),
                                decoration: BoxDecoration(
                                  color: _cardColor,
                                  borderRadius: BorderRadius.circular(
                                    QuizPlayerVisual.cardRadius,
                                  ),
                                  border: Border.all(color: _neutralColor),
                                ),
                                child: QuizQuestionPromptPanel(
                                  questionNumber: currentIndex + 1,
                                  prompt: question.prompt,
                                  imagePath: question.imagePath,
                                  compact: compact,
                                  dense: dense,
                                  labelColor: _primaryColor,
                                  textColor: _textPrimaryColor,
                                ),
                              ),
                              SizedBox(
                                height: QuizPlayerDensity.sectionSpacing(
                                  density,
                                ),
                              ),
                              ...question.options.map(
                                (option) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: QuizPlayerDensity.answerSpacing(
                                      density,
                                    ),
                                  ),
                                  child: QuizPlayerAnswerTile(
                                    answerNumber: option.index + 1,
                                    text: question.textForOption(option),
                                    onTap: revealed
                                        ? null
                                        : () => onSelectAnswer(option),
                                    backgroundColor: _optionBackground(
                                      option,
                                      selected,
                                      revealed,
                                      question.correctOption,
                                    ),
                                    borderColor: _optionBorder(
                                      option,
                                      selected,
                                      revealed,
                                      question.correctOption,
                                    ),
                                    borderWidth: _optionBorderWidth(
                                      option,
                                      selected,
                                      revealed,
                                      question.correctOption,
                                    ),
                                    markerState: _markerState(
                                      option,
                                      selected,
                                      revealed,
                                      question.correctOption,
                                    ),
                                    density: density,
                                  ),
                                ),
                              ),
                              if (revealed) ...[
                                const SizedBox(height: 2),
                                QuizAnswerResultChip(
                                  isCorrect: selected == question.correctOption,
                                  correctLetter: question.correctOption.letter,
                                  explanation: question.explanation,
                                  dense: dense || compact,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Material(
            color: _backgroundColor,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                QuizPlayerVisual.bottomBarPaddingV,
                12,
                12,
              ),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: onGoBack,
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Domanda precedente',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimaryAction,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: QuizPlayerVisual.bottomButtonPaddingV,
                        ),
                      ),
                      child: Text(
                        QuizSheetPlayerNavigation.primaryButtonLabel(
                          currentIndex: currentIndex,
                          questionCount: questions.length,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: onGoForward,
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Domanda successiva',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static NauticalAnswerMarkerState _markerState(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
    QuizAnswerOption correct,
  ) {
    if (revealed) {
      if (option == correct) return NauticalAnswerMarkerState.correct;
      if (option == selected) return NauticalAnswerMarkerState.wrong;
      return NauticalAnswerMarkerState.neutral;
    }
    if (option == selected) return NauticalAnswerMarkerState.selected;
    return NauticalAnswerMarkerState.neutral;
  }

  static Color _optionBackground(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
    QuizAnswerOption correct,
  ) {
    if (!revealed) {
      if (option == selected) return QuizPlayerVisual.selectedFill;
      return _cardColor;
    }
    if (option == correct) return _correctBg;
    if (option == selected) return _wrongBg;
    return _cardColor;
  }

  static Color _optionBorder(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
    QuizAnswerOption correct,
  ) {
    if (!revealed) {
      if (option == selected) return QuizPlayerVisual.selectedBorder;
      return _neutralColor;
    }
    if (option == correct) return _correctColor;
    if (option == selected && option != correct) return _wrongColor;
    return _neutralColor;
  }

  static double _optionBorderWidth(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
    QuizAnswerOption correct,
  ) {
    if (!revealed) {
      if (option == selected) return 2.0;
      return 1.2;
    }
    if (option == correct || option == selected) return 2.4;
    return 1.2;
  }
}
