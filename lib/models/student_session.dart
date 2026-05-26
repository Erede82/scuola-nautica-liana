import '../domain/backoffice/backoffice_enums.dart';
import '../domain/backoffice/ids.dart';
import '../domain/backoffice/student_profile.dart';
import '../domain/course_taxonomy.dart';

/// Sessione allievo lato app dopo registrazione / login.
///
/// In produzione si popola da token (Supabase) + `GET /students/me`.
/// Nel mock locale è mantenuta in memoria con [studentSession].
class StudentSession {
  const StudentSession({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.enrolledCoursePath,
    required this.registrationStatus,
  });

  final StudentId studentId;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final EnrollmentCoursePath enrolledCoursePath;
  final StudentRegistrationStatus registrationStatus;

  String get displayName => '$firstName $lastName'.trim();

  factory StudentSession.fromProfile(StudentProfile p) {
    return StudentSession(
      studentId: p.id,
      firstName: p.firstName,
      lastName: p.lastName,
      email: p.email ?? '',
      phone: p.phone,
      enrolledCoursePath: p.enrolledCoursePath,
      registrationStatus: p.registrationStatus,
    );
  }
}
