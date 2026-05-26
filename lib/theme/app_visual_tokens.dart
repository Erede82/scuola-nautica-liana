import 'package:flutter/material.dart';

/// Identità visiva premium: beige caldo, testo inchiostro, blu logo e azzurri come accenti.
abstract final class AppVisual {
  /// Sfondo dominante (scaffold, drawer body, canvas).
  static const Color warmBeige = Color(0xFFC7B299);
  static const Color beigeHighlight = Color(0xFFD2C4B0);
  static const Color beigeDepth = Color(0xFFC5B396);

  /// Carte / campi / superfici chiare sul beige.
  static const Color ivory = Color(0xFFF7F3ED);
  static const Color ivoryDeep = Color(0xFFEDE6DC);

  static const Color ink = Color(0xFF0A0A0A);
  static const Color inkMuted = Color(0xFF4A4540);

  static const Color logoBlue = Color(0xFF005E83);
  static const Color logoBlueDeep = Color(0xFF004A66);
  static const Color brandAzure = Color(0xFF17A1C8);
  static const Color accentLight = Color(0xFF6FD6E8);

  /// Bordi caldi (non grigio-azzurro “clinical”).
  static const Color border = Color(0xFFC4B4A3);
  static const Color chipFill = Color(0xFFE8DFD4);

  static const Color success = Color(0xFF2E9E5B);
  static const Color error = Color(0xFFD64545);

  static const Color canvas = warmBeige;
  static const Color surface = ivory;
}
