import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/course_taxonomy.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/services/demo_student_enrollment.dart';
import 'package:scuola_nautica_liana/services/student_content_navigation.dart';

void main() {
  group('categoryForEnrollmentPath', () {
    test('entro 12 miglia motore → motore', () {
      expect(
        StudentContentNavigation.categoryForEnrollmentPath(
          EnrollmentCoursePath.entro12Miglia,
        ),
        LicenseCategoryId.motore,
      );
    });

    test('D1 → d1', () {
      expect(
        StudentContentNavigation.categoryForEnrollmentPath(
          EnrollmentCoursePath.d1,
        ),
        LicenseCategoryId.d1,
      );
    });

    test('motore + vela → motore (categoria primaria)', () {
      expect(
        StudentContentNavigation.categoryForEnrollmentPath(
          EnrollmentCoursePath.entro12MigliaVela,
        ),
        LicenseCategoryId.motore,
      );
    });
  });

  group('directErrorReviewCategoryForCurrentUser', () {
    tearDown(() {
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.entro12Miglia;
      clearStudentSession();
    });

    test('allievo entro 12 → motore', () {
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.entro12Miglia;
      expect(
        StudentContentNavigation.directErrorReviewCategoryForCurrentUser(),
        LicenseCategoryId.motore,
      );
    });

    test('allievo D1 → d1', () {
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.d1;
      expect(
        StudentContentNavigation.directErrorReviewCategoryForCurrentUser(),
        LicenseCategoryId.d1,
      );
    });
  });
}
