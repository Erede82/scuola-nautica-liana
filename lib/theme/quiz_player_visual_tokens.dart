import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_visual_tokens.dart';

/// Classi viewport del player quiz (solo larghezza logica).
enum QuizPlayerViewportClass { mobile, tablet, desktop, largeDesktop }

/// Scala tipografica del player.
///
/// [legacy]: Assigned Quiz e altri call site pre-UNIFY.2 (17 / 18.5).
/// [classroom]: Schede / Multischeda / Exam (opt-in esplicito).
enum QuizPlayerTypeScale { legacy, classroom }

/// Metriche e colori condivisi tra Quiz Esame e Schede lezione.
///
/// UNIFY.2: scala classroom — un solo sistema responsive per Lesson / Multischeda / Exam.
abstract final class QuizPlayerVisual {
  /// Fondo pagina (avorio caldo, non beige scuro né bianco puro).
  static const Color pageBackground = Color(0xFFF7F3ED);

  /// Superficie card domanda / risposta / progress.
  static const Color cardSurface = Color(0xFFFBF8F3);

  /// Bordo beige morbido.
  static const Color cardBorder = Color(0xFFD8C8B5);

  /// Testo principale.
  static const Color ink = Color(0xFF171717);

  /// Accento istituzionale.
  static const Color accent = AppVisual.logoBlue;

  /// Risposta selezionata: azzurro molto chiaro + bordo blu.
  static const Color selectedFill = Color(0xFFE8F4FA);
  static const Color selectedBorder = accent;

  static const Color correctFill = Color(0xFFE8F7EE);
  static const Color correctBorder = Color(0xFF15803D);
  static const Color wrongFill = Color(0xFFFDECEC);
  static const Color wrongBorder = Color(0xFFD32F2F);

  /// Larghezza storica fissa (legacy / test regressione).
  static const double contentMaxWidth = 720;

  /// Cap massimo contenuto player (classroom large desktop).
  static const double playerContentMaxWidthCap = 1600;

  /// Alias storico — ora punta al cap classroom.
  static const double lessonSheetContentMaxWidth = playerContentMaxWidthCap;

  /// Legacy reading cap (non più usato come tetto layout).
  static const double noImageReadingMaxWidth = 860;

  /// Frazione viewport usata sul contenuto (desktop+).
  static const double playerContentWidthFraction = 0.88;

  /// Breakpoint tablet / mobile.
  static const double tabletWidthBreakpoint = 600;
  static const double compactWidthBreakpoint = tabletWidthBreakpoint;

  /// Breakpoint desktop.
  static const double desktopWidthBreakpoint = 1024;

  /// Breakpoint large desktop.
  static const double largeDesktopWidthBreakpoint = 1440;

  /// Altezza sotto la quale riduciamo tipografia large-desktop.
  static const double lowHeightBreakpoint = 780;

  /// Frazione colonna media (image-side condivisa).
  /// UNIFY.2 final: 0.22 lascia più aria a domanda/risposte.
  static const double mediaColumnFraction = 0.22;

  static const double mediaColumnMinWidth = 200;
  static const double mediaColumnMaxWidth = 380;

  /// Gap tra media e colonna domanda/risposte.
  static const double mediaContentGap = 16;

  /// Legacy tablet/desktop width constants (test / fallback).
  static const double examContentMaxWidthTablet = 920;
  static const double examContentMaxWidthDesktop = 1280;

  static QuizPlayerViewportClass viewportClassFor(double viewportWidth) {
    if (viewportWidth < compactWidthBreakpoint) {
      return QuizPlayerViewportClass.mobile;
    }
    if (viewportWidth < desktopWidthBreakpoint) {
      return QuizPlayerViewportClass.tablet;
    }
    if (viewportWidth < largeDesktopWidthBreakpoint) {
      return QuizPlayerViewportClass.desktop;
    }
    return QuizPlayerViewportClass.largeDesktop;
  }

  static QuizPlayerViewportClass viewportClass(BuildContext context) =>
      viewportClassFor(MediaQuery.sizeOf(context).width);

  /// Larghezza contenuto player unificato (Esame + Schede / Multischeda).
  ///
  /// Mobile: nessun tetto (padding laterale).
  /// Tablet+: ~88% viewport, capped a [playerContentMaxWidthCap].
  static double playerContentMaxWidthFor(double viewportWidth) {
    switch (viewportClassFor(viewportWidth)) {
      case QuizPlayerViewportClass.mobile:
        return double.infinity;
      case QuizPlayerViewportClass.tablet:
        return math.min(viewportWidth * 0.92, examContentMaxWidthTablet);
      case QuizPlayerViewportClass.desktop:
        return math.min(
          viewportWidth * playerContentWidthFraction,
          examContentMaxWidthDesktop,
        );
      case QuizPlayerViewportClass.largeDesktop:
        return math.min(
          viewportWidth * playerContentWidthFraction,
          playerContentMaxWidthCap,
        );
    }
  }

  static double playerContentMaxWidth(BuildContext context) =>
      playerContentMaxWidthFor(MediaQuery.sizeOf(context).width);

  /// Alias storico.
  static double examContentMaxWidthFor(double viewportWidth) =>
      playerContentMaxWidthFor(viewportWidth);

  /// Alias storico.
  static double examContentMaxWidth(BuildContext context) =>
      playerContentMaxWidth(context);

  /// Larghezza colonna media (image-side).
  static double mediaColumnWidthFor(double contentWidth) {
    return (contentWidth * mediaColumnFraction).clamp(
      mediaColumnMinWidth,
      mediaColumnMaxWidth,
    );
  }

