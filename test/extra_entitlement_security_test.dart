import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/extra_bundle_catalog.dart';

void main() {
  group('Extra entitlement RLS migrations', () {
    const unsafeStudentWritePolicies = <String>[
      'student_extra_purchases_student_insert_own',
      'student_extra_purchases_student_update_own',
    ];

    test('leave student_extra_purchases student write policies dropped', () {
      final migrations = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final policyName in unsafeStudentWritePolicies) {
        final actions = <_PolicyAction>[];
        final dropPattern = RegExp(
          r'\bDROP\s+POLICY\s+IF\s+EXISTS\s+' + policyName + r'\b',
          caseSensitive: false,
          multiLine: true,
        );
        final createPattern = RegExp(
          r'\bCREATE\s+POLICY\s+' + policyName + r'\b',
          caseSensitive: false,
          multiLine: true,
        );

        for (final migration in migrations) {
          final sql = migration.readAsStringSync();
          if (dropPattern.hasMatch(sql)) {
            actions.add(_PolicyAction.drop(migration.path));
          }
          if (createPattern.hasMatch(sql)) {
            actions.add(_PolicyAction.create(migration.path));
          }
        }

        expect(
          actions,
          isNotEmpty,
          reason: 'Expected the migration chain to mention $policyName.',
        );
        expect(
          actions.last.kind,
          _PolicyActionKind.drop,
          reason:
              '$policyName must stay dropped so students cannot self-grant '
              'paid Extra entitlements.',
        );
      }
    });
  });

  group('Extra bundle entitlement mapping', () {
    test('revokes the same bundle products that grants unlock', () {
      final bundleProducts = <String>[
        ExtraBundleCatalog.bundleId,
        ...ExtraBundleCatalog.bundleIncludedProductIds,
      ];

      expect(
        ExtraBundleCatalog.productsToGrantOnAccess(
          ExtraBundleCatalog.bundleId,
        ),
        bundleProducts,
      );
      expect(
        ExtraBundleCatalog.productsToRevokeOnAccess(
          ExtraBundleCatalog.bundleId,
        ),
        bundleProducts,
      );
      expect(
        ExtraBundleCatalog.productsToRevokeOnAccess('ex-theory'),
        <String>['ex-theory'],
      );
    });
  });
}

enum _PolicyActionKind { create, drop }

class _PolicyAction {
  const _PolicyAction._(this.kind, this.path);

  const _PolicyAction.create(String path)
      : this._(_PolicyActionKind.create, path);

  const _PolicyAction.drop(String path) : this._(_PolicyActionKind.drop, path);

  final _PolicyActionKind kind;
  final String path;
}
