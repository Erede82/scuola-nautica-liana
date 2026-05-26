import 'license_models.dart';

/// Tipologia contenuto soggetto ad abilitazione manuale dalla scuola.
enum StudyContentType {
  /// Schede quiz di una lezione (per numero scheda).
  lessonQuizSheet,

  /// Sezione / modalità quiz esame.
  examQuiz,

  /// Singolo argomento suggerito nel ripasso errori.
  errorReviewTopic,
}

/// Origine sblocco — in produzione arriverà dal backend (assegnazione segreteria).
enum StudyUnlockSource {
  /// Abilitazione esplicita da parte della scuola (unica fonte prevista per ora).
  manualBySchool,
}

/// Stato accesso per un contenuto studio (DTO per UI e futuro sync Supabase).
class StudyContentAccessSnapshot {
  const StudyContentAccessSnapshot({
    required this.contentType,
    required this.categoryId,
    required this.contentId,
    required this.isUnlocked,
    this.unlockSource,
    this.unlockMessage,
    this.lockedMessage,
  });

  final StudyContentType contentType;
  final LicenseCategoryId categoryId;

  /// Identificativo stabile nel dominio (es. `sheet:12`, `exam`, `topic:L6`).
  final String contentId;

  final bool isUnlocked;

  /// Popolato solo se [isUnlocked] è true.
  final StudyUnlockSource? unlockSource;

  /// Etichetta breve quando sbloccato (es. badge).
  final String? unlockMessage;

  /// Spiegazione quando bloccato — mostrata allo studente.
  final String? lockedMessage;

  bool get isLocked => !isUnlocked;
}
