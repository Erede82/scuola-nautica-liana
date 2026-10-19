import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'quiz_player_visual_tokens.dart';

/// Densità layout player quiz: standard per contenuti brevi, dense per testi lunghi su mobile.
enum QuizPlayerContentDensity { standard, dense }

/// Rilevamento densità e metriche condivise (esame + schede).
abstract final class QuizPlayerDensity {
  /// Soglia righe stimate (domanda + tre risposte) oltre la quale attiva `dense` su mobile.
  static const int denseLineThreshold = 10;

  /// Soglia più alta su desktop/web: densità ridotta solo con testi molto lunghi.
  static const int desktopDenseLineThreshold = 14;

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

  /// Risolve densità da viewport, altezza e contenuto.
  ///
  /// Mobile: `dense` oltre [denseLineThreshold].
  /// Desktop/web: `dense` solo oltre [desktopDenseLineThreshold] (testi molto lunghi).
  /// Low-height desktop: soglia ridotta per evitare footer fuori schermo.
  static QuizPlayerContentDensity resolve({
    required BuildContext context,
    required String prompt,
    required List<String> answers,
    required double contentWidth,
  }) {
    final totalLines = estimateTotalLines(
      context: context,
      prompt: prompt,
      answers: answers,
      contentWidth: contentWidth,
    );
    var threshold = QuizPlayerVisual.isCompact(context)
        ? denseLineThreshold
        : desktopDenseLineThreshold;
    if (QuizPlayerVisual.isLowHeight(context) &&
        !QuizPlayerVisual.isCompact(context)) {
      threshold = math.min(threshold, 11);
    }
    return totalLines > threshold
        ? QuizPlayerContentDensity.dense
        : QuizPlayerContentDensity.standard;
  }

  /// Stima righe totali domanda + risposte (utile al layout fill).
  static int estimateTotalLines({
    required BuildContext context,
    required String prompt,
    required List<String> answers,
    required double contentWidth,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    // Density è chiamata solo da Schede / Exam → stima con scala classroom.
    final questionStyle = QuizPlayerVisual.questionStyle(
      context,
      scale: QuizPlayerTypeScale.classroom,
    );
    final answerStyle = QuizPlayerVisual.answerStyle(
      context,
      scale: QuizPlayerTypeScale.classroom,
    );

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
    return totalLines;
  }

  static bool isDense(QuizPlayerContentDensity density) =>
      density == QuizPlayerContentDensity.dense;

  static double answerMinHeight(
    QuizPlayerContentDensity density, {
    BuildContext? context,
  }) {
    if (isDense(density)) return QuizPlayerVisual.answerMinHeightDense;
    if (context != null &&
        QuizPlayerVisual.viewportClass(context) ==
            QuizPlayerViewportClass.largeDesktop &&
        !QuizPlayerVisual.isLowHeight(context)) {
      return QuizPlayerVisual.answerMinHeightLarge;
    }
    return QuizPlayerVisual.answerMinHeight;
  }

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
