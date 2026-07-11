import 'package:flutter/material.dart';

import '../domain/exam_error_review.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/quiz_question_image.dart';

/// Review locale errori/non risposte post-simulazione esame (nessun DB).
class QuizExamErrorReviewPage extends StatelessWidget {
  const QuizExamErrorReviewPage({super.key, required this.entries});

  final List<ExamErrorReviewEntry> entries;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _correctColor = Color(0xFF15803D);
  static const Color _wrongColor = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Rivedi errori'),
        centerTitle: true,
      ),
      body: entries.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nessun errore da rivedere.',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: _textPrimaryColor,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _ReviewCard(entry: entries[index]);
              },
            ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.entry});

  final ExamErrorReviewEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final question = entry.question;
    final userText = entry.isUnanswered
        ? 'Non risposta'
        : question.textForOption(entry.userAnswer!);
    final correctText = question.textForOption(question.correctOption);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppVisual.chipFill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Domanda ${entry.questionNumber}',
            style: textTheme.labelLarge?.copyWith(
              color: QuizExamErrorReviewPage._primaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (question.imagePath?.trim().isNotEmpty == true) ...[
            QuizQuestionImage(imagePath: question.imagePath, maxHeight: 120),
            const SizedBox(height: 8),
          ],
          Text(
            question.prompt,
            style: textTheme.titleSmall?.copyWith(
              color: QuizExamErrorReviewPage._textPrimaryColor,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _AnswerLine(
            label: entry.isUnanswered ? 'Non risposta' : 'La tua risposta',
            value: userText,
            accent: entry.isUnanswered
                ? QuizExamErrorReviewPage._wrongColor
                : QuizExamErrorReviewPage._wrongColor,
          ),
          const SizedBox(height: 8),
          _AnswerLine(
            label: 'Risposta corretta',
            value: correctText,
            accent: QuizExamErrorReviewPage._correctColor,
          ),
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
