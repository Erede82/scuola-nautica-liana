import '../data/license_catalog.dart';
import '../models/license_models.dart';
import '../models/lesson_quiz_performance_snapshot.dart';

/// Dati performance lezione-quiz simulati.
///
/// Allineati a **tutte** le lezioni di [LicenseCatalog] per coerenza con Statistiche e Ripasso errori.
/// **D1** e motore: stesso elenco lezioni (`patenteD1` riusa il catalogo motore).
/// **Vela**: nessun dato locale (contenuti inattivi).
abstract final class LessonQuizPerformanceMock {
  /// Soglia minima errori (%) per comparire nel ripasso. Modificabile lato dominio.
  static const double attentionThresholdPercent = 15;

  /// Snapshot per ogni lezione del catalogo categoria, con % errori e tentativi deterministico-demo.
  static List<LessonQuizPerformanceSnapshot> snapshotsFor(
    LicenseCategoryId categoryId,
  ) {
    switch (categoryId) {
      case LicenseCategoryId.motore:
        return _snapshotsForCategory(LicenseCategoryId.motore);
      case LicenseCategoryId.d1:
        return _snapshotsForCategory(LicenseCategoryId.d1);
      case LicenseCategoryId.vela:
        return const [];
    }
  }

  static List<LessonQuizPerformanceSnapshot> _snapshotsForCategory(
    LicenseCategoryId categoryId,
  ) {
    final category = LicenseCatalog.byId(categoryId);
    if (!category.isAvailable || category.lessons.isEmpty) return const [];

    return category.lessons.map((lesson) {
      final n = lesson.number;
      final errorPct = (6.0 + (n * 19) % 34).clamp(0.0, 48.0);
      final attempts = 12 + (n * 5) % 36;
      return LessonQuizPerformanceSnapshot(
        categoryId: categoryId,
        lessonNumber: n,
        lessonTitle: lesson.title,
        totalAttempts: attempts,
        averageErrorPercentage: errorPct,
      );
    }).toList(growable: false);
  }
}
