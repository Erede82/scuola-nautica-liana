import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import 'welcome_asset_hints.dart';

/// Shell visuale di startup allineata alla hero Welcome (foto + overlay + logo).
///
/// Solo rendering: nessuna logica Auth/bootstrap.
class StartupVisualShell extends StatelessWidget {
  const StartupVisualShell({super.key});

  static const Color fallbackBg = Color(0xFF0A1620);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fallbackBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _BoatBackground(
            cacheWidth: WelcomeAssetHints.heroCacheWidth(context),
          ),
          const ColoredBox(color: Color(0x8C000000)),
          const Center(
            child: _OfficialMark(),
          ),
        ],
      ),
    );
  }
}

class _BoatBackground extends StatelessWidget {
  const _BoatBackground({this.cacheWidth});

  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppBranding.welcomeBoatJpg,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) =>
          const ColoredBox(color: StartupVisualShell.fallbackBg),
    );
  }
}

class _OfficialMark extends StatelessWidget {
  const _OfficialMark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppBranding.logoMarkWhite,
      width: 168,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}
