import '../../domain/backoffice/backoffice.dart';
import '../../models/license_models.dart';

/// Valore colonna `license_category` (allineato a CHECK SQL e a [LicenseCategoryId.name]).
String licenseCategoryColumn(LicenseCategoryId id) => id.name;

/// Data-only `YYYY-MM-DD` per colonne `date` Postgres.
String? dateOnlyIso(DateTime? d) {
  if (d == null) return null;
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String practiceDocumentWaiverActivityDescription({
  required String requirementLabel,
  String? note,
}) {
  final trimmedNote = note?.trim();
  if (trimmedNote == null || trimmedNote.isEmpty) {
    return requirementLabel;
  }
  return '$requirementLabel · Nota: $trimmedNote';
}

bool isActivityEventTypePersisted(BackofficeActivityType type) {
  switch (type) {
    case BackofficeActivityType.studentRegisteredFromApp:
    case BackofficeActivityType.backofficeStudentCreated:
      return false;
    case BackofficeActivityType.paymentAdded:
    case BackofficeActivityType.guidanceAppointmentAdded:
    case BackofficeActivityType.examResultRecorded:
    case BackofficeActivityType.internalNoteAdded:
    case BackofficeActivityType.practiceDossierUpdated:
    case BackofficeActivityType.studyAccessChanged:
    case BackofficeActivityType.profileInternalNoteUpdated:
    case BackofficeActivityType.onboardingStatusChanged:
      return true;
  }
}
