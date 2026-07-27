import 'package:flutter/material.dart';

import '../models/license_models.dart';
import '../theme/quiz_player_visual_tokens.dart';
import 'lesson_quiz_sheet_summary_outcome.dart';

/// Corpo riepilogo scheda lezione (senza azioni di navigazione / salvataggio).
class LessonQuizSheetSummaryBody extends StatelessWidget {
  const LessonQuizSheetSummaryBody({
    super.key,
    required this.categoryId,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
  });

  final LicenseCategoryId categoryId;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;

  static const Color _correctColor = QuizPlayerVisual.correctBorder;
  static const Color _wrongColor = QuizPlayerVisual.wrongBorder;
  static const Color _unansweredColor = Color(0xFF6B7280);
  static const Color _textPrimaryColor = QuizPlayerVisual.ink;
  static const Color _neutralColor = QuizPlayerVisual.cardBorder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scheda completata',
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            color: _textPrimaryColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        _SummaryStatRow(label: 'Domande totali', value: '$totalQuestions'),
        _SummaryStatRow(
          label: 'Risposte corrette',
          value: '$correctCount',
          valueColor: _correctColor,
        ),
        _SummaryStatRow(
          label: 'Risposte errate',
          value: '$wrongCount',
          valueColor: wrongCount > 0 ? _wrongColor : _textPrimaryColor,
        ),
        _SummaryStatRow(
          label: 'Non risposte',
          value: '$unansweredCount',
          valueColor: unansweredCount > 0
              ? _unansweredColor
              : _textPrimaryColor,
        ),
        LessonQuizSheetSummaryOutcome(
          categoryId: categoryId,
          wrongCount: wrongCount,
          unansweredCount: unansweredCount,
        ),
      ],
    );
  }
}

class _SummaryStatRow extends StatelessWidget {
  const _SummaryStatRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: QuizPlayerVisual.cardSurface,
        borderRadius: BorderRadius.circular(QuizPlayerVisual.cardRadius),
        border: Border.all(color: LessonQuizSheetSummaryBody._neutralColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyLarge?.copyWith(
                color: LessonQuizSheetSummaryBody._textPrimaryColor,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: valueColor ?? LessonQuizSheetSummaryBody._textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
