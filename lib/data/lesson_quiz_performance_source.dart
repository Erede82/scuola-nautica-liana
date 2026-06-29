import '../models/lesson_quiz_performance_snapshot.dart';
import '../models/license_models.dart';
import 'lesson_quiz_performance_mock.dart';

/// Sorgente unica delle performance lezione-quiz per la UI studente.
///
/// Oggi non esiste ancora il flusso quiz reale (domande/tentativi salvati): per
/// un allievo senza storico la sorgente ritorna una lista **vuota**, così
/// Statistiche e Ripasso errori mostrano un empty state coerente invece di
/// percentuali simulate.
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
