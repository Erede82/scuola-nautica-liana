import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';

void main() {
  test(
    'createBackofficeStudent persiste E.164 + ISO2 (non nazionale)',
    () async {
      final repo = BackofficeRepositoryMock();
      final outcome = await repo.createBackofficeStudent(
        firstName: 'Anna',
        lastName: 'Rossi',
        phone: '+393331234567',
        phoneCountryIso2: 'IT',
        email:
            'anna.phone.${DateTime.now().microsecondsSinceEpoch}@example.com',
        createPracticeDossier: false,
      );
      expect(outcome.profile.phone, '+393331234567');
      expect(outcome.profile.phoneCountryIso2, 'IT');
      expect(outcome.profile.phone, isNot('3331234567'));
    },
  );
}
