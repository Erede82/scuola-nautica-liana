import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/quiz_question.dart';

/// Esito persistenza tentativo scheda lezione.
class QuizAttemptSubmitResult {
  const QuizAttemptSubmitResult({required this.quizResultId});

  final String quizResultId;
}

/// `quiz_results` creato ma `quiz_attempt_answers` non salvato — retry senza nuovo result.
class QuizAttemptAnswersPartialFailure extends StateError {
  QuizAttemptAnswersPartialFailure({required this.quizResultId})
    : super(
        'Risultato creato, ma dettaglio risposte non salvato. '
        'Puoi riprovare il salvataggio.',
      );

  final String quizResultId;
}

/// Calcolo payload tentativo (testabile senza Supabase).
class QuizAttemptPayload {
  const QuizAttemptPayload({
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.wrongQuestionIds,
    required this.answerRows,
    required this.durationSeconds,
  });

  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final List<String> wrongQuestionIds;
  final List<QuizAttemptAnswerRow> answerRows;
  final int durationSeconds;
}

class QuizAttemptAnswerRow {
  const QuizAttemptAnswerRow({
    required this.questionId,
    required this.selectedOption,
    required this.correctOption,
    required this.isCorrect,
  });

  final String questionId;
  final String? selectedOption;
  final String correctOption;
  final bool isCorrect;
}

abstract class QuizAttemptRepository {
  Future<QuizAttemptSubmitResult> submitLessonSheetAttempt({
    required String quizSetId,
    required List<QuizQuestion> questions,
    required List<QuizAnswerOption?> answers,
    required DateTime startedAt,
    required DateTime completedAt,
    String? existingQuizResultId,
  });
}

class QuizAttemptRepositorySupabase implements QuizAttemptRepository {
  QuizAttemptRepositorySupabase._();

  static final QuizAttemptRepositorySupabase instance =
      QuizAttemptRepositorySupabase._();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non inizializzato.');
    }
    return Supabase.instance.client;
  }

  @override
  Future<QuizAttemptSubmitResult> submitLessonSheetAttempt({
    required String quizSetId,
    required List<QuizQuestion> questions,
    required List<QuizAnswerOption?> answers,
    required DateTime startedAt,
    required DateTime completedAt,
    String? existingQuizResultId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError(
        'Utente non autenticato: impossibile salvare il tentativo.',
      );
    }

    if (questions.length != answers.length) {
      throw ArgumentError(
        'Domande (${questions.length}) e risposte (${answers.length}) non allineate.',
      );
    }

    final payload = buildQuizAttemptPayload(
      questions: questions,
      answers: answers,
      startedAt: startedAt,
      completedAt: completedAt,
    );

    return runQuizAttemptSubmit(
      existingQuizResultId: existingQuizResultId,
      createQuizResult: () => _createQuizResult(
        userId: userId,
        quizSetId: quizSetId,
        payload: payload,
        startedAt: startedAt,
        completedAt: completedAt,
      ),
      insertAnswers: (quizResultId) => _insertAttemptAnswers(
        userId: userId,
        quizResultId: quizResultId,
        payload: payload,
        completedAt: completedAt,
      ),
    );
  }

  Future<String> _createQuizResult({
    required String userId,
    required String quizSetId,
    required QuizAttemptPayload payload,
    required DateTime startedAt,
    required DateTime completedAt,
  }) async {
    final resultRow = await _client
        .from('quiz_results')
        .insert({
          'user_id': userId,
          'quiz_set_id': quizSetId,
          'total_questions': payload.totalQuestions,
          'correct_count': payload.correctCount,
          'wrong_count': payload.wrongCount,
          'wrong_question_ids': payload.wrongQuestionIds,
          'unanswered_count': payload.unansweredCount,
          'started_at': startedAt.toUtc().toIso8601String(),
          'completed_at': completedAt.toUtc().toIso8601String(),
          'duration_seconds': payload.durationSeconds,
        })
        .select('id')
        .single();

    final quizResultId = (resultRow['id'] as String?)?.toString();
    if (quizResultId == null || quizResultId.isEmpty) {
      throw StateError('Salvataggio tentativo: id risultato mancante.');
    }
    return quizResultId;
  }

  Future<void> _insertAttemptAnswers({
    required String userId,
    required String quizResultId,
    required QuizAttemptPayload payload,
    required DateTime completedAt,
  }) async {
    final answerPayload = buildQuizAttemptAnswerInsertPayload(
      userId: userId,
      quizResultId: quizResultId,
      payload: payload,
      completedAt: completedAt,
    );

    await _client.from('quiz_attempt_answers').insert(answerPayload);
  }
}

