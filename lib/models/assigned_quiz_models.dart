import '../domain/assigned_quiz_exception.dart';
import 'assigned_quiz_enums.dart';

export '../domain/assigned_quiz_exception.dart';
export 'assigned_quiz_enums.dart';

/// Riepilogo assegnazione per liste staff / studente.
class AssignedQuizSummary {
  const AssignedQuizSummary({
    required this.id,
    required this.publicCode,
    required this.studentId,
    required this.studentUserId,
    required this.licenseCategory,
    required this.title,
    required this.status,
    required this.questionCount,
    required this.repeatPolicy,
    required this.createdAt,
    this.staffNote,
    this.maxAttempts,
    this.assignedAt,
    this.expiresAt,
    this.archivedAt,
    this.attemptsCount,
    this.submittedAttemptsCount,
    this.latestAttemptAt,
    this.bestScorePercentage,
    this.averageScorePercentage,
    this.hasInProgressAttempt,
  });

  final String id;
  final String publicCode;
  final String studentId;
  final String studentUserId;

  /// Valore DB (`A12` / `D1`).
  final String licenseCategory;
  final String title;
  final String? staffNote;
  final AssignedQuizStatus status;
  final int questionCount;
  final AssignedQuizRepeatPolicy repeatPolicy;
  final int? maxAttempts;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? expiresAt;
  final DateTime? archivedAt;

  final int? attemptsCount;
  final int? submittedAttemptsCount;
  final DateTime? latestAttemptAt;
  final double? bestScorePercentage;
  final double? averageScorePercentage;
  final bool? hasInProgressAttempt;
}

/// Richiesta generazione da errori storici (staff).
///
/// La categoria patente **non** è inclusa: viene derivata server-side.
class AssignedQuizGenerationRequest {
  const AssignedQuizGenerationRequest({
    required this.studentId,
    required this.title,
    this.staffNote,
    this.questionCount = 20,
    this.lessonFilterMode = AssignedQuizLessonFilterMode.allLessons,
    this.lessonNumbers = const [],
    this.sortMode = AssignedQuizSortMode.mostWrong,
    this.repeatPolicy = AssignedQuizRepeatPolicy.unlimited,
    this.maxAttempts,
    this.expiresAt,
    this.allowPartial = false,
    this.assignImmediately = true,
    this.idempotencyKey,
  });

  final String studentId;
  final String title;
  final String? staffNote;
  final int questionCount;
  final AssignedQuizLessonFilterMode lessonFilterMode;
  final List<int> lessonNumbers;
  final AssignedQuizSortMode sortMode;
  final AssignedQuizRepeatPolicy repeatPolicy;
  final int? maxAttempts;
  final DateTime? expiresAt;
  final bool allowPartial;
  final bool assignImmediately;
  final String? idempotencyKey;

  /// Validazione lato Dart prima della RPC. Ritorna messaggio IT o `null`.
  String? validate() {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return 'Il titolo è obbligatorio.';
    }
    if (studentId.trim().isEmpty) {
      return 'Lo studente è obbligatorio.';
    }
    if (questionCount < 1 || questionCount > 50) {
      return 'Il numero di domande deve essere compreso tra 1 e 50.';
    }
    if (lessonFilterMode == AssignedQuizLessonFilterMode.selectedLessons) {
      if (lessonNumbers.isEmpty) {
        return 'Seleziona almeno una lezione.';
      }
      for (final n in lessonNumbers) {
        if (n < 1 || n > 14) {
          return 'Le lezioni devono essere comprese tra 1 e 14.';
        }
      }
    }
    if (repeatPolicy == AssignedQuizRepeatPolicy.limited) {
      if (maxAttempts == null || maxAttempts! < 1) {
        return 'Con ripetizione limitata indica almeno 1 tentativo.';
      }
    }
    if (repeatPolicy == AssignedQuizRepeatPolicy.unlimited &&
        maxAttempts != null) {
      return 'Con ripetizione illimitata non impostare un massimo tentativi.';
    }
    if (expiresAt != null &&
        !expiresAt!.toUtc().isAfter(DateTime.now().toUtc())) {
      return 'La scadenza deve essere nel futuro.';
    }
    return null;
  }

  void ensureValid() {
    final error = validate();
    if (error != null) {
      throw AssignedQuizException(
        code: AssignedQuizErrorCode.validationFailed,
        message: error,
      );
    }
  }
}

