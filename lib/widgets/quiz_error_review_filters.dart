import 'package:flutter/material.dart';

import '../data/supabase/mappers/quiz_error_review_mapper.dart';
import '../models/quiz_error_review_data.dart';
import '../theme/app_visual_tokens.dart';

/// Filtri locali lezione e ordinamento (nessun nuovo fetch).
class QuizErrorReviewFilters extends StatelessWidget {
  const QuizErrorReviewFilters({
    super.key,
    required this.data,
    required this.selectedLesson,
    required this.sort,
    required this.onLessonChanged,
    required this.onSortChanged,
  });

  final QuizErrorReviewData data;
  final int? selectedLesson;
  final QuizErrorReviewSort sort;
  final ValueChanged<int?> onLessonChanged;
  final ValueChanged<QuizErrorReviewSort> onSortChanged;

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _neutralColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: selectedLesson,
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Tutte le lezioni',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ...data.availableLessons.map((lessonNumber) {
                      final title =
                          lessonTitleFor(
                            categoryId: data.categoryId,
                            lessonNumber: lessonNumber,
                          ) ??
                          'Lezione $lessonNumber';
                      return DropdownMenuItem<int?>(
                        value: lessonNumber,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: onLessonChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _neutralColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<QuizErrorReviewSort>(
                value: sort,
                items: const [
                  DropdownMenuItem(
                    value: QuizErrorReviewSort.recent,
                    child: Text('Più recenti'),
                  ),
                  DropdownMenuItem(
                    value: QuizErrorReviewSort.mostFrequent,
                    child: Text('Più sbagliate'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
