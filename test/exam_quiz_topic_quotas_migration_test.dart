import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';

void main() {
  test('migration enforce A12 topic quotas allineate a ExamQuizRules', () {
    final migration = File(
      'supabase/migrations/20260725120000_exam_quiz_attempt_topic_quotas.sql',
    ).readAsStringSync();

    expect(migration, contains('invalid_exam_topic_quotas'));
    expect(migration, contains("v_category = 'A12'"));
    expect(migration, contains('CREATE OR REPLACE FUNCTION public.submit_exam_quiz_attempt'));

    for (final entry in ExamQuizRules.a12TopicQuotas.entries) {
      expect(
        migration,
        contains("= '${entry.key}'"),
        reason: 'topic ${entry.key} must be checked',
      );
      expect(
        migration,
        contains(') <> ${entry.value}'),
        reason: 'quota ${entry.key}=${entry.value} must be enforced',
      );
    }
  });
}
