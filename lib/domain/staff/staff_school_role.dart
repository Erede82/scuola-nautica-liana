/// Ruolo scuola da `public.school_user_roles.role` (account operativi backoffice).
/// Valori DB tipici: `school_admin` (alias `admin` mappato lato app).
///
/// Distinto dal ruolo “studente” nell’app: solo [schoolAdmin], [staff] e [instructor]
/// possono accedere al backoffice UI.
enum StaffSchoolRole {
  schoolAdmin,
  staff,
  instructor,
}

extension StaffSchoolRoleLabels on StaffSchoolRole {
  /// Etichetta breve per messaggi UI (italiano).
  String get labelIt {
    switch (this) {
      case StaffSchoolRole.schoolAdmin:
        return 'Amministratore scuola';
      case StaffSchoolRole.staff:
        return 'Staff';
      case StaffSchoolRole.instructor:
        return 'Istruttore';
    }
  }
}
