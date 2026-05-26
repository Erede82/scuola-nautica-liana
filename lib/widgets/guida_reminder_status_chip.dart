import 'package:flutter/material.dart';

import '../models/guida_reminder.dart';
import '../theme/app_visual_tokens.dart';

/// Badge stato promemoria Guida.
class GuidaReminderStatusChip extends StatelessWidget {
  const GuidaReminderStatusChip({
    super.key,
    required this.status,
    this.compact = false,
    this.hidden = false,
    this.labelOverride,
  });

  final GuidaReminderStatus status;
  final bool compact;

  /// Se true, non mostra lo stato (es. in archivio con stato "daLeggere" non va mostrato).
  final bool hidden;

  /// Sostituisce la label dallo enum (es. "Svolta" al posto di "Completato").
  final String? labelOverride;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _successColor = Color(0xFF2E9E5B);
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    late Color bg;
    late Color fg;

    switch (status) {
      case GuidaReminderStatus.daLeggere:
        bg = _accentColor.withValues(alpha: 0.22);
        fg = _primaryColor;
        break;
      case GuidaReminderStatus.confermato:
        bg = _primaryColor.withValues(alpha: 0.12);
        fg = _primaryColor;
        break;
      case GuidaReminderStatus.completato:
        bg = _successColor.withValues(alpha: 0.18);
        fg = _successColor;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _textPrimaryColor.withValues(alpha: 0.06),
          width: 0.6,
        ),
      ),
      child: Text(
        labelOverride ?? status.label,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: compact ? 10 : 11,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}
