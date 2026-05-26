import 'package:flutter/material.dart';

import '../../theme/app_visual_tokens.dart';

/// Colori backoffice — allineati a [AppVisual].
abstract final class BackofficeUiTokens {
  static const Color primary = AppVisual.logoBlue;
  static const Color accent = AppVisual.brandAzure;
  static const Color accentLight = AppVisual.accentLight;
  static const Color background = AppVisual.canvas;
  static const Color card = AppVisual.surface;
  static const Color border = AppVisual.border;
  static const Color success = AppVisual.success;
  static const Color error = AppVisual.error;
  static const Color neutral = AppVisual.chipFill;
  static const Color text = AppVisual.ink;
  static const Color textMuted = AppVisual.inkMuted;
}
