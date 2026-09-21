import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/exam_quiz_rules.dart';

void main() {
  test('migration enforce A12+D1 topic quotas allineate a ExamQuizRules', () {
    final migration = File(
      'supabase/migrations/20260727130000_exam_quiz_attempt_topic_quotas.sql',
    ).readAsStringSync();

    expect(migration, contains('invalid_exam_topic_quotas'));
    expect(migration, contains("v_category = 'A12'"));
    expect(migration, contains("v_category = 'D1'"));
    expect(
      migration,
      contains('CREATE OR REPLACE FUNCTION public.submit_exam_quiz_attempt'),
    );
    // Must keep the Supabase pgcrypto schema qualification from 20260725140000.
    expect(migration, contains('extensions.digest('));
    expect(migration.contains('\ndigest('), isFalse);

    for (final entry in ExamQuizRules.a12TopicQuotas.entries) {
      expect(
        migration,
        contains("= '${entry.key}'"),
        reason: 'A12 topic ${entry.key} must be checked',
      );
      expect(
        migration,
        contains(') <> ${entry.value}'),
        reason: 'A12 quota ${entry.key}=${entry.value} must be enforced',
      );
    }

    for (final entry in ExamQuizRules.d1TopicQuotas.entries) {
      expect(
        migration,
        contains("= '${entry.key}'"),
        reason: 'D1 topic ${entry.key} must be checked',
      );
      expect(
        migration,
        contains(') <> ${entry.value}'),
        reason: 'D1 quota ${entry.key}=${entry.value} must be enforced',
      );
    }

    // D1-specific quotas that differ from A12 (regression vs A12-only patch).
    expect(migration, contains("v_category = 'D1'"));
    // MOTORE D1=2, A12=1 — both must appear as inequality checks.
    expect(migration, contains(') <> 2'));
    expect(migration, contains(') <> 1'));
  });
}
