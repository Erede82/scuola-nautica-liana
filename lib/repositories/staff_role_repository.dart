import '../domain/staff/staff_school_role.dart';

/// Risolve il ruolo scuola dell’utente autenticato (tabella `school_user_roles`).
abstract class StaffRoleRepository {
  /// `null` se non autenticato, nessuna riga, ruolo `student`, o errore gestito come “non staff”.
  Future<StaffSchoolRole?> resolveCurrentUserRole();
}
