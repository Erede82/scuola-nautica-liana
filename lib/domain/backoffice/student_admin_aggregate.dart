import 'accounting.dart';
import 'activity_log.dart';
import 'exam_records.dart';
import 'guidance_appointment.dart';
import 'practice_document.dart';
import 'staff_internal_note.dart';
import 'student_profile.dart';
import 'student_study_progress.dart';

/// DTO aggregato per la scheda completa studente nel pannello scuola.
///
/// **Uso:** risposta API GraphQL/REST o snapshot offline admin; non caricare nell’app allievo intero.
/// **Supabase:** costruito con più query o vista materializzata `student_360`.
class StudentAdmin360View {
  const StudentAdmin360View({
    required this.profile,
    required this.studyProgress,
    required this.appointments,
    required this.examSummary,
    required this.financialSummary,
    required this.payments,
    this.practiceDossier,
    this.documents = const [],
    this.photos = const [],
    this.staffNotes = const [],
    this.activityLog = const [],
  });

  final StudentProfile profile;
  final StudentStudyProgressBundle studyProgress;
  final List<GuidanceAppointment> appointments;
  final StudentExamSummary examSummary;
  final StudentFinancialSummary financialSummary;
  final List<PaymentReceived> payments;
  final PracticeLicenseDossier? practiceDossier;
  final List<StudentDocument> documents;
  final List<StudentPhoto> photos;

  /// Note interne strutturate staff (storico; ordinate desc in DTO).
  final List<StaffInternalNote> staffNotes;

  /// Audit leggero azioni backoffice su questo studente.
  final List<BackofficeActivityEvent> activityLog;
}
