import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  });
}
