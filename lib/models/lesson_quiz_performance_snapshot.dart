import 'license_models.dart';

/// Snapshot aggregato per lezione — ciò che in produzione arriverebbe da statistiche / backend.
///
/// Sostituire la sorgente mock con repository (es. Supabase) mantenendo questo DTO.
class LessonQuizPerformanceSnapshot {
  const LessonQuizPerformanceSnapshot({
    required this.categoryId,
    required this.lessonNumber,
    required this.lessonTitle,
    required this.totalAttempts,
    required this.averageErrorPercentage,
  });

  final LicenseCategoryId categoryId;

  /// Numero lezione allineato a [LicenseCatalog] / [LessonItem.number].
  final int lessonNumber;

  final String lessonTitle;

  /// Tentativi totali sulle schede quiz di questa lezione (proxy volume dati).
  final int totalAttempts;

  /// Percentuale errori media sulle risposte date (0–100).
  final double averageErrorPercentage;
}
