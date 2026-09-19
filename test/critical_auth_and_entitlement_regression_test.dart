import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('critical entitlement policies', () {
    test('student clients cannot write their own Extra purchases', () {
      expect(
        _finalPolicyAction('student_extra_purchases_student_insert_own'),
        'drop',
      );
      expect(
        _finalPolicyAction('student_extra_purchases_student_update_own'),
        'drop',
      );
    });
  });

  group('registration navigation', () {
    test('login page closes after a successful nested registration', () {
      final source = File('lib/pages/login_page.dart').readAsStringSync();

      expect(source, contains('Navigator.push<bool>'));
      expect(source, contains('registered == true && mounted'));
      expect(source, contains('Navigator.of(context).pop();'));
    });
  });
}

String? _finalPolicyAction(String policyName) {
  final migrations = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  String? action;
  for (final migration in migrations) {
    final sql = migration.readAsStringSync();
    final dropPattern = RegExp(
      r'DROP\s+POLICY\s+IF\s+EXISTS\s+' + RegExp.escape(policyName) + r'\b',
      caseSensitive: false,
    );
    final createPattern = RegExp(
      r'CREATE\s+POLICY\s+' + RegExp.escape(policyName) + r'\b',
      caseSensitive: false,
    );

    final matches = <({int offset, String action})>[
      for (final match in dropPattern.allMatches(sql))
        (offset: match.start, action: 'drop'),
      for (final match in createPattern.allMatches(sql))
        (offset: match.start, action: 'create'),
    ]..sort((a, b) => a.offset.compareTo(b.offset));

    for (final match in matches) {
      action = match.action;
    }
  }

  return action;
}
