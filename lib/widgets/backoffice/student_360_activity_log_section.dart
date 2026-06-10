import 'package:flutter/material.dart';

import '../../domain/backoffice/backoffice.dart';
import 'backoffice_formatters.dart';
import 'backoffice_ui_tokens.dart';
import 'student_360_section_layout.dart';

/// Storico attività staff sulla Scheda 360 (da `StudentAdmin360View.activityLog`).
class Student360ActivityLogSection extends StatelessWidget {
  const Student360ActivityLogSection({
    super.key,
    required this.view,
    this.maxEvents = 80,
  });

  final StudentAdmin360View view;
  final int maxEvents;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final acts = view.activityLog;

    return Student360InfoCard(
      title: 'Storico attività',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Registro delle attività operative eseguite sul profilo allievo.',
            style: textTheme.bodySmall?.copyWith(
              color: BackofficeUiTokens.text.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 12),
          if (acts.isEmpty)
            Text('Nessun evento ancora.', style: textTheme.bodyMedium)
          else
            ...acts.take(maxEvents).map((e) => _ActivityEventRow(event: e)),
        ],
      ),
    );
  }
}

class _ActivityEventRow extends StatelessWidget {
  const _ActivityEventRow({required this.event});

  final BackofficeActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chipLabel =
        BackofficeFormatters.activityFollowUpChipLabel(event.title);
    final chipResolved = chipLabel != null &&
        BackofficeFormatters.activityFollowUpChipIsResolved(event.title);
    final chipBg = chipResolved
        ? BackofficeUiTokens.success.withValues(alpha: 0.14)
        : BackofficeUiTokens.primary.withValues(alpha: 0.12);
    final chipFg =
        chipResolved ? BackofficeUiTokens.success : BackofficeUiTokens.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: BackofficeUiTokens.neutral),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              child: Text(
                BackofficeFormatters.dateTimeUi(event.occurredAt),
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: BackofficeUiTokens.text.withValues(alpha: 0.75),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        event.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (chipLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: chipFg.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            chipLabel,
                            style: textTheme.labelSmall?.copyWith(
                              color: chipFg,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    BackofficeFormatters.activityType(event.type),
                    style: textTheme.labelSmall?.copyWith(
                      color: BackofficeUiTokens.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (event.description != null &&
                      event.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.description!,
                      style: textTheme.bodySmall?.copyWith(
                        height: 1.3,
                        color:
                            BackofficeUiTokens.text.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
