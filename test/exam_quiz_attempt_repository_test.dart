import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postgrest/postgrest.dart';
import 'package:scuola_nautica_liana/data/supabase/mappers/exam_quiz_attempt_mapper.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_exception.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_models.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_submission.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/repositories/exam_quiz_attempt_repository.dart';

Map<String, dynamic> _summaryJson({
  String id = 'att-1',
  String category = 'A12',
  String completedAt = '2026-07-21T10:00:00Z',
  int durationSeconds = 900,
  bool timeExpired = false,
  int total = 20,
  int correct = 16,
  int wrong = 3,
  int unanswered = 1,
  bool passed = true,
  bool? idempotent,
}) {
  return {
    'id': id,
    'attempt_id': id,
    'license_category': category,
    'completed_at': completedAt,
    'duration_seconds': durationSeconds,
    'time_expired': timeExpired,
    'total_questions': total,
    'correct_count': correct,
    'wrong_count': wrong,
    'unanswered_count': unanswered,
    'passed': passed,
    'idempotent': ?idempotent,
  };
}

Map<String, dynamic> _answerJson({
  required int position,
  required String questionId,
  String prompt = 'Domanda?',
  String optionA = 'A',
  String optionB = 'B',
  String optionC = 'C',
  String? imagePath,
  String? selected,
  String correct = 'A',
  bool? isCorrect,
}) {
  final selectedOption = selected;
  final correctOption = correct;
  final computed = selectedOption != null && selectedOption == correctOption;
  return {
    'position': position,
    'question_id': questionId,
    'prompt_snapshot': prompt,
    'option_a_snapshot': optionA,
    'option_b_snapshot': optionB,
    'option_c_snapshot': optionC,
    'image_path_snapshot': imagePath,
    'selected_option': selectedOption,
    'correct_option': correctOption,
    'is_correct': isCorrect ?? computed,
  };
}

List<Map<String, dynamic>> _twentyAnswers({
  int wrongFrom = 17,
  int unansweredFrom = 20,
}) {
  return List.generate(20, (i) {
    final pos = i + 1;
    final qid = '00000000-0000-0000-0000-${pos.toString().padLeft(12, '0')}';
    if (pos >= unansweredFrom) {
      return _answerJson(
        position: pos,
        questionId: qid,
        selected: null,
        correct: 'A',
      );
    }
    if (pos >= wrongFrom) {
      return _answerJson(
        position: pos,
        questionId: qid,
        selected: 'B',
        correct: 'A',
      );
    }
    return _answerJson(
      position: pos,
      questionId: qid,
      selected: 'A',
      correct: 'A',
    );
  });
}

ExamQuizAttemptSummary _summary({
  String id = 'att-1',
  LicenseCategoryId category = LicenseCategoryId.motore,
  DateTime? completedAt,
  int correct = 16,
  int wrong = 3,
  int unanswered = 1,
}) {
  return ExamQuizAttemptSummary(
    id: id,
    licenseCategory: category,
    completedAt: completedAt ?? DateTime.utc(2026, 7, 21, 10),
    duration: const Duration(seconds: 900),
    timeExpired: false,
    totalQuestions: 20,
    correctCount: correct,
    wrongCount: wrong,
    unansweredCount: unanswered,
    outcome: (wrong + unanswered) <= ExamQuizRules.maxErrorsToPass
        ? ExamQuizOutcome.passed
        : ExamQuizOutcome.failed,
  );
}

ExamQuizAttemptSubmission _submission() {
  return ExamQuizAttemptSubmission(
    clientAttemptToken: 'token-1',
    licenseCategory: LicenseCategoryId.motore,
    duration: const Duration(minutes: 12),
    timeExpired: false,
    answers: List.generate(
      20,
      (i) => ExamQuizSubmissionAnswer(
        position: i + 1,
        questionId: 'q-$i',
        selectedOption: QuizAnswerOption.a,
      ),
    ),
  );
}

