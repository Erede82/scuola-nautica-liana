import 'package:flutter/material.dart';

import '../domain/exam_error_review.dart';
import '../models/quiz_question.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/nautical_answer_marker.dart';
import '../widgets/quiz_question_image.dart';
import '../widgets/quiz_question_prompt_panel.dart';

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
          ...question.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReviewOptionTile(
                answerNumber: option.index + 1,
                text: question.textForOption(option),
                markerState: _reviewMarkerState(
                  option: option,
                  correct: question.correctOption,
                  userAnswer: entry.userAnswer,
                ),
                rowHighlighted:
                    option == question.correctOption ||
                    (entry.userAnswer != null && option == entry.userAnswer),
                isCorrectRow: option == question.correctOption,
                isWrongRow:
                    entry.userAnswer != null &&
                    option == entry.userAnswer &&
                    option != question.correctOption,
              ),
            ),
          ),
        ],
      ),
    );
  }

  NauticalAnswerMarkerState _reviewMarkerState({
    required QuizAnswerOption option,
    required QuizAnswerOption correct,
    required QuizAnswerOption? userAnswer,
  }) {
    if (option == correct) return NauticalAnswerMarkerState.correct;
    if (userAnswer != null && option == userAnswer) {
      return NauticalAnswerMarkerState.wrong;
    }
    return NauticalAnswerMarkerState.neutral;
  }
}

class _ReviewOptionTile extends StatelessWidget {
  const _ReviewOptionTile({
    required this.answerNumber,
    required this.text,
    required this.markerState,
    required this.rowHighlighted,
    required this.isCorrectRow,
    required this.isWrongRow,
  });

  final int answerNumber;
  final String text;
  final NauticalAnswerMarkerState markerState;
  final bool rowHighlighted;
  final bool isCorrectRow;
  final bool isWrongRow;

  @override
  Widget build(BuildContext context) {
    final answerStyle = QuizAnswerTextStyle.answer(context, compact: false);

    Color background = Colors.white;
    Color border = AppVisual.chipFill;
    var borderWidth = 1.2;

    if (isCorrectRow) {
      background = const Color(0xFFE8F7EE);
      border = QuizExamErrorReviewPage._correctColor;
      borderWidth = 2.2;
    } else if (isWrongRow) {
      background = const Color(0xFFFDECEC);
      border = QuizExamErrorReviewPage._wrongColor;
      borderWidth = 2.2;
    } else if (rowHighlighted) {
      border = AppVisual.logoBlue;
      borderWidth = 1.6;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(text, style: answerStyle)),
          const SizedBox(width: 10),
          NauticalAnswerMarker(answerNumber: answerNumber, state: markerState),
        ],
      ),
    );
  }
}
