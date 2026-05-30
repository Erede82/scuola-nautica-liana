import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/supabase/dto/backoffice_rows.dart';
import 'package:scuola_nautica_liana/data/supabase/mappers/backoffice_row_mappers.dart';
import 'package:scuola_nautica_liana/domain/course_taxonomy.dart';

void main() {
  StudentRow baseStudentRow({
    String? enrolledCoursePath,
    String enrolledLicenseCategory = 'motore',
    String? practiceDossierType,
  }) {
    return StudentRow(
      id: 'student-1',
      firstName: 'Ada',
      lastName: 'Lovelace',
      enrolledCoursePath: enrolledCoursePath,
      enrolledLicenseCategory: enrolledLicenseCategory,
      registrationStatus: 'pending',
      practiceDossierType: practiceDossierType,
    );
  }

  test('keeps renewal/duplicate rows out of course paths', () {
    final profile = mapStudentRowToProfile(
      baseStudentRow(
        enrolledCoursePath: 'entro_12_miglia',
        enrolledLicenseCategory: 'motore',
        practiceDossierType: 'renewal',
      ),
    );

    expect(profile.practiceDossierType, 'renewal');
    expect(profile.hasEnrollmentCoursePath, isFalse);
    expect(profile.enrolledCoursePath, EnrollmentCoursePath.entro12Miglia);
  });

  test('still infers legacy course path when legacy category exists', () {
    final profile = mapStudentRowToProfile(
      baseStudentRow(enrolledLicenseCategory: 'd1'),
    );

    expect(profile.hasEnrollmentCoursePath, isTrue);
    expect(profile.enrolledCoursePath, EnrollmentCoursePath.d1);
  });
}
