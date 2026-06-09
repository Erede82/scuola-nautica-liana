import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';

void main() {
  group('evaluatePracticeDocumentChecklist waivers', () {
    const practiceType = 'new_license';
    final reference = DateTime(2026, 5, 31);

    test('required missing without waiver counts as missing', () {
      final checklist = evaluatePracticeDocumentChecklist(
        practiceType: practiceType,
        documents: const [],
        photos: const [],
        now: reference,
      );

      final practiceForm = checklist.items.firstWhere(
        (i) => i.requirement.id == PracticeDocumentRequirementId.practiceForm,
      );
      expect(practiceForm.status, PracticeDocumentChecklistItemStatus.missing);
      expect(checklist.missingRequiredCount, 5);
      expect(checklist.isRequiredChecklistComplete, isFalse);
    });

    test('required missing with waiver becomes notRequired', () {
      const waiver = PracticeDocumentWaiver(
        id: 'w1',
        practiceDossierId: 'prac-1',
        requirementId: PracticeDocumentRequirementId.practiceForm,
      );

      final checklist = evaluatePracticeDocumentChecklist(
        practiceType: practiceType,
        documents: const [],
        photos: const [],
        waivers: const [waiver],
        now: reference,
      );

      final practiceForm = checklist.items.firstWhere(
        (i) => i.requirement.id == PracticeDocumentRequirementId.practiceForm,
      );
      expect(
        practiceForm.status,
        PracticeDocumentChecklistItemStatus.notRequired,
      );
      expect(practiceForm.countsAsMissingRequired, isFalse);
      expect(checklist.missingRequiredCount, 4);
      expect(checklist.notRequiredCount, 1);
      expect(checklist.isRequiredChecklistComplete, isFalse);
    });

    test('present file wins over waiver', () {
      const waiver = PracticeDocumentWaiver(
        id: 'w2',
        practiceDossierId: 'prac-1',
        requirementId: PracticeDocumentRequirementId.fiscalCode,
      );
      final documents = [
        StudentDocument(
          id: 'doc-cf',
          studentId: 'stu-1',
          documentType: 'taxCode',
          title: 'CF',
          status: 'uploaded',
        ),
      ];

      final checklist = evaluatePracticeDocumentChecklist(
        practiceType: practiceType,
        documents: documents,
        photos: const [],
        waivers: const [waiver],
        now: reference,
      );

      final fiscal = checklist.items.firstWhere(
        (i) => i.requirement.id == PracticeDocumentRequirementId.fiscalCode,
      );
      expect(fiscal.status, PracticeDocumentChecklistItemStatus.present);
      expect(fiscal.matchedWaiver, isNull);
    });

    test('expired medical certificate is not turned into notRequired', () {
      const waiver = PracticeDocumentWaiver(
        id: 'w3',
        practiceDossierId: 'prac-1',
        requirementId: PracticeDocumentRequirementId.medicalCertificate,
      );
      final documents = [
        StudentDocument(
          id: 'doc-med',
          studentId: 'stu-1',
          documentType: 'medicalCertificate',
          title: 'Medico',
          status: 'expired',
          expiresAt: DateTime(2026, 4, 1),
        ),
      ];

      final checklist = evaluatePracticeDocumentChecklist(
        practiceType: practiceType,
        documents: documents,
        photos: const [],
        waivers: const [waiver],
        now: reference,
      );

      final medical = checklist.items.firstWhere(
        (i) =>
            i.requirement.id == PracticeDocumentRequirementId.medicalCertificate,
      );
      expect(medical.status, PracticeDocumentChecklistItemStatus.expired);
      expect(medical.countsAsMissingRequired, isTrue);
    });

    test('summary excludes waived items from missingRequiredCount', () {
      const waiver = PracticeDocumentWaiver(
        id: 'w4',
        practiceDossierId: 'prac-1',
        requirementId: PracticeDocumentRequirementId.licensePhoto,
      );

      final checklist = evaluatePracticeDocumentChecklist(
        practiceType: practiceType,
        documents: const [],
        photos: const [],
        waivers: const [waiver],
        now: reference,
      );
      final summary = PracticeDocumentChecklistSummary.fromChecklist(checklist);

      expect(summary.notRequiredCount, 1);
      expect(summary.missingRequiredCount, 4);
    });
  });
}
