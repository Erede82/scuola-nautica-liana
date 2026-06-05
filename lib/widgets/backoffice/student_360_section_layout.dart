import 'package:flutter/material.dart';

import '../../theme/app_visual_tokens.dart';

/// Scroll sicuro per tab TabBarView: niente [Expanded] nel child, larghezza vincolata.
class Student360SectionScroll extends StatelessWidget {
  const Student360SectionScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppVisual.canvas,
      child: LayoutBuilder(
        builder: (context, outer) {
          final compact = outer.maxWidth < student360TwoColumnBreakpoint;
          final pad = compact ? 12.0 : 16.0;
          final contentWidth = outer.maxWidth.isFinite
              ? (outer.maxWidth - pad * 2).clamp(0.0, outer.maxWidth)
              : outer.maxWidth;

          return SingleChildScrollView(
            // TabBarView: evita conflitto con PrimaryScrollController (tab Documenti).
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad + 32),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: contentWidth.isFinite ? contentWidth : null,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class Student360SectionContent extends StatelessWidget {
  const Student360SectionContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class Student360InfoCard extends StatelessWidget {
  const Student360InfoCard({
    super.key,
    required this.title,
    required this.child,
    this.stretch = false,
    this.minHeight,
  });

  final String title;
  final Widget child;

  /// Riempie l’altezza quando la card è in una riga [Student360SiblingCardsRow].
  final bool stretch;

  /// Altezza minima per bilanciare card sorelle su desktop.
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < student360TwoColumnBreakpoint;
    final padding = compact ? 12.0 : 16.0;
    final titleGap = compact ? 8.0 : 12.0;
    final textTheme = Theme.of(context).textTheme;
    final body = stretch
        ? Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: child,
            ),
          )
        : child;

    return Container(
      width: double.infinity,
      constraints: minHeight != null
          ? BoxConstraints(minHeight: minHeight!)
          : null,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppVisual.ivory,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: AppVisual.chipFill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: AppVisual.ink,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 15 : null,
            ),
          ),
          SizedBox(height: titleGap),
          body,
        ],
      ),
    );
  }
}

/// Due card affiancate con stessa altezza su desktop ([IntrinsicHeight], senza scroll risk).
class Student360SiblingCardsRow extends StatelessWidget {
  const Student360SiblingCardsRow({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 12,
    this.breakpoint = student360TwoColumnBreakpoint,
  });

  final Widget left;
  final Widget right;
  final double spacing;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final wide = maxW.isFinite && maxW > 0 && maxW >= breakpoint;

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              left,
              SizedBox(height: spacing),
              right,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              SizedBox(width: spacing),
              Expanded(child: right),
            ],
          ),
        );
      },
    );
  }
}

/// Soglia larghezza per layout a due colonne (Scheda allievo, iscrizione/pratica).
const double student360TwoColumnBreakpoint = 720;

Widget student360SubsectionTitle(String title, TextTheme textTheme) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Text(
      title,
      style: textTheme.labelLarge?.copyWith(
        color: AppVisual.ink,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

Widget student360KvRow(
  String k,
  String v,
  TextTheme textTheme, {
  double labelWidth = 160,
  double bottomPadding = 12,
}) {
  const textColor = AppVisual.ink;
  return Padding(
    padding: EdgeInsets.only(bottom: bottomPadding),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            k,
            style: textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            v,
            style: textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Due colonne affiancate su desktop; impilato su mobile. Senza [Expanded] su asse orizzontale non vincolato.
class Student360ResponsiveRow extends StatelessWidget {
  const Student360ResponsiveRow({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = student360TwoColumnBreakpoint,
    this.spacing = 16,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.leftFixedWidth,
  });

  final Widget left;
  final Widget right;
  final double breakpoint;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  /// Se valorizzato, colonna sinistra a larghezza fissa (es. foto 200px).
  final double? leftFixedWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final hasBoundedWidth = maxW.isFinite && maxW > 0;
        final wide = hasBoundedWidth && maxW >= breakpoint;

        if (wide) {
          final leftW = leftFixedWidth ?? (maxW - spacing) / 2;
          final rightW = (maxW - leftW - spacing).clamp(0.0, maxW);
          return Row(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              SizedBox(width: leftW, child: left),
              SizedBox(width: spacing),
              SizedBox(width: rightW, child: right),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            left,
            SizedBox(height: spacing),
            right,
          ],
        );
      },
    );
  }
}
