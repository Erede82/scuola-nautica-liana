import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/domain/backoffice/student_app_access_credentials.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/utils/app_access_password_generator.dart';

/// Regression: Nuova pratica e Modifica anagrafica condividono lo stesso
/// generatore (util) e lo stesso contratto `createStudentAppAccess`.
void main() {
  test('Nuova pratica source importa util (no Random locale)', () {
    final practice = File(
      'lib/widgets/backoffice/backoffice_new_practice_dialog.dart',
    ).readAsStringSync();
    expect(practice, contains("app_access_password_generator.dart"));
    expect(practice, contains('generateReadableAppAccessPassword()'));
    expect(practice, isNot(contains('dart:math')));
    expect(
      practice,
      isNot(contains('String generateReadableAppAccessPassword')),
    );
    expect(practice, contains('showAppAccessCredentialsDialog'));
    expect(practice, contains('createStudentAppAccess'));
    expect(practice, contains('temporaryPassword'));
    expect(practice, contains('Genera password'));
  });

  test(
    'shared generator usable for Nuova pratica create access path',
    () async {
      final generated = generateReadableAppAccessPassword();
      expect(generated.length, greaterThanOrEqualTo(8));

      final manual = 'ManualPass99';
      expect(manual.length, greaterThanOrEqualTo(8));

      final repo = BackofficeRepositoryMock();
      backofficeDemoStore.clearStudentAppAccessLink('stu-demo-lucia-001');
      backofficeDemoStore.clearStudentAppAccessLink('stu-demo-marco-002');

      // Manual password path (as Nuova pratica does when draft length >= 8).
      final credsManual = await repo.createStudentAppAccess(
        studentId: 'stu-demo-lucia-001',
        email: 'practice.manual@example.com',
        temporaryPassword: manual,
      );
      expect(credsManual, isA<StudentAppAccessCredentials>());
      expect(credsManual.temporaryPassword, manual);
      expect(credsManual.email, 'practice.manual@example.com');

      // Generated password path.
      final credsGen = await repo.createStudentAppAccess(
        studentId: 'stu-demo-marco-002',
        email: 'practice.gen@example.com',
        temporaryPassword: generated,
      );
      expect(credsGen.temporaryPassword, generated);
      expect(credsGen.email, 'practice.gen@example.com');

      backofficeDemoStore.clearStudentAppAccessLink('stu-demo-lucia-001');
      backofficeDemoStore.clearStudentAppAccessLink('stu-demo-marco-002');
    },
  );
}
