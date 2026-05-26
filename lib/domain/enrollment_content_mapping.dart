import '../models/license_models.dart';
import 'course_taxonomy.dart';

/// Deriva moduli contenuto e categorie catalogo dal percorso di iscrizione.
///
/// Layer di dominio condiviso app / backoffice (nessuna dipendenza Flutter UI).
abstract final class EnrollmentContentMapping {
  static List<ContentModuleId> contentModulesForPath(EnrollmentCoursePath path) {
    switch (path) {
      case EnrollmentCoursePath.entro12Miglia:
        return const [ContentModuleId.motoreEntro12];
      case EnrollmentCoursePath.d1:
        return const [ContentModuleId.d1];
      case EnrollmentCoursePath.entro12MigliaVela:
        return const [ContentModuleId.motoreEntro12, ContentModuleId.vela];
    }
  }

  static LicenseCategoryId primaryLicenseCategory(EnrollmentCoursePath path) {
    final modules = contentModulesForPath(path);
    return contentModuleToLicenseCategoryId(modules.first);
  }

  static LicenseCategoryId contentModuleToLicenseCategoryId(ContentModuleId m) {
    switch (m) {
      case ContentModuleId.motoreEntro12:
        return LicenseCategoryId.motore;
      case ContentModuleId.vela:
        return LicenseCategoryId.vela;
      case ContentModuleId.d1:
        return LicenseCategoryId.d1;
    }
  }

  static ContentModuleId? contentModuleForLicenseCategory(LicenseCategoryId id) {
    switch (id) {
      case LicenseCategoryId.motore:
        return ContentModuleId.motoreEntro12;
      case LicenseCategoryId.vela:
        return ContentModuleId.vela;
      case LicenseCategoryId.d1:
        return ContentModuleId.d1;
    }
  }

  static bool pathIncludesContentModule(
    EnrollmentCoursePath path,
    ContentModuleId module,
  ) =>
      contentModulesForPath(path).contains(module);

  static Set<LicenseCategoryId> licenseCategoriesForPath(
    EnrollmentCoursePath path,
  ) =>
      contentModulesForPath(path)
          .map(contentModuleToLicenseCategoryId)
          .toSet();

  static EnrollmentCoursePath inferEnrollmentPathFromLegacyCategory(
    LicenseCategoryId category,
  ) {
    switch (category) {
      case LicenseCategoryId.motore:
        return EnrollmentCoursePath.entro12Miglia;
      case LicenseCategoryId.d1:
        return EnrollmentCoursePath.d1;
      case LicenseCategoryId.vela:
        return EnrollmentCoursePath.entro12MigliaVela;
    }
  }

  /// Etichetta breve modulo contenuto (IT) — senza dipendenze UI.
  static String contentModuleLabelIt(ContentModuleId m) {
    switch (m) {
      case ContentModuleId.motoreEntro12:
        return 'Entro le 12 miglia motore';
      case ContentModuleId.vela:
        return 'Vela';
      case ContentModuleId.d1:
        return 'D1';
    }
  }

  static String contentModulesJoinedIt(EnrollmentCoursePath path) =>
      contentModulesForPath(path).map(contentModuleLabelIt).join(' · ');
}
