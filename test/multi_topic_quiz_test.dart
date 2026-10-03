import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/license_catalog.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/quiz_sheet_catalog_row.dart';
import 'package:scuola_nautica_liana/domain/lesson_quiz_rules.dart';
import 'package:scuola_nautica_liana/domain/lesson_sheet_catalog_filter.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_client_token.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_history_answer_review.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_question_selection.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_attempt_exception.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_attempt_result.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_attempt_submission.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_guards.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_history_models.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_session.dart';
import 'package:scuola_nautica_liana/domain/multi_topic_quiz_support.dart';
import 'package:scuola_nautica_liana/domain/quiz_license_category.dart';
import 'package:scuola_nautica_liana/domain/quiz_sheet_exit_policy.dart';
import 'package:scuola_nautica_liana/data/supabase/mappers/multi_topic_quiz_attempt_mapper.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/models/quiz_question.dart';
import 'package:scuola_nautica_liana/repositories/multi_topic_quiz_attempt_repository.dart';

QuizQuestion _q(
  String id, {
  required int lesson,
  String licenseCategory = 'A12',
}) => QuizQuestion(
  id: id,
  prompt: 'Prompt $id',
  optionA: 'A',
  optionB: 'B',
  optionC: 'C',
  correctOption: QuizAnswerOption.a,
  lessonNumber: lesson,
  licenseCategory: licenseCategory,
);

QuizSheetCatalogRow _catalogRow({
  required String id,
  required String licenseCategory,
  required int lessonNumber,
  required int sheetNumber,
}) => QuizSheetCatalogRow(
  id: id,
  kind: 'lesson',
  licenseCategory: licenseCategory,
  lessonNumber: lessonNumber,
  sheetNumber: sheetNumber,
);

