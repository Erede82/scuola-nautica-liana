import 'backoffice_enums.dart';
import 'ids.dart';

/// Utente del sistema (staff o studente) con ruolo per RBAC.
///
/// In Supabase: tabella `profiles` + `user_roles` o claim JWT `role`.
/// L’app studente usa in genere solo l’account con ruolo [BackofficeRole.student].
class BackofficeUser {
  const BackofficeUser({
    required this.id,
    required this.authUserId,
    required this.primaryRole,
    this.linkedStudentId,
    this.displayName,
    this.email,
    this.phone,
    this.active = true,
  });

  final BackofficeUserId id;

  /// UUID Supabase Auth.
  final String authUserId;
  final BackofficeRole primaryRole;

  /// Se ruolo studente, FK verso [StudentProfile.id].
  final StudentId? linkedStudentId;
  final String? displayName;
  final String? email;
  final String? phone;
  final bool active;
}
