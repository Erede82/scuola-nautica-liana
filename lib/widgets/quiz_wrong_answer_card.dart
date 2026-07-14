import 'package:flutter/material.dart';

import '../data/supabase/mappers/quiz_error_review_mapper.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../models/quiz_wrong_answer_entry.dart';
import '../repositories/study_access_repository.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/guida_datetime_format.dart';
import 'nautical_answer_marker.dart';
import 'quiz_question_image.dart';

/// Card espandibile read-only per una domanda sbagliata.
class QuizWrongAnswerCard extends StatefulWidget {
  const QuizWrongAnswerCard({
    super.key,
    required this.entry,
    required this.categoryId,
  });

  final QuizWrongAnswerEntry entry;
  final LicenseCategoryId categoryId;

  @override
  State<QuizWrongAnswerCard> createState() => _QuizWrongAnswerCardState();
}

class _QuizWrongAnswerCardState extends State<QuizWrongAnswerCard> {
  bool _expanded = false;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _warnColor = Color(0xFFC75D3A);
  static const Color _successColor = Color(0xFF2E9E5B);

  bool get _isUnlocked => studyAccessRepository.effectiveErrorTopicUnlocked(
    widget.categoryId,
    widget.entry.lessonNumber,
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entry = widget.entry;

    if (!_isUnlocked) {
      return _buildLockedCard(textTheme, entry);
    }

    final lessonTitle =
        lessonTitleFor(
          categoryId: widget.categoryId,
          lessonNumber: entry.lessonNumber,
        ) ??
        'Lezione ${entry.lessonNumber}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neutralColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lezione ${entry.lessonNumber} · $lessonTitle',
                          style: textTheme.labelMedium?.copyWith(
                            color: _primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: _textPrimaryColor.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.prompt,
                    maxLines: _expanded ? null : 3,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip(
                        textTheme,
                        'Sbagliata ${entry.errorCount} volte',
                        _warnColor.withValues(alpha: 0.12),
                        _warnColor,
                      ),
                      _chip(
                        textTheme,
                        'Ultimo: ${GuidaDateTimeFormat.formatDate(entry.lastWrongAt)}',
                        _neutralColor.withValues(alpha: 0.5),
                        _textPrimaryColor.withValues(alpha: 0.8),
                      ),
                      if (entry.sheetNumbers.length == 1)
                        _chip(
                          textTheme,
                          'Scheda ${entry.sheetNumbers.single}',
                          _primaryColor.withValues(alpha: 0.08),
                          _primaryColor,
                        )
                      else
                        _chip(
                          textTheme,
                          'Schede ${entry.sheetNumbers.join(', ')}',
                          _primaryColor.withValues(alpha: 0.08),
                          _primaryColor,
                        ),
                    ],
                  ),
                  if (!_expanded) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Hai risposto: ${entry.latestSelectedOption.letter} — '
                      '${entry.selectedAnswerText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: _warnColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Corretta: ${entry.correctOption.letter} — '
                      '${entry.correctAnswerText}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: _successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.hasImage) ...[
                    QuizQuestionImage(imagePath: entry.imagePath!),
                    const SizedBox(height: 12),
                  ],
                  _optionRow(
                    textTheme,
                    option: QuizAnswerOption.a,
                    number: 1,
                    text: entry.optionA,
                    entry: entry,
                  ),
                  const SizedBox(height: 8),
                  _optionRow(
                    textTheme,
                    option: QuizAnswerOption.b,
                    number: 2,
                    text: entry.optionB,
                    entry: entry,
                  ),
                  const SizedBox(height: 8),
                  _optionRow(
                    textTheme,
                    option: QuizAnswerOption.c,
                    number: 3,
                    text: entry.optionC,
                    entry: entry,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Hai risposto: ${entry.latestSelectedOption.letter} — '
                    '${entry.selectedAnswerText}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: _warnColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Risposta corretta: ${entry.correctOption.letter} — '
                    '${entry.correctAnswerText}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: _successColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (entry.hasExplanation) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Spiegazione',
                      style: textTheme.titleSmall?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.explanation!,
                      style: textTheme.bodyMedium?.copyWith(
                        color: _textPrimaryColor.withValues(alpha: 0.88),
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLockedCard(TextTheme textTheme, QuizWrongAnswerEntry entry) {
    final lessonTitle =
        lessonTitleFor(
          categoryId: widget.categoryId,
          lessonNumber: entry.lessonNumber,
        ) ??
        'Lezione ${entry.lessonNumber}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _neutralColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _neutralColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: _primaryColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lezione ${entry.lessonNumber} · $lessonTitle',
                  style: textTheme.titleSmall?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${entry.errorCount} errori registrati',
                  style: textTheme.bodySmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ripasso non ancora disponibile',
                  style: textTheme.bodySmall?.copyWith(
                    color: _warnColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow(
    TextTheme textTheme, {
    required QuizAnswerOption option,
    required int number,
    required String text,
    required QuizWrongAnswerEntry entry,
  }) {
    NauticalAnswerMarkerState state;
    if (option == entry.correctOption) {
      state = NauticalAnswerMarkerState.correct;
    } else if (option == entry.latestSelectedOption) {
      state = NauticalAnswerMarkerState.wrong;
    } else {
      state = NauticalAnswerMarkerState.neutral;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NauticalAnswerMarker(answerNumber: number, state: state, compact: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${option.letter}. $text',
            style: textTheme.bodyMedium?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.9),
              height: 1.4,
              fontWeight:
                  option == entry.latestSelectedOption ||
                      option == entry.correctOption
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(TextTheme textTheme, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
