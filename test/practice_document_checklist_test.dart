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

    test('newer valid medical certificate wins over an older expired one', () {
      final documents = [
        StudentDocument(
          id: 'doc-med-old',
          studentId: 'stu-1',
          documentType: 'medicalCertificate',
          title: 'Medico scaduto',
          status: 'expired',
          expiresAt: DateTime(2026, 4, 1),
          createdAt: DateTime(2026, 1, 10),
        ),
        StudentDocument(
          id: 'doc-med-new',
          studentId: 'stu-1',
          documentType: 'medicalCertificate',
          title: 'Medico rinnovato',
          status: 'uploaded',
          expiresAt: DateTime(2027, 3, 1),
          createdAt: DateTime(2026, 5, 2),
        ),
      ];

      final checklist = evaluatePracticeDocumentChecklist(
        practiceType: practiceType,
        documents: documents,
        photos: const [],
        now: reference,
      );

      final medical = checklist.items.firstWhere(
        (i) =>
            i.requirement.id == PracticeDocumentRequirementId.medicalCertificate,
      );
      expect(medical.status, PracticeDocumentChecklistItemStatus.present);
      expect(medical.matchedDocument?.id, 'doc-med-new');
      expect(medical.countsAsMissingRequired, isFalse);
      expect(checklist.missingRequiredCount, 4);
    });

    test('long-valid medical certificate beats an earlier expiring one', () {
      final documents = [
        StudentDocument(
          id: 'doc-med-soon',
          studentId: 'stu-1',
          documentType: 'medicalCertificate',
          title: 'Medico in scadenza',
          status: 'uploaded',
          expiresAt: DateTime(2026, 6, 10),
          createdAt: DateTime(2025, 6, 10),
        ),
        StudentDocument(
          id: 'doc-med-long',
          studentId: 'stu-1',
          documentType: 'medicalCertificate',
          title: 'Medico lungo',
          status: 'uploaded',
          expiresAt: DateTime(2027, 8, 1),
          createdAt: DateTime(2026, 5, 20),
        ),
      ];

      final checklist = evaluatePracticeDocumentChecklist(
        practiceType: practiceType,
        documents: documents,
        photos: const [],
        now: reference,
      );
      final summary = PracticeDocumentChecklistSummary.fromChecklist(checklist);

      final medical = checklist.items.firstWhere(
        (i) =>
            i.requirement.id == PracticeDocumentRequirementId.medicalCertificate,
      );
      expect(medical.status, PracticeDocumentChecklistItemStatus.present);
      expect(medical.matchedDocument?.id, 'doc-med-long');
      expect(
        summary.medicalCertificate,
        PracticeMedicalCertificateSummaryKind.ok,
      );
    });

    test('expired medical stays expired when every copy is expired', () {
      final documents = [
        StudentDocument(
          id: 'doc-med-older',
          studentId: 'stu-1',
          documentType: 'medicalCertificate',
          title: 'Medico 2024',
          status: 'expired',
          expiresAt: DateTime(2025, 1, 1),
          createdAt: DateTime(2024, 6, 1),
        ),
        StudentDocument(
          id: 'doc-med-newer',
          studentId: 'stu-1',
          documentType: 'medicalCertificate',
          title: 'Medico 2025',
          status: 'expired',
          expiresAt: DateTime(2026, 4, 1),
          createdAt: DateTime(2025, 6, 1),
        ),
      ];

      final checklist = evaluatePracticeDocumentChecklist(
        practiceType: practiceType,
        documents: documents,
        photos: const [],
        now: reference,
      );

      final medical = checklist.items.firstWhere(
        (i) =>
            i.requirement.id == PracticeDocumentRequirementId.medicalCertificate,
      );
      expect(medical.status, PracticeDocumentChecklistItemStatus.expired);
      expect(medical.matchedDocument?.id, 'doc-med-newer');
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
