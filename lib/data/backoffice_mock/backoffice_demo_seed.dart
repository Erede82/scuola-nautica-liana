import '../../domain/backoffice/backoffice.dart';

/// Snapshot clonabile del seed statico [SchoolBackofficeDemoData] per uso in store mutabile.
class BackofficeDemoSeed {
  const BackofficeDemoSeed({
    required this.profiles,
    required this.progressBundles,
    required this.appointments,
    required this.exams,
    required this.payments,
    required this.financial,
    required this.practice,
    this.documents = const [],
    this.photos = const [],
  });

  final List<StudentProfile> profiles;
  final List<StudentStudyProgressBundle> progressBundles;
  final List<GuidanceAppointment> appointments;
  final List<ExamAttempt> exams;
  final List<PaymentReceived> payments;
  final Map<StudentId, StudentFinancialSummary> financial;
  final Map<StudentId, PracticeLicenseDossier?> practice;
  final List<StudentDocument> documents;
  final List<StudentPhoto> photos;
}
