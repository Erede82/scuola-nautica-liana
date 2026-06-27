import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/extra_content_ids.dart';
import 'package:scuola_nautica_liana/data/extra_bundle_catalog.dart';

void main() {
  group('Extra entitlement security migrations', () {
    test('students cannot self-write Extra purchases after all migrations', () {
      for (final policyName in <String>[
        'student_extra_purchases_student_insert_own',
        'student_extra_purchases_student_update_own',
      ]) {
        expect(
          _lastPolicyAction(policyName),
          _PolicyAction.drop,
          reason:
              '$policyName must end as DROP so paid video entitlements can '
              'only be granted by staff or service-role checkout fulfillment.',
        );
      }
    });
  });

  group('Extra bundle entitlement mapping', () {
    test('bundle grant and revoke product lists stay symmetric', () {
      const bundleProducts = <String>[
        ExtraContentIds.extraPacchetto,
        ExtraContentIds.extraTeoria,
        ExtraContentIds.extraCarteggio,
        ExtraContentIds.extraGuida,
      ];

      expect(
        ExtraBundleCatalog.productsToGrantOnAccess(
          ExtraContentIds.extraPacchetto,
        ),
        bundleProducts,
      );
      expect(
        ExtraBundleCatalog.productsToRevokeOnAccess(
          ExtraContentIds.extraPacchetto,
        ),
        bundleProducts,
      );
    });

    test('single-product grants and revokes are unchanged', () {
      expect(
        ExtraBundleCatalog.productsToGrantOnAccess(ExtraContentIds.extraTeoria),
        <String>[ExtraContentIds.extraTeoria],
      );
      expect(
        ExtraBundleCatalog.productsToRevokeOnAccess(ExtraContentIds.extraTeoria),
        <String>[ExtraContentIds.extraTeoria],
      );
    });
  });
}

enum _PolicyAction { create, drop }

_PolicyAction? _lastPolicyAction(String policyName) {
  final migrations = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final pattern = RegExp(
    r'\b(DROP|CREATE)\s+POLICY(?:\s+IF\s+EXISTS)?\s+' + policyName + r'\b',
    caseSensitive: false,
  );

  _PolicyAction? action;
  for (final migration in migrations) {
    for (final match in pattern.allMatches(migration.readAsStringSync())) {
      final raw = match.group(1)!.toUpperCase();
      action = raw == 'DROP' ? _PolicyAction.drop : _PolicyAction.create;
    }
  }
  return action;
}