void main() {
  group('ExamQuizAttemptRepositorySupabase source contracts', () {
    late String repoSource;

    setUpAll(() {
      repoSource = File(
        'lib/repositories/exam_quiz_attempt_repository.dart',
      ).readAsStringSync();
    });

    test('RPC submit_exam_quiz_attempt con soli toRpcParams()', () {
      expect(repoSource, contains('examQuizAttemptSubmitRpcName'));
      expect(repoSource, contains('submission.toRpcParams()'));
      expect(repoSource, contains('validateExamQuizAttemptSubmitRpcParams'));
      expect(repoSource, contains('debugLogExamQuizAttemptSubmitRpcRequest'));
      expect(repoSource, contains('debugLogExamQuizAttemptPostgrestException'));
      expect(repoSource, isNot(contains("'p_user_id'")));
      expect(repoSource, isNot(contains("'p_correct_count'")));
      expect(repoSource, isNot(contains("'p_passed'")));
      expect(repoSource, isNot(contains("'correct_option'")));
      expect(repoSource, isNot(contains(".from('quiz_results')")));
      expect(repoSource, isNot(contains(".from('assigned_quizzes')")));
      expect(repoSource, isNot(contains(".from('quiz_attempt_answers')")));
    });

    test('log diagnostico non interpola token, risposte o credenziali', () {
      expect(repoSource, contains('examQuizAttemptRpcParamTypeLabel'));
      expect(repoSource, isNot(contains('submission.clientAttemptToken')));
      expect(repoSource, isNot(contains('params.toString()')));
      expect(repoSource, isNot(contains('accessToken')));
      expect(repoSource, isNot(contains('refreshToken')));
      expect(repoSource, isNot(contains('currentSession')));
      expect(repoSource, isNot(contains('\'types=\${params\'')));
    });

    test('query solo exam_quiz_attempts / exam_quiz_attempt_answers', () {
      expect(repoSource, contains(".from('exam_quiz_attempts')"));
      expect(repoSource, contains(".from('exam_quiz_attempt_answers')"));
      expect(repoSource, contains("order('completed_at', ascending: false)"));
      expect(repoSource, contains("order('position', ascending: true)"));
    });

    test('lista corrente filtra esplicitamente per user_id', () {
      expect(repoSource, contains(".eq('user_id', uid)"));
      expect(
        repoSource,
        contains("fetchCurrentUserAttempts"),
      );
    });
  });

  group('ExamQuizAttempt submit RPC params (P9E.6-A3)', () {
    test('toRpcParams espone esattamente cinque chiavi p_*', () {
      final params = _submission().toRpcParams();
      expect(params.keys.toSet(), examQuizAttemptSubmitRpcParamKeys);
      for (final key in params.keys) {
        expect(key.startsWith('p_'), isTrue);
      }
      expect(params.containsKey('client_attempt_token'), isFalse);
      expect(params.containsKey('license_category'), isFalse);
    });

    test('tipi Dart attesi per ogni parametro RPC', () {
      final params = _submission().toRpcParams();
      expect(params['p_client_attempt_token'], isA<String>());
      expect(params['p_license_category'], isA<String>());
      expect(params['p_duration_seconds'], isA<int>());
      expect(params['p_time_expired'], isA<bool>());
      expect(params['p_answers'], isA<List<dynamic>>());
      expect(
        examQuizAttemptRpcParamTypeLabel(params['p_client_attempt_token']),
        'String',
      );
      expect(examQuizAttemptRpcParamTypeLabel(params['p_answers']), 'List');
    });

    test('validateExamQuizAttemptSubmitRpcParams accetta payload valido', () {
      expect(
        () =>
            validateExamQuizAttemptSubmitRpcParams(_submission().toRpcParams()),
        returnsNormally,
      );
    });

    test('validateExamQuizAttemptSubmitRpcParams rifiuta chiavi errate', () {
      expect(
        () => validateExamQuizAttemptSubmitRpcParams({
          'p_client_attempt_token': 'x',
          'license_category': 'A12',
        }),
        throwsA(
          isA<ExamQuizAttemptException>().having(
            (e) => e.code,
            'code',
            ExamQuizAttemptErrorCode.invalidPayload,
          ),
        ),
      );
    });
  });

  group('ExamQuizAttempt error mapping', () {
    test('estrae codici RPC noti', () {
      expect(
        extractExamQuizAttemptErrorCode(
          const PostgrestException(message: 'idempotency_conflict'),
        ),
        ExamQuizAttemptErrorCode.idempotencyConflict,
      );
      expect(
        extractExamQuizAttemptErrorCode(
          const PostgrestException(message: 'exam_access_denied'),
        ),
        ExamQuizAttemptErrorCode.examAccessDenied,
      );
      expect(
        extractExamQuizAttemptErrorCode(
          const PostgrestException(message: 'not_authenticated'),
        ),
        ExamQuizAttemptErrorCode.notAuthenticated,
      );
      expect(
        extractExamQuizAttemptErrorCode(
          const PostgrestException(message: 'client_attempt_token_required'),
        ),
        ExamQuizAttemptErrorCode.clientAttemptTokenRequired,
      );
      expect(
        extractExamQuizAttemptErrorCode(
          const PostgrestException(message: 'question_not_valid_for_exam'),
        ),
        ExamQuizAttemptErrorCode.questionNotValidForExam,
      );
      expect(
        extractExamQuizAttemptErrorCode(
          const PostgrestException(message: 'invalid_exam_topic_quotas'),
        ),
        ExamQuizAttemptErrorCode.invalidExamTopicQuotas,
      );
      expect(
        examQuizAttemptErrorMessageIt(
          ExamQuizAttemptErrorCode.invalidExamTopicQuotas,
        ),
        contains('quote'),
      );
    });
  });

  group('parseExamQuizAttemptSubmitResult', () {
    test('mapping risultato idempotent=false', () {
      final result = parseExamQuizAttemptSubmitResult(
        _summaryJson(idempotent: false),
      );
      expect(result.idempotent, isFalse);
      expect(result.attemptId, 'att-1');
      expect(result.attempt.licenseCategory, LicenseCategoryId.motore);
      expect(result.attempt.correctCount, 16);
      expect(result.attempt.outcome, ExamQuizOutcome.passed);
      expect(result.attempt.duration.inSeconds, 900);
    });

    test('mapping risultato idempotent=true', () {
      final result = parseExamQuizAttemptSubmitResult(
        _summaryJson(idempotent: true),
      );
      expect(result.idempotent, isTrue);
      expect(result.attempt.outcome, ExamQuizOutcome.passed);
    });
  });

  group('parseExamQuizAttemptSummary / lista', () {
    test('mapping conteggi ed esito', () {
      final summary = parseExamQuizAttemptSummary(
        _summaryJson(correct: 10, wrong: 5, unanswered: 5, passed: false),
      );
      expect(summary.passed, isFalse);
      expect(summary.errorCount, 10);
      expect(summary.unansweredCount, 5);
    });

    test('rifiuta attempt id vuoto', () {
      expect(
        () => parseExamQuizAttemptSummary(_summaryJson(id: '  ')),
        throwsA(
          isA<ExamQuizAttemptException>().having(
            (e) => e.code,
            'code',
            ExamQuizAttemptErrorCode.invalidPayload,
          ),
        ),
      );
    });

    test('rifiuta categoria sconosciuta', () {
      expect(
        () => parseExamQuizAttemptSummary(_summaryJson(category: 'XX')),
        throwsA(
          isA<ExamQuizAttemptException>().having(
            (e) => e.code,
            'code',
            ExamQuizAttemptErrorCode.invalidLicenseCategory,
          ),
        ),
      );
    });

    test('rifiuta timestamp non valido', () {
      expect(
        () => parseExamQuizAttemptSummary(
          _summaryJson(completedAt: 'not-a-date'),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('rifiuta conteggi negativi', () {
      expect(
        () => parseExamQuizAttemptSummary(_summaryJson(wrong: -1)),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('rifiuta somma conteggi diversa dal totale', () {
      expect(
        () => parseExamQuizAttemptSummary(
          _summaryJson(correct: 10, wrong: 1, unanswered: 1, passed: true),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('rifiuta passed incoerente con errori', () {
      expect(
        () => parseExamQuizAttemptSummary(
          _summaryJson(correct: 10, wrong: 5, unanswered: 5, passed: true),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('D1 accetta 15 domande e soglia 3 errori', () {
      final summary = parseExamQuizAttemptSummary(
        _summaryJson(
          category: 'D1',
          total: 15,
          correct: 12,
          wrong: 2,
          unanswered: 1,
          passed: true,
        ),
      );
      expect(summary.licenseCategory, LicenseCategoryId.d1);
      expect(summary.totalQuestions, 15);
      expect(summary.outcome, ExamQuizOutcome.passed);
    });

    test('D1 rifiuta passed con 4 errori', () {
      expect(
        () => parseExamQuizAttemptSummary(
          _summaryJson(
            category: 'D1',
            total: 15,
            correct: 11,
            wrong: 3,
            unanswered: 1,
            passed: true,
          ),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('D1 rifiuta total_questions=20 anche se conteggi coerenti', () {
      expect(
        () => parseExamQuizAttemptSummary(
          _summaryJson(
            category: 'D1',
            total: 20,
            correct: 16,
            wrong: 3,
            unanswered: 1,
            passed: true,
          ),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('D1 rifiuta total_questions=14', () {
      expect(
        () => parseExamQuizAttemptSummary(
          _summaryJson(
            category: 'D1',
            total: 14,
            correct: 12,
            wrong: 1,
            unanswered: 1,
            passed: true,
          ),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('A12 rifiuta total_questions=15', () {
      expect(
        () => parseExamQuizAttemptSummary(
          _summaryJson(
            category: 'A12',
            total: 15,
            correct: 12,
            wrong: 2,
            unanswered: 1,
            passed: true,
          ),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });
  });

  group('parseExamQuizAttemptResult dettaglio', () {
    test(
      '20 snapshot ordinati, mix corretta/errata/non risposta, image null',
      () {
        final result = parseExamQuizAttemptResult(
          attemptJson: _summaryJson(),
          answerRows: _twentyAnswers(),
        );
        expect(result.answers, hasLength(20));
        expect(result.answers.first.position, 1);
        expect(result.answers.last.position, 20);
        expect(result.answers[0].isCorrect, isTrue);
        expect(result.answers[16].isCorrect, isFalse);
        expect(result.answers[16].selectedOption, QuizAnswerOption.b);
        expect(result.answers[19].isUnanswered, isTrue);
        expect(result.answers[0].imagePath, isNull);
        // Review indipendente da tabella questions: snapshot presenti.
        expect(result.answers[0].prompt, isNotEmpty);
        expect(result.answers[0].optionA, isNotEmpty);
        expect(result.answers[0].correctOption, QuizAnswerOption.a);
      },
    );

    test('ordina risposte anche se input disordinato', () {
      final rows = _twentyAnswers().reversed.toList();
      final result = parseExamQuizAttemptResult(
        attemptJson: _summaryJson(),
        answerRows: rows,
      );
      expect(result.answers.map((a) => a.position).toList(), [
        for (var i = 1; i <= 20; i++) i,
      ]);
    });

    test('rifiuta numero risposte diverso da total_questions', () {
      expect(
        () => parseExamQuizAttemptResult(
          attemptJson: _summaryJson(),
          answerRows: _twentyAnswers().take(19).toList(),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('rifiuta posizioni duplicate', () {
      final rows = _twentyAnswers();
      rows[1] = _answerJson(
        position: 1,
        questionId: '00000000-0000-0000-0000-000000000099',
        selected: 'A',
        correct: 'A',
      );
      expect(
        () => parseExamQuizAttemptResult(
          attemptJson: _summaryJson(),
          answerRows: rows,
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('rifiuta posizioni non sequenziali', () {
      final rows = _twentyAnswers();
      rows[5] = _answerJson(
        position: 99,
        questionId: rows[5]['question_id'] as String,
        selected: 'A',
        correct: 'A',
      );
      expect(
        () => parseExamQuizAttemptResult(
          attemptJson: _summaryJson(),
          answerRows: rows,
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('rifiuta question_id duplicati', () {
      final rows = _twentyAnswers();
      rows[2] = _answerJson(
        position: 3,
        questionId: rows[0]['question_id'] as String,
        selected: 'A',
        correct: 'A',
      );
      expect(
        () => parseExamQuizAttemptResult(
          attemptJson: _summaryJson(),
          answerRows: rows,
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('rifiuta opzioni invalide', () {
      expect(
        () => parseExamQuizAttemptAnswerSnapshot(
          _answerJson(
            position: 1,
            questionId: 'q1',
            selected: 'Z',
            correct: 'A',
            isCorrect: false,
          ),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });

    test('rifiuta is_correct incoerente', () {
      expect(
        () => parseExamQuizAttemptAnswerSnapshot(
          _answerJson(
            position: 1,
            questionId: 'q1',
            selected: 'A',
            correct: 'A',
            isCorrect: false,
          ),
        ),
        throwsA(isA<ExamQuizAttemptException>()),
      );
    });
  });

  group('ExamQuizAttemptRepositoryFake', () {
    test('submit usa toRpcParams senza campi autorevoli', () async {
      final attempt = _summary();
      final repo = ExamQuizAttemptRepositoryFake(
        submitResult: ExamQuizAttemptSubmitResult(
          attempt: attempt,
          idempotent: false,
        ),
      );
      final submission = _submission();
      final result = await repo.submitAttempt(submission);
      expect(result.idempotent, isFalse);
      expect(repo.submitCalls, 1);
      final params = repo.submitRpcParamsLog.single;
      expect(params.keys.toSet(), {
        'p_client_attempt_token',
        'p_license_category',
        'p_duration_seconds',
        'p_time_expired',
        'p_answers',
      });
      expect(params.containsKey('p_user_id'), isFalse);
      expect(params.containsKey('p_correct_count'), isFalse);
      expect(params.containsKey('p_passed'), isFalse);
      expect(params['p_license_category'], 'A12');
    });

    test('submit idempotent=true e errori tipizzati', () async {
      final repo = ExamQuizAttemptRepositoryFake(
        submitResult: ExamQuizAttemptSubmitResult(
          attempt: _summary(),
          idempotent: true,
        ),
      );
      expect((await repo.submitAttempt(_submission())).idempotent, isTrue);

      repo.throwOnSubmit = ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.idempotencyConflict,
        message: examQuizAttemptErrorMessageIt(
          ExamQuizAttemptErrorCode.idempotencyConflict,
        ),
      );
      await expectLater(
        repo.submitAttempt(_submission()),
        throwsA(
          isA<ExamQuizAttemptException>().having(
            (e) => e.code,
            'code',
            ExamQuizAttemptErrorCode.idempotencyConflict,
          ),
        ),
      );

      repo.throwOnSubmit = ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.examAccessDenied,
        message: examQuizAttemptErrorMessageIt(
          ExamQuizAttemptErrorCode.examAccessDenied,
        ),
      );
      await expectLater(
        repo.submitAttempt(_submission()),
        throwsA(
          isA<ExamQuizAttemptException>().having(
            (e) => e.code,
            'code',
            ExamQuizAttemptErrorCode.examAccessDenied,
          ),
        ),
      );

      repo.throwOnSubmit = ExamQuizAttemptException(
        code: ExamQuizAttemptErrorCode.notAuthenticated,
        message: examQuizAttemptErrorMessageIt(
          ExamQuizAttemptErrorCode.notAuthenticated,
        ),
      );
      await expectLater(
        repo.submitAttempt(_submission()),
        throwsA(
          isA<ExamQuizAttemptException>().having(
            (e) => e.code,
            'code',
            ExamQuizAttemptErrorCode.notAuthenticated,
          ),
        ),
      );
    });

    test('lista: filtro categoria, ordinamento, vuota', () async {
      final repo = ExamQuizAttemptRepositoryFake(
        summaries: [
          _summary(id: 'old', completedAt: DateTime.utc(2026, 7, 1)),
          _summary(id: 'new', completedAt: DateTime.utc(2026, 7, 20)),
          _summary(
            id: 'd1',
            category: LicenseCategoryId.d1,
            completedAt: DateTime.utc(2026, 7, 21),
          ),
        ],
      );
      final motore = await repo.fetchCurrentUserAttempts(
        category: LicenseCategoryId.motore,
      );
      expect(motore.map((s) => s.id).toList(), ['new', 'old']);

      final d1 = await repo.fetchCurrentUserAttempts(
        category: LicenseCategoryId.d1,
      );
      expect(d1.single.id, 'd1');

      final emptyRepo = ExamQuizAttemptRepositoryFake();
      expect(
        await emptyRepo.fetchCurrentUserAttempts(
          category: LicenseCategoryId.motore,
        ),
        isEmpty,
      );
    });

    test('dettaglio e not found', () async {
      final detail = parseExamQuizAttemptResult(
        attemptJson: _summaryJson(id: 'att-x'),
        answerRows: _twentyAnswers(),
      );
      final repo = ExamQuizAttemptRepositoryFake(details: {'att-x': detail});
      final loaded = await repo.fetchAttemptDetail('att-x');
      expect(loaded.answers, hasLength(20));
      expect(loaded.id, 'att-x');

      await expectLater(
        repo.fetchAttemptDetail('missing'),
        throwsA(
          isA<ExamQuizAttemptException>().having(
            (e) => e.code,
            'code',
            ExamQuizAttemptErrorCode.attemptNotFound,
          ),
        ),
      );
    });
  });

  group('ExamQuizAttemptRepositoryEmpty', () {
    test('nessun falso successo', () async {
      const repo = ExamQuizAttemptRepositoryEmpty();
      await expectLater(
        repo.submitAttempt(_submission()),
        throwsA(
          isA<ExamQuizAttemptException>().having(
            (e) => e.code,
            'code',
            ExamQuizAttemptErrorCode.repositoryUnavailable,
          ),
        ),
      );
      expect(
        await repo.fetchCurrentUserAttempts(category: LicenseCategoryId.motore),
        isEmpty,
      );
      await expectLater(
        repo.fetchAttemptDetail('any'),
        throwsA(
          isA<ExamQuizAttemptException>().having(
            (e) => e.code,
            'code',
            ExamQuizAttemptErrorCode.attemptNotFound,
          ),
        ),
      );
    });
  });
}
