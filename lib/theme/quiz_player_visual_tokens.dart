import 'package:flutter/material.dart';

import 'app_visual_tokens.dart';

/// Metriche e colori condivisi tra Quiz Esame e Schede lezione.
///
/// Fonte unica per evitare scale e contrasti diversi nei due player.
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

  static const double contentMaxWidth = 720;

  static const double questionFontDesktop = 18.5;
  static const double questionFontMobile = 17.0;

  static const double answerFontDesktop = 16.5;
  static const double answerFontMobile = 16.0;

  static const double answerMinHeight = 52;
  static const double answerMinHeightDense = 45;
  static const double cardRadius = 14;
  static const double cardPadding = 14;
  static const double cardPaddingDense = 10;
  static const double sectionSpacing = 10;
  static const double sectionSpacingDense = 6;
  static const double answerSpacing = 8;
  static const double answerSpacingDense = 5;

  static const EdgeInsets answerPadding = EdgeInsets.fromLTRB(12, 12, 10, 12);
  static const EdgeInsets answerPaddingDense = EdgeInsets.fromLTRB(
    12,
    8,
    10,
    8,
  );
  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(16, 10, 16, 16);
  static const EdgeInsets progressPanelMargin = EdgeInsets.fromLTRB(
    16,
    8,
    16,
    0,
  );
  static const EdgeInsets progressPanelPadding = EdgeInsets.fromLTRB(
    10,
    8,
    10,
    8,
  );

  static const double bottomBarPaddingV = 8;
  static const double bottomButtonPaddingV = 14;

  /// Breakpoint mobile condiviso (esame e scheda).
  static const double compactWidthBreakpoint = 600;

  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < compactWidthBreakpoint;
  }

  static double questionFontSize(BuildContext context) =>
      isCompact(context) ? questionFontMobile : questionFontDesktop;

  static double answerFontSize(BuildContext context) =>
      isCompact(context) ? answerFontMobile : answerFontDesktop;

  static TextStyle questionStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge!.copyWith(
      color: ink,
      fontWeight: FontWeight.w700,
      height: 1.35,
      fontSize: questionFontSize(context),
    );
  }

  static TextStyle answerStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleSmall!.copyWith(
      color: ink,
      fontWeight: FontWeight.w600,
      height: 1.35,
      fontSize: answerFontSize(context),
    );
  }
}
