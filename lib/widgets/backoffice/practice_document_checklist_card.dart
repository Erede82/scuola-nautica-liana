import 'package:flutter/material.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../theme/app_visual_tokens.dart';
import 'backoffice_formatters.dart';
import 'backoffice_ui_tokens.dart';

typedef PracticeDocumentUploadRequest = void Function({
  String? documentUiType,
  String? photoUiType,
});

/// Card checklist documenti richiesti per fascicolo pratica (Fase A — client-side).
class PracticeDocumentChecklistCard extends StatelessWidget {
  const PracticeDocumentChecklistCard({
    super.key,
    required this.checklist,
    required this.onUploadRequested,
  });

  final PracticeDocumentChecklist checklist;
  final PracticeDocumentUploadRequest onUploadRequested;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (!checklist.applicable) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppVisual.inkMuted.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documenti richiesti',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: BackofficeUiTokens.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tipo pratica: ${practiceTypeLabelIt(checklist.practiceType)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppVisual.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(
                  complete: checklist.isRequiredChecklistComplete,
                  missingCount: checklist.missingRequiredCount,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              checklist.isRequiredChecklistComplete
                  ? 'Checklist obbligatoria completa.'
                  : 'Mancano ${checklist.missingRequiredCount} documenti obbligatori.',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: checklist.isRequiredChecklistComplete
                    ? Colors.green.shade800
                    : Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 12),
            ...checklist.items.map(
              (item) => _ChecklistRow(
                item: item,
                onUpload: item.countsAsMissingRequired ||
                        item.status ==
                            PracticeDocumentChecklistItemStatus.recommendedMissing
                    ? () => onUploadRequested(
                        documentUiType: item.requirement.documentUiType,
                        photoUiType: item.requirement.photoUiType,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.complete,
    required this.missingCount,
  });

  final bool complete;
  final int missingCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bg = complete ? Colors.green.shade50 : Colors.orange.shade50;
    final fg = complete ? Colors.green.shade900 : Colors.orange.shade900;
    final label = complete ? 'Completa' : 'Mancano $missingCount';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.item,
    this.onUpload,
  });

  final PracticeDocumentChecklistItem item;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = item.status;
    final iconData = _iconForStatus(status);
    final iconColor = _colorForStatus(status);
    final statusLabel = _labelForStatus(status, item.requirement.level);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.requirement.label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  statusLabel,
                  style: textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
                ),
                if (item.matchedDocument?.expiresAt != null &&
                    (status == PracticeDocumentChecklistItemStatus.expired ||
                        status ==
                            PracticeDocumentChecklistItemStatus.expiringSoon))
                  Text(
                    'Scadenza: ${BackofficeFormatters.dateUi(item.matchedDocument!.expiresAt)}',
                    style: textTheme.bodySmall?.copyWith(color: iconColor),
                  ),
              ],
            ),
          ),
          if (onUpload != null)
            TextButton(
              onPressed: onUpload,
              child: const Text('Carica'),
            ),
        ],
      ),
    );
  }

  static IconData _iconForStatus(PracticeDocumentChecklistItemStatus status) {
    switch (status) {
      case PracticeDocumentChecklistItemStatus.present:
      case PracticeDocumentChecklistItemStatus.recommendedPresent:
        return Icons.check_circle_outline;
      case PracticeDocumentChecklistItemStatus.missing:
      case PracticeDocumentChecklistItemStatus.recommendedMissing:
        return Icons.radio_button_unchecked;
      case PracticeDocumentChecklistItemStatus.expired:
        return Icons.error_outline;
      case PracticeDocumentChecklistItemStatus.expiringSoon:
        return Icons.schedule_outlined;
    }
  }

  static Color _colorForStatus(PracticeDocumentChecklistItemStatus status) {
    switch (status) {
      case PracticeDocumentChecklistItemStatus.present:
      case PracticeDocumentChecklistItemStatus.recommendedPresent:
        return Colors.green.shade700;
      case PracticeDocumentChecklistItemStatus.missing:
      case PracticeDocumentChecklistItemStatus.recommendedMissing:
        return Colors.orange.shade800;
      case PracticeDocumentChecklistItemStatus.expired:
        return Colors.red.shade700;
      case PracticeDocumentChecklistItemStatus.expiringSoon:
        return Colors.amber.shade800;
    }
  }

  static String _labelForStatus(
    PracticeDocumentChecklistItemStatus status,
    PracticeDocumentRequirementLevel level,
  ) {
    switch (status) {
      case PracticeDocumentChecklistItemStatus.present:
        return 'Presente';
      case PracticeDocumentChecklistItemStatus.missing:
        return 'Mancante';
      case PracticeDocumentChecklistItemStatus.expired:
        return 'Scaduto';
      case PracticeDocumentChecklistItemStatus.expiringSoon:
        return 'In scadenza';
      case PracticeDocumentChecklistItemStatus.recommendedMissing:
        return level == PracticeDocumentRequirementLevel.recommended
            ? 'Consigliato / da verificare'
            : 'Da verificare';
      case PracticeDocumentChecklistItemStatus.recommendedPresent:
        return 'Consigliato — presente';
    }
  }
}
