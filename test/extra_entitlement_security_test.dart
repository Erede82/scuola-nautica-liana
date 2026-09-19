import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Extra entitlement security', () {
    test('student write policies end as dropped in the migration chain', () {
      final migrations = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      const unsafePolicyNames = <String>[
        'student_extra_purchases_student_insert_own',
        'student_extra_purchases_student_update_own',
      ];

      for (final policyName in unsafePolicyNames) {
        String? lastAction;
        final actionPattern = RegExp(
          r'^\s*(DROP|CREATE)\s+POLICY(?:\s+IF\s+EXISTS)?\s+' +
              RegExp.escape(policyName) +
              r'\b',
          caseSensitive: false,
        );

        for (final migration in migrations) {
          for (final line in migration.readAsLinesSync()) {
            final match = actionPattern.firstMatch(line);
            if (match != null) {
              lastAction = match.group(1)!.toUpperCase();
            }
          }
        }

        expect(
          lastAction,
          'DROP',
          reason: '$policyName must not leave students able to self-grant '
              'Extra access.',
        );
      }
    });

    test('bundle revocation mirrors bundle grant expansion', () {
      final catalog = File(
        'lib/data/extra_bundle_catalog.dart',
      ).readAsStringSync();
      final supabaseRepo = File(
        'lib/repositories/backoffice/management_repository_supabase.dart',
      ).readAsStringSync();
      final mockRepo = File(
        'lib/repositories/backoffice/management_repository_mock.dart',
      ).readAsStringSync();
      final adminPage = File(
        'lib/pages/backoffice/video_courses_admin_page.dart',
      ).readAsStringSync();

      expect(catalog, contains('productsToGrantOnAccess(productId);'));
      expect(catalog, contains('productsToRevokeOnAccess(String productId)'));
      expect(supabaseRepo, contains('productsToRevokeOnAccess(productId)'));
      expect(supabaseRepo, contains(".inFilter('product_id', productIds)"));
      expect(mockRepo, contains('productsToRevokeOnAccess(productId)'));
      expect(adminPage, contains('productsToGrantOnAccess(productId)'));
      expect(adminPage, contains('productsToRevokeOnAccess(productId)'));
      expect(adminPage, contains('..removeAll(revokedIds)'));
    });
  });
}
