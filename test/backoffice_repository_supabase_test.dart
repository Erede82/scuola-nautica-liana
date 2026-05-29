import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/course_taxonomy.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_supabase.dart';

void main() {
  group('buildBackofficeStudentInsertPayload', () {
    test('fills legacy enrollment defaults when enrollment is omitted', () {
      final payload = buildBackofficeStudentInsertPayload(
        firstName: 'Mario',
        lastName: 'Rossi',
      );

      expect(
        payload['enrolled_course_path'],
        EnrollmentCoursePathStorage.entro12Miglia,
      );
      expect(
        payload['enrolled_license_category'],
        LicenseCategoryId.motore.name,
      );
    });

    test('derives legacy license category from supplied course path', () {
      final payload = buildBackofficeStudentInsertPayload(
        firstName: 'Mario',
        lastName: 'Rossi',
        enrolledCoursePath: EnrollmentCoursePathStorage.d1,
      );

      expect(payload['enrolled_course_path'], EnrollmentCoursePathStorage.d1);
      expect(payload['enrolled_license_category'], LicenseCategoryId.d1.name);
    });
  });
}
