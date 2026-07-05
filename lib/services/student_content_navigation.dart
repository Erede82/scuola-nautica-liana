import '../data/license_catalog.dart';
import '../domain/enrollment_content_mapping.dart';
import '../models/license_models.dart';
import '../services/demo_student_enrollment.dart';
import '../services/staff_access_service.dart';

/// Risolve navigazione contenuti studente senza passaggi UI superflui.
abstract final class StudentContentNavigation {
  /// Categoria statistiche del percorso iscrizione, se nota e utilizzabile.
  ///
  /// Restituisce `null` per staff (scelta manuale), assenza sessione allievo,
  /// o categoria non ancora disponibile nel catalogo app.
  static LicenseCategoryId? directStatisticsCategoryForCurrentUser() {
    if (staffAccessNotifier.value.staffRole != null) return null;

    final session = studentSession.value;
    if (session == null) return null;

    final categoryId = EnrollmentContentMapping.primaryLicenseCategory(
      session.enrolledCoursePath,
    );
    if (!LicenseCatalog.byId(categoryId).isAvailable) return null;

    return categoryId;
  }
}
