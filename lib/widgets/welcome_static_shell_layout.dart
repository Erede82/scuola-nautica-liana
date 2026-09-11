import 'package:flutter/material.dart';

/// Costanti hero Welcome + colore startup condiviso (STARTUP.DECISIVE).
///
/// Startup (Apple / HTML / StartupVisualShell) =
/// Azzurro Capri `#00BFFF` + logo bianco + «Scuola Nautica Liana».
/// Welcome Flutter resta l'unica superficie boat/copy/CTA.
abstract final class WelcomeStaticShellLayout {
  /// Azzurro Capri — unico background pre-Welcome (STARTUP.DECISIVE).
  static const Color fallbackBg = Color(0xFF00BFFF);

  /// Altezza logo startup (logical px).
  static const double startupLogoHeight = 100;

  /// Gap logo → titolo brand sullo splash.
  static const double startupLogoToTitleGap = 24;

  /// Titolo brand sullo splash (Montserrat Bold).
  static const double startupTitleFontSize = 22;

  /// Stessi stop/alpha della hero Welcome (`0.72 → 0.62 → 0.55 → 0.48`).
  static const LinearGradient heroOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.35, 0.65, 1.0],
    colors: [
      Color(0xB8000000), // 0.72
      Color(0x9E000000), // 0.62
      Color(0x8C000000), // 0.55
      Color(0x7A000000), // 0.48
    ],
  );

  static const String welcomeSubtitle =
      'Benvenuto, sei pronto a navigare con noi?';

  static const String welcomeEditorial =
      "Un'esperienza di studio che parte dalla scuola e guarda subito al mare.";

  static const String ctaAccedi = 'Accedi';
  static const String ctaRegistrati = 'Registrati';
  static const String ctaForgot = 'Password dimenticata?';
  static const String ctaScoprici = 'SCOPRICI';

  /// Allineati a Welcome desktop FRONT.3 (usati dai test Welcome, non dallo splash).
  static const double desktopLogoHeight = 86;
  /// Area copy FRONT.8 (ancoraggio CTA): logoHeight + questo gap dall'alto Stack.
  static const double desktopLogoToCopyGap = 24;
  /// FRONT.FINAL: distanza geometrica logo.bottom → title.top.
  static const double desktopLogoToTitleGap = 28;
  static const double desktopHorizontalPadding = 40;
  static const double desktopVerticalPadding = 36;
}
