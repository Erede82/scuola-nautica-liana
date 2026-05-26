/// Percorso di iscrizione scelto in segreteria / onboarding — **non** è un modulo contenuto app.
///
/// Mappa su colonne tipo `students.enrolled_course_path` (stringa stabile snake_case DB).
enum EnrollmentCoursePath {
  /// Patente entro 12 miglia (contenuto principale: modulo motore entro 12).
  entro12Miglia,

  /// Patente D1.
  d1,

  /// Percorso misto: entro 12 miglia + vela (due moduli contenuto; vela può essere “in arrivo”).
  entro12MigliaVela,
}

/// Etichetta prodotto (IT) per UI app / backoffice.
extension EnrollmentCoursePathDisplayIt on EnrollmentCoursePath {
  String get labelIt {
    switch (this) {
      case EnrollmentCoursePath.entro12Miglia:
        return 'Entro le 12 miglia motore';
      case EnrollmentCoursePath.d1:
        return 'D1';
      case EnrollmentCoursePath.entro12MigliaVela:
        return 'Oltre 12 miglia vela e motore';
    }
  }
}

/// Moduli di contenuto erogati nell’app (quiz, lezioni, esami per area).
///
/// Separato da [EnrollmentCoursePath]: un iscrizione attiva uno o più moduli.
/// Mappa su tabelle accessi studio (`license_category` lato DB può restare allineata a questi valori).
enum ContentModuleId {
  /// Quiz/teoria patente entro 12 miglia (oggi catalogo `LicenseCategoryId.motore`).
  motoreEntro12,

  /// Modulo vela (contenuti possono essere parziali / in arrivo).
  vela,

  /// Modulo D1.
  d1,
}

/// Valori serializzati per Postgres / Supabase (`CHECK`, PostgREST).
abstract final class EnrollmentCoursePathStorage {
  static const String entro12Miglia = 'entro_12_miglia';
  static const String d1 = 'd1';
  static const String entro12MigliaVela = 'entro_12_miglia_vela';

  static String toStorage(EnrollmentCoursePath p) {
    switch (p) {
      case EnrollmentCoursePath.entro12Miglia:
        return entro12Miglia;
      case EnrollmentCoursePath.d1:
        return d1;
      case EnrollmentCoursePath.entro12MigliaVela:
        return entro12MigliaVela;
    }
  }

  static EnrollmentCoursePath? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    switch (raw) {
      case entro12Miglia:
        return EnrollmentCoursePath.entro12Miglia;
      case d1:
        return EnrollmentCoursePath.d1;
      case entro12MigliaVela:
        return EnrollmentCoursePath.entro12MigliaVela;
      default:
        return null;
    }
  }
}

abstract final class ContentModuleIdStorage {
  static const String motoreEntro12 = 'motore_entro_12';
  static const String vela = 'vela';
  static const String d1 = 'd1';

  static String toStorage(ContentModuleId m) {
    switch (m) {
      case ContentModuleId.motoreEntro12:
        return motoreEntro12;
      case ContentModuleId.vela:
        return vela;
      case ContentModuleId.d1:
        return d1;
    }
  }

  static ContentModuleId? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    switch (raw) {
      case motoreEntro12:
        return ContentModuleId.motoreEntro12;
      case vela:
        return ContentModuleId.vela;
      case d1:
        return ContentModuleId.d1;
      default:
        return null;
    }
  }
}