class QuizAttemptRepositoryNoop implements QuizAttemptRepository {
  const QuizAttemptRepositoryNoop();

  @override
  Future<QuizAttemptSubmitResult> submitLessonSheetAttempt({
    required String quizSetId,
    required List<QuizQuestion> questions,
    required List<QuizAnswerOption?> answers,
    required DateTime startedAt,
    required DateTime completedAt,
    String? existingQuizResultId,
  }) async {
    throw StateError('Salvataggio tentativi non disponibile.');
  }
}

/// True solo al primo salvataggio (nessun quiz_results parziale da riusare).
bool shouldCreateQuizResultForSubmit(String? existingQuizResultId) =>
    existingQuizResultId == null || existingQuizResultId.isEmpty;

/// Orchestrazione INSERT quiz_results + quiz_attempt_answers (testabile).
Future<QuizAttemptSubmitResult> runQuizAttemptSubmit({
  required String? existingQuizResultId,
  required Future<String> Function() createQuizResult,
  required Future<void> Function(String quizResultId) insertAnswers,
}) async {
  final quizResultId = shouldCreateQuizResultForSubmit(existingQuizResultId)
      ? await createQuizResult()
      : existingQuizResultId!;

  try {
    await insertAnswers(quizResultId);
  } catch (err, st) {
    debugPrint(
      'QuizAttemptRepository: insert quiz_attempt_answers fallito '
      'per result $quizResultId: $err\n$st',
    );
    if (shouldCreateQuizResultForSubmit(existingQuizResultId)) {
      throw QuizAttemptAnswersPartialFailure(quizResultId: quizResultId);
    }
    throw StateError(
      'Risultato creato, ma dettaglio risposte non salvato. '
      'Puoi riprovare il salvataggio.',
    );
  }

  return QuizAttemptSubmitResult(quizResultId: quizResultId);
}

List<Map<String, dynamic>> buildQuizAttemptAnswerInsertPayload({
  required String userId,
  required String quizResultId,
  required QuizAttemptPayload payload,
  required DateTime completedAt,
}) {
  return payload.answerRows
      .map(
        (row) => {
          'quiz_result_id': quizResultId,
          'user_id': userId,
          'question_id': row.questionId,
          'selected_option': row.selectedOption,
          'correct_option': row.correctOption,
          'is_correct': row.isCorrect,
          'answered_at': completedAt.toUtc().toIso8601String(),
        },
      )
      .toList();
}

QuizAttemptPayload buildQuizAttemptPayload({
  required List<QuizQuestion> questions,
  required List<QuizAnswerOption?> answers,
  required DateTime startedAt,
  required DateTime completedAt,
}) {
  if (questions.length != answers.length) {
    throw ArgumentError(
      'Domande (${questions.length}) e risposte (${answers.length}) non allineate.',
    );
  }

  var correctCount = 0;
  var wrongCount = 0;
  var unansweredCount = 0;
  final wrongQuestionIds = <String>[];
  final answerRows = <QuizAttemptAnswerRow>[];

  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    final answer = answers[i];

    if (answer == null) {
      unansweredCount++;
      answerRows.add(
        QuizAttemptAnswerRow(
          questionId: question.id,
          selectedOption: null,
          correctOption: question.correctOption.letter,
          isCorrect: false,
        ),
      );
      continue;
    }

    final isCorrect = answer == question.correctOption;
    if (isCorrect) {
      correctCount++;
    } else {
      wrongCount++;
      wrongQuestionIds.add(question.id);
    }

    answerRows.add(
      QuizAttemptAnswerRow(
        questionId: question.id,
        selectedOption: answer.letter,
        correctOption: question.correctOption.letter,
        isCorrect: isCorrect,
      ),
    );
  }

  final durationSeconds = completedAt.difference(startedAt).inSeconds;
  return QuizAttemptPayload(
    totalQuestions: questions.length,
    correctCount: correctCount,
    wrongCount: wrongCount,
    unansweredCount: unansweredCount,
    wrongQuestionIds: wrongQuestionIds,
    answerRows: answerRows,
    durationSeconds: durationSeconds < 0 ? 0 : durationSeconds,
  );
}

QuizAttemptRepository get quizAttemptRepository {
  if (SupabaseConfig.isConfigured) {
    return QuizAttemptRepositorySupabase.instance;
  }
  return const QuizAttemptRepositoryNoop();
}
