import '../data/license_catalog.dart';
import '../domain/course_taxonomy.dart';
import '../domain/enrollment_content_mapping.dart';
import '../models/license_models.dart';
import '../services/demo_student_enrollment.dart';
import '../services/staff_access_service.dart';
import '../services/student_area_context.dart';

/// Risolve navigazione contenuti studente senza passaggi UI superflui.
abstract final class StudentContentNavigation {
  /// Categoria statistiche del percorso iscrizione, se nota e utilizzabile.
  ///
  /// Restituisce `null` per staff (scelta manuale), assenza sessione allievo,
  /// o categoria non ancora disponibile nel catalogo app.
  static LicenseCategoryId? directStatisticsCategoryForCurrentUser() {
    if (_staffManualCategorySelectionRequired) return null;

    final session = studentSession.value;
    if (session == null) return null;

    final categoryId = EnrollmentContentMapping.primaryLicenseCategory(
      session.enrolledCoursePath,
    );
    if (!LicenseCatalog.byId(categoryId).isAvailable) return null;

    return categoryId;
  }

  /// Categoria lezioni del percorso iscrizione attivo (bypass scelta categoria).
  ///
  /// Restituisce `null` per staff (scelta manuale) o categoria non disponibile.
  static LicenseCategoryId? directLessonsCategoryForCurrentUser() =>
      _directCategoryForStudentEnrollment();

  /// Categoria quiz esame del percorso iscrizione attivo (bypass scelta categoria).
  ///
  /// Restituisce `null` per staff (scelta manuale) o categoria non disponibile.
  static LicenseCategoryId? directExamCategoryForCurrentUser() =>
      _directCategoryForStudentEnrollment();

  /// Categoria Ripasso errori del percorso iscrizione attivo (nessuna scelta libera).
  ///
  /// Restituisce `null` per staff (scelta manuale) o categoria non disponibile.
  static LicenseCategoryId? directErrorReviewCategoryForCurrentUser() =>
      _directCategoryForStudentEnrollment();

  static LicenseCategoryId? _directCategoryForStudentEnrollment() {
    if (_staffManualCategorySelectionRequired) return null;

    final path =
        studentSession.value?.enrolledCoursePath ??
        demoStudentEnrollmentPath.value;
    return categoryForEnrollmentPath(path);
  }

  /// Mappa percorso iscrizione → categoria catalogo se disponibile (testabile).
  static LicenseCategoryId? categoryForEnrollmentPath(
    EnrollmentCoursePath path,
  ) {
    final categoryId = EnrollmentContentMapping.primaryLicenseCategory(path);
    if (!LicenseCatalog.byId(categoryId).isAvailable) return null;
    return categoryId;
  }

  /// Staff fuori anteprima deve scegliere la categoria manualmente.
  static bool get _staffManualCategorySelectionRequired {
    if (studentAreaPreviewActiveMode.value == StudentAreaMode.staffPreview) {
      return false;
    }
    return staffAccessNotifier.value.staffRole != null;
  }
}
