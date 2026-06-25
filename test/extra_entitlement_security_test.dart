import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/extra_content_ids.dart';
import 'package:scuola_nautica_liana/data/extra_bundle_catalog.dart';

void main() {
  group('Extra entitlement security', () {
    test('student write policies are finally dropped in the migration chain', () {
      expect(
        _finalPolicyAction('student_extra_purchases_student_insert_own'),
        'DROP',
      );
      expect(
        _finalPolicyAction('student_extra_purchases_student_update_own'),
        'DROP',
      );
    });

    test('bundle grant and revoke affect the same product rows', () {
      expect(
        ExtraBundleCatalog.productsToGrantOnAccess(
          ExtraContentIds.extraPacchetto,
        ),
        ExtraBundleCatalog.productsToRevokeOnAccess(
          ExtraContentIds.extraPacchetto,
        ),
      );
      expect(
        ExtraBundleCatalog.productsToRevokeOnAccess(
          ExtraContentIds.extraPacchetto,
        ),
        <String>[
          ExtraContentIds.extraPacchetto,
          ExtraContentIds.extraTeoria,
          ExtraContentIds.extraCarteggio,
          ExtraContentIds.extraGuida,
        ],
      );
    });
  });
}

String _finalPolicyAction(String policyName) {
  final migrations = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  String? action;
  final policyPattern = RegExp(
    r'\b(DROP|CREATE)\s+POLICY\s+(?:IF\s+EXISTS\s+)?' +
        RegExp.escape(policyName) +
        r'\b',
    caseSensitive: false,
  );

  for (final migration in migrations) {
    final sql = migration.readAsStringSync();
    for (final match in policyPattern.allMatches(sql)) {
      action = match.group(1)!.toUpperCase();
    }
  }

  if (action == null) {
    throw StateError('Policy $policyName was not found in migrations.');
  }
  return action;
}
