import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'quiz_player_visual_tokens.dart';

/// Densità layout player quiz: standard per contenuti brevi, dense per testi lunghi su mobile.
enum QuizPlayerContentDensity { standard, dense }

/// Rilevamento densità e metriche condivise (esame + schede).
abstract final class QuizPlayerDensity {
  /// Soglia righe stimate (domanda + tre risposte) oltre la quale attiva `dense`.
  static const int denseLineThreshold = 10;

  /// Larghezza stimata del marker risposta (cerchio + padding interno tile).
  static const double answerMarkerReserve = 44;

  static int estimateLineCount({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextScaler textScaler,
  }) {
    final width = math.max(1.0, maxWidth);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: width);

    final metrics = painter.computeLineMetrics();
    if (metrics.isNotEmpty) return metrics.length;

    final fontSize = style.fontSize ?? 16;
    final heightFactor = style.height ?? 1.35;
    final lineHeight = fontSize * heightFactor;
    if (lineHeight <= 0) return 1;
    return math.max(1, (painter.height / lineHeight).ceil());
  }

  /// Risolve densità da viewport e contenuto. `dense` solo su viewport stretta.
  static QuizPlayerContentDensity resolve({
    required BuildContext context,
    required String prompt,
    required List<String> answers,
    required double contentWidth,
  }) {
    if (!QuizPlayerVisual.isCompact(context)) {
      return QuizPlayerContentDensity.standard;
    }

    final textScaler = MediaQuery.textScalerOf(context);
    final questionStyle = QuizPlayerVisual.questionStyle(context);
    final answerStyle = QuizPlayerVisual.answerStyle(context);

    final questionTextWidth = math.max(
      1.0,
      contentWidth -
          QuizPlayerVisual.bodyPadding.horizontal -
          QuizPlayerVisual.cardPadding * 2,
    );
    final answerTextWidth = math.max(
      1.0,
      contentWidth -
          QuizPlayerVisual.bodyPadding.horizontal -
          QuizPlayerVisual.answerPadding.horizontal -
          answerMarkerReserve,
    );

    var totalLines = estimateLineCount(
      text: prompt,
      style: questionStyle,
      maxWidth: questionTextWidth,
      textScaler: textScaler,
    );
    for (final answer in answers) {
      totalLines += estimateLineCount(
        text: answer,
        style: answerStyle,
        maxWidth: answerTextWidth,
        textScaler: textScaler,
      );
    }

    return totalLines > denseLineThreshold
        ? QuizPlayerContentDensity.dense
        : QuizPlayerContentDensity.standard;
  }

  static bool isDense(QuizPlayerContentDensity density) =>
      density == QuizPlayerContentDensity.dense;

  static double answerMinHeight(QuizPlayerContentDensity density) =>
      isDense(density)
      ? QuizPlayerVisual.answerMinHeightDense
      : QuizPlayerVisual.answerMinHeight;

  static EdgeInsets answerPadding(QuizPlayerContentDensity density) =>
      isDense(density)
      ? QuizPlayerVisual.answerPaddingDense
      : QuizPlayerVisual.answerPadding;

  static double sectionSpacing(QuizPlayerContentDensity density) =>
      isDense(density)
      ? QuizPlayerVisual.sectionSpacingDense
      : QuizPlayerVisual.sectionSpacing;

  static double answerSpacing(QuizPlayerContentDensity density) =>
      isDense(density)
      ? QuizPlayerVisual.answerSpacingDense
      : QuizPlayerVisual.answerSpacing;

  static double cardPadding(QuizPlayerContentDensity density) =>
      isDense(density)
      ? QuizPlayerVisual.cardPaddingDense
      : QuizPlayerVisual.cardPadding;

  static Key densityKey(QuizPlayerContentDensity density) => ValueKey<String>(
    isDense(density)
        ? 'quiz-player-density-dense'
        : 'quiz-player-density-standard',
  );
}
