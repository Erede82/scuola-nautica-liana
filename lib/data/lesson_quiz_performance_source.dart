import '../models/lesson_quiz_performance_snapshot.dart';
import '../models/license_models.dart';
import 'lesson_quiz_performance_mock.dart';

/// Sorgente sincrona legacy per Ripasso errori (pagina dedicata).
///
/// La pagina Statistiche (B2) usa [QuizStatisticsRepository] e non legge più
/// questa sorgente. Resta per [ErrorReviewPage] finché C1 non collega i dati
/// reali anche al ripasso per domanda.
///
/// Oggi, senza [useDemoData], ritorna lista **vuota** per empty state coerente.
///
/// [LessonQuizPerformanceMock] resta disponibile solo dietro [useDemoData]
/// (default `false`) per anteprime/debug interni: non è più collegato alla UI
/// reale dello studente. Quando il backend quiz sarà pronto,
/// [snapshotsFor] leggerà i tentativi reali dell'allievo.
abstract final class LessonQuizPerformanceSource {
  /// Quando `true` ripropone i dati demo deterministici (solo debug/anteprima).
  static bool useDemoData = false;

  /// Soglia minima errori (%) per comparire nel ripasso.
  static double get attentionThresholdPercent =>
      LessonQuizPerformanceMock.attentionThresholdPercent;

  static List<LessonQuizPerformanceSnapshot> snapshotsFor(
    LicenseCategoryId categoryId,
  ) {
    if (useDemoData) {
      return LessonQuizPerformanceMock.snapshotsFor(categoryId);
    }
    return const [];
  }
}