  /// Legacy (Assigned / pre-UNIFY.2).
  static const double questionFontLegacyMobile = 17.0;
  static const double questionFontLegacyDesktop = 18.5;
  static const double answerFontLegacyMobile = 16.0;
  static const double answerFontLegacyDesktop = 16.5;

  /// Classroom UNIFY.2 (Schede / Multi / Exam).
  static const double questionFontMobile = 17.0;
  static const double questionFontTablet = 20.0;
  static const double questionFontDesktop = 26.0;
  static const double questionFontLargeDesktop = 32.0;

  static const double answerFontMobile = 16.0;
  static const double answerFontTablet = 18.0;
  static const double answerFontDesktop = 21.0;
  static const double answerFontLargeDesktop = 23.0;

  static const double answerMinHeight = 56;
  static const double answerMinHeightDense = 48;
  static const double answerMinHeightLarge = 64;
  static const double cardRadius = 14;
  static const double cardPadding = 16;
  static const double cardPaddingDense = 12;
  static const double sectionSpacing = 12;
  static const double sectionSpacingDense = 8;
  static const double answerSpacing = 10;
  static const double answerSpacingDense = 6;

  static const EdgeInsets answerPadding = EdgeInsets.fromLTRB(14, 14, 12, 14);
  static const EdgeInsets answerPaddingDense = EdgeInsets.fromLTRB(
    12,
    10,
    10,
    10,
  );

  /// Padding corpo condiviso (Esame + Schede).
  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(16, 10, 16, 16);

  /// Alias.
  static const EdgeInsets lessonSheetBodyPadding = bodyPadding;

  static const EdgeInsets progressPanelMargin = EdgeInsets.fromLTRB(
    16,
    8,
    16,
    0,
  );

  /// Alias.
  static const EdgeInsets lessonSheetProgressPanelMargin = progressPanelMargin;

  static const EdgeInsets progressPanelPadding = EdgeInsets.fromLTRB(
    10,
    8,
    10,
    8,
  );

  static const double bottomBarPaddingV = 8;
  static const double bottomButtonPaddingV = 14;

  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < compactWidthBreakpoint;
  }

  static bool isLowHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height < lowHeightBreakpoint;
  }

  /// Font domanda. Default [QuizPlayerTypeScale.legacy] (Assigned-safe).
  static double questionFontSize(
    BuildContext context, {
    String? prompt,
    QuizPlayerTypeScale scale = QuizPlayerTypeScale.legacy,
  }) {
    if (scale == QuizPlayerTypeScale.legacy) {
      return isCompact(context)
          ? questionFontLegacyMobile
          : questionFontLegacyDesktop;
    }

    final size = MediaQuery.sizeOf(context);
    var base = switch (viewportClassFor(size.width)) {
      QuizPlayerViewportClass.mobile => questionFontMobile,
      QuizPlayerViewportClass.tablet => questionFontTablet,
      QuizPlayerViewportClass.desktop => questionFontDesktop,
      QuizPlayerViewportClass.largeDesktop => questionFontLargeDesktop,
    };
    if (size.height < lowHeightBreakpoint &&
        viewportClassFor(size.width) == QuizPlayerViewportClass.largeDesktop) {
      base = questionFontDesktop;
    } else if (size.height < lowHeightBreakpoint &&
        viewportClassFor(size.width) == QuizPlayerViewportClass.desktop) {
      base = math.min(base, 24.0);
    }
    final len = prompt?.trim().length ?? 0;
    if (len > 280) return math.max(base * 0.90, questionFontMobile);
    if (len > 180) return math.max(base * 0.95, questionFontMobile);
    return base;
  }

  /// Font risposta. Default [QuizPlayerTypeScale.legacy] (Assigned-safe).
  static double answerFontSize(
    BuildContext context, {
    QuizPlayerTypeScale scale = QuizPlayerTypeScale.legacy,
  }) {
    if (scale == QuizPlayerTypeScale.legacy) {
      return isCompact(context)
          ? answerFontLegacyMobile
          : answerFontLegacyDesktop;
    }

    final size = MediaQuery.sizeOf(context);
    var base = switch (viewportClassFor(size.width)) {
      QuizPlayerViewportClass.mobile => answerFontMobile,
      QuizPlayerViewportClass.tablet => answerFontTablet,
      QuizPlayerViewportClass.desktop => answerFontDesktop,
      QuizPlayerViewportClass.largeDesktop => answerFontLargeDesktop,
    };
    if (size.height < lowHeightBreakpoint &&
        viewportClassFor(size.width) == QuizPlayerViewportClass.largeDesktop) {
      base = answerFontDesktop;
    } else if (size.height < lowHeightBreakpoint &&
        viewportClassFor(size.width) == QuizPlayerViewportClass.desktop) {
      base = math.min(base, 19.5);
    }
    return base;
  }

  static TextStyle questionStyle(
    BuildContext context, {
    String? prompt,
    QuizPlayerTypeScale scale = QuizPlayerTypeScale.legacy,
  }) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
      color: ink,
      fontWeight: FontWeight.w700,
      height: scale == QuizPlayerTypeScale.classroom ? 1.32 : 1.35,
      fontSize: questionFontSize(context, prompt: prompt, scale: scale),
    );
  }

  static TextStyle answerStyle(
    BuildContext context, {
    QuizPlayerTypeScale scale = QuizPlayerTypeScale.legacy,
  }) {
    return Theme.of(context).textTheme.titleSmall!.copyWith(
      color: ink,
      fontWeight: FontWeight.w600,
      height: scale == QuizPlayerTypeScale.classroom ? 1.32 : 1.35,
      fontSize: answerFontSize(context, scale: scale),
    );
  }
}
