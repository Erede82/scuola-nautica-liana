import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/quiz_sheet_player_navigation.dart';
import '../models/quiz_question.dart';
import '../theme/quiz_player_density.dart';
import '../theme/quiz_player_visual_tokens.dart';
import 'nautical_answer_marker.dart';
import 'quiz_answer_result_chip.dart';
import 'quiz_lesson_sheet_progress_panel.dart';
import 'quiz_player_answer_tile.dart';
import 'quiz_question_image.dart';
import 'quiz_question_progress_strip.dart';
import 'quiz_question_prompt_panel.dart';

/// Layout automatico del player lesson-style (Scheda / Multischeda).
enum LessonStyleQuizLayout {
  /// Nessuna figura: domanda full-width + risposte sotto.
  noImage,

  /// Desktop/tablet: immagine sinistra, domanda+risposte a destra.
  withImageSide,

  /// Mobile: stacked (prompt panel con figura) + risposte sotto.
  withImageStacked,
}

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

  /// Breakpoint two-column image (allineato a [QuizQuestionPromptPanel]).
  @visibleForTesting
  static const double sideLayoutMinWidth = 600;

  /// Altezza body minima per side layout utile.
  ///
  /// Side mette immagine e (prompt + 3 risposte) in una riga condivisa.
  /// Sotto ~420px il body forza scroll eccessivo e l'immagine laterale
  /// domina (ex floor 260). Preferiamo stacked.
  @visibleForTesting
  static const double sideLayoutMinBodyHeight = 420;

  /// Cap altezza figura in side layout (BoxFit.contain, no crop).
  @visibleForTesting
  static const double sideImageMaxHeightCap = 420;

  /// Floor adattivo figura side (mai sopra lo spazio body disponibile).
  @visibleForTesting
  static const double sideImageMinHeightFloor = 160;

  /// Frazione colonna immagine (desktop side).
  @visibleForTesting
  static const double imageColumnFlex = 0.36;

  /// Pavimento min-height area contenuto desktop.
  @visibleForTesting
  static const double questionCardMinHeightFloor = 200;

  /// Quota massima body dedicata all'area domanda (no-image).
  @visibleForTesting
  static const double questionCardMaxBodyFraction = 0.62;

  @visibleForTesting
  static bool hasQuestionImage(String? imagePath) {
    final trimmed = imagePath?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }

  /// Decide il layout da figura + larghezza + altezza body utile.
  ///
  /// Usa [availableBodyHeight] (area dopo progress/padding), non screen height.
  @visibleForTesting
  static LessonStyleQuizLayout resolveLayout({
    required String? imagePath,
    required bool compact,
    required double contentWidth,
    required double availableBodyHeight,
  }) {
    if (!hasQuestionImage(imagePath)) {
      return LessonStyleQuizLayout.noImage;
    }
    if (compact || contentWidth < sideLayoutMinWidth) {
      return LessonStyleQuizLayout.withImageStacked;
    }
    if (availableBodyHeight < sideLayoutMinBodyHeight) {
      return LessonStyleQuizLayout.withImageStacked;
    }
    return LessonStyleQuizLayout.withImageSide;
  }

  /// Max height figura laterale adattiva allo spazio body.
  @visibleForTesting
  static double resolveSideImageMaxHeight({
    required double availableBodyHeight,
    required double minRowHeight,
  }) {
    final preferred = math.max(minRowHeight - 24, sideImageMinHeightFloor);
    final cappedByBody = math.max(
      sideImageMinHeightFloor,
      availableBodyHeight - 24,
    );
    return math
        .min(preferred, cappedByBody)
        .clamp(sideImageMinHeightFloor, sideImageMaxHeightCap);
  }

  /// Min-height area domanda (no-image / stacked): indipendente da imagePath.
  @visibleForTesting
  static double resolveQuestionCardMinHeight({
    required double availableBodyHeight,
    required bool compact,
    required int optionCount,
    required QuizPlayerContentDensity density,
  }) {
    if (compact || availableBodyHeight <= 0 || optionCount <= 0) {
      return 0;
    }

    final answerBlock =
        QuizPlayerDensity.answerMinHeight(density) * optionCount +
        QuizPlayerDensity.answerSpacing(density) *
            math.max(0, optionCount - 1) +
        QuizPlayerDensity.sectionSpacing(density);
    final leftover = availableBodyHeight - answerBlock;
    if (leftover <= 0) return 0;

    final ceiling = availableBodyHeight * questionCardMaxBodyFraction;
    return leftover.clamp(questionCardMinHeightFloor, ceiling);
  }

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
                        final bodyPadding =
                            QuizPlayerVisual.lessonSheetBodyPadding;
                        final availableBodyHeight = math.max(
                          0.0,
                          contentConstraints.maxHeight - bodyPadding.vertical,
                        );
                        final layout = resolveLayout(
                          imagePath: question.imagePath,
                          compact: compact,
                          contentWidth: contentConstraints.maxWidth,
                          availableBodyHeight: availableBodyHeight,
                        );

                        return SingleChildScrollView(
                          padding: bodyPadding,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: availableBodyHeight,
                            ),
                            child: KeyedSubtree(
                              key: QuizPlayerDensity.densityKey(density),
                              child: switch (layout) {
                                LessonStyleQuizLayout.noImage =>
                                  _buildNoImageBody(
                                    question: question,
                                    selected: selected,
                                    revealed: revealed,
                                    compact: compact,
                                    dense: dense,
                                    density: density,
                                    availableBodyHeight: availableBodyHeight,
                                  ),
                                LessonStyleQuizLayout.withImageSide =>
                                  _buildImageSideBody(
                                    question: question,
                                    selected: selected,
                                    revealed: revealed,
                                    compact: compact,
                                    dense: dense,
                                    density: density,
                                    availableBodyHeight: availableBodyHeight,
                                    contentWidth: contentConstraints.maxWidth,
                                  ),
                                LessonStyleQuizLayout.withImageStacked =>
                                  _buildImageStackedBody(
                                    question: question,
                                    selected: selected,
                                    revealed: revealed,
                                    compact: compact,
                                    dense: dense,
                                    density: density,
                                  ),
                              },
                            ),
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
            key: const Key('lesson_style_quiz_player_footer'),
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

  Widget _buildNoImageBody({
    required QuizQuestion question,
    required QuizAnswerOption? selected,
    required bool revealed,
    required bool compact,
    required bool dense,
    required QuizPlayerContentDensity density,
    required double availableBodyHeight,
  }) {
    final questionMinHeight = resolveQuestionCardMinHeight(
      availableBodyHeight: availableBodyHeight,
      compact: compact,
      optionCount: question.options.length,
      density: density,
    );

    return Column(
      key: const Key('lesson_style_layout_no_image'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: questionMinHeight),
          child: _questionCard(
            child: QuizQuestionPromptPanel(
              questionNumber: currentIndex + 1,
              prompt: question.prompt,
              imagePath: null,
              includeImage: false,
              compact: compact,
              dense: dense,
              labelColor: _primaryColor,
              textColor: _textPrimaryColor,
            ),
            density: density,
          ),
        ),
        SizedBox(height: QuizPlayerDensity.sectionSpacing(density)),
        ..._answerTiles(
          question: question,
          selected: selected,
          revealed: revealed,
          density: density,
          dense: dense,
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildImageSideBody({
    required QuizQuestion question,
    required QuizAnswerOption? selected,
    required bool revealed,
    required bool compact,
    required bool dense,
    required QuizPlayerContentDensity density,
    required double availableBodyHeight,
    required double contentWidth,
  }) {
    final imageWidth = (contentWidth * imageColumnFlex).clamp(220.0, 420.0);
    final minRowHeight = compact
        ? 0.0
        : math.max(questionCardMinHeightFloor, availableBodyHeight * 0.55);
    final imageMaxHeight = resolveSideImageMaxHeight(
      availableBodyHeight: availableBodyHeight,
      minRowHeight: minRowHeight,
    );

    return ConstrainedBox(
      key: const Key('lesson_style_layout_with_image_side'),
      constraints: BoxConstraints(minHeight: minRowHeight),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: const Key('lesson_style_image_column'),
              width: imageWidth,
              child: Container(
                padding: EdgeInsets.all(QuizPlayerDensity.cardPadding(density)),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(
                    QuizPlayerVisual.cardRadius,
                  ),
                  border: Border.all(color: _neutralColor),
                ),
                child: Center(
                  child: SizedBox(
                    key: const Key('quiz_prompt_side_image'),
                    width:
                        imageWidth - QuizPlayerDensity.cardPadding(density) * 2,
                    child: QuizQuestionImage(
                      imagePath: question.imagePath,
                      sidePanelLayout: true,
                      maxWidth:
                          imageWidth -
                          QuizPlayerDensity.cardPadding(density) * 2,
                      maxHeight: imageMaxHeight,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              key: const Key('lesson_style_right_column'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _questionCard(
                    child: QuizQuestionPromptPanel(
                      questionNumber: currentIndex + 1,
                      prompt: question.prompt,
                      imagePath: question.imagePath,
                      includeImage: false,
                      compact: compact,
                      dense: dense,
                      labelColor: _primaryColor,
                      textColor: _textPrimaryColor,
                    ),
                    density: density,
                  ),
                  SizedBox(height: QuizPlayerDensity.sectionSpacing(density)),
                  ..._answerTiles(
                    question: question,
                    selected: selected,
                    revealed: revealed,
                    density: density,
                    dense: dense,
                    compact: compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageStackedBody({
    required QuizQuestion question,
    required QuizAnswerOption? selected,
    required bool revealed,
    required bool compact,
    required bool dense,
    required QuizPlayerContentDensity density,
  }) {
    return Column(
      key: const Key('lesson_style_layout_with_image_stacked'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _questionCard(
          child: QuizQuestionPromptPanel(
            questionNumber: currentIndex + 1,
            prompt: question.prompt,
            imagePath: question.imagePath,
            includeImage: true,
            // Force stacked image path even when MediaQuery width >= 600
            // (height gate can select stacked on wide-but-short viewports).
            compact: true,
            dense: dense,
            labelColor: _primaryColor,
            textColor: _textPrimaryColor,
          ),
          density: density,
        ),
        SizedBox(height: QuizPlayerDensity.sectionSpacing(density)),
        ..._answerTiles(
          question: question,
          selected: selected,
          revealed: revealed,
          density: density,
          dense: dense,
          compact: compact,
        ),
      ],
    );
  }

  Widget _questionCard({
    required Widget child,
    required QuizPlayerContentDensity density,
  }) {
    return Container(
      key: const Key('lesson_style_question_card'),
      alignment: Alignment.topLeft,
      padding: EdgeInsets.all(QuizPlayerDensity.cardPadding(density)),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(QuizPlayerVisual.cardRadius),
        border: Border.all(color: _neutralColor),
      ),
      child: child,
    );
  }

  List<Widget> _answerTiles({
    required QuizQuestion question,
    required QuizAnswerOption? selected,
    required bool revealed,
    required QuizPlayerContentDensity density,
    required bool dense,
    required bool compact,
  }) {
    return [
      for (final option in question.options)
        Padding(
          key: Key('lesson_style_answer_${option.index}'),
          padding: EdgeInsets.only(
            bottom: QuizPlayerDensity.answerSpacing(density),
          ),
          child: QuizPlayerAnswerTile(
            answerNumber: option.index + 1,
            text: question.textForOption(option),
            onTap: revealed ? null : () => onSelectAnswer(option),
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
      if (revealed) ...[
        const SizedBox(height: 2),
        QuizAnswerResultChip(
          isCorrect: selected == question.correctOption,
          correctLetter: question.correctOption.letter,
          explanation: question.explanation,
          dense: dense || compact,
        ),
      ],
    ];
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
