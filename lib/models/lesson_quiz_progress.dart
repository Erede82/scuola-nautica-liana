/// Avanzamento schede lezione per singolo argomento (1–14).
class LessonQuizProgress {
  const LessonQuizProgress({
    required this.lessonNumber,
    required this.lessonTitle,
    required this.availableSheetsCount,
    required this.completedUniqueSheetsCount,
    required this.completionPercentage,
    required this.isAvailable,
    required this.isComplete,
  });

  final int lessonNumber;
  final String lessonTitle;

  /// Schede `quiz_sets` disponibili per la lezione nella categoria.
  final int availableSheetsCount;

  /// Schede uniche completate (distinct `quiz_set_id`).
  final int completedUniqueSheetsCount;

  /// 0–100 se [isAvailable]; altrimenti 0.
  final double completionPercentage;

  /// La lezione possiede almeno una scheda nel catalogo.
  final bool isAvailable;

  /// [isAvailable] e avanzamento al 100%.
  final bool isComplete;

  bool get isInProgress =>
      isAvailable && !isComplete && completedUniqueSheetsCount > 0;

  bool get isNotStarted => isAvailable && completedUniqueSheetsCount == 0;
}

/// Aggregato avanzamento schede per categoria patente.
class CategoryQuizProgress {
  const CategoryQuizProgress({
    required this.totalAvailableSheets,
    required this.totalCompletedUniqueSheets,
    required this.overallCompletionPercentage,
    required this.lessonProgress,
    required this.completedLessonsCount,
    required this.availableLessonsCount,
    required this.inProgressLessonsCount,
  });

  final int totalAvailableSheets;
  final int totalCompletedUniqueSheets;
  final double overallCompletionPercentage;
  final List<LessonQuizProgress> lessonProgress;
  final int completedLessonsCount;
  final int availableLessonsCount;
  final int inProgressLessonsCount;

  bool get hasCatalog => totalAvailableSheets > 0;

  static const empty = CategoryQuizProgress(
    totalAvailableSheets: 0,
    totalCompletedUniqueSheets: 0,
    overallCompletionPercentage: 0,
    lessonProgress: [],
    completedLessonsCount: 0,
    availableLessonsCount: 0,
    inProgressLessonsCount: 0,
  );
}
