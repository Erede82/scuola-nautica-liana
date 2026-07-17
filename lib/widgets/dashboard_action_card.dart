import 'package:flutter/material.dart';

import '../theme/app_visual_tokens.dart';

/// Small label shown on dashboard tiles — keeps palette cohesive.
enum DashboardCardBadge { none, premium, nuovo, prossimamente }

extension on DashboardCardBadge {
  String? get label {
    switch (this) {
      case DashboardCardBadge.none:
        return null;
      case DashboardCardBadge.premium:
        return 'Premium';
      case DashboardCardBadge.nuovo:
        return 'Nuovo';
      case DashboardCardBadge.prossimamente:
        return 'Prossimamente';
    }
  }

  Color backgroundColor(
    Color primary,
    Color accent,
    Color success,
    Color neutral,
  ) {
    switch (this) {
      case DashboardCardBadge.none:
        return neutral;
      case DashboardCardBadge.premium:
        return accent.withValues(alpha: 0.22);
      case DashboardCardBadge.nuovo:
        return success.withValues(alpha: 0.18);
      case DashboardCardBadge.prossimamente:
        return neutral;
    }
  }

  Color foregroundColor(
    Color primary,
    Color accent,
    Color success,
    Color textPrimary,
  ) {
    switch (this) {
      case DashboardCardBadge.none:
        return textPrimary;
      case DashboardCardBadge.premium:
        return primary;
      case DashboardCardBadge.nuovo:
        return success;
      case DashboardCardBadge.prossimamente:
        return textPrimary.withValues(alpha: 0.85);
    }
  }
}

/// Dashboard tile with subtle press scale, soft shadow shift, and optional badge.
class DashboardActionCard extends StatefulWidget {
  const DashboardActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge = DashboardCardBadge.none,
    this.unreadCount,
    this.dense = false,
    this.backgroundTint,
    this.useStudentBrandStyle = false,
    this.titleMaxLines,
    this.compactContent = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final DashboardCardBadge badge;

  /// Badge numerico (es. Guida non letti). Se > 0 sostituisce il pill [badge] in alto a destra.
  final int? unreadCount;

  /// Layout compatto per griglie strette (es. home 2×2 su desktop).
  final bool dense;

  /// Sfondo raffinato in palette (es. home: tint diversa per sezione).
  final Color? backgroundTint;

  /// Stile allievo: stessa identità premium (avorio + blu logo); leggermente più enfasi colore.
  final bool useStudentBrandStyle;

  /// Se valorizzato, limita le righe del titolo (es. titoli lunghi in griglia).
  /// Default `null` = comportamento storico (nessun limite esplicito).
  final int? titleMaxLines;

  /// Padding/gap ridotti solo dove serve (es. tile con titolo lungo).
  /// Default `false` = metriche storiche invariate.
  final bool compactContent;

  static const Color _successColor = Color(0xFF2E9E5B);

  @override
  State<DashboardActionCard> createState() => _DashboardActionCardState();
}

class _DashboardActionCardState extends State<DashboardActionCard> {
  bool _pressed = false;

  static const Duration _animDuration = Duration(milliseconds: 120);
  static const Curve _animCurve = Curves.easeOutCubic;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badgeLabel = widget.badge.label;
    final unread = widget.unreadCount;
    final showUnread = unread != null && unread > 0;
    final showMarketingBadge = badgeLabel != null && !showUnread;
    final d = widget.dense;
    final compact = widget.compactContent;
    final isBrand = widget.useStudentBrandStyle;
    final cardColor = widget.backgroundTint ?? AppVisual.ivory;

