import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('student_extra_purchases RLS', () {
    const unsafeStudentWritePolicies = [
      'student_extra_purchases_student_insert_own',
      'student_extra_purchases_student_update_own',
    ];

    test('does not leave student-owned write policies active', () {
      for (final policyName in unsafeStudentWritePolicies) {
        final operations = _policyOperations(policyName);

        expect(
          operations,
          isNotEmpty,
          reason: 'The migration history should mention $policyName.',
        );
        expect(
          operations.last.kind,
          _PolicyOperationKind.drop,
          reason:
              'The final migration operation for $policyName must be DROP so '
              'students cannot self-grant paid Extra access.',
        );
      }
    });
  });
}

List<_PolicyOperation> _policyOperations(String policyName) {
  final migrations = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final operationPattern = RegExp(
    r'\b(DROP|CREATE)\s+POLICY(?:\s+IF\s+EXISTS)?\s+' +
        RegExp.escape(policyName) +
        r'\b',
    caseSensitive: false,
  );

  return [
    for (final migration in migrations)
      for (final match in operationPattern.allMatches(
        migration.readAsStringSync(),
      ))
        _PolicyOperation(
          migration.path,
          match.group(1)!.toUpperCase() == 'DROP'
              ? _PolicyOperationKind.drop
              : _PolicyOperationKind.create,
        ),
  ];
}

class _PolicyOperation {
  const _PolicyOperation(this.migrationPath, this.kind);

  final String migrationPath;
  final _PolicyOperationKind kind;

  @override
  String toString() => '$kind in $migrationPath';
}

enum _PolicyOperationKind { create, drop }
