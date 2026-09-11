import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import 'welcome_static_shell_layout.dart';

/// Shell startup: Capri + logo + «Scuola Nautica Liana» (STARTUP.DECISIVE).
///
/// Nessuna boat/gradient/CTA — [WelcomePage] è l'unico layer hero completo.
/// [IgnorePointer] evita input fantasma durante cold start.
class StartupVisualShell extends StatelessWidget {
  const StartupVisualShell({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Scaffold(
        backgroundColor: WelcomeStaticShellLayout.fallbackBg,
        body: ColoredBox(
          color: WelcomeStaticShellLayout.fallbackBg,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppBranding.logoMarkWhite,
                  height: WelcomeStaticShellLayout.startupLogoHeight,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => SizedBox(
                    height: WelcomeStaticShellLayout.startupLogoHeight,
                  ),
                ),
                const SizedBox(
                  height: WelcomeStaticShellLayout.startupLogoToTitleGap,
                ),
                Text(
                  AppBranding.schoolName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: WelcomeStaticShellLayout.startupTitleFontSize,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
