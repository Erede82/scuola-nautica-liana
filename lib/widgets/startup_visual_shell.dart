import 'package:flutter/material.dart';

import '../constants/app_branding.dart';

/// Shell visuale di startup allineata alla hero Welcome (foto + overlay + logo).
///
/// Solo rendering: nessuna logica Auth/bootstrap.
class StartupVisualShell extends StatelessWidget {
  const StartupVisualShell({super.key});

  static const Color fallbackBg = Color(0xFF0A1620);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: fallbackBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _BoatBackground(),
          ColoredBox(color: Color(0x8C000000)),
          Center(
            child: _OfficialMark(),
          ),
        ],
      ),
    );
  }
}

class _BoatBackground extends StatelessWidget {
  const _BoatBackground();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppBranding.welcomeBoatJpg,
      fit: BoxFit.cover,
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
