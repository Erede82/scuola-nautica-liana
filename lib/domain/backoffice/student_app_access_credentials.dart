import 'ids.dart';

/// Risposta Edge Function `create-student-app-access` (credenziali solo in memoria).
class StudentAppAccessCredentials {
  const StudentAppAccessCredentials({
    required this.studentId,
    required this.userId,
    required this.email,
    required this.temporaryPassword,
  });

  final StudentId studentId;
  final String userId;
  final String email;
  final String temporaryPassword;

  factory StudentAppAccessCredentials.fromEdgeJson(Map<String, dynamic> json) {
    final sid = json['studentId'] as String?;
    final uid = json['userId'] as String?;
    final em = json['email'] as String?;
    final pw = json['temporaryPassword'] as String?;
    if (sid == null || uid == null || em == null || pw == null) {
      throw FormatException('Risposta accesso app incompleta.');
    }
    return StudentAppAccessCredentials(
      studentId: sid,
      userId: uid,
      email: em,
      temporaryPassword: pw,
    );
  }
}
