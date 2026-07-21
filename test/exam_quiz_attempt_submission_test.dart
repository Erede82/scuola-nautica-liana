import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_attempt_submission.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';

QuizQuestion _question(
  int index, {
  QuizAnswerOption correct = QuizAnswerOption.a,
}) {
  return QuizQuestion(
    id: 'q-$index',
    prompt: 'Domanda $index?',
    optionA: 'A$index',
    optionB: 'B$index',
    optionC: 'C$index',
    correctOption: correct,
    lessonNumber: 1,
    licenseCategory: 'A12',
  );
}

List<QuizQuestion> _twentyQuestions() =>
    List.generate(ExamQuizRules.questionCount, (i) => _question(i));

void main() {
  group('buildExamQuizAttemptSubmission - payload valido', () {
    test('20 domande con mix corrette/errate/non risposte', () {
      final questions = _twentyQuestions();
      final answers = <QuizAnswerOption?>[
        for (var i = 0; i < 20; i++)
          if (i < 12)
            QuizAnswerOption
                .a // corrette
          else if (i < 17)
            QuizAnswerOption
                .b // errate
          else
            null, // non risposte
      ];

      final submission = buildExamQuizAttemptSubmission(
        licenseCategory: LicenseCategoryId.motore,
        clientAttemptToken: 'token-123',
        duration: const Duration(minutes: 12),
        timeExpired: false,
        questions: questions,
        userAnswers: answers,
      );

      expect(submission.answers.length, 20);
      expect(submission.clientAttemptToken, 'token-123');
      expect(submission.licenseCategory, LicenseCategoryId.motore);
      expect(submission.duration, const Duration(minutes: 12));
      expect(submission.timeExpired, isFalse);

      for (var i = 0; i < 20; i++) {
        expect(submission.answers[i].position, i + 1);
        expect(submission.answers[i].questionId, 'q-$i');
      }
      expect(submission.answers[17].selectedOption, isNull);
      expect(submission.answers[0].selectedOption, QuizAnswerOption.a);
      expect(submission.answers[12].selectedOption, QuizAnswerOption.b);
    });

    test(
      'payload non contiene dati di sicurezza (solo id/posizione/scelta)',
      () {
        final submission = buildExamQuizAttemptSubmission(
          licenseCategory: LicenseCategoryId.motore,
          clientAttemptToken: 'token',
          duration: const Duration(minutes: 5),
          timeExpired: true,
          questions: _twentyQuestions(),
          userAnswers: List<QuizAnswerOption?>.filled(20, QuizAnswerOption.a),
        );

        final params = submission.toRpcParams();
        expect(params['p_client_attempt_token'], 'token');
        expect(params['p_time_expired'], isTrue);
        expect(params['p_license_category'], 'A12');

        final forbiddenKeys = <String>{
          'user_id',
          'student_id',
          'correct_option',
          'is_correct',
          'correct_count',
          'wrong_count',
          'unanswered_count',
          'passed',
          'prompt',
          'option_a',
          'option_b',
          'option_c',
          'image_path',
        };
        for (final key in forbiddenKeys) {
          expect(
            params.containsKey(key),
            isFalse,
            reason: 'payload principale contiene $key',
          );
        }

        final rows = params['p_answers'] as List;
        expect(rows.length, 20);
        const allowedRowKeys = {'position', 'question_id', 'selected_option'};
        for (var i = 0; i < rows.length; i++) {
          final row = rows[i] as Map<String, dynamic>;
          expect(
            row.keys.toSet(),
            allowedRowKeys,
            reason: 'riga $i ha chiavi non consentite: ${row.keys}',
          );
          for (final key in forbiddenKeys) {
            expect(
              row.containsKey(key),
              isFalse,
              reason: 'riga $i contiene $key',
            );
          }
        }
      },
    );
  });

  group('toRpcParams - serializzazione categoria DB', () {
    ExamQuizAttemptSubmission payloadFor(LicenseCategoryId category) {
      return ExamQuizAttemptSubmission(
        clientAttemptToken: 'token',
        licenseCategory: category,
        duration: const Duration(minutes: 1),
        timeExpired: false,
        answers: const [
          ExamQuizSubmissionAnswer(
            position: 1,
            questionId: 'q-0',
            selectedOption: null,
          ),
        ],
      );
    }

    test('motore → A12', () {
      expect(
        payloadFor(
          LicenseCategoryId.motore,
        ).toRpcParams()['p_license_category'],
        'A12',
      );
    });

    test('d1 → D1', () {
      expect(
        payloadFor(LicenseCategoryId.d1).toRpcParams()['p_license_category'],
        'D1',
      );
    });

    test('vela → null (nessun codice DB nel mapping esistente)', () {
      // dbLicenseCategoryFor(vela) restituisce null: nessun inventato codice DB.
      expect(
        payloadFor(LicenseCategoryId.vela).toRpcParams()['p_license_category'],
        isNull,
      );
    });
  });

  group('buildExamQuizAttemptSubmission - idempotenza', () {
    test('stesso token e stessi input producono payload equivalenti', () {
      final questions = _twentyQuestions();
      final answers = List<QuizAnswerOption?>.generate(
        20,
        (i) => i.isEven ? QuizAnswerOption.a : null,
      );

      ExamQuizAttemptSubmission build() => buildExamQuizAttemptSubmission(
        licenseCategory: LicenseCategoryId.motore,
        clientAttemptToken: 'stable-token',
        duration: const Duration(minutes: 30),
        timeExpired: false,
        questions: questions,
        userAnswers: answers,
      );

      final a = build();
      final b = build();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      // Il token non viene mutato dal builder.
      expect(a.clientAttemptToken, 'stable-token');
      expect(b.clientAttemptToken, 'stable-token');
    });
  });

  group('buildExamQuizAttemptSubmission - tutte non risposte', () {
    test('il payload mantiene tutte le 20 righe', () {
      final submission = buildExamQuizAttemptSubmission(
        licenseCategory: LicenseCategoryId.motore,
        clientAttemptToken: 'token',
        duration: Duration.zero,
        timeExpired: true,
        questions: _twentyQuestions(),
        userAnswers: List<QuizAnswerOption?>.filled(20, null),
      );

      expect(submission.answers.length, 20);
      expect(submission.answers.every((a) => a.selectedOption == null), isTrue);
      for (var i = 0; i < 20; i++) {
        expect(submission.answers[i].position, i + 1);
      }
    });
  });

  group('buildExamQuizAttemptSubmission - validazioni', () {
    ExamQuizAttemptSubmission callWith({
      String token = 'token',
      Duration duration = const Duration(minutes: 1),
      List<QuizQuestion>? questions,
      List<QuizAnswerOption?>? userAnswers,
    }) {
      final qs = questions ?? _twentyQuestions();
      return buildExamQuizAttemptSubmission(
        licenseCategory: LicenseCategoryId.motore,
        clientAttemptToken: token,
        duration: duration,
        timeExpired: false,
        questions: qs,
        userAnswers:
            userAnswers ?? List<QuizAnswerOption?>.filled(qs.length, null),
      );
    }

    test('token vuoto', () {
      expect(() => callWith(token: '   '), throwsArgumentError);
    });

    test('durata negativa', () {
      expect(
        () => callWith(duration: const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });

    test('lista domande vuota', () {
      expect(
        () => callWith(questions: const [], userAnswers: const []),
        throwsArgumentError,
      );
    });

    test('numero domande diverso da 20', () {
      final nineteen = List.generate(19, (i) => _question(i));
      expect(
        () => callWith(
          questions: nineteen,
          userAnswers: List<QuizAnswerOption?>.filled(19, null),
        ),
        throwsArgumentError,
      );
    });

    test('id domanda duplicati', () {
      final questions = _twentyQuestions();
      final withDup = [...questions.sublist(0, 19), questions[0]];
      expect(
        () => callWith(
          questions: withDup,
          userAnswers: List<QuizAnswerOption?>.filled(20, null),
        ),
        throwsArgumentError,
      );
    });

    test('risposta per domanda estranea (disallineamento lunghezze)', () {
      expect(
        () => callWith(
          userAnswers: List<QuizAnswerOption?>.filled(21, QuizAnswerOption.a),
        ),
        throwsArgumentError,
      );
    });
  });

  group('riepilogo locale - coerenza con buildExamQuizSummary', () {
    test('examQuizSummaryFromAnswers non duplica la soglia di superamento', () {
      final questions = _twentyQuestions(); // corrette = A
      // 16 corrette, 3 errate, 1 non risposta -> 4 errori -> passed (<=4).
      final answers = <QuizAnswerOption?>[
        for (var i = 0; i < 16; i++) QuizAnswerOption.a,
        QuizAnswerOption.b,
        QuizAnswerOption.b,
        QuizAnswerOption.b,
        null,
      ];

      final summary = examQuizSummaryFromAnswers(
        questions: questions,
        userAnswers: answers,
      );

      final reference = buildExamQuizSummary(
        totalQuestions: 20,
        correctCount: 16,
        wrongCount: 3,
        unansweredCount: 1,
      );

      expect(summary.correctCount, reference.correctCount);
      expect(summary.wrongCount, reference.wrongCount);
      expect(summary.unansweredCount, reference.unansweredCount);
      expect(summary.errorCount, reference.errorCount);
      expect(summary.outcome, reference.outcome);
      expect(summary.outcome, ExamQuizOutcome.passed);
    });

    test('le non risposte contano come errore per l\'esito', () {
      final questions = _twentyQuestions();
      // 15 corrette, 0 errate, 5 non risposte -> 5 errori -> failed (>4).
      final answers = <QuizAnswerOption?>[
        for (var i = 0; i < 15; i++) QuizAnswerOption.a,
        for (var i = 0; i < 5; i++) null,
      ];

      final summary = examQuizSummaryFromAnswers(
        questions: questions,
        userAnswers: answers,
      );

      expect(summary.unansweredCount, 5);
      expect(summary.errorCount, 5);
      expect(summary.outcome, ExamQuizOutcome.failed);
    });
  });
}
