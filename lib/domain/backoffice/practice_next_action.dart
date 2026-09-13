import 'accounting.dart';
import 'practice_document_requirements.dart';
import 'practice_directory_overview.dart';
import 'practice_registry.dart';
import 'student_admin_aggregate.dart';

/// Tipi di «Prossima azione» Scheda 360 (PRATICHE.8G) — first-match frozen.
enum PracticeNextActionKind {
  medicalExpired,
  documentsIncomplete,
  registryMissing,
  feeNotSet,
  medicalExpiringSoon,
  openBalance,
  none,
}

/// Azione derivata read-only per header Scheda 360.
class PracticeNextAction {
  const PracticeNextAction({
    required this.kind,
    required this.label,
    this.optionalCount,
    this.targetTabIndex,
  });

  final PracticeNextActionKind kind;
  final String label;

  /// Es. documenti mancanti (N); null se non applicabile.
  final int? optionalCount;

  /// Indice tab Scheda 360 (null = non cliccabile).
  final int? targetTabIndex;

  bool get isClickable => targetTabIndex != null;
}

/// Tab Scheda 360 (allineati a [Student360DetailView]).
const int kPracticeNextActionTabScheda = 0;
const int kPracticeNextActionTabDocumenti = 1;
const int kPracticeNextActionTabContabilita = 5;

/// Semantica finanziaria 8E su summary 360 (fee/remaining in centesimi).
PracticeFinancialStatus practiceFinancialStatusFromSummary(
  StudentFinancialSummary summary,
) {
  final fee = summary.registrationFeeCents;
  if (fee == 0) return PracticeFinancialStatus.feeNotSet;
  if (summary.remainingBalanceCents <= 0) {
    return PracticeFinancialStatus.settled;
  }
  return PracticeFinancialStatus.open;
}

/// Risoluzione pura dalla checklist già valutata + registry + financial.
///
/// Gerarchia first-match FROZEN (PRATICHE.8G §1).
PracticeNextAction resolvePracticeNextAction({
  required PracticeDocumentChecklistSummary docs,
  required bool registryAssignable,
  required PracticeFinancialStatus financial,
}) {
  if (docs.applicable &&
      docs.medicalCertificate == PracticeMedicalCertificateSummaryKind.expired) {
    return const PracticeNextAction(
      kind: PracticeNextActionKind.medicalExpired,
      label: 'Rinnova certificato medico',
      targetTabIndex: kPracticeNextActionTabDocumenti,
    );
  }

  if (docs.applicable && docs.missingRequiredCount > 0) {
    final n = docs.missingRequiredCount;
    return PracticeNextAction(
      kind: PracticeNextActionKind.documentsIncomplete,
      label: 'Completa documenti ($n)',
      optionalCount: n,
      targetTabIndex: kPracticeNextActionTabDocumenti,
    );
  }

  if (registryAssignable) {
    return const PracticeNextAction(
      kind: PracticeNextActionKind.registryMissing,
      label: 'Assegna numero registro',
      targetTabIndex: kPracticeNextActionTabScheda,
    );
  }

  if (financial == PracticeFinancialStatus.feeNotSet) {
    return const PracticeNextAction(
      kind: PracticeNextActionKind.feeNotSet,
      label: 'Imposta quota',
      targetTabIndex: kPracticeNextActionTabContabilita,
    );
  }

  if (docs.applicable &&
      docs.medicalCertificate ==
          PracticeMedicalCertificateSummaryKind.expiringSoon) {
    return const PracticeNextAction(
      kind: PracticeNextActionKind.medicalExpiringSoon,
      label: 'Certificato medico in scadenza',
      targetTabIndex: kPracticeNextActionTabDocumenti,
    );
  }

  if (financial == PracticeFinancialStatus.open) {
    return const PracticeNextAction(
      kind: PracticeNextActionKind.openBalance,
      label: 'Saldo da incassare',
      targetTabIndex: kPracticeNextActionTabContabilita,
    );
  }

  return const PracticeNextAction(
    kind: PracticeNextActionKind.none,
    label: 'Nessuna azione urgente',
  );
}

/// Deriva la prossima azione da [StudentAdmin360View] (nessun fetch).
PracticeNextAction derivePracticeNextActionFromView(
  StudentAdmin360View view, {
  DateTime? now,
}) {
  final dossier = view.practiceDossier;
  final checklist = evaluatePracticeDocumentChecklist(
    practiceType: dossier?.practiceType,
    documents: view.documents,
    photos: view.photos,
    waivers: view.documentWaivers,
    now: now,
  );
  final docs = PracticeDocumentChecklistSummary.fromChecklist(checklist);
  return resolvePracticeNextAction(
    docs: docs,
    registryAssignable: canAssignPracticeRegistryNumberToDossier(dossier),
    financial: practiceFinancialStatusFromSummary(view.financialSummary),
  );
}
