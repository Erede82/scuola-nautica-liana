import '../domain/course_taxonomy.dart';
import 'student_session.dart';

/// Dati inviati dal form di registrazione (prima della persistenza).
class StudentRegistrationRequest {
  const StudentRegistrationRequest({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.password,
    required this.enrolledCoursePath,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String password;
  final EnrollmentCoursePath enrolledCoursePath;
}

/// Esito registrazione — usato dal repository mock e futuro Supabase.
class StudentRegistrationResult {
  const StudentRegistrationResult._({
    required this.success,
    this.errorMessage,
    this.session,
  });

  final bool success;
  final String? errorMessage;
  final StudentSession? session;

  factory StudentRegistrationResult.ok(StudentSession session) =>
      StudentRegistrationResult._(success: true, session: session);

  factory StudentRegistrationResult.error(String message) =>
      StudentRegistrationResult._(success: false, errorMessage: message);
}

/// Esito login — allineato a [StudentRegistrationResult] (sessione oppure errore).
///
/// Login riuscito può avere [session] null se l’account è solo staff (nessuna riga `students`).
class StudentLoginResult {
  const StudentLoginResult._({
    required this.success,
    this.errorMessage,
    this.session,
  });

  final bool success;
  final String? errorMessage;
  final StudentSession? session;

  /// Profilo allievo caricato (tabella `students`). `false` per account solo staff.
  bool get hasStudentProfile => session != null;

  /// Accesso riuscito; [session] può essere null per utenti solo staff.
  factory StudentLoginResult.ok([StudentSession? session]) =>
      StudentLoginResult._(success: true, session: session);

  factory StudentLoginResult.error(String message) =>
      StudentLoginResult._(success: false, errorMessage: message);
}