void main() {
  group('STUDIO → SCHEDE catalog filtering', () {
    test('1. A12 lesson with quiz → present', () {
      final catalog = [
        _catalogRow(
          id: 'a',
          licenseCategory: 'A12',
          lessonNumber: 3,
          sheetNumber: 1,
        ),
      ];
      final filtered = filterLessonsWithRealSheets(
        catalogLessons: LicenseCatalog.patenteMotore.lessons,
        lessonNumbersWithSheets: lessonNumbersWithRealSheets(catalog),
      );
      expect(filtered.map((l) => l.number), contains(3));
    });

    test('2. D1 lesson with quiz → present', () {
      final catalog = [
        for (var lesson = 1; lesson <= 10; lesson++)
          _catalogRow(
            id: 'd$lesson',
            licenseCategory: 'D1',
            lessonNumber: lesson,
            sheetNumber: 1,
          ),
      ];
      final filtered = filterLessonsWithRealSheets(
        catalogLessons: LicenseCatalog.patenteD1.lessons,
        lessonNumbersWithSheets: lessonNumbersWithRealSheets(catalog),
      );
      expect(filtered.map((l) => l.number), containsAll([1, 5, 10]));
    });

    test('3. D1 lesson without quiz → absent', () {
      final catalog = [
        for (var lesson = 1; lesson <= 10; lesson++)
          _catalogRow(
            id: 'd$lesson',
            licenseCategory: 'D1',
            lessonNumber: lesson,
            sheetNumber: 1,
          ),
      ];
      final filtered = filterLessonsWithRealSheets(
        catalogLessons: LicenseCatalog.patenteD1.lessons,
        lessonNumbersWithSheets: lessonNumbersWithRealSheets(catalog),
      );
      expect(filtered.map((l) => l.number), isNot(contains(11)));
      expect(filtered.map((l) => l.number), isNot(contains(14)));
    });

    test('4. no hardcoded D1 <= 10', () {
      // Source of truth is quiz_sets catalog rows, not a magic 10.
      final withFuture = [
        for (var lesson = 1; lesson <= 12; lesson++)
          _catalogRow(
            id: 'd$lesson',
            licenseCategory: 'D1',
            lessonNumber: lesson,
            sheetNumber: 1,
          ),
      ];
      final filtered = filterLessonsWithRealSheets(
        catalogLessons: LicenseCatalog.patenteD1.lessons,
        lessonNumbersWithSheets: lessonNumbersWithRealSheets(withFuture),
      );
      expect(filtered.map((l) => l.number), contains(11));
      expect(filtered.map((l) => l.number), contains(12));
    });

    test('5. future D1 lesson cataloged → automatically visible', () {
      final catalog = [
        _catalogRow(
          id: 'd14',
          licenseCategory: 'D1',
          lessonNumber: 14,
          sheetNumber: 1,
        ),
      ];
      final filtered = filterLessonsWithRealSheets(
        catalogLessons: LicenseCatalog.patenteD1.lessons,
        lessonNumbersWithSheets: lessonNumbersWithRealSheets(catalog),
      );
      expect(filtered.single.number, 14);
    });

    test('6. Schede filter does not alter theory catalog lessons', () {
      expect(LicenseCatalog.patenteD1.lessons.length, 14);
      expect(LicenseCatalog.patenteMotore.lessons.length, 14);
    });
  });

  group('Multischeda eligibility', () {
    test('7. supported + pool + unlocked + sheets → selectable', () {
      expect(
        isLessonEligibleForMultiTopic(
          categoryId: LicenseCategoryId.motore,
          hasQuestionPool: true,
          isUnlocked: true,
          availableSheetCount: 6,
        ),
        isTrue,
      );
    });

    test('8. pool + locked → not selectable', () {
      expect(
        isLessonEligibleForMultiTopic(
          categoryId: LicenseCategoryId.motore,
          hasQuestionPool: true,
          isUnlocked: false,
          availableSheetCount: 0,
        ),
        isFalse,
      );
    });

    test('9. unlocked + no pool → not selectable', () {
      expect(
        isLessonEligibleForMultiTopic(
          categoryId: LicenseCategoryId.d1,
          hasQuestionPool: false,
          isUnlocked: true,
          availableSheetCount: 4,
        ),
        isFalse,
      );
    });

    test('9b. pool + unlocked + 0 sheets → not selectable', () {
      expect(
        isLessonEligibleForMultiTopic(
          categoryId: LicenseCategoryId.motore,
          hasQuestionPool: true,
          isUnlocked: true,
          availableSheetCount: 0,
        ),
        isFalse,
      );
    });

    test('10. completion is not a gate (function has no completion param)', () {
      expect(
        isLessonEligibleForMultiTopic(
          categoryId: LicenseCategoryId.motore,
          hasQuestionPool: true,
          isUnlocked: true,
          availableSheetCount: 1,
        ),
        isTrue,
      );
    });

    test('11. Vela → Multischeda unavailable', () {
      expect(isMultiTopicCategorySupported(LicenseCategoryId.vela), isFalse);
      expect(dbLicenseCategoryFor(LicenseCategoryId.vela), isNull);
      expect(
        isLessonEligibleForMultiTopic(
          categoryId: LicenseCategoryId.vela,
          hasQuestionPool: true,
          isUnlocked: true,
          availableSheetCount: 5,
        ),
        isFalse,
      );
    });
  });

  group('Question generation', () {
    Map<int, List<QuizQuestion>> pool({
      required int perLesson,
      required List<int> lessons,
      String cat = 'A12',
    }) {
      return {
        for (final lesson in lessons)
          lesson: List.generate(
            perLesson,
            (i) => _q('L$lesson-$i', lesson: lesson, licenseCategory: cat),
          ),
      };
    }

    test('12. only selected lessons', () {
      final picked = pickMultiTopicSheetQuestions(
        poolByLesson: pool(perLesson: 30, lessons: [1, 2, 3, 4]),
        selectedLessonNumbers: const [1, 3],
        questionsPerSheet: 20,
        sheetIndex: 1,
        usedQuestionIds: const {},
        random: Random(1),
      )!;
      expect(
        picked.questions.every(
          (q) => q.lessonNumber == 1 || q.lessonNumber == 3,
        ),
        isTrue,
      );
      expect(picked.questions.any((q) => q.lessonNumber == 2), isFalse);
    });

    test('13. A12 = 20', () {
      final rules = lessonQuizRulesForCategory(LicenseCategoryId.motore)!;
      expect(rules.questionsPerSheet, 20);
      final picked = pickMultiTopicSheetQuestions(
        poolByLesson: pool(perLesson: 40, lessons: [1, 2]),
        selectedLessonNumbers: const [1, 2],
        questionsPerSheet: rules.questionsPerSheet,
        sheetIndex: 1,
        usedQuestionIds: const {},
        random: Random(2),
      )!;
      expect(picked.questions, hasLength(20));
    });

    test('14. D1 = 15', () {
      final rules = lessonQuizRulesForCategory(LicenseCategoryId.d1)!;
      expect(rules.questionsPerSheet, 15);
      final picked = pickMultiTopicSheetQuestions(
        poolByLesson: pool(perLesson: 40, lessons: [1, 2], cat: 'D1'),
        selectedLessonNumbers: const [1, 2],
        questionsPerSheet: rules.questionsPerSheet,
        sheetIndex: 1,
        usedQuestionIds: const {},
        random: Random(3),
      )!;
      expect(picked.questions, hasLength(15));
    });

    test('15-16. balance with max difference 1', () {
      final quotas1 = multiTopicBalancedQuotas(
        questionsPerSheet: 20,
        lessonCount: 3,
        sheetIndex: 1,
      );
      expect(quotas1, [7, 7, 6]);
      final quotas2 = multiTopicBalancedQuotas(
        questionsPerSheet: 20,
        lessonCount: 3,
        sheetIndex: 2,
      );
      expect(quotas2, [6, 7, 7]);
      for (final q in [...quotas1, ...quotas2]) {
        expect(q, anyOf(6, 7));
      }
    });

    test('17. no intra-sheet duplicates', () {
      final picked = pickMultiTopicSheetQuestions(
        poolByLesson: pool(perLesson: 40, lessons: [1, 2, 3]),
        selectedLessonNumbers: const [1, 2, 3],
        questionsPerSheet: 20,
        sheetIndex: 1,
        usedQuestionIds: const {},
        random: Random(4),
      )!;
      expect(picked.questions.map((q) => q.id).toSet(), hasLength(20));
    });

    test('18-19. anti-repeat then reuse after exhaustion', () {
      final pools = pool(perLesson: 12, lessons: [1, 2]);
      final used = <String>{};
      final first = pickMultiTopicSheetQuestions(
        poolByLesson: pools,
        selectedLessonNumbers: const [1, 2],
        questionsPerSheet: 20,
        sheetIndex: 1,
        usedQuestionIds: used,
        allowReuse: false,
        random: Random(5),
      )!;
      used.addAll(first.questions.map((q) => q.id));
      expect(used, hasLength(20));

      final secondNoReuse = pickMultiTopicSheetQuestions(
        poolByLesson: pools,
        selectedLessonNumbers: const [1, 2],
        questionsPerSheet: 20,
        sheetIndex: 2,
        usedQuestionIds: used,
        allowReuse: false,
        random: Random(6),
      );
      expect(secondNoReuse, isNull);

      final secondReuse = pickMultiTopicSheetQuestions(
        poolByLesson: pools,
        selectedLessonNumbers: const [1, 2],
        questionsPerSheet: 20,
        sheetIndex: 2,
        usedQuestionIds: used,
        allowReuse: true,
        random: Random(7),
      )!;
      expect(secondReuse.usedReuse, isTrue);
      expect(secondReuse.questions.map((q) => q.id).toSet(), hasLength(20));
    });

    test('20. A12 lesson_number NULL excluded via lesson filter', () {
      // Questions without a selected lesson number never enter pools keyed by lesson.
      final pools = {
        1: [_q('a', lesson: 1)],
        2: [_q('b', lesson: 2)],
      };
      final picked = pickMultiTopicSheetQuestions(
        poolByLesson: pools,
        selectedLessonNumbers: const [1, 2],
        questionsPerSheet: 2,
        sheetIndex: 1,
        usedQuestionIds: const {},
        random: Random(8),
      )!;
      expect(picked.questions.every((q) => q.lessonNumber > 0), isTrue);
    });

    test('21. insufficient pool handled', () {
      final shortfall = findMultiTopicPoolShortfall(
        poolByLesson: {
          1: [_q('a', lesson: 1)],
          2: [_q('b', lesson: 2)],
        },
        selectedLessonNumbers: const [1, 2],
        questionsPerSheet: 20,
        sheetCount: 1,
      );
      expect(shortfall, isNotNull);
      expect(
        pickMultiTopicSheetQuestions(
          poolByLesson: {
            1: [_q('a', lesson: 1)],
            2: [_q('b', lesson: 2)],
          },
          selectedLessonNumbers: const [1, 2],
          questionsPerSheet: 20,
          sheetIndex: 1,
          usedQuestionIds: const {},
        ),
        isNull,
      );
    });

    test('21b. sumSelectedLessonSheetCounts 6+7=13', () {
      expect(
        sumSelectedLessonSheetCounts(
          sheetCountByLesson: const {2: 6, 4: 7, 9: 3},
          selectedLessonNumbers: const [2, 4],
        ),
        13,
      );
      expect(
        sumSelectedLessonSheetCounts(
          sheetCountByLesson: const {2: 6, 4: 7, 9: 3},
          selectedLessonNumbers: const [2, 4, 9],
        ),
        16,
      );
      expect(
        sumSelectedLessonSheetCounts(
          sheetCountByLesson: const {2: 6},
          selectedLessonNumbers: const [2, 99],
        ),
        6,
      );
      expect(
        sumSelectedLessonSheetCounts(
          sheetCountByLesson: const {},
          selectedLessonNumbers: const [1, 2],
        ),
        0,
      );
      // No double-count of duplicate lesson ids in selection.
      expect(
        sumSelectedLessonSheetCounts(
          sheetCountByLesson: const {2: 6, 4: 7},
          selectedLessonNumbers: const [2, 2, 4],
        ),
        13,
      );
    });

    test('21b2. distinct sheet_number + locked sheets reduce actionable', () {
      final catalog = [
        _catalogRow(
          id: 'a',
          licenseCategory: 'A12',
          lessonNumber: 2,
          sheetNumber: 1,
        ),
        _catalogRow(
          id: 'b',
          licenseCategory: 'A12',
          lessonNumber: 2,
          sheetNumber: 2,
        ),
        _catalogRow(
          id: 'dup',
          licenseCategory: 'A12',
          lessonNumber: 2,
          sheetNumber: 2,
        ),
        _catalogRow(
          id: 'c',
          licenseCategory: 'A12',
          lessonNumber: 2,
          sheetNumber: 3,
        ),
        _catalogRow(
          id: 'd',
          licenseCategory: 'A12',
          lessonNumber: 2,
          sheetNumber: 4,
        ),
        _catalogRow(
          id: 'e',
          licenseCategory: 'A12',
          lessonNumber: 2,
          sheetNumber: 5,
        ),
        _catalogRow(
          id: 'f',
          licenseCategory: 'A12',
          lessonNumber: 2,
          sheetNumber: 6,
        ),
      ];
      final numbers = distinctLessonSheetNumbersByLesson(catalog);
      expect(numbers[2], [1, 2, 3, 4, 5, 6]);
      expect(numbers[2]!.length, 6); // duplicate sheet 2 counted once

      final actionable = actionableLessonSheetNumbers(
        catalogSheetNumbers: numbers[2]!,
        isSheetUnlocked: (sheet) => sheet <= 4,
      );
      expect(actionable, [1, 2, 3, 4]);
      expect(actionable.length, 4);
    });

    test('21c. catalog total may exceed distinctMax when reuse allowed', () {
      final pools = {
        1: List.generate(12, (i) => _q('l1-$i', lesson: 1)),
        2: List.generate(12, (i) => _q('l2-$i', lesson: 2)),
      };
      final distinctMax = maxDistinctMultiTopicSheets(
        poolByLesson: pools,
        selectedLessonNumbers: const [1, 2],
        questionsPerSheet: 20,
      );
      expect(distinctMax, greaterThanOrEqualTo(1));
      expect(distinctMax, lessThan(13));
      expect(
        findMultiTopicPoolShortfall(
          poolByLesson: pools,
          selectedLessonNumbers: const [1, 2],
          questionsPerSheet: 20,
          sheetCount: 13,
        ),
        isNull,
      );
      expect(
        sumSelectedLessonSheetCounts(
          sheetCountByLesson: const {1: 6, 2: 7},
          selectedLessonNumbers: const [1, 2],
        ),
        13,
      );
    });
  });

  group('Lifecycle / persistence', () {
    test('22. Scheda X di Y labels from session indexes', () {
      final session = MultiTopicQuizSession(
        sessionId: 's',
        licenseCategory: LicenseCategoryId.motore,
        selectedLessonNumbers: const [1, 2],
        totalSheets: 3,
        poolByLesson: const {},
      );
      expect(session.nextSheetIndex, 1);
      session.markSheetConsumed(sheetIndex: 1, questionIds: const ['a']);
      expect(session.nextSheetIndex, 2);
      expect(session.hasMoreSheets, isTrue);
      session.markSheetConsumed(sheetIndex: 3, questionIds: const ['b']);
      expect(session.hasMoreSheets, isFalse);
    });

    test('23. next sheet generated lazy (session starts at 0)', () {
      final session = MultiTopicQuizSession(
        sessionId: 's',
        licenseCategory: LicenseCategoryId.motore,
        selectedLessonNumbers: const [1, 2],
        totalSheets: 2,
        poolByLesson: const {},
      );
      expect(session.currentSheetIndex, 0);
    });

    test('24-28. immutable submission + single RPC retry reuse', () async {
      final questions = List.generate(
        20,
        (i) => _q('q$i', lesson: i.isEven ? 1 : 2),
      );
      final answers = List<QuizAnswerOption?>.filled(20, QuizAnswerOption.a);
      final started = DateTime.utc(2026, 9, 26, 10);
      final completed = started.add(const Duration(seconds: 40));
      final submission = buildMultiTopicQuizAttemptSubmission(
        clientSubmissionId: 'client-1',
        sessionId: 'session-1',
        licenseCategory: LicenseCategoryId.motore,
        lessonNumbers: const [2, 1],
        sheetIndex: 1,
        totalSheets: 3,
        startedAt: started,
        completedAt: completed,
        questions: questions,
        userAnswers: answers,
      );

      expect(submission.lessonNumbers, [1, 2]);
      expect(submission.durationSeconds, 40);
      final params = submission.toRpcParams();
      expect(params.keys.toSet(), multiTopicQuizAttemptSubmitRpcParamKeys);
      expect(params['p_license_category'], 'A12');
      expect(params['p_answers'], hasLength(20));
      for (final answer in params['p_answers'] as List) {
        expect((answer as Map).containsKey('correct_option'), isFalse);
      }

      final fake = MultiTopicQuizAttemptRepositoryFake(
        submitResult: MultiTopicQuizAttemptResult(
          attemptId: 'att-1',
          sessionId: 'session-1',
          sheetIndex: 1,
          totalSheets: 3,
          licenseCategory: LicenseCategoryId.motore,
          lessonNumbers: const [1, 2],
          completedAt: completed,
          durationSeconds: 40,
          totalQuestions: 20,
          correctCount: 20,
          wrongCount: 0,
          unansweredCount: 0,
          idempotent: false,
        ),
      );

      await fake.submitAttempt(submission);
      await fake.submitAttempt(submission);
      expect(fake.submitCalls, hasLength(2));
      // Retry riusa lo stesso oggetto immutabile.
      expect(identical(fake.submitCalls[0], fake.submitCalls[1]), isTrue);
      expect(fake.submitCalls[0], equals(fake.submitCalls[1]));
      expect(fake.submitCalls[0].clientSubmissionId, 'client-1');
      expect(fake.submitCalls[0].durationSeconds, 40);
    });

    test('29. interrupted session leaves future sheets uncreated', () {
      final session = MultiTopicQuizSession(
        sessionId: 's',
        licenseCategory: LicenseCategoryId.motore,
        selectedLessonNumbers: const [1, 2],
        totalSheets: 3,
        poolByLesson: const {},
      );
      session.markSheetConsumed(sheetIndex: 2, questionIds: const ['a', 'b']);
      expect(session.currentSheetIndex, 2);
      expect(session.hasMoreSheets, isTrue);
      // No automatic advance to sheet 3 without user action.
      expect(session.nextSheetIndex, 3);
    });

    test('32. idempotent result flag', () {
      final result = MultiTopicQuizAttemptResult(
        attemptId: 'a',
        sessionId: 's',
        sheetIndex: 1,
        totalSheets: 1,
        licenseCategory: LicenseCategoryId.d1,
        lessonNumbers: const [1, 2],
        completedAt: DateTime.utc(2026, 1, 1),
        durationSeconds: 10,
        totalQuestions: 15,
        correctCount: 10,
        wrongCount: 3,
        unansweredCount: 2,
        idempotent: true,
      );
      expect(result.idempotent, isTrue);
    });

    test('33-35. typed error codes', () {
      expect(
        extractMultiTopicQuizAttemptErrorCode(
          Exception('multi_topic_access_denied'),
        ),
        MultiTopicQuizAttemptErrorCode.multiTopicAccessDenied,
      );
      expect(
        extractMultiTopicQuizAttemptErrorCode(
          Exception('idempotency_conflict'),
        ),
        MultiTopicQuizAttemptErrorCode.idempotencyConflict,
      );
      expect(
        extractMultiTopicQuizAttemptErrorCode(
          Exception('session_sheet_conflict'),
        ),
        MultiTopicQuizAttemptErrorCode.sessionSheetConflict,
      );
    });

    test('UUID generator produces distinct values', () {
      final a = generateMultiTopicUuid();
      final b = generateMultiTopicUuid();
      expect(a, isNot(equals(b)));
      expect(a, contains('-'));
    });
  });

  group('Flutter Safe fixes — guards', () {
    test('double close blocked when pending/summary/in-flight', () {
      expect(
        multiTopicCloseSheetMayProceed(
          showSummary: false,
          submitInFlight: false,
          hasPendingSubmission: false,
        ),
        isTrue,
      );
      expect(
        multiTopicCloseSheetMayProceed(
          showSummary: true,
          submitInFlight: false,
          hasPendingSubmission: false,
        ),
        isFalse,
      );
      expect(
        multiTopicCloseSheetMayProceed(
          showSummary: false,
          submitInFlight: true,
          hasPendingSubmission: false,
        ),
        isFalse,
      );
      expect(
        multiTopicCloseSheetMayProceed(
          showSummary: false,
          submitInFlight: false,
          hasPendingSubmission: true,
        ),
        isFalse,
      );
      expect(
        multiTopicCloseSheetMayProceed(
          showSummary: false,
          submitInFlight: false,
          hasPendingSubmission: false,
          closeInProgress: true,
        ),
        isFalse,
      );
    });

    test('freezeOrReuse keeps the same immutable object', () {
      final first = buildMultiTopicQuizAttemptSubmission(
        clientSubmissionId: 'c1',
        sessionId: 's1',
        licenseCategory: LicenseCategoryId.motore,
        lessonNumbers: const [1, 2],
        sheetIndex: 1,
        totalSheets: 1,
        startedAt: DateTime.utc(2026, 9, 26, 10),
        completedAt: DateTime.utc(2026, 9, 26, 10, 0, 30),
        questions: List.generate(
          20,
          (i) => _q('q$i', lesson: i.isEven ? 1 : 2),
        ),
        userAnswers: List<QuizAnswerOption?>.filled(20, QuizAnswerOption.a),
      );
      var builds = 0;
      final reused = freezeOrReusePendingSubmission(
        pending: first,
        build: () {
          builds++;
          return buildMultiTopicQuizAttemptSubmission(
            clientSubmissionId: 'c2',
            sessionId: 's1',
            licenseCategory: LicenseCategoryId.motore,
            lessonNumbers: const [1, 2],
            sheetIndex: 1,
            totalSheets: 1,
            startedAt: DateTime.utc(2026, 9, 26, 10),
            completedAt: DateTime.utc(2026, 9, 26, 10, 1, 0),
            questions: List.generate(
              20,
              (i) => _q('q$i', lesson: i.isEven ? 1 : 2),
            ),
            userAnswers: List<QuizAnswerOption?>.filled(20, QuizAnswerOption.a),
          );
        },
      );
      expect(identical(reused, first), isTrue);
      expect(builds, 0);
      expect(reused.durationSeconds, 30);
      expect(reused.clientSubmissionId, 'c1');
    });

    test('start session double tap protected', () {
      expect(
        multiTopicStartSessionMayProceed(starting: false, startEnabled: true),
        isTrue,
      );
      expect(
        multiTopicStartSessionMayProceed(starting: true, startEnabled: true),
        isFalse,
      );
      expect(
        multiTopicStartSessionMayProceed(starting: false, startEnabled: false),
        isFalse,
      );
    });

    test('back/esci blocked while saving', () {
      expect(multiTopicBlocksExitWhileSaving(isSaving: true), isTrue);
      expect(multiTopicBlocksExitWhileSaving(isSaving: false), isFalse);
    });
  });

  group('Multischeda eligibility requires actionable sheets', () {
    test('pool + unlocked + sheets → selectable', () {
      expect(
        isLessonEligibleForMultiTopic(
          categoryId: LicenseCategoryId.d1,
          hasQuestionPool: true,
          isUnlocked: true,
          availableSheetCount: 3,
        ),
        isTrue,
      );
    });

    test('pool + unlocked + 0 actionable sheets → not selectable', () {
      expect(
        isLessonEligibleForMultiTopic(
          categoryId: LicenseCategoryId.d1,
          hasQuestionPool: true,
          isUnlocked: true,
          availableSheetCount: 0,
        ),
        isFalse,
      );
    });

    test(
      'Schede filter uses quiz_sets; Multischeda also needs sheet count',
      () {
        final schedeFiltered = filterLessonsWithRealSheets(
          catalogLessons: LicenseCatalog.patenteD1.lessons,
          lessonNumbersWithSheets: {1, 2},
        );
        expect(schedeFiltered.map((l) => l.number).toSet(), {1, 2});
        expect(
          isLessonEligibleForMultiTopic(
            categoryId: LicenseCategoryId.d1,
            hasQuestionPool: true,
            isUnlocked: true,
            availableSheetCount: 2,
          ),
          isTrue,
        );
      },
    );
  });

  group('Multischeda history', () {
    test('history load + metadata', () async {
      final summary = MultiTopicQuizAttemptSummary(
        id: 'att-h1',
        sessionId: 'sess-1',
        licenseCategory: LicenseCategoryId.motore,
        lessonNumbers: const [1, 3, 5],
        sheetIndex: 2,
        totalSheets: 3,
        completedAt: DateTime.utc(2026, 9, 26, 12),
        durationSeconds: 95,
        totalQuestions: 20,
        correctCount: 16,
        wrongCount: 3,
        unansweredCount: 1,
      );
      final fake = MultiTopicQuizAttemptRepositoryFake(history: [summary]);
      final list = await fake.fetchCurrentUserAttempts(
        category: LicenseCategoryId.motore,
      );
      expect(list, hasLength(1));
      expect(list.single.progressLabel, 'Scheda 2 di 3');
      expect(list.single.lessonNumbers, [1, 3, 5]);
      expect(list.single.correctCount, 16);
      expect(dbLicenseCategoryFor(list.single.licenseCategory), 'A12');
    });

    test('history empty', () async {
      final fake = MultiTopicQuizAttemptRepositoryFake();
      final list = await fake.fetchCurrentUserAttempts(
        category: LicenseCategoryId.d1,
      );
      expect(list, isEmpty);
    });

    test('history load error', () async {
      final fake = MultiTopicQuizAttemptRepositoryFake(
        throwOnHistoryFetch: const MultiTopicQuizAttemptException(
          code: MultiTopicQuizAttemptErrorCode.notAuthenticated,
          message: 'Sessione non disponibile. Accedi nuovamente.',
        ),
      );
      expect(
        () => fake.fetchCurrentUserAttempts(category: LicenseCategoryId.motore),
        throwsA(isA<MultiTopicQuizAttemptException>()),
      );
    });

    test('history mapping from snapshot rows', () {
      final detail = parseMultiTopicQuizAttemptDetail(
        attemptRow: {
          'id': 'att-1',
          'session_id': 'sess-1',
          'license_category': 'D1',
          'lesson_numbers': [2, 4],
          'sheet_index': 1,
          'total_sheets': 2,
          'completed_at': '2026-09-26T10:00:00Z',
          'duration_seconds': 40,
          'total_questions': 15,
          'correct_count': 12,
          'wrong_count': 2,
          'unanswered_count': 1,
        },
        answerRows: [
          {
            'position': 1,
            'question_id': 'q1',
            'prompt_snapshot': 'P?',
            'option_a_snapshot': 'A',
            'option_b_snapshot': 'B',
            'option_c_snapshot': 'C',
            'image_path_snapshot': null,
            'explanation_snapshot': 'perché',
            'lesson_number_snapshot': 2,
            'selected_option': 'A',
            'correct_option': 'A',
            'is_correct': true,
          },
        ],
      );
      expect(detail.summary.licenseCategory, LicenseCategoryId.d1);
      expect(detail.summary.progressLabel, 'Scheda 1 di 2');
      expect(detail.answers.single.explanation, 'perché');
      expect(detail.answers.single.isCorrect, isTrue);
      expect(detail.answers.single.imagePath, isNull);
    });

    test('selected_option null → unanswered review status (not wrong)', () {
      final detail = parseMultiTopicQuizAttemptDetail(
        attemptRow: {
          'id': 'att-u',
          'session_id': 'sess-u',
          'license_category': 'A12',
          'lesson_numbers': [1, 2],
          'sheet_index': 1,
          'total_sheets': 1,
          'completed_at': '2026-09-26T11:00:00Z',
          'duration_seconds': 20,
          'total_questions': 20,
          'correct_count': 18,
          'wrong_count': 1,
          'unanswered_count': 1,
        },
        answerRows: [
          {
            'position': 1,
            'question_id': 'q-unanswered',
            'prompt_snapshot': 'Domanda senza risposta?',
            'option_a_snapshot': 'A',
            'option_b_snapshot': 'B',
            'option_c_snapshot': 'C',
            'image_path_snapshot': null,
            'explanation_snapshot': null,
            'lesson_number_snapshot': 1,
            'selected_option': null,
            'correct_option': 'B',
            'is_correct': false,
          },
        ],
      );
      final answer = detail.answers.single;
      expect(answer.selectedOption, isNull);
      expect(answer.explanation, isNull);
      expect(answer.imagePath, isNull);
      expect(answer.correctOption, QuizAnswerOption.b);

      final status = multiTopicHistoryAnswerReviewStatus(
        selectedOption: answer.selectedOption,
        isCorrect: answer.isCorrect,
      );
      expect(status, MultiTopicHistoryAnswerReviewStatus.unanswered);
      expect(multiTopicHistoryAnswerReviewLabel(status), 'Non risposta');
      expect(
        multiTopicHistoryAnswerReviewLabel(status),
        isNot(equals('Risposta errata')),
      );
    });

    test('history review statuses: correct / wrong / unanswered', () {
      expect(
        multiTopicHistoryAnswerReviewStatus(
          selectedOption: QuizAnswerOption.a,
          isCorrect: true,
        ),
        MultiTopicHistoryAnswerReviewStatus.correct,
      );
      expect(
        multiTopicHistoryAnswerReviewStatus(
          selectedOption: QuizAnswerOption.b,
          isCorrect: false,
        ),
        MultiTopicHistoryAnswerReviewStatus.wrong,
      );
      expect(
        multiTopicHistoryAnswerReviewStatus(
          selectedOption: null,
          isCorrect: false,
        ),
        MultiTopicHistoryAnswerReviewStatus.unanswered,
      );
    });

    test(
      'history isolation: dedicated tables + Multischeda metadata only',
      () async {
        final summary = MultiTopicQuizAttemptSummary(
          id: 'att-iso',
          sessionId: 'sess-iso',
          licenseCategory: LicenseCategoryId.motore,
          lessonNumbers: const [1, 7, 9],
          sheetIndex: 2,
          totalSheets: 4,
          completedAt: DateTime.utc(2026, 9, 26, 15),
          durationSeconds: 70,
          totalQuestions: 20,
          correctCount: 14,
          wrongCount: 4,
          unansweredCount: 2,
        );
        final detail = MultiTopicQuizAttemptDetail(
          summary: summary,
          answers: [
            MultiTopicQuizAttemptAnswerSnapshot(
              position: 1,
              questionId: 'q1',
              prompt: 'P',
              optionA: 'A',
              optionB: 'B',
              optionC: 'C',
              selectedOption: null,
              correctOption: QuizAnswerOption.a,
              isCorrect: false,
              lessonNumber: 1,
            ),
          ],
        );
        final fake = MultiTopicQuizAttemptRepositoryFake(
          history: [summary],
          detailById: {'att-iso': detail},
        );

        final list = await fake.fetchCurrentUserAttempts(
          category: LicenseCategoryId.motore,
        );
        final loaded = await fake.fetchAttemptDetail('att-iso');

        // Storage contract: only Multischeda tables.
        expect(
          fake.historyStorageTouches,
          containsAll([
            multiTopicQuizAttemptsTable,
            multiTopicQuizAttemptAnswersTable,
          ]),
        );
        expect(multiTopicQuizAttemptsTable, 'multi_topic_quiz_attempts');
        expect(
          multiTopicQuizAttemptAnswersTable,
          'multi_topic_quiz_attempt_answers',
        );
        for (final forbidden in multiTopicForbiddenLessonHistoryTables) {
          expect(fake.historyStorageTouches, isNot(contains(forbidden)));
        }
        expect(fake.historyStorageTouches, isNot(contains('quiz_results')));
        expect(fake.historyStorageTouches, isNot(contains('quiz_sets')));

        // Metadata Multischeda preserved (not lesson Scheda X / Svolta).
        expect(list.single.sessionId, 'sess-iso');
        expect(list.single.sheetIndex, 2);
        expect(list.single.totalSheets, 4);
        expect(list.single.lessonNumbers, [1, 7, 9]);
        expect(list.single.correctCount, 14);
        expect(list.single.wrongCount, 4);
        expect(list.single.unansweredCount, 2);
        expect(loaded.summary.progressLabel, 'Scheda 2 di 4');
        expect(loaded.summary.sessionId, summary.sessionId);

        // Submit path (write) unused by history read — no ghost lesson completion.
        expect(fake.submitCalls, isEmpty);
      },
    );
  });

  group('STUDIO.QUIZ.UNANSWERED.1 — empty / partial Multischeda', () {
    List<QuizQuestion> a12Questions() =>
        List.generate(20, (i) => _q('q$i', lesson: i.isEven ? 1 : 2));

    List<QuizQuestion> d1Questions() => List.generate(
      15,
      (i) => _q('d1-q$i', lesson: i.isEven ? 1 : 2, licenseCategory: 'D1'),
    );

    test('A. 0/20 A12 → cannot build submission (no persist)', () {
      expect(
        quizSheetMayPersistAttempt(List<Object?>.filled(20, null)),
        isFalse,
      );
      expect(
        () => buildMultiTopicQuizAttemptSubmission(
          clientSubmissionId: 'c-empty',
          sessionId: 's-empty',
          licenseCategory: LicenseCategoryId.motore,
          lessonNumbers: const [1, 2],
          sheetIndex: 1,
          totalSheets: 1,
          startedAt: DateTime.utc(2026, 10, 1),
          completedAt: DateTime.utc(2026, 10, 1, 0, 1),
          questions: a12Questions(),
          userAnswers: List<QuizAnswerOption?>.filled(20, null),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        lessonQuizOutcomeLabel(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 0,
          unansweredCount: 20,
        ),
        isNot('PROMOSSO'),
      );
    });

    test('B. 0/15 D1 → cannot build submission', () {
      expect(
        () => buildMultiTopicQuizAttemptSubmission(
          clientSubmissionId: 'c-empty-d1',
          sessionId: 's-empty-d1',
          licenseCategory: LicenseCategoryId.d1,
          lessonNumbers: const [1, 2],
          sheetIndex: 1,
          totalSheets: 1,
          startedAt: DateTime.utc(2026, 10, 1),
          completedAt: DateTime.utc(2026, 10, 1, 0, 1),
          questions: d1Questions(),
          userAnswers: List<QuizAnswerOption?>.filled(15, null),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('C. 1 correct + 19 unanswered A12 → effectiveErrors = 19', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 0,
          unansweredCount: 19,
        ),
        19,
      );
      expect(
        lessonQuizOutcomeLabel(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 0,
          unansweredCount: 19,
        ),
        'BOCCIATO',
      );
    });

    test('D. 1 wrong + 19 unanswered A12 → effectiveErrors = 20', () {
      expect(
        lessonQuizErrorCountForResult(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 1,
          unansweredCount: 19,
        ),
        20,
      );
    });

    test(
      'E. partial exit policy: empty immediate; ≥1 requires confirm path',
      () {
        final empty = List<Object?>.filled(20, null);
        final partial = <Object?>[QuizAnswerOption.a, ...List.filled(19, null)];
        expect(allowsImmediateQuizSheetExit(empty), isTrue);
        expect(quizSheetMayPersistAttempt(empty), isFalse);
        expect(allowsImmediateQuizSheetExit(partial), isFalse);
        expect(quizSheetMayPersistAttempt(partial), isTrue);
        expect(shouldConfirmExitBeforeSummary(partial), isTrue);
      },
    );

    test(
      'F. partial submit keeps wrong/unanswered separate; pass/fail uses sum',
      () {
        final answers = <QuizAnswerOption?>[
          QuizAnswerOption.a, // correct
          QuizAnswerOption.b, // wrong (correct is a)
          ...List<QuizAnswerOption?>.filled(18, null),
        ];
        final submission = buildMultiTopicQuizAttemptSubmission(
          clientSubmissionId: 'c-partial',
          sessionId: 's-partial',
          licenseCategory: LicenseCategoryId.motore,
          lessonNumbers: const [1, 2],
          sheetIndex: 1,
          totalSheets: 1,
          startedAt: DateTime.utc(2026, 10, 1),
          completedAt: DateTime.utc(2026, 10, 1, 0, 2),
          questions: a12Questions(),
          userAnswers: answers,
        );
        final rpcAnswers = submission.toRpcParams()['p_answers'] as List;
        expect(rpcAnswers, hasLength(20));
        expect((rpcAnswers[0] as Map)['selected_option'], 'A');
        expect((rpcAnswers[1] as Map)['selected_option'], 'B');
        expect((rpcAnswers[2] as Map)['selected_option'], isNull);
        // Counts stay separate for history; outcome uses sum.
        expect(
          lessonQuizErrorCountForResult(
            categoryId: LicenseCategoryId.motore,
            wrongCount: 1,
            unansweredCount: 18,
          ),
          19,
        );
        expect(
          lessonQuizWithinErrorThreshold(
            categoryId: LicenseCategoryId.motore,
            wrongCount: 1,
            unansweredCount: 18,
          ),
          isFalse,
        );
      },
    );

    test('G. fully answered sheet unchanged (4 wrong → PROMOSSO)', () {
      expect(
        lessonQuizOutcomeLabel(
          categoryId: LicenseCategoryId.motore,
          wrongCount: 4,
          unansweredCount: 0,
        ),
        'PROMOSSO',
      );
      final answers = List<QuizAnswerOption?>.filled(20, QuizAnswerOption.a);
      final submission = buildMultiTopicQuizAttemptSubmission(
        clientSubmissionId: 'c-full',
        sessionId: 's-full',
        licenseCategory: LicenseCategoryId.motore,
        lessonNumbers: const [1, 2],
        sheetIndex: 1,
        totalSheets: 1,
        startedAt: DateTime.utc(2026, 10, 1),
        completedAt: DateTime.utc(2026, 10, 1, 0, 3),
        questions: a12Questions(),
        userAnswers: answers,
      );
      expect(submission.answers, hasLength(20));
      expect(submission.answers.every((a) => a.selectedOption != null), isTrue);
    });

    test('H. double close guard still blocks second conclude', () {
      expect(
        multiTopicCloseSheetMayProceed(
          showSummary: false,
          submitInFlight: false,
          hasPendingSubmission: false,
          closeInProgress: false,
        ),
        isTrue,
      );
      expect(
        multiTopicCloseSheetMayProceed(
          showSummary: false,
          submitInFlight: false,
          hasPendingSubmission: true,
          closeInProgress: false,
        ),
        isFalse,
      );
      expect(
        multiTopicCloseSheetMayProceed(
          showSummary: false,
          submitInFlight: false,
          hasPendingSubmission: false,
          closeInProgress: true,
        ),
        isFalse,
      );
    });

    test('I. empty attempt not representable as valid submission', () {
      // History must never receive empty builds from client domain.
      expect(quizSheetMayPersistAttempt(List.filled(20, null)), isFalse);
    });
  });
}
