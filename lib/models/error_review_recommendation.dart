import 'license_models.dart';

/// Priorità suggerimento (derivata dalla percentuale errori in [ErrorReviewProvider]).
enum ErrorReviewPriority {
  high,
  medium,
  low,
}

extension ErrorReviewPriorityX on ErrorReviewPriority {
  String get badgeLabel {
    switch (this) {
      case ErrorReviewPriority.high:
        return 'Priorità alta';
      case ErrorReviewPriority.medium:
        return 'Da ripassare';
      case ErrorReviewPriority.low:
        return 'Migliorabile';
    }
  }
}

/// Tipo di azione principale sulla card (navigazione locale; estendibile).
enum ErrorReviewCtaKind {
  openLessonSheets,
  openQuizHome,
  reviewTopic,
}

class ErrorReviewRecommendation {
  const ErrorReviewRecommendation({
    required this.lessonNumber,
    required this.lessonTitle,
    required this.averageErrorPercentage,
    required this.recommendationTitle,
    required this.recommendationMessage,
    required this.priority,
    required this.linkedCategory,
    required this.ctaLabel,
    required this.ctaKind,
    required this.isSchoolUnlocked,
    required this.schoolLockMessage,
    this.linkedExtraContentId,
    this.linkedQuizSectionId,
  });

  final int lessonNumber;
  final String lessonTitle;
  final double averageErrorPercentage;

  final String recommendationTitle;
  final String recommendationMessage;
  final ErrorReviewPriority priority;

  /// Riferimento opzionale al catalogo Extra (es. scheda “Ripasso errori”).
  final String? linkedExtraContentId;

  /// Id concettuale sezione quiz (es. per deep link futuri).
  final String? linkedQuizSectionId;

  final LicenseCategoryId linkedCategory;

  final String ctaLabel;
  final ErrorReviewCtaKind ctaKind;

  /// Abilitazione contenuto ripasso da parte della scuola (indipendente dal “suggerito”).
  final bool isSchoolUnlocked;

  /// Messaggio da mostrare quando [isSchoolUnlocked] è false.
  final String schoolLockMessage;

  /// Etichetta breve stato abilitazione (UI).
  String get schoolUnlockBadge =>
      isSchoolUnlocked ? 'Sbloccato dalla scuola' : 'In attesa abilitazione';
}

/// Esito schermata: lista piena o stato vuoto gestito con [AppEmptyState].
enum ErrorReviewEmptyKind {
  /// Nessun tentativo quiz ancora registrato (o dataset assente).
  noQuizData,

  /// Ci sono dati ma nessuna lezione sopra soglia di attenzione.
  allClear,
}

class ErrorReviewViewData {
  const ErrorReviewViewData({
    required this.categoryId,
    required this.totalAttemptsAcrossLessons,
    required this.recommendations,
    required this.emptyKind,
  });

  final LicenseCategoryId categoryId;

  /// Somma tentativi sulle lezioni considerate per questa categoria.
  final int totalAttemptsAcrossLessons;

  /// Suggerimenti ordinati per priorità / errore. Vuoto se [emptyKind] != null.
  final List<ErrorReviewRecommendation> recommendations;

  final ErrorReviewEmptyKind? emptyKind;

  bool get hasRecommendations =>
      emptyKind == null && recommendations.isNotEmpty;

  bool get allRecommendedTopicsLocked =>
      recommendations.isNotEmpty &&
      recommendations.every((r) => !r.isSchoolUnlocked);

  bool get hasAnySchoolUnlockedTopic =>
      recommendations.any((r) => r.isSchoolUnlocked);
}
