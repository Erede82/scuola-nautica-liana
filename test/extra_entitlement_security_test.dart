import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/extra_content_ids.dart';
import 'package:scuola_nautica_liana/data/extra_bundle_catalog.dart';

void main() {
  group('student_extra_purchases RLS', () {
    test('final migration action drops student self-write policies', () {
      final migrations = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      expect(
        _finalPolicyAction(
          migrations,
          'student_extra_purchases_student_insert_own',
        ),
        'DROP',
      );
      expect(
        _finalPolicyAction(
          migrations,
          'student_extra_purchases_student_update_own',
        ),
        'DROP',
      );
    });
  });

  group('Extra bundle entitlement symmetry', () {
    test('bundle grant and revoke touch the same product ids', () {
      const expected = <String>[
        ExtraContentIds.extraPacchetto,
        ExtraContentIds.extraTeoria,
        ExtraContentIds.extraCarteggio,
        ExtraContentIds.extraGuida,
      ];

      expect(
        ExtraBundleCatalog.productsToGrantOnAccess(
          ExtraContentIds.extraPacchetto,
        ),
        expected,
      );
      expect(
        ExtraBundleCatalog.productsToRevokeOnAccess(
          ExtraContentIds.extraPacchetto,
        ),
        expected,
      );
    });

    test('single-product grant and revoke stay scoped to that product', () {
      expect(
        ExtraBundleCatalog.productsToGrantOnAccess(ExtraContentIds.extraTeoria),
        const <String>[ExtraContentIds.extraTeoria],
      );
      expect(
        ExtraBundleCatalog.productsToRevokeOnAccess(ExtraContentIds.extraTeoria),
        const <String>[ExtraContentIds.extraTeoria],
      );
    });
  });
}

String? _finalPolicyAction(List<File> migrations, String policyName) {
  String? action;
  final createPattern = RegExp(
    r'\bCREATE\s+POLICY\s+' + RegExp.escape(policyName) + r'\b',
    caseSensitive: false,
  );
  final dropPattern = RegExp(
    r'\bDROP\s+POLICY\s+(?:IF\s+EXISTS\s+)?' +
        RegExp.escape(policyName) +
        r'\b',
    caseSensitive: false,
  );

  for (final migration in migrations) {
    final sql = migration.readAsStringSync();
    if (createPattern.hasMatch(sql)) {
      action = 'CREATE';
    }
    if (dropPattern.hasMatch(sql)) {
      action = 'DROP';
    }
  }

  return action;
}
