import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/extra_content_ids.dart';
import 'package:scuola_nautica_liana/data/extra_bundle_catalog.dart';

void main() {
  group('Extra entitlement security', () {
    test('bundle revoke mirrors all materialized grant rows', () {
      const expectedBundleRows = <String>[
        ExtraContentIds.extraPacchetto,
        ExtraContentIds.extraTeoria,
        ExtraContentIds.extraCarteggio,
        ExtraContentIds.extraGuida,
      ];

      expect(
        ExtraBundleCatalog.productsToGrantOnAccess(
          ExtraContentIds.extraPacchetto,
        ),
        expectedBundleRows,
      );
      expect(
        ExtraBundleCatalog.productsToRevokeOnAccess(
          ExtraContentIds.extraPacchetto,
        ),
        expectedBundleRows,
      );
      expect(
        ExtraBundleCatalog.productsToRevokeOnAccess(ExtraContentIds.extraTeoria),
        const <String>[ExtraContentIds.extraTeoria],
      );
    });

    test('migration chain removes student self-write entitlement policies', () {
      final migrations = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      final createInsertPolicy = RegExp(
        r'CREATE\s+POLICY\s+student_extra_purchases_student_insert_own\b',
        caseSensitive: false,
      );
      final createUpdatePolicy = RegExp(
        r'CREATE\s+POLICY\s+student_extra_purchases_student_update_own\b',
        caseSensitive: false,
      );
      final dropInsertPolicy = RegExp(
        r'DROP\s+POLICY\s+IF\s+EXISTS\s+student_extra_purchases_student_insert_own\b',
        caseSensitive: false,
      );
      final dropUpdatePolicy = RegExp(
        r'DROP\s+POLICY\s+IF\s+EXISTS\s+student_extra_purchases_student_update_own\b',
        caseSensitive: false,
      );

      var lastInsertCreate = -1;
      var lastUpdateCreate = -1;
      var lastInsertDrop = -1;
      var lastUpdateDrop = -1;

      for (var i = 0; i < migrations.length; i += 1) {
        final sql = migrations[i].readAsStringSync();
        if (createInsertPolicy.hasMatch(sql)) lastInsertCreate = i;
        if (createUpdatePolicy.hasMatch(sql)) lastUpdateCreate = i;
        if (dropInsertPolicy.hasMatch(sql)) lastInsertDrop = i;
        if (dropUpdatePolicy.hasMatch(sql)) lastUpdateDrop = i;
      }

      expect(lastInsertCreate, greaterThanOrEqualTo(0));
      expect(lastUpdateCreate, greaterThanOrEqualTo(0));
      expect(lastInsertDrop, greaterThan(lastInsertCreate));
      expect(lastUpdateDrop, greaterThan(lastUpdateCreate));
      expect(
        migrations[lastInsertDrop].path,
        contains('secure_student_extra_purchases'),
      );
      expect(
        migrations[lastUpdateDrop].path,
        contains('secure_student_extra_purchases'),
      );
    });
  });
}
