import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import 'welcome_asset_hints.dart';
import 'welcome_static_shell_layout.dart';

/// Shell visuale di startup allineata alla hero Welcome (foto + overlay + copy).
///
/// Solo rendering: nessuna logica Auth/bootstrap. [IgnorePointer] evita input
/// fantasma durante cold start / snapshot iOS.
class StartupVisualShell extends StatelessWidget {
  const StartupVisualShell({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Scaffold(
        backgroundColor: WelcomeStaticShellLayout.fallbackBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _BoatBackground(
              cacheWidth: WelcomeAssetHints.heroCacheWidth(context),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: WelcomeStaticShellLayout.heroOverlayGradient,
              ),
            ),
            const SafeArea(
              bottom: false,
              child: _ShellHeroForeground(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellHeroForeground extends StatelessWidget {
  const _ShellHeroForeground();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        return WelcomeStaticShellForeground(viewportConstraints: viewport);
      },
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
      errorBuilder: (_, _, _) => const ColoredBox(
        color: WelcomeStaticShellLayout.fallbackBg,
      ),
    );
  }
}
