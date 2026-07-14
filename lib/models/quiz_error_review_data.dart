import 'license_models.dart';
import 'quiz_wrong_answer_entry.dart';

/// Ordinamento elenco errori deduplicati.
enum QuizErrorReviewSort { recent, mostFrequent }

/// Aggregato dominio Ripasso errori (schede lezione, read-only).
class QuizErrorReviewData {
  const QuizErrorReviewData({
    required this.categoryId,
    required this.entries,
    required this.totalUniqueQuestions,
    required this.totalWrongOccurrences,
    required this.lessonCounts,
    required this.lastWrongAt,
    required this.ignoredMalformedRows,
  });

  final LicenseCategoryId categoryId;
  final List<QuizWrongAnswerEntry> entries;
  final int totalUniqueQuestions;
  final int totalWrongOccurrences;
  final Map<int, int> lessonCounts;
  final DateTime? lastWrongAt;
  final int ignoredMalformedRows;

  bool get isEmpty => entries.isEmpty;

  bool get hasData => entries.isNotEmpty;

  List<QuizWrongAnswerEntry> entriesForLesson(int lessonNumber) {
    return entries
        .where((e) => e.lessonNumber == lessonNumber)
        .toList(growable: false);
  }

  List<int> get availableLessons {
    final lessons = lessonCounts.keys.toList(growable: false)..sort();
    return lessons;
  }

  List<QuizWrongAnswerEntry> get mostFrequentErrors {
    final sorted = List<QuizWrongAnswerEntry>.from(entries)
      ..sort((a, b) {
        final byCount = b.errorCount.compareTo(a.errorCount);
        if (byCount != 0) return byCount;
        return b.lastWrongAt.compareTo(a.lastWrongAt);
      });
    return sorted;
  }

  List<QuizWrongAnswerEntry> get mostRecentErrors {
    final sorted = List<QuizWrongAnswerEntry>.from(entries)
      ..sort((a, b) => b.lastWrongAt.compareTo(a.lastWrongAt));
    return sorted;
  }

  static QuizErrorReviewData empty(LicenseCategoryId categoryId) {
    return QuizErrorReviewData(
      categoryId: categoryId,
      entries: const [],
      totalUniqueQuestions: 0,
      totalWrongOccurrences: 0,
      lessonCounts: const {},
      lastWrongAt: null,
      ignoredMalformedRows: 0,
    );
  }
}
