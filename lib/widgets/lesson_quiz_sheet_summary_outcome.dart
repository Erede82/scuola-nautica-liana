import 'package:flutter/material.dart';

import '../domain/lesson_quiz_rules.dart';
import '../models/license_models.dart';
import '../theme/app_visual_tokens.dart';

/// Card esito scheda lezione: PROMOSSO / BOCCIATO (regole [LessonQuizRules]).
class LessonQuizSheetSummaryOutcome extends StatelessWidget {
  const LessonQuizSheetSummaryOutcome({
    super.key,
    required this.categoryId,
    required this.wrongCount,
    required this.unansweredCount,
  });

  final LicenseCategoryId categoryId;
  final int wrongCount;
  final int unansweredCount;

  static const Color _promotedColor = Color(0xFF15803D);
  static const Color _failedColor = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = lessonQuizOutcomeLabel(
      categoryId: categoryId,
      wrongCount: wrongCount,
      unansweredCount: unansweredCount,
    );
    final detail = lessonQuizOutcomeDetail(
      categoryId: categoryId,
      wrongCount: wrongCount,
      unansweredCount: unansweredCount,
    );
    if (label == null || detail == null) {
      return const SizedBox.shrink();
    }

    final promoted = label == 'PROMOSSO';
    final accent = promoted ? _promotedColor : _failedColor;
    final background = promoted
        ? const Color(0xFFDFF5E8)
        : const Color(0xFFFDE8E8);
    final icon = promoted ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Semantics(
      label: 'Esito $label. $detail',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esito',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppVisual.ink.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: textTheme.titleLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppVisual.ink,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
