import 'package:flutter/material.dart';

import '../theme/app_visual_tokens.dart';
import '../theme/quiz_player_visual_tokens.dart';
import 'quiz_question_image.dart';

/// Corpo domanda quiz: figura a sinistra su viewport largo, testo più leggibile.
class QuizQuestionPromptPanel extends StatelessWidget {
  const QuizQuestionPromptPanel({
    super.key,
    required this.questionNumber,
    required this.prompt,
    this.imagePath,
    this.compact = false,
    this.dense = false,
    this.includeImage = true,
    this.labelColor = AppVisual.logoBlue,
    this.textColor = QuizPlayerVisual.ink,
  });

  final int questionNumber;
  final String prompt;
  final String? imagePath;
  final bool compact;
  final bool dense;

  /// Se false, renderizza solo label+testo (l'immagine è gestita dallo shell).
  final bool includeImage;
  final Color labelColor;
  final Color textColor;

  static const double _sideLayoutMinWidth = 600;

  /// Frazione dell’area prompt dedicata alla figura laterale (desktop wide).
  static const double sideImageWidthFraction = 0.32;

  static const double sideImageMinWidth = 200;
  static const double sideImageMaxWidth = 360;

  static double stackedImageBoxHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return 120;
    if (width < 900) return 132;
    return 140;
  }

  static double sideImageBoxHeight(BuildContext context, {double? imageWidth}) {
    final width = MediaQuery.sizeOf(context).width;
    final base = width < 700 ? 132.0 : 140.0;
    if (imageWidth == null) return base;
    // Altezza cresce con la larghezza figura, senza sforare troppo in verticale.
    return (imageWidth * 0.72).clamp(base, 260.0);
  }

  /// Larghezza figura laterale in funzione dello spazio prompt disponibile.
  static double resolveSideImageWidth(double availableWidth) {
    if (availableWidth <= 0) return sideImageMinWidth;
    return (availableWidth * sideImageWidthFraction).clamp(
      sideImageMinWidth,
      sideImageMaxWidth,
    );
  }

  bool _hasImage(String? path) {
    final trimmed = path?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final hasImage = includeImage && _hasImage(imagePath);
    final useCompact = compact || QuizPlayerVisual.isCompact(context);
    final sideLayout = hasImage && !useCompact && width >= _sideLayoutMinWidth;
    final labelGap = dense ? 6.0 : (useCompact ? 8.0 : 10.0);

    final labelStyle = textTheme.labelLarge?.copyWith(
      color: labelColor,
      fontWeight: FontWeight.w800,
    );

    final promptStyle = QuizPlayerVisual.questionStyle(
      context,
    ).copyWith(color: textColor);

    final promptWidget = Text(prompt, style: promptStyle);

    if (!hasImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Domanda $questionNumber', style: labelStyle),
          SizedBox(height: labelGap),
          promptWidget,
        ],
      );
    }

    if (sideLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Domanda $questionNumber', style: labelStyle),
          SizedBox(height: labelGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final imageWidth = resolveSideImageWidth(constraints.maxWidth);
              final imageHeight = sideImageBoxHeight(
                context,
                imageWidth: imageWidth,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    key: const Key('quiz_prompt_side_image'),
                    width: imageWidth,
                    height: imageHeight,
                    child: QuizQuestionImage(
                      imagePath: imagePath,
                      sidePanelLayout: true,
                      maxHeight: imageHeight,
                      maxWidth: imageWidth,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: promptWidget),
                ],
              );
            },
          ),
        ],
      );
    }

    final imageHeight = stackedImageBoxHeight(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Domanda $questionNumber', style: labelStyle),
        SizedBox(height: labelGap),
        SizedBox(
          key: const Key('quiz_prompt_stacked_image'),
          height: imageHeight,
          width: double.infinity,
          child: QuizQuestionImage(
            imagePath: imagePath,
            maxHeight: imageHeight,
          ),
        ),
        SizedBox(height: dense ? 8 : 10),
        promptWidget,
      ],
    );
  }
}

/// Stili testo risposta quiz — allineati a [QuizPlayerVisual].
class QuizAnswerTextStyle {
  QuizAnswerTextStyle._();

  static TextStyle answer(BuildContext context, {required bool compact}) {
    return QuizPlayerVisual.answerStyle(context);
  }
}
