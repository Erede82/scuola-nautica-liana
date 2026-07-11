import 'package:flutter/material.dart';

import '../theme/app_visual_tokens.dart';
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
    this.textColor = AppVisual.ink,
  });

  final int questionNumber;
  final String prompt;
  final String? imagePath;
  final bool compact;
  final Color labelColor;
  final Color textColor;

  static const double _sideLayoutMinWidth = 600;

  bool _hasImage(String? path) {
    final trimmed = path?.trim();
    return trimmed != null && trimmed.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final hasImage = _hasImage(imagePath);
    final sideLayout = hasImage && !compact && width >= _sideLayoutMinWidth;

    final labelStyle = textTheme.labelLarge?.copyWith(
      color: labelColor,
      fontWeight: FontWeight.w800,
    );

    final promptStyle = (compact ? textTheme.titleMedium : textTheme.titleLarge)
        ?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          height: compact ? 1.35 : 1.4,
          fontSize: compact ? 17 : 20,
        );

    final promptWidget = Text(prompt, style: promptStyle);

    if (!hasImage) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Domanda $questionNumber', style: labelStyle),
          SizedBox(height: compact ? 8 : 10),
          promptWidget,
        ],
      );
    }

    if (sideLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Domanda $questionNumber', style: labelStyle),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: compact ? 200 : 240,
                child: QuizQuestionImage(
                  imagePath: imagePath,
                  sidePanelLayout: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: promptWidget),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Domanda $questionNumber', style: labelStyle),
        SizedBox(height: compact ? 8 : 10),
        QuizQuestionImage(imagePath: imagePath),
        promptWidget,
      ],
    );
  }
}

/// Stili testo risposta quiz con font leggermente più grande.
class QuizAnswerTextStyle {
  QuizAnswerTextStyle._();

  static TextStyle answer(BuildContext context, {required bool compact}) {
    final textTheme = Theme.of(context).textTheme;
    return (compact ? textTheme.bodyLarge : textTheme.titleSmall)!.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.35,
      fontSize: compact ? 16 : 17.5,
    );
  }
}
