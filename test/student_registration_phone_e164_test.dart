import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/course_taxonomy.dart';
import 'package:scuola_nautica_liana/models/student_registration.dart';
import 'package:scuola_nautica_liana/repositories/student_auth_repository_mock.dart';

void main() {
  test('mock registration salva E.164 + ISO2', () async {
    final repo = StudentAuthRepositoryMock.instance;
    final email =
        'phone-e164-${DateTime.now().microsecondsSinceEpoch}@example.com';
    final result = await repo.register(
      StudentRegistrationRequest(
        firstName: 'Test',
        lastName: 'Phone',
        phone: '+393331234567',
        phoneCountryIso2: 'IT',
        email: email,
        password: 'SecurePass1',
        enrolledCoursePath: EnrollmentCoursePath.entro12Miglia,
      ),
    );
    expect(result.success, isTrue);
    expect(result.session?.phone, '+393331234567');
    expect(result.session?.phoneCountryIso2, 'IT');
  });
}
