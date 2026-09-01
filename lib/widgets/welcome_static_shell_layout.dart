import 'package:flutter/material.dart';

import '../constants/app_branding.dart';

/// Composizione statica Welcome-like per shell HTML/Flutter (solo rendering).
///
/// Testi e gradient allineati alla hero [WelcomePage]; nessuna interazione.
abstract final class WelcomeStaticShellLayout {
  static const Color fallbackBg = Color(0xFF0A1620);

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
}

/// Foreground Welcome-like per [StartupVisualShell] (nessun input).
class WelcomeStaticShellForeground extends StatelessWidget {
  const WelcomeStaticShellForeground({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 900;
    final cramped = isCompact && size.height < 720;
    final horizontalPadding = isCompact ? 24.0 : 40.0;
    final verticalPadding = isCompact ? (cramped ? 12.0 : 20.0) : 36.0;
    final logoHeight = cramped ? 56.0 : (isCompact ? 70.0 : 86.0);

    return LayoutBuilder(
      builder: (context, viewport) {
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StaticHeroLogo(height: logoHeight),
                  ),
                  SizedBox(height: cramped ? 12 : 24),
                  _StaticHeroCopy(
                    cramped: cramped,
                    isCompact: isCompact,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StaticHeroLogo extends StatelessWidget {
  const _StaticHeroLogo({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.52),
            blurRadius: 26,
            spreadRadius: -1,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.14),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Image.asset(
        AppBranding.logoMarkWhite,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => SizedBox(height: height),
      ),
    );
  }
}

class _StaticHeroCopy extends StatelessWidget {
  const _StaticHeroCopy({
    required this.cramped,
    required this.isCompact,
  });

  final bool cramped;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            AppBranding.schoolName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: cramped ? 32 : (isCompact ? 40 : 68),
              fontWeight: FontWeight.w700,
              height: 1.08,
              letterSpacing: isCompact ? 0.2 : 0.35,
            ),
          ),
        ),
        SizedBox(height: cramped ? 10 : (isCompact ? 12 : 14)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            WelcomeStaticShellLayout.welcomeSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: cramped ? 16 : (isCompact ? 17 : 20),
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
        SizedBox(height: cramped ? 10 : (isCompact ? 12 : 14)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Text(
            WelcomeStaticShellLayout.welcomeEditorial,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: cramped ? 13 : (isCompact ? 14 : 15),
              height: 1.55,
            ),
          ),
        ),
        SizedBox(height: cramped ? 12 : 22),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: const [
            _StaticOutlineCta(
              label: WelcomeStaticShellLayout.ctaAccedi,
              compact: false,
            ),
            _StaticOutlineCta(
              label: WelcomeStaticShellLayout.ctaRegistrati,
              compact: false,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          WelcomeStaticShellLayout.ctaForgot,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isCompact ? (cramped ? 14 : 20) : 22),
        const _StaticOutlineCta(
          label: WelcomeStaticShellLayout.ctaScoprici,
          compact: true,
        ),
      ],
    );
  }
}

/// CTA visiva statica (stile outline hero Welcome, senza interazione).
class _StaticOutlineCta extends StatelessWidget {
  const _StaticOutlineCta({
    required this.label,
    required this.compact,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 22, vertical: 14)
        : const EdgeInsets.symmetric(horizontal: 28, vertical: 18);
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: compact ? 13 : 15,
      fontWeight: FontWeight.w700,
      letterSpacing: compact ? 1.05 : 0,
    );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.50),
          width: 1.2,
        ),
      ),
      child: Text(label, style: textStyle),
    );
  }
}
