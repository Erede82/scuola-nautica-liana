import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('assigned quiz staff-note confidentiality', () {
    late String migrationSource;
    late String repositorySource;

    setUpAll(() {
      final migrationFiles = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      migrationSource = migrationFiles
          .map((file) => file.readAsStringSync())
          .join('\n');
      repositorySource = File(
        'lib/repositories/assigned_quiz_repository.dart',
      ).readAsStringSync();
    });

    test('latest migration removes direct student assignment SELECT', () {
      final policyCreate = migrationSource.lastIndexOf(
        'CREATE POLICY assigned_quizzes_student_select',
      );
      final policyDrop = migrationSource.lastIndexOf(
        'DROP POLICY IF EXISTS assigned_quizzes_student_select',
      );

      expect(policyCreate, greaterThanOrEqualTo(0));
      expect(policyDrop, greaterThan(policyCreate));
    });

    test('student RPC returns only a safe assignment projection', () {
      const signature =
          'CREATE OR REPLACE FUNCTION public.get_my_assigned_quizzes()';
      final functionStart = migrationSource.lastIndexOf(signature);
      final functionEnd = migrationSource.indexOf('\n\$\$;', functionStart);
      expect(functionStart, greaterThanOrEqualTo(0));
      expect(functionEnd, greaterThan(functionStart));

      final functionDefinition = migrationSource.substring(
        functionStart,
        functionEnd,
      );
      expect(functionDefinition, contains('SECURITY DEFINER'));
      expect(functionDefinition, contains('aq.student_user_id = v_uid'));
      expect(functionDefinition, isNot(contains("'staff_note'")));
      expect(functionDefinition, isNot(contains("'generation_params'")));
    });

    test('loadMine uses the safe RPC instead of the sensitive table', () {
      final loadMineStart = repositorySource.indexOf(
        'Future<List<AssignedQuizSummary>> loadMine() async',
      );
      final loadMineEnd = repositorySource.indexOf(
        '\n  @override',
        loadMineStart + 1,
      );
      expect(loadMineStart, greaterThanOrEqualTo(0));
      expect(loadMineEnd, greaterThan(loadMineStart));

      final loadMineSource = repositorySource.substring(
        loadMineStart,
        loadMineEnd,
      );
      expect(loadMineSource, contains("rpc('get_my_assigned_quizzes')"));
      expect(loadMineSource, isNot(contains(".from('assigned_quizzes')")));
    });
  });
}
