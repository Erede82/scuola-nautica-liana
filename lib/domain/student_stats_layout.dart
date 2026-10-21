import 'student_quiz_statistics_aggregator.dart';

/// Breakpoint riga top cards (3 colonne).
const double kStudentStatsTopCardsWideMinWidth = 1024;

/// Breakpoint review: Top 5 vs Top 3.
const double kStudentStatsReviewTop5MinWidth = 1366;

/// Breakpoint topic: due colonne affiancate.
const double kStudentStatsTopicTwoColumnMinWidth = 1200;

/// Quanti argomenti review mostrare per la larghezza corrente.
int studentStatsReviewVisibleLimitForWidth(double width) {
  if (width >= kStudentStatsReviewTop5MinWidth) {
    return kStudentStatsReviewMaxLimit;
  }
  return kStudentStatsTop3Limit;
}

/// Split lista filtrata/ordinata in due colonne (ceil half a sinistra).
({List<T> left, List<T> right}) splitStudentStatsTopicsForTwoColumns<T>(
  List<T> items,
) {
  if (items.isEmpty) {
    return (left: <T>[], right: <T>[]);
  }
  final splitIndex = (items.length / 2).ceil();
  return (
    left: items.sublist(0, splitIndex),
    right: items.sublist(splitIndex),
  );
}
