import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/models/assigned_quiz_models.dart';
import 'package:scuola_nautica_liana/repositories/assigned_quiz_repository.dart';

void main() {
  group('AssignedQuizRepositorySupabase source contracts', () {
    late String repoSource;
    late String mapperSource;

    setUpAll(() {
      repoSource = File(
        'lib/repositories/assigned_quiz_repository.dart',
      ).readAsStringSync();
      mapperSource = File(
        'lib/data/supabase/mappers/assigned_quiz_mapper.dart',
      ).readAsStringSync();
    });

    test('RPC generate/start/player/save/submit/abandon/review collegate', () {
      expect(repoSource, contains("'generate_assigned_quiz_from_errors'"));
      expect(repoSource, contains("'start_assigned_quiz_attempt'"));
      expect(repoSource, contains("'get_assigned_quiz_attempt_questions'"));
      expect(repoSource, contains("'save_assigned_quiz_attempt_answer'"));
      expect(repoSource, contains("'submit_assigned_quiz_attempt'"));
      expect(repoSource, contains("'abandon_assigned_quiz_attempt'"));
      expect(repoSource, contains("'get_assigned_quiz_attempt_review'"));
    });

    test('parametri RPC generate senza license_category', () {
      expect(mapperSource, contains("'p_student_id'"));
      expect(mapperSource, contains("'p_title'"));
      expect(mapperSource, contains("'p_staff_note'"));
      expect(mapperSource, contains("'p_question_count'"));
      expect(mapperSource, contains("'p_lesson_filter_mode'"));
      expect(mapperSource, contains("'p_lesson_numbers'"));
      expect(mapperSource, contains("'p_sort_mode'"));
      expect(mapperSource, contains("'p_repeat_policy'"));
      expect(mapperSource, contains("'p_max_attempts'"));
      expect(mapperSource, contains("'p_expires_at'"));
      expect(mapperSource, contains("'p_allow_partial'"));
      expect(mapperSource, contains("'p_assign_immediately'"));
      expect(mapperSource, contains("'p_idempotency_key'"));
      expect(mapperSource, isNot(contains("'p_license_category'")));
    });

    test('query solo assigned_quizzes e assigned_quiz_attempts', () {
      expect(repoSource, contains(".from('assigned_quizzes')"));
      expect(repoSource, contains(".from('assigned_quiz_attempts')"));
      expect(repoSource, isNot(contains(".from('assigned_quiz_items')")));
      expect(
        repoSource,
        isNot(contains(".from('assigned_quiz_attempt_answers')")),
      );
      expect(repoSource, isNot(contains(".from('quiz_results')")));
      expect(repoSource, isNot(contains(".from('quiz_attempt_answers')")));
    });

    test('loadMine arricchisce con query batch tentativi (no N+1)', () {
      expect(
        repoSource,
        contains("select('assignment_id, status, attempt_number')"),
      );
      expect(repoSource, contains(".inFilter('assignment_id', assignmentIds)"));
      expect(
        repoSource,
        contains('enrichAssignedQuizSummariesWithAttemptRows'),
      );
      final supabaseImpl = repoSource
          .split('class AssignedQuizRepositorySupabase')
          .last
          .split('class AssignedQuizRepositoryFake')
          .first;
      expect(supabaseImpl, contains(".from('assigned_quizzes')"));
      expect(supabaseImpl, contains(".from('assigned_quiz_attempts')"));
      // Nessun loop per-assignment nella select tentativi di loadMine.
      expect(supabaseImpl, isNot(contains('for (final assignmentId')));
      final attemptsSelectCount = 'assignment_id, status, attempt_number'
          .allMatches(supabaseImpl)
          .length;
      expect(attemptsSelectCount, 1);
    });

    test('submit non invia risposte o punteggi', () {
      expect(repoSource, contains("'submit_assigned_quiz_attempt'"));
      expect(repoSource, contains("'p_attempt_id': attemptId"));
      expect(repoSource, isNot(contains("'p_correct_count'")));
      expect(repoSource, isNot(contains("'p_score_percentage'")));
      expect(repoSource, isNot(contains("'p_answers'")));
    });
  });

  group('AssignedQuizRepositoryEmpty', () {
    test('liste vuote senza rete', () async {
      const repo = AssignedQuizRepositoryEmpty();
      expect(await repo.loadMine(), isEmpty);
      expect(await repo.loadForStudent('st-1'), isEmpty);
    });

    test('scritture falliscono con AssignedQuizException', () async {
      const repo = AssignedQuizRepositoryEmpty();
      await expectLater(
        repo.archiveAssignment('a1'),
        throwsA(isA<AssignedQuizException>()),
      );
      await expectLater(
        repo.deleteDraft('a1'),
        throwsA(isA<AssignedQuizException>()),
      );
      await expectLater(
        repo.updateAssignmentMetadata(
          'a1',
          const AssignedQuizMetadataPatch(
            title: AssignedQuizFieldPatch.set('X'),
          ),
        ),
        throwsA(isA<AssignedQuizException>()),
      );
      await expectLater(
        repo.saveAnswer(
          attemptId: 'att',
          assignmentItemId: 'item',
          selectedOption: 'A',
        ),
        throwsA(isA<AssignedQuizException>()),
      );
      await expectLater(
        repo.abandonAttempt('att'),
        throwsA(isA<AssignedQuizException>()),
      );
    });
  });

  group('AssignedQuizRepositoryFake metadata patch', () {
    test('applica set e clear', () async {
      final created = DateTime.utc(2026, 7, 1);
      final repo = AssignedQuizRepositoryFake(
        summaries: [
          AssignedQuizSummary(
            id: 'aq-1',
            publicCode: 'AQZ-1',
            studentId: 'st-1',
            studentUserId: 'u-1',
            licenseCategory: 'A12',
            title: 'Vecchio',
            staffNote: 'Nota',
            status: AssignedQuizStatus.draft,
            questionCount: 10,
            repeatPolicy: AssignedQuizRepeatPolicy.unlimited,
            createdAt: created,
            expiresAt: DateTime.utc(2026, 8, 1),
          ),
        ],
      );

      await repo.updateAssignmentMetadata(
        'aq-1',
        const AssignedQuizMetadataPatch(
          title: AssignedQuizFieldPatch.set('Nuovo'),
          staffNote: AssignedQuizFieldPatch.clear(),
          expiresAt: AssignedQuizFieldPatch.clear(),
        ),
      );

      final updated = repo.summaries.single;
      expect(updated.title, 'Nuovo');
      expect(updated.staffNote, isNull);
      expect(updated.expiresAt, isNull);
      expect(repo.lastMetadataPatch, isNotNull);
    });
  });

  group('AssignedQuizRepositoryFake loadMine enrichment', () {
    AssignedQuizSummary base({
      required String id,
      AssignedQuizStatus status = AssignedQuizStatus.assigned,
    }) {
      return AssignedQuizSummary(
        id: id,
        publicCode: 'AQZ-$id',
        studentId: 'st-1',
        studentUserId: 'u-1',
        licenseCategory: 'A12',
        title: 'T$id',
        status: status,
        questionCount: 5,
        repeatPolicy: AssignedQuizRepeatPolicy.limited,
        maxAttempts: 2,
        createdAt: DateTime.utc(2026, 7, 1),
        assignedAt: DateTime.utc(2026, 7, 2),
      );
    }

    AssignedQuizAttemptSummary attempt({
      required String id,
      required String assignmentId,
      required int number,
      required AssignedQuizAttemptStatus status,
    }) {
      return AssignedQuizAttemptSummary(
        id: id,
        assignmentId: assignmentId,
        attemptNumber: number,
        status: status,
        startedAt: DateTime.utc(2026, 7, 3),
        correctCount: 0,
        wrongCount: 0,
        unansweredCount: 0,
      );
    }

    test('senza tentativi lascia summary invariati', () async {
      final repo = AssignedQuizRepositoryFake(summaries: [base(id: 'a1')]);
      final mine = await repo.loadMine();
      expect(mine.single.hasInProgressAttempt, isNull);
      expect(mine.single.submittedAttemptsCount, isNull);
      expect(mine.single.attemptsUsedCount, isNull);
    });

    test('lista vuota', () async {
      final repo = AssignedQuizRepositoryFake();
      expect(await repo.loadMine(), isEmpty);
    });

    test('mappa in_progress, submitted e slot usati per assignment', () async {
      final repo = AssignedQuizRepositoryFake(
        summaries: [
          base(id: 'a1'),
          base(id: 'a2'),
        ],
        attempts: [
          attempt(
            id: 't1',
            assignmentId: 'a1',
            number: 1,
            status: AssignedQuizAttemptStatus.submitted,
          ),
          attempt(
            id: 't2',
            assignmentId: 'a1',
            number: 2,
            status: AssignedQuizAttemptStatus.inProgress,
          ),
          attempt(
            id: 't3',
            assignmentId: 'a2',
            number: 1,
            status: AssignedQuizAttemptStatus.abandoned,
          ),
        ],
      );
      final mine = await repo.loadMine();
      final a1 = mine.firstWhere((s) => s.id == 'a1');
      final a2 = mine.firstWhere((s) => s.id == 'a2');
      expect(a1.hasInProgressAttempt, isTrue);
      expect(a1.submittedAttemptsCount, 1);
      expect(a1.attemptsUsedCount, 2);
      expect(a2.hasInProgressAttempt, isFalse);
      expect(a2.submittedAttemptsCount, 0);
      expect(a2.attemptsUsedCount, 1);
    });

    test('tentativi di altre assegnazioni non contaminano', () async {
      final repo = AssignedQuizRepositoryFake(
        summaries: [base(id: 'a1')],
        attempts: [
          attempt(
            id: 'other',
            assignmentId: 'other-id',
            number: 1,
            status: AssignedQuizAttemptStatus.inProgress,
          ),
        ],
      );
      final mine = await repo.loadMine();
      expect(mine.single.hasInProgressAttempt, isNull);
      expect(mine.single.attemptsUsedCount, isNull);
    });

    test('assegnazione senza tentativi tra altre con tentativi', () async {
      final repo = AssignedQuizRepositoryFake(
        summaries: [
          base(id: 'a1'),
          base(id: 'a2'),
        ],
        attempts: [
          attempt(
            id: 't1',
            assignmentId: 'a1',
            number: 1,
            status: AssignedQuizAttemptStatus.submitted,
          ),
        ],
      );
      final mine = await repo.loadMine();
      expect(mine.firstWhere((s) => s.id == 'a1').submittedAttemptsCount, 1);
      expect(
        mine.firstWhere((s) => s.id == 'a2').submittedAttemptsCount,
        isNull,
      );
    });
  });
}
