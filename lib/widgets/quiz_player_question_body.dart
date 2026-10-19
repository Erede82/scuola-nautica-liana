import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/quiz_player_density.dart';
import '../theme/quiz_player_visual_tokens.dart';
import 'quiz_question_image.dart';
import 'quiz_question_prompt_panel.dart';

/// Layout corpo domanda condiviso (Lesson / Multischeda / Exam).
enum QuizPlayerBodyLayout {
  noImage,
  imageSide,
  imageStacked,
}

/// Composizione classroom-scale: domanda ± media + risposte.
///
/// Image-side: media a sinistra (~25%), domanda+risposte a destra — stesso
/// linguaggio per Exam e Schede (UNIFY.2).
class QuizPlayerQuestionBody extends StatelessWidget {
  const QuizPlayerQuestionBody({
    super.key,
    required this.questionNumber,
    required this.prompt,
    required this.imagePath,
    required this.compact,
    required this.dense,
    required this.density,
    required this.layout,
    required this.answersBuilder,
    required this.labelColor,
    required this.textColor,
    required this.cardColor,
    required this.borderColor,
    this.availableBodyHeight,
    this.contentWidth,
  });

  final int questionNumber;
  final String prompt;
  final String? imagePath;
  final bool compact;
  final bool dense;
  final QuizPlayerContentDensity density;
  final QuizPlayerBodyLayout layout;
  final List<Widget> Function() answersBuilder;
  final Color labelColor;
  final Color textColor;
  final Color cardColor;
  final Color borderColor;
  final double? availableBodyHeight;
  final double? contentWidth;

  static bool hasImage(String? path) {
    final trimmed = path?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }

  /// Breakpoint side layout (allineato allo shell lesson / prompt).
  static const double sideLayoutMinWidth = 600;
  static const double sideLayoutMinBodyHeight = 420;

  static QuizPlayerBodyLayout resolveLayout({
    required String? imagePath,
    required bool compact,
    required double contentWidth,
    required double availableBodyHeight,
  }) {
    if (!hasImage(imagePath)) return QuizPlayerBodyLayout.noImage;
    if (compact || contentWidth < sideLayoutMinWidth) {
      return QuizPlayerBodyLayout.imageStacked;
    }
    if (availableBodyHeight < sideLayoutMinBodyHeight) {
      return QuizPlayerBodyLayout.imageStacked;
    }
    return QuizPlayerBodyLayout.imageSide;
  }

  static double resolveMediaMaxHeight({
    required double? availableBodyHeight,
  }) {
    final body = availableBodyHeight ?? 520;
    return body.clamp(180.0, 480.0);
  }

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      QuizPlayerBodyLayout.noImage => _buildNoImage(),
      QuizPlayerBodyLayout.imageStacked => _buildStacked(),
      QuizPlayerBodyLayout.imageSide => _buildSide(context),
    };
  }

  Widget _questionCard({required Widget child}) {
    return Container(
      key: const Key('quiz_player_question_card'),
      alignment: Alignment.topLeft,
      padding: EdgeInsets.all(QuizPlayerDensity.cardPadding(density)),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(QuizPlayerVisual.cardRadius),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _buildNoImage() {
    return Column(
      key: const Key('quiz_player_body_no_image'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _questionCard(
          child: QuizQuestionPromptPanel(
            questionNumber: questionNumber,
            prompt: prompt,
            imagePath: null,
            includeImage: false,
            compact: compact,
            dense: dense,
            classroomScale: true,
            labelColor: labelColor,
            textColor: textColor,
          ),
        ),
        SizedBox(height: QuizPlayerDensity.sectionSpacing(density)),
        ...answersBuilder(),
      ],
    );
  }

  Widget _buildStacked() {
    return Column(
      key: const Key('quiz_player_body_image_stacked'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _questionCard(
          child: QuizQuestionPromptPanel(
            questionNumber: questionNumber,
            prompt: prompt,
            imagePath: imagePath,
            includeImage: true,
            compact: true,
            dense: dense,
            classroomScale: true,
            labelColor: labelColor,
            textColor: textColor,
          ),
        ),
        SizedBox(height: QuizPlayerDensity.sectionSpacing(density)),
        ...answersBuilder(),
      ],
    );
  }

  Widget _buildSide(BuildContext context) {
    final width = contentWidth ?? MediaQuery.sizeOf(context).width;
    final mediaW = QuizPlayerVisual.mediaColumnWidthFor(width);
    final mediaMaxH = resolveMediaMaxHeight(
      availableBodyHeight: availableBodyHeight,
    );

    return Row(
      key: const Key('quiz_player_body_image_side'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          key: const Key('quiz_player_media_column'),
          width: mediaW,
          child: Container(
            padding: EdgeInsets.all(QuizPlayerDensity.cardPadding(density)),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(QuizPlayerVisual.cardRadius),
              border: Border.all(color: borderColor),
            ),
            child: SizedBox(
              key: const Key('quiz_player_media_image'),
              width: math.max(
                1.0,
                mediaW - QuizPlayerDensity.cardPadding(density) * 2,
              ),
              child: QuizQuestionImage(
                imagePath: imagePath,
                sidePanelLayout: true,
                maxWidth: math.max(
                  1.0,
                  mediaW - QuizPlayerDensity.cardPadding(density) * 2,
                ),
                maxHeight: mediaMaxH,
              ),
            ),
          ),
        ),
        const SizedBox(width: QuizPlayerVisual.mediaContentGap),
        Expanded(
          key: const Key('quiz_player_qa_column'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _questionCard(
                child: QuizQuestionPromptPanel(
                  questionNumber: questionNumber,
                  prompt: prompt,
                  imagePath: imagePath,
                  includeImage: false,
                  compact: compact,
                  dense: dense,
                  classroomScale: true,
                  labelColor: labelColor,
                  textColor: textColor,
                ),
              ),
              SizedBox(height: QuizPlayerDensity.sectionSpacing(density)),
              ...answersBuilder(),
            ],
          ),
        ),
      ],
    );
  }
}
