import 'package:flutter/material.dart';

import '../models/extra_content_item.dart';
import '../theme/app_visual_tokens.dart';

/// Card catalogo Extra con stati: sbloccato, premium bloccato, prossimamente.
class ExtraCatalogCard extends StatelessWidget {
  const ExtraCatalogCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final ExtraContentItem item;
  final VoidCallback onTap;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _successColor = Color(0xFF2E9E5B);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _neutralColor = AppVisual.chipFill;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final state = item.uiState;
    final isComingSoon = state == ExtraCatalogUiState.comingSoon;
    final isLocked = state == ExtraCatalogUiState.premiumLocked;
    final included = item.isIncludedAppBenefit;

    final opacity = isComingSoon ? 0.88 : (isLocked ? 0.94 : 1.0);
    final borderColor = isComingSoon
        ? _neutralColor
        : included
            ? _successColor.withValues(alpha: 0.45)
            : isLocked
                ? _primaryColor.withValues(alpha: 0.22)
                : _neutralColor;
    final borderWidth = (isLocked || included) ? 1.2 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isComingSoon ? 0.03 : (included ? 0.07 : 0.06),
                  ),
                  blurRadius: included ? 16 : (isLocked ? 10 : 14),
                  offset: Offset(0, isComingSoon ? 2 : (included ? 5 : 4)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isComingSoon
                              ? [
                                  _neutralColor,
                                  _neutralColor.withValues(alpha: 0.85),
                                ]
                              : included
                                  ? [
                                      _successColor.withValues(alpha: 0.95),
                                      _primaryColor.withValues(alpha: 0.82),
                                    ]
                                  : [
                                      _accentColor.withValues(alpha: 0.9),
                                      _primaryColor.withValues(alpha: 0.75),
                                    ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: included
                                        ? _successColor.withValues(alpha: 0.12)
                                        : _primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: included
                                          ? _successColor.withValues(alpha: 0.28)
                                          : _neutralColor,
                                    ),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: isComingSoon
                                        ? _textPrimaryColor.withValues(alpha: 0.45)
                                        : included
                                            ? _successColor.withValues(alpha: 0.92)
                                            : _primaryColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title,
                                              style: textTheme.titleSmall
                                                  ?.copyWith(
                                                color: _textPrimaryColor,
                                                fontWeight: FontWeight.w800,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                          if (included)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4,
                                              ),
                                              child: Icon(
                                                Icons.verified_rounded,
                                                size: 20,
                                                color: _successColor
                                                    .withValues(alpha: 0.9),
                                              ),
                                            ),
                                          if (isLocked)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 6,
                                              ),
                                              child: Icon(
                                                Icons.lock_rounded,
                                                size: 18,
                                                color: _primaryColor
                                                    .withValues(alpha: 0.75),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.subtitle,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: _textPrimaryColor
                                              .withValues(alpha: 0.76),
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: _textPrimaryColor.withValues(alpha: 0.88),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _Pill(
                                  label: item.type.label,
                                  subtle: true,
                                ),
                                if (item.lessonCount != null)
                                  _Pill(
                                    label: '${item.lessonCount} lezioni',
                                    subtle: true,
                                  ),
                                if (item.durationLabel != null)
                                  _Pill(
                                    label: item.durationLabel!,
                                    subtle: true,
                                  ),
                                if (item.badgeLabel != null)
                                  _StatusPill(
                                    label: item.badgeLabel!,
                                    state: state,
                                    isIncludedBenefit: included,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.subtle = false});

  final String label;
  final bool subtle;

  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: subtle ? _neutralColor.withValues(alpha: 0.55) : _neutralColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: _textPrimaryColor.withValues(alpha: 0.85),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.state,
    this.isIncludedBenefit = false,
  });

  final String label;
  final ExtraCatalogUiState state;
  final bool isIncludedBenefit;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _successColor = Color(0xFF2E9E5B);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    late Color bg;
    late Color fg;

    switch (state) {
      case ExtraCatalogUiState.unlocked:
        if (isIncludedBenefit) {
          bg = _successColor.withValues(alpha: 0.22);
          fg = _successColor;
        } else {
          bg = _successColor.withValues(alpha: 0.18);
          fg = _successColor;
        }
        break;
      case ExtraCatalogUiState.premiumLocked:
        bg = _accentColor.withValues(alpha: 0.22);
        fg = _primaryColor;
        break;
      case ExtraCatalogUiState.comingSoon:
        bg = _neutralColor.withValues(alpha: 0.85);
        fg = _textPrimaryColor.withValues(alpha: 0.78);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isIncludedBenefit
              ? _successColor.withValues(alpha: 0.35)
              : _neutralColor.withValues(alpha: 0.9),
          width: isIncludedBenefit ? 1 : 0.7,
        ),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}
