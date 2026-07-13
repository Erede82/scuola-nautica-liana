import '../models/license_models.dart';

/// Valore `questions.license_category` / `quiz_sets.license_category` (DB).
String? dbLicenseCategoryFor(LicenseCategoryId categoryId) {
  switch (categoryId) {
    case LicenseCategoryId.motore:
      return 'A12';
    case LicenseCategoryId.d1:
      return 'D1';
    case LicenseCategoryId.vela:
      return null;
  }
}

/// Mappa categoria DB → enum app (solo A12/D1 note in produzione).
LicenseCategoryId? licenseCategoryIdFromDb(String? raw) {
  switch (raw?.trim()) {
    case 'A12':
      return LicenseCategoryId.motore;
    case 'D1':
      return LicenseCategoryId.d1;
    default:
      return null;
  }
}
