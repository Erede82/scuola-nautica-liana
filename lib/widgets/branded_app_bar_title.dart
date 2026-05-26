import 'package:flutter/material.dart';

import '../constants/app_branding.dart';

/// Titolo AppBar: marchio bianco (simbolo) + testo, senza glow o contenitori
/// semitrasparenti — per fondo blu (home e sezioni allievo).
class SectionAppBarTitle extends StatelessWidget {
  const SectionAppBarTitle(
    this.title, {
    super.key,
    this.logoHeight = 24,
  });

  final String title;
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge;
    final textStyle = base?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppBranding.logoMarkWhite,
            height: logoHeight,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
          Text(title, style: textStyle),
        ],
      ),
    );
  }
}

/// Pannello admin: simbolo + testo bianco, stesso criterio visivo.
class AdminPanelAppBarTitle extends StatelessWidget {
  const AdminPanelAppBarTitle({
    super.key,
    required this.title,
    this.logoHeight = 24,
  });

  final String title;
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return SectionAppBarTitle(
      title,
      logoHeight: logoHeight,
    );
  }
}
