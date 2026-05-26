import 'package:flutter/foundation.dart';

import '../domain/course_taxonomy.dart';
import '../models/student_session.dart';
import '../repositories/study_access_repository.dart';

/// Percorso di iscrizione **demo** lato app studente (in attesa di backend reale).
///
/// Dopo registrazione ([studentSession]) viene allineato al profilo reale.
/// Influenza filtri UI ([CategorySelectionPage]) e profilo account.
final ValueNotifier<EnrollmentCoursePath> demoStudentEnrollmentPath =
    ValueNotifier<EnrollmentCoursePath>(EnrollmentCoursePath.entro12Miglia);

/// Sessione locale dopo registrazione / login (mock). Con Supabase: JWT + profilo remoto.
final ValueNotifier<StudentSession?> studentSession =
    ValueNotifier<StudentSession?>(null);

/// Allinea notifiers app dopo login/registrazione (mock o Supabase).
void applyStudentSession(StudentSession session) {
  studentSession.value = session;
  demoStudentEnrollmentPath.value = session.enrolledCoursePath;
}

/// Reset sessione e percorso demo (logout).
void clearStudentSession() {
  studentSession.value = null;
  demoStudentEnrollmentPath.value = EnrollmentCoursePath.entro12Miglia;
  studyAccessWritableRepository.resetDemoAssignments();
}
