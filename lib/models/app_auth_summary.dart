import '../domain/staff/staff_school_role.dart';
import '../services/auth_identity.dart';
import '../services/staff_access_service.dart';
import 'student_session.dart';

/// Classificazione utente per UI e routing (student / staff / misto / limitato).
enum AppUserKind {
  /// Nessuna sessione (ospite).
  guest,

  /// Account con riga `students` e uso tipico app allievo.
  studentOnly,

  /// Account operativo senza profilo allievo (solo `school_user_roles` staff).
  staffOnly,

  /// Allievo con anche ruolo operativo scuola (futuro / casi reali).
  studentAndStaff,

  /// JWT valido ma senza profilo studente né ruolo staff (da gestire con messaggio).
  authenticatedLimited,
}

/// Riepilogo sessione app: combina sessione studente locale e snapshot staff.
///
/// Non sostituisce i notifier esistenti; è una vista aggregata per widget e logica UI.
class AppAuthSummary {
  const AppAuthSummary({
    required this.kind,
    this.studentSession,
    this.staffRole,
    this.authEmail,
    required this.hasJwtOrMockAuth,
  });

  final AppUserKind kind;
  final StudentSession? studentSession;
  final StaffSchoolRole? staffRole;

  /// Email account (Supabase) o da [StudentSession] in mock.
  final String? authEmail;

  /// True se c’è sessione Supabase JWT o sessione studente mock attiva.
  final bool hasJwtOrMockAuth;

  /// Costruisce da sessione studente e snapshot staff.
  static AppAuthSummary fromSources({
    required StudentSession? student,
    required StaffAccessSnapshot staffSnap,
  }) {
    final hasStudent = student != null;
    final staff = staffSnap.staffRole;
    final hasAuth =
        staffSnap.hasAuthSession || AuthIdentity.hasSupabaseJwt();

    final String? email = switch (student) {
      null => AuthIdentity.supabaseAuthEmail(),
      final s when s.email.isNotEmpty => s.email,
      _ => AuthIdentity.supabaseAuthEmail(),
    };

    if (!hasAuth && !hasStudent) {
      return const AppAuthSummary(
        kind: AppUserKind.guest,
        hasJwtOrMockAuth: false,
      );
    }

    if (hasStudent && staff != null) {
      return AppAuthSummary(
        kind: AppUserKind.studentAndStaff,
        studentSession: student,
        staffRole: staff,
        authEmail: email,
        hasJwtOrMockAuth: hasAuth,
      );
    }
    if (hasStudent) {
      return AppAuthSummary(
        kind: AppUserKind.studentOnly,
        studentSession: student,
        authEmail: email,
        hasJwtOrMockAuth: hasAuth,
      );
    }
    if (staff != null) {
      return AppAuthSummary(
        kind: AppUserKind.staffOnly,
        staffRole: staff,
        authEmail: email,
        hasJwtOrMockAuth: hasAuth,
      );
    }

    return AppAuthSummary(
      kind: AppUserKind.authenticatedLimited,
      authEmail: email,
      hasJwtOrMockAuth: hasAuth,
    );
  }

  bool get hasStudentProfile => studentSession != null;
  bool get hasStaffAccess => staffRole != null;

  /// True se l’utente può uscire in modo significativo (sessione reale o mock).
  bool get canSignOut => hasJwtOrMockAuth || studentSession != null;

  String get displayNameOrPlaceholder {
    if (studentSession != null) return studentSession!.displayName;
    if (authEmail != null && authEmail!.isNotEmpty) {
      return authEmail!.split('@').first;
    }
    return 'Utente';
  }
}