    final iconBox = d ? (compact ? 36.0 : 44.0) : 48.0;
    final iconSize = d ? (compact ? 22.0 : 26.0) : 28.0;
    final pad = d
        ? EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 12 : 20,
          )
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 22);
    final gapAfterIcon = d ? (compact ? 8.0 : 12.0) : 14.0;
    final gapTitleToSubtitle = d ? (compact ? 6.0 : 10.0) : 16.0;
    final subtitleMaxLines = d ? 2 : 3;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: _animDuration,
      curve: _animCurve,
      child: AnimatedContainer(
        duration: _animDuration,
        curve: _animCurve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBrand
                ? AppVisual.logoBlue.withValues(alpha: 0.22)
                : AppVisual.border.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: AppVisual.ink.withValues(alpha: _pressed ? 0.05 : 0.09),
              blurRadius: _pressed ? 6 : 14,
              offset: Offset(0, _pressed ? 2 : 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  splashColor: AppVisual.logoBlue.withValues(
                    alpha: isBrand ? 0.12 : 0.08,
                  ),
                  highlightColor: AppVisual.logoBlue.withValues(
                    alpha: isBrand ? 0.06 : 0.04,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  onTapDown: (_) => _setPressed(true),
                  onTapCancel: () => _setPressed(false),
                  onTapUp: (_) => _setPressed(false),
                  onTap: widget.onTap,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxH = constraints.maxHeight;
                      final content = Center(
                        child: Padding(
                          padding: pad,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: iconBox,
                                height: iconBox,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isBrand
                                      ? AppVisual.logoBlue
                                      : AppVisual.logoBlue.withValues(
                                          alpha: 0.12,
                                        ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isBrand
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : AppVisual.logoBlue.withValues(
                                            alpha: 0.15,
                                          ),
                                  ),
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: isBrand
                                      ? Colors.white
                                      : AppVisual.logoBlue,
                                  size: iconSize,
                                ),
                              ),
                              SizedBox(height: gapAfterIcon),
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                maxLines: widget.titleMaxLines,
                                overflow: widget.titleMaxLines != null
                                    ? TextOverflow.ellipsis
                                    : TextOverflow.visible,
                                style:
                                    (d
                                            ? textTheme.titleSmall
                                            : textTheme.titleMedium)
                                        ?.copyWith(
                                          color: AppVisual.ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                              ),
                              SizedBox(height: gapTitleToSubtitle),
                              Text(
                                widget.subtitle,
                                maxLines: subtitleMaxLines,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppVisual.ink.withValues(alpha: 0.82),
                                  height: d ? 1.28 : 1.3,
                                  fontSize: d ? 11.5 : null,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (maxH.isFinite) {
                        return SizedBox(
                          width: double.infinity,
                          height: maxH,
                          child: content,
                        );
                      }
                      return SizedBox(width: double.infinity, child: content);
                    },
                  ),
                ),
                if (showMarketingBadge)
                  Positioned(
                    top: d ? 7 : 10,
                    right: d ? 7 : 10,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _pressed ? 0.92 : 1.0,
                        duration: _animDuration,
                        curve: _animCurve,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: d ? 6 : 8,
                            vertical: d ? 3 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: isBrand
                                ? AppVisual.accentLight.withValues(alpha: 0.22)
                                : widget.badge.backgroundColor(
                                    AppVisual.logoBlue,
                                    AppVisual.brandAzure,
                                    DashboardActionCard._successColor,
                                    AppVisual.chipFill,
                                  ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isBrand
                                  ? AppVisual.logoBlue.withValues(alpha: 0.35)
                                  : AppVisual.border,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badgeLabel,
                            style: textTheme.labelSmall?.copyWith(
                              color: isBrand
                                  ? AppVisual.logoBlue
                                  : widget.badge.foregroundColor(
                                      AppVisual.logoBlue,
                                      AppVisual.brandAzure,
                                      DashboardActionCard._successColor,
                                      AppVisual.ink,
                                    ),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              fontSize: d ? 9 : 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showUnread)
                  Positioned(
                    top: d ? 6 : 8,
                    right: d ? 6 : 8,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _pressed ? 0.92 : 1.0,
                        duration: _animDuration,
                        curve: _animCurve,
                        child: Container(
                          constraints: BoxConstraints(minWidth: d ? 20 : 22),
                          padding: EdgeInsets.symmetric(
                            horizontal: d ? 6 : 7,
                            vertical: d ? 3 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: isBrand ? Colors.white : AppVisual.logoBlue,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isBrand
                                  ? AppVisual.logoBlue.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.85),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppVisual.ink.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall?.copyWith(
                              color: isBrand
                                  ? AppVisual.logoBlue
                                  : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: d ? 10 : 11,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
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
