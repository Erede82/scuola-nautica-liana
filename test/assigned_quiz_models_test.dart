import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/mappers/assigned_quiz_mapper.dart';
import 'package:scuola_nautica_liana/models/assigned_quiz_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/repositories/assigned_quiz_repository.dart';

void main() {
  group('AssignedQuiz enums parsing', () {
    test('status', () {
      expect(AssignedQuizStatus.tryParse('draft'), AssignedQuizStatus.draft);
      expect(
        AssignedQuizStatus.tryParse('ASSIGNED'),
        AssignedQuizStatus.assigned,
      );
      expect(
        AssignedQuizStatus.tryParse('archived'),
        AssignedQuizStatus.archived,
      );
      expect(AssignedQuizStatus.tryParse('nope'), isNull);
    });

    test('repeat policy', () {
      expect(
        AssignedQuizRepeatPolicy.tryParse('unlimited'),
        AssignedQuizRepeatPolicy.unlimited,
      );
      expect(
        AssignedQuizRepeatPolicy.tryParse('limited'),
        AssignedQuizRepeatPolicy.limited,
      );
      expect(AssignedQuizRepeatPolicy.tryParse('x'), isNull);
    });

    test('attempt status', () {
      expect(
        AssignedQuizAttemptStatus.tryParse('in_progress'),
        AssignedQuizAttemptStatus.inProgress,
      );
      expect(
        AssignedQuizAttemptStatus.tryParse('submitted'),
        AssignedQuizAttemptStatus.submitted,
      );
      expect(
        AssignedQuizAttemptStatus.tryParse('abandoned'),
        AssignedQuizAttemptStatus.abandoned,
      );
      expect(AssignedQuizAttemptStatus.tryParse('running'), isNull);
    });
  });

  group('AssignedQuizGenerationRequest validation', () {
    AssignedQuizGenerationRequest base({
      String title = 'Ripasso personalizzato',
      int questionCount = 20,
      AssignedQuizLessonFilterMode lessonFilterMode =
          AssignedQuizLessonFilterMode.allLessons,
      List<int> lessonNumbers = const [],
      AssignedQuizRepeatPolicy repeatPolicy =
          AssignedQuizRepeatPolicy.unlimited,
      int? maxAttempts,
      DateTime? expiresAt,
    }) {
      return AssignedQuizGenerationRequest(
        studentId: 'student-1',
        title: title,
        questionCount: questionCount,
        lessonFilterMode: lessonFilterMode,
        lessonNumbers: lessonNumbers,
        repeatPolicy: repeatPolicy,
        maxAttempts: maxAttempts,
        expiresAt: expiresAt,
      );
    }

    test('questionCount 0 e 51 rifiutati', () {
      expect(base(questionCount: 0).validate(), isNotNull);
      expect(base(questionCount: 51).validate(), isNotNull);
      expect(base(questionCount: 1).validate(), isNull);
      expect(base(questionCount: 50).validate(), isNull);
    });

    test('selected lessons vuote rifiutate', () {
      expect(
        base(
          lessonFilterMode: AssignedQuizLessonFilterMode.selectedLessons,
          lessonNumbers: const [],
        ).validate(),
        isNotNull,
      );
    });

    test('lezioni fuori 1–14 rifiutate', () {
      expect(
        base(
          lessonFilterMode: AssignedQuizLessonFilterMode.selectedLessons,
          lessonNumbers: const [0, 1],
        ).validate(),
        isNotNull,
      );
      expect(
        base(
          lessonFilterMode: AssignedQuizLessonFilterMode.selectedLessons,
          lessonNumbers: const [1, 15],
        ).validate(),
        isNotNull,
      );
      expect(
        base(
          lessonFilterMode: AssignedQuizLessonFilterMode.selectedLessons,
          lessonNumbers: const [1, 14],
        ).validate(),
        isNull,
      );
    });

    test('limited senza maxAttempts rifiutato', () {
      expect(
        base(
          repeatPolicy: AssignedQuizRepeatPolicy.limited,
          maxAttempts: null,
        ).validate(),
        isNotNull,
      );
    });

    test('unlimited con maxAttempts rifiutato', () {
      expect(
        base(
          repeatPolicy: AssignedQuizRepeatPolicy.unlimited,
          maxAttempts: 3,
        ).validate(),
        isNotNull,
      );
    });

    test('titolo vuoto rifiutato', () {
      expect(base(title: '   ').validate(), isNotNull);
    });

    test('expiry passata rifiutata', () {
      expect(
        base(
          expiresAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
        ).validate(),
        isNotNull,
      );
      expect(
        base(
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        ).validate(),
        isNull,
      );
    });

    test('categoria non presente nella request / RPC params', () {
      final request = base();
      final params = assignedQuizGenerateRpcParams(request);
      expect(params.containsKey('license_category'), isFalse);
      expect(params.containsKey('p_license_category'), isFalse);
      expect(params['p_student_id'], 'student-1');
      expect(params['p_title'], 'Ripasso personalizzato');
      expect(params['p_question_count'], 20);
    });
  });

  group('AssignedQuiz mapper parsing', () {
    test('summary', () {
      final summary = parseAssignedQuizSummary({
        'id': 'aq-1',
        'public_code': 'AQZ-2026-00001',
        'student_id': 'st-1',
        'student_user_id': 'user-1',
        'license_category': 'A12',
        'title': 'Quiz errori',
        'staff_note': null,
        'status': 'assigned',
        'question_count': 10,
        'repeat_policy': 'unlimited',
        'max_attempts': null,
        'created_at': '2026-07-16T10:00:00Z',
        'assigned_at': '2026-07-16T10:01:00Z',
        'expires_at': null,
        'archived_at': null,
      });
      expect(summary.id, 'aq-1');
      expect(summary.status, AssignedQuizStatus.assigned);
      expect(summary.maxAttempts, isNull);
      expect(summary.expiresAt, isNull);
      expect(summary.createdAt.isUtc, isTrue);
    });

    test('generation result', () {
      final result = parseAssignedQuizGenerationResult({
        'assignment_id': 'aq-1',
        'public_code': 'AQZ-2026-00001',
        'item_count': 12,
        'status': 'draft',
        'license_category': 'D1',
        'idempotent': true,
      });
      expect(result.itemCount, 12);
      expect(result.status, AssignedQuizStatus.draft);
      expect(result.idempotent, isTrue);
    });

    test('start result', () {
      final result = parseAssignedQuizAttemptStartResult({
        'attempt_id': 'att-1',
        'attempt_number': 2,
        'resumed': true,
        'question_count': 8,
        'max_attempts': 3,
        'attempts_used': 2,
      });
      expect(result.resumed, isTrue);
      expect(result.maxAttempts, 3);
    });

    test('question senza campi soluzione', () {
      final question = parseAssignedQuizQuestion({
        'assignment_item_id': 'item-1',
        'position': 1,
        'prompt': 'Domanda?',
        'option_a': 'A',
        'option_b': 'B',
        'option_c': 'C',
        'image_path': null,
        'lesson_number': 3,
        'selected_option': null,
      });
      expect(question.selectedOption, isNull);
      expect(question.lessonNumber, 3);
      expect(
        () => (question as dynamic).correctOption,
        throwsNoSuchMethodError,
      );
      expect(() => (question as dynamic).explanation, throwsNoSuchMethodError);
      expect(() => (question as dynamic).isCorrect, throwsNoSuchMethodError);
    });

    test('question rifiuta payload con correct_option', () {
      expect(
        () => parseAssignedQuizQuestion({
          'assignment_item_id': 'item-1',
          'position': 1,
          'prompt': 'Domanda?',
          'option_a': 'A',
          'option_b': 'B',
          'option_c': 'C',
          'lesson_number': 1,
          'correct_option': 'A',
        }),
        throwsFormatException,
      );
    });

    test('save result con selectedOption null', () {
      final result = parseAssignedQuizAnswerSaveResult({
        'assignment_item_id': 'item-1',
        'selected_option': null,
        'answered_at': null,
      });
      expect(result.selectedOption, isNull);
      expect(result.answeredAt, isNull);
    });

    test('submit result', () {
      final result = parseAssignedQuizSubmitResult({
        'attempt_id': 'att-1',
        'attempt_number': 1,
        'correct_count': 7,
        'wrong_count': 2,
        'unanswered_count': 1,
        'score_percentage': 70.0,
        'submitted_at': '2026-07-16T12:00:00Z',
        'already_submitted': false,
      });
      expect(result.scorePercentage, 70);
      expect(result.submittedAt!.isUtc, isTrue);
    });

    test('review item con explanation null', () {
      final item = parseAssignedQuizReviewItem({
        'position': 1,
        'prompt': 'P?',
        'option_a': 'A',
        'option_b': 'B',
        'option_c': 'C',
        'image_path': null,
        'selected_option': 'B',
        'correct_option': 'A',
        'is_correct': false,
        'explanation': null,
        'lesson_number': 2,
      });
      expect(item.explanation, isNull);
      expect(item.correctOption, 'A');
    });

    test('attempt summary', () {
      final attempt = parseAssignedQuizAttemptSummary({
        'id': 'att-1',
        'assignment_id': 'aq-1',
        'attempt_number': 1,
        'status': 'in_progress',
        'started_at': '2026-07-16T11:00:00Z',
        'submitted_at': null,
        'abandoned_at': null,
        'correct_count': 0,
        'wrong_count': 0,
        'unanswered_count': 0,
        'score_percentage': null,
        'duration_seconds': null,
      });
      expect(attempt.status, AssignedQuizAttemptStatus.inProgress);
      expect(attempt.scorePercentage, isNull);
    });
  });

  group('mapping A/B/C ↔ marker', () {
    test('option letter e marker', () {
      expect(QuizAnswerOption.a.letter, 'A');
      expect(assignedQuizOptionToMarkerNumber(QuizAnswerOption.a), 1);
      expect(assignedQuizOptionToMarkerNumber(QuizAnswerOption.b), 2);
      expect(assignedQuizOptionToMarkerNumber(QuizAnswerOption.c), 3);
      expect(assignedQuizMarkerNumberToOption(1), QuizAnswerOption.a);
      expect(normalizeAssignedQuizSelectedOption('b'), 'B');
      expect(normalizeAssignedQuizSelectedOption(null), isNull);
      expect(
        () => normalizeAssignedQuizSelectedOption('Z'),
        throwsA(isA<AssignedQuizException>()),
      );
    });
  });

  group('error mapping', () {
    test('estrae codice da messaggio grezzo', () {
      expect(
        extractAssignedQuizErrorCode(Exception('not_authorized')),
        AssignedQuizErrorCode.notAuthorized,
      );
      expect(
        extractAssignedQuizErrorCode(
          Exception(
            'PostgrestException(message: insufficient_error_questions)',
          ),
        ),
        AssignedQuizErrorCode.insufficientErrorQuestions,
      );
      expect(
        assignedQuizExceptionFrom(Exception('attempt_limit_reached')).message,
        contains('massimo'),
      );
    });
  });

  group('AssignedQuizRepositoryFake', () {
    test(
      'generate non invia license_category e rispetta validazione',
      () async {
        final repo = AssignedQuizRepositoryFake();
        await repo.generateFromErrors(
          const AssignedQuizGenerationRequest(
            studentId: 'st-1',
            title: 'Test',
            questionCount: 5,
          ),
        );
        expect(repo.rpcCalls, contains('generate_assigned_quiz_from_errors'));
        expect(
          repo.lastGenerateParams!.containsKey('p_license_category'),
          isFalse,
        );
        expect(repo.lastGenerateParams!['p_question_count'], 5);
      },
    );

    test('submit non invia punteggi', () async {
      final repo = AssignedQuizRepositoryFake();
      await repo.submitAttempt('att-1');
      expect(repo.lastSubmitParams, {'p_attempt_id': 'att-1'});
      expect(repo.lastSubmitParams!.containsKey('score'), isFalse);
      expect(repo.lastSubmitParams!.containsKey('correct_count'), isFalse);
    });

    test('saveAnswer normalizza selectedOption null', () async {
      final repo = AssignedQuizRepositoryFake();
      final result = await repo.saveAnswer(
        attemptId: 'att-1',
        assignmentItemId: 'item-1',
        selectedOption: null,
      );
      expect(result.selectedOption, isNull);
      expect(repo.lastSavedOption, isNull);
    });
  });
}
