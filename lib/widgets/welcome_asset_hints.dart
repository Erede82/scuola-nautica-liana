import 'package:flutter/material.dart';

import '../constants/app_branding.dart';

/// Limiti decode/precache per Welcome su layout compatto (desktop resta full-res).
///
/// Usato da [WelcomePage] hero/card (FRONT.6: shell non decodifica più la boat).
/// FRONT.8: [heroProvider] è l'unica source ImageProvider per precache + Welcome.
abstract final class WelcomeAssetHints {
  static const int compactHeroMinCacheWidth = 960;
  static const int compactHeroMaxCacheWidth = 1600;
  static const int compactCardMaxCacheWidth = 1200;
  static const int loginLogoMaxCacheWidth = 480;

  static ImageProvider resizedAsset(
    String assetPath, {
    int? cacheWidth,
  }) {
    final provider = AssetImage(assetPath);
    if (cacheWidth == null) return provider;
    return ResizeImage(provider, width: cacheWidth);
  }

  /// Provider IDENTICO per precache gate e [WelcomePage] hero.
  static ImageProvider heroProvider(BuildContext context) {
    return resizedAsset(
      AppBranding.welcomeBoatJpg,
      cacheWidth: heroCacheWidth(context),
    );
  }

  static int? heroCacheWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (width * dpr * 1.1)
        .round()
        .clamp(compactHeroMinCacheWidth, compactHeroMaxCacheWidth);
  }

  static int? discoverCardCacheWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cardWidth = width >= 900 ? width / 2 : width - 40;
    return (cardWidth * dpr * 1.05)
        .round()
        .clamp(720, compactCardMaxCacheWidth);
  }

  static int? loginLogoCacheWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200) return null;
    final logoWidth = (width * 0.55).clamp(150.0, 210.0);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final target = (logoWidth * dpr * 1.15).round();
    if (target >= 760) return null;
    return target.clamp(300, loginLogoMaxCacheWidth);
  }
}
