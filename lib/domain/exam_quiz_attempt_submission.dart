import '../models/license_models.dart';
import '../models/quiz_question.dart';
import 'exam_quiz_rules.dart';
import 'quiz_license_category.dart';

/// Contratto di submit **client → futura RPC** per una simulazione esame conclusa.
///
/// Contiene soltanto dati che il client può legittimamente dichiarare. Non
/// include `userId`/`studentId` (derivati da `auth.uid()` server-side) né dati
/// di sicurezza ricalcolabili dal server (opzione corretta, `isCorrect`,
/// conteggi, esito). Questi saranno ricostruiti dalla RPC leggendo `questions`.
class ExamQuizAttemptSubmission {
  const ExamQuizAttemptSubmission({
    required this.clientAttemptToken,
    required this.licenseCategory,
    required this.duration,
    required this.timeExpired,
    required this.answers,
  });

  /// Token idempotente generato dal player (mai rigenerato dal builder).
  final String clientAttemptToken;
  final LicenseCategoryId licenseCategory;
  final Duration duration;

  /// True se la simulazione è stata chiusa dallo scadere del timer.
  final bool timeExpired;

  /// Righe ordinate per posizione (1..N), una per ogni domanda della sessione.
  final List<ExamQuizSubmissionAnswer> answers;

  /// Payload snake_case per la futura RPC (nessun campo di sicurezza).
  ///
  /// La categoria è serializzata con il mapping DB reale
  /// ([dbLicenseCategoryFor]: `A12` / `D1`, `null` per vela), coerente con
  /// `questions.license_category` e con gli altri contratti del progetto.
  Map<String, dynamic> toRpcParams() => {
    'p_client_attempt_token': clientAttemptToken,
    'p_license_category': dbLicenseCategoryFor(licenseCategory),
    'p_duration_seconds': duration.inSeconds,
    'p_time_expired': timeExpired,
    'p_answers': answers.map((a) => a.toJson()).toList(growable: false),
  };

  @override
  bool operator ==(Object other) =>
      other is ExamQuizAttemptSubmission &&
      other.clientAttemptToken == clientAttemptToken &&
      other.licenseCategory == licenseCategory &&
      other.duration == duration &&
      other.timeExpired == timeExpired &&
      _answersEqual(other.answers, answers);

  @override
  int get hashCode => Object.hash(
    clientAttemptToken,
    licenseCategory,
    duration,
    timeExpired,
    Object.hashAll(answers),
  );
}

/// Riga risposta del payload client: soltanto posizione, id domanda e scelta.
class ExamQuizSubmissionAnswer {
  const ExamQuizSubmissionAnswer({
    required this.position,
    required this.questionId,
    required this.selectedOption,
  });

  /// Posizione 1-based della domanda nella simulazione.
  final int position;
  final String questionId;

  /// `null` = domanda non risposta.
  final QuizAnswerOption? selectedOption;

  Map<String, dynamic> toJson() => {
    'position': position,
    'question_id': questionId,
    'selected_option': selectedOption?.letter,
  };

  @override
  bool operator ==(Object other) =>
      other is ExamQuizSubmissionAnswer &&
      other.position == position &&
      other.questionId == questionId &&
      other.selectedOption == selectedOption;

  @override
  int get hashCode => Object.hash(position, questionId, selectedOption);
}

/// Costruisce il payload di submit da domande selezionate e risposte del player.
///
/// Funzione pura: non genera token, non calcola conteggi/esito, non include dati
/// ricavabili dal server. Conserva l'ordine originale tramite [position] e
/// include anche le domande non risposte (`selectedOption == null`).
///
/// Il [clientAttemptToken] deve essere fornito dall'esterno (vedi P9E.5 per la
/// generazione lato player).
ExamQuizAttemptSubmission buildExamQuizAttemptSubmission({
  required LicenseCategoryId licenseCategory,
  required String clientAttemptToken,
  required Duration duration,
  required bool timeExpired,
  required List<QuizQuestion> questions,
  required List<QuizAnswerOption?> userAnswers,
}) {
  if (clientAttemptToken.trim().isEmpty) {
    throw ArgumentError.value(
      clientAttemptToken,
      'clientAttemptToken',
      'Token idempotente obbligatorio.',
    );
  }
  if (duration.isNegative) {
    throw ArgumentError.value(
      duration,
      'duration',
      'La durata non può essere negativa.',
    );
  }
  if (questions.isEmpty) {
    throw ArgumentError.value(
      questions,
      'questions',
      'Nessuna domanda nella simulazione.',
    );
  }
  if (questions.length != ExamQuizRules.questionCount) {
    throw ArgumentError.value(
      questions.length,
      'questions',
      'La simulazione esame richiede esattamente '
          '${ExamQuizRules.questionCount} domande.',
    );
  }
  if (userAnswers.length != questions.length) {
    throw ArgumentError(
      'Risposte (${userAnswers.length}) non allineate alle domande '
      '(${questions.length}): risposta associata a una domanda non presente.',
    );
  }

  final seenIds = <String>{};
  final rows = <ExamQuizSubmissionAnswer>[];
  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    if (question.id.trim().isEmpty) {
      throw ArgumentError('Domanda in posizione ${i + 1} senza id.');
    }
    if (!seenIds.add(question.id)) {
      throw ArgumentError(
        'Domanda duplicata nella simulazione: ${question.id}.',
      );
    }
    rows.add(
      ExamQuizSubmissionAnswer(
        position: i + 1,
        questionId: question.id,
        selectedOption: userAnswers[i],
      ),
    );
  }

  return ExamQuizAttemptSubmission(
    clientAttemptToken: clientAttemptToken,
    licenseCategory: licenseCategory,
    duration: duration,
    timeExpired: timeExpired,
    answers: List.unmodifiable(rows),
  );
}

bool _answersEqual(
  List<ExamQuizSubmissionAnswer> a,
  List<ExamQuizSubmissionAnswer> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
