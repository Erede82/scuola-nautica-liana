import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/extra_content_ids.dart';
import 'package:scuola_nautica_liana/data/extra_bundle_catalog.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/management_repository_mock.dart';

void main() {
  group('Extra entitlement security', () {
    test('student purchase write policies end as dropped', () {
      final finalActions = _finalPolicyActions();

      expect(
        finalActions['student_extra_purchases_student_insert_own'],
        'DROP',
      );
      expect(
        finalActions['student_extra_purchases_student_update_own'],
        'DROP',
      );
    });

    test('bundle grant and revoke touch the same entitlement rows', () async {
      final repository = ManagementRepositoryMock();
      const studentId = 'student-extra-security';

      await repository.grantStudentExtraProductAccess(
        studentId: studentId,
        productId: ExtraContentIds.extraPacchetto,
      );

      final granted = await repository.listPurchasedExtraProductIds(studentId);
      expect(
        granted,
        containsAll(
          ExtraBundleCatalog.productsToGrantOnAccess(
            ExtraContentIds.extraPacchetto,
          ),
        ),
      );

      await repository.revokeStudentExtraProductAccess(
        studentId: studentId,
        productId: ExtraContentIds.extraPacchetto,
      );

      final afterRevoke = await repository.listPurchasedExtraProductIds(
        studentId,
      );
      for (final productId in ExtraBundleCatalog.productsToRevokeOnAccess(
        ExtraContentIds.extraPacchetto,
      )) {
        expect(afterRevoke, isNot(contains(productId)));
      }
    });
  });
}

Map<String, String> _finalPolicyActions() {
  final migrations = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final actions = <String, String>{};
  final policyAction = RegExp(
    r'^\s*(DROP|CREATE)\s+POLICY(?:\s+IF\s+EXISTS)?\s+([a-zA-Z0-9_]+)',
    caseSensitive: false,
    multiLine: true,
  );

  for (final migration in migrations) {
    final sql = migration.readAsStringSync();
    for (final match in policyAction.allMatches(sql)) {
      final action = match.group(1)!.toUpperCase();
      final policyName = match.group(2)!;
      actions[policyName] = action;
    }
  }

  return actions;
}