/// Esito RPC `generate_assigned_quiz_from_errors`.
class AssignedQuizGenerationResult {
  const AssignedQuizGenerationResult({
    required this.assignmentId,
    required this.publicCode,
    required this.itemCount,
    required this.status,
    required this.licenseCategory,
    this.idempotent = false,
  });

  final String assignmentId;
  final String publicCode;
  final int itemCount;
  final AssignedQuizStatus status;
  final String licenseCategory;
  final bool idempotent;
}

/// Esito RPC `start_assigned_quiz_attempt`.
class AssignedQuizAttemptStartResult {
  const AssignedQuizAttemptStartResult({
    required this.attemptId,
    required this.attemptNumber,
    required this.resumed,
    required this.questionCount,
    required this.attemptsUsed,
    this.maxAttempts,
  });

  final String attemptId;
  final int attemptNumber;
  final bool resumed;
  final int questionCount;
  final int? maxAttempts;
  final int attemptsUsed;
}

/// Domanda sicura per il player (senza soluzione).
///
/// Non espone `correctOption`, `explanation` né `isCorrect`.
class AssignedQuizQuestion {
  const AssignedQuizQuestion({
    required this.assignmentItemId,
    required this.position,
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.lessonNumber,
    this.imagePath,
    this.selectedOption,
  });

  final String assignmentItemId;
  final int position;
  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;
  final String? imagePath;
  final int lessonNumber;

  /// Valore DB `A`/`B`/`C` o null.
  final String? selectedOption;
}

/// Esito RPC `save_assigned_quiz_attempt_answer`.
class AssignedQuizAnswerSaveResult {
  const AssignedQuizAnswerSaveResult({
    required this.assignmentItemId,
    this.selectedOption,
    this.answeredAt,
  });

  final String assignmentItemId;
  final String? selectedOption;
  final DateTime? answeredAt;
}

/// Esito RPC `submit_assigned_quiz_attempt`.
class AssignedQuizSubmitResult {
  const AssignedQuizSubmitResult({
    required this.attemptId,
    required this.attemptNumber,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.scorePercentage,
    this.submittedAt,
    this.alreadySubmitted = false,
  });

  final String attemptId;
  final int attemptNumber;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final double scorePercentage;
  final DateTime? submittedAt;
  final bool alreadySubmitted;
}

/// Voce review post-submit / staff (include soluzione).
class AssignedQuizReviewItem {
  const AssignedQuizReviewItem({
    required this.position,
    required this.prompt,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.correctOption,
    required this.lessonNumber,
    this.imagePath,
    this.selectedOption,
    this.isCorrect,
    this.explanation,
  });

  final int position;
  final String prompt;
  final String optionA;
  final String optionB;
  final String optionC;
  final String? imagePath;
  final String? selectedOption;
  final String correctOption;
  final bool? isCorrect;
  final String? explanation;
  final int lessonNumber;
}

/// Riepilogo tentativo.
class AssignedQuizAttemptSummary {
  const AssignedQuizAttemptSummary({
    required this.id,
    required this.assignmentId,
    required this.attemptNumber,
    required this.status,
    required this.startedAt,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    this.submittedAt,
    this.abandonedAt,
    this.scorePercentage,
    this.durationSeconds,
  });

  final String id;
  final String assignmentId;
  final int attemptNumber;
  final AssignedQuizAttemptStatus status;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final DateTime? abandonedAt;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final double? scorePercentage;
  final int? durationSeconds;
}
