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
    this.labelColor = AppVisual.logoBlue,
    this.textColor = QuizPlayerVisual.ink,
  });

  final int questionNumber;
  final String prompt;
  final String? imagePath;
  final bool compact;
  final Color labelColor;
  final Color textColor;

  static const double _sideLayoutMinWidth = 600;

  static double stackedImageBoxHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return 120;
    if (width < 900) return 132;
    return 140;
  }

  static double sideImageBoxHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 700) return 132;
    return 140;
  }

  bool _hasImage(String? path) {
    final trimmed = path?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final hasImage = _hasImage(imagePath);
    final useCompact = compact || QuizPlayerVisual.isCompact(context);
    final sideLayout = hasImage && !useCompact && width >= _sideLayoutMinWidth;

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
          SizedBox(height: useCompact ? 8 : 10),
          promptWidget,
        ],
      );
    }

    if (sideLayout) {
      final imageHeight = sideImageBoxHeight(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Domanda $questionNumber', style: labelStyle),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                height: imageHeight,
                child: QuizQuestionImage(
                  imagePath: imagePath,
                  sidePanelLayout: true,
                  maxHeight: imageHeight,
                  maxWidth: 220,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: promptWidget),
            ],
          ),
        ],
      );
    }

    final imageHeight = stackedImageBoxHeight(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Domanda $questionNumber', style: labelStyle),
        SizedBox(height: useCompact ? 8 : 10),
        SizedBox(
          height: imageHeight,
          width: double.infinity,
          child: QuizQuestionImage(
            imagePath: imagePath,
            maxHeight: imageHeight,
          ),
        ),
        const SizedBox(height: 10),
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
