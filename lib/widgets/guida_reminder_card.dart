import 'package:flutter/material.dart';

import '../models/guida_reminder.dart';
import '../utils/guida_datetime_format.dart';
import 'guida_reminder_status_chip.dart';
import '../theme/app_visual_tokens.dart';

/// Card promemoria per elenco Guida.
class GuidaReminderCard extends StatelessWidget {
  const GuidaReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    this.isInArchivio = false,
  });

  final GuidaReminder reminder;
  final VoidCallback onTap;

  /// Nelle card archivio: nessun testo "Da leggere" sul chip, "Completato" come "Svolta";
  /// nessun indicatore di non letto (punto) su archivio.
  final bool isInArchivio;

  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _neutralColor = AppVisual.chipFill;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final highlight = reminder.shouldHighlight;
    final dateStr = GuidaDateTimeFormat.formatDate(reminder.scheduledAt);
    final timeStr = GuidaDateTimeFormat.formatTime(
      reminder.scheduledAt,
      override: reminder.timeDisplayOverride,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlight
                  ? _accentColor.withValues(alpha: 0.55)
                  : _neutralColor,
              width: highlight ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: highlight ? 0.07 : 0.045),
                blurRadius: highlight ? 14 : 10,
                offset: Offset(0, highlight ? 5 : 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: highlight
                        ? _accentColor
                        : _neutralColor.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          reminder.title,
                                          style: textTheme.titleSmall?.copyWith(
                                            color: _textPrimaryColor,
                                            fontWeight: FontWeight.w800,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                      if (reminder.isUnread && !isInArchivio)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(
                                            left: 6,
                                            top: 4,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: _accentColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Istruttore',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: _textPrimaryColor.withValues(alpha: 0.55),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    reminder.instructorName,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: _textPrimaryColor
                                          .withValues(alpha: 0.82),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GuidaReminderStatusChip(
                              status: reminder.status,
                              compact: true,
                              hidden: isInArchivio &&
                                  reminder.status ==
                                      GuidaReminderStatus.daLeggere,
                              labelOverride: isInArchivio &&
                                      reminder.status ==
                                          GuidaReminderStatus.completato
                                  ? 'Svolta'
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaPill(
                              icon: Icons.calendar_today_rounded,
                              label: dateStr,
                            ),
                            _MetaPill(
                              icon: Icons.schedule_rounded,
                              label: timeStr,
                            ),
                            if (reminder.category != null)
                              _MetaPill(
                                icon: Icons.label_outline_rounded,
                                label: reminder.category!.label,
                                subtle: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          reminder.shortMessage,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: _textPrimaryColor.withValues(alpha: 0.92),
                            height: 1.45,
                          ),
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
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.subtle = false,
  });

  final IconData icon;
  final String label;
  final bool subtle;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: subtle
            ? _neutralColor.withValues(alpha: 0.45)
            : _neutralColor.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: _primaryColor
                .withValues(alpha: subtle ? 0.65 : 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
