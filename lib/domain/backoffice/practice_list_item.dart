import 'backoffice_enums.dart';
import 'ids.dart';

/// Riga directory pratiche (lettura-only): fascicolo + identificazione minima allievo.
class PracticeListItem {
  const PracticeListItem({
    required this.practiceDossierId,
    required this.studentId,
    required this.studentFullName,
    this.studentEmail,
    this.studentPhone,
    this.practiceType,
    this.registrationDate,
    this.registryYear,
    this.registryNumber,
    this.registryCode,
    this.practiceNumber,
    required this.documentStatus,
    required this.practiceStatus,
  });

  final PracticeDossierId practiceDossierId;
  final StudentId studentId;
  final String studentFullName;
  final String? studentEmail;
  final String? studentPhone;

  /// DB: `new_license` | `renewal` | `duplicate`.
  final String? practiceType;
  final DateTime? registrationDate;
  final int? registryYear;
  final int? registryNumber;
  final String? registryCode;
  final String? practiceNumber;

  final LicenseDocumentStatus documentStatus;
  final PracticeFileStatus practiceStatus;

  bool get hasRegistryNumberAssigned =>
      registryNumber != null &&
      registryCode != null &&
      registryCode!.trim().isNotEmpty;

  /// Per filtro rapido: fascicolo documentale non avviato, oppure pratica in attesa documenti.
  ///
  /// `collected` nel dominio è la fase successiva a [LicenseDocumentStatus.notStarted]
  /// (“Raccolta documenti” in UI) e non va trattata come “da completare”.
  bool get isDocumentFlowIncomplete =>
      documentStatus == LicenseDocumentStatus.notStarted ||
      practiceStatus == PracticeFileStatus.waitingDocuments;
}
