import 'package:flutter/material.dart';

import '../domain/exam_quiz_attempt_models.dart';
import '../domain/exam_quiz_rules.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/backoffice/assigned_quiz_staff_labels.dart';

/// Card riepilogo di un tentativo esame persistito (lista storico).
class ExamQuizAttemptCard extends StatelessWidget {
  const ExamQuizAttemptCard({
    super.key,
    required this.attempt,
    required this.onOpen,
  });

  final ExamQuizAttemptSummary attempt;
  final VoidCallback onOpen;

  static const Color _passedColor = Color(0xFF15803D);
  static const Color _failedColor = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final passed = attempt.passed;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppVisual.chipFill),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _StatusBadge(
                    label: 'Svolto',
                    background: AppVisual.logoBlue.withValues(alpha: 0.12),
                    foreground: AppVisual.logoBlue,
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                    label: passed ? 'Superato' : 'Non superato',
                    background: passed
                        ? _passedColor.withValues(alpha: 0.12)
                        : _failedColor.withValues(alpha: 0.12),
                    foreground: passed ? _passedColor : _failedColor,
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: AppVisual.inkMuted),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                AssignedQuizStaffLabels.formatDateTime(attempt.completedAt),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppVisual.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Corrette ${attempt.correctCount} · '
                'Errate ${attempt.wrongCount} · '
                'Non risposte ${attempt.unansweredCount}',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppVisual.inkMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Durata ${formatExamDurationMmSs(attempt.duration)}'
                '${attempt.timeExpired ? ' · Timer scaduto' : ''}',
                style: textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
