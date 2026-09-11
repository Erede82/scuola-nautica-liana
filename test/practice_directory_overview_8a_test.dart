import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';

PracticeListItem _item({
  required String id,
  required String? practiceType,
  PracticeDocumentChecklistSummary summary =
      PracticeDocumentChecklistSummary.notApplicable,
  LicenseDocumentStatus documentStatus = LicenseDocumentStatus.collected,
  PracticeFileStatus practiceStatus = PracticeFileStatus.inProgress,
  int? registryNumber,
  String? registryCode,
}) {
  return PracticeListItem(
    practiceDossierId: id,
    studentId: 'stu-$id',
    studentFullName: 'Studente $id',
    practiceType: practiceType,
    documentStatus: documentStatus,
    practiceStatus: practiceStatus,
    documentChecklistSummary: summary,
    registryNumber: registryNumber,
    registryCode: registryCode,
  );
}

PracticeDocumentChecklistSummary _summary({
  required bool complete,
  required PracticeMedicalCertificateSummaryKind medical,
  int missing = 0,
}) {
  return PracticeDocumentChecklistSummary(
    applicable: true,
    missingRequiredCount: missing,
    isRequiredChecklistComplete: complete,
    medicalCertificate: medical,
  );
}

void main() {
  group('PracticeDirectoryOverview', () {
    test('conteggi su dataset controllato', () {
      final items = [
        _item(
          id: 'nl-ok',
          practiceType: 'new_license',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
        ),
        _item(
          id: 'nl-docs',
          practiceType: 'new_license',
          summary: _summary(
            complete: false,
            missing: 2,
            medical: PracticeMedicalCertificateSummaryKind.missing,
          ),
        ),
        _item(
          id: 'ren-exp',
          practiceType: 'renewal',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
        ),
        _item(
          id: 'ren-soon',
          practiceType: 'renewal',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
          ),
        ),
        _item(
          id: 'dup',
          practiceType: 'duplicate',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.notApplicable,
          ),
        ),
        _item(
          id: 'nl-no-expiry',
          practiceType: 'new_license',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
        ),
      ];

      final o = PracticeDirectoryOverview.fromItems(items);
      expect(o.total, 6);
      expect(o.newLicense, 3);
      expect(o.renewal, 2);
      expect(o.duplicate, 1);
      expect(o.docsIncomplete, 1);
      expect(o.medicalAttention, 2, reason: 'expired + expiringSoon');
    });

    test('medical ok e missing NON entrano in Medico', () {
      expect(
        practiceNeedsMedicalAttention(
          _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
        ),
        isFalse,
      );
      expect(
        practiceNeedsMedicalAttention(
          _summary(
            complete: false,
            missing: 1,
            medical: PracticeMedicalCertificateSummaryKind.missing,
          ),
        ),
        isFalse,
      );
      expect(
        practiceNeedsMedicalAttention(
          const PracticeDocumentChecklistSummary(
            applicable: true,
            medicalCertificate: PracticeMedicalCertificateSummaryKind.notApplicable,
          ),
        ),
        isFalse,
      );
      expect(
        practiceNeedsMedicalAttention(
          _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
        ),
        isTrue,
      );
      expect(
        practiceNeedsMedicalAttention(
          _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
          ),
        ),
        isTrue,
      );
    });
  });

  group('PracticeDirectoryFilterState applyDashboard exclusivity', () {
    test('Tutte azzera type/status/quick filters', () {
      final dirty = const PracticeDirectoryFilterState(
        practiceTypeFilter: 'renewal',
        practiceStatusFilter: PracticeFileStatus.submitted,
        onlyWithoutRegistry: true,
        onlyDocsIncomplete: true,
        onlyMedicalAttention: true,
      );
      final next = dirty.applyDashboard(PracticeDirectoryDashboardCard.all);
      expect(next.practiceTypeFilter, isNull);
      expect(next.practiceStatusFilter, isNull);
      expect(next.onlyWithoutRegistry, isFalse);
      expect(next.onlyDocsIncomplete, isFalse);
      expect(next.onlyMedicalAttention, isFalse);
      expect(next.activeDashboardCard, PracticeDirectoryDashboardCard.all);
    });

    test('Conseguimento / Rinnovo / Duplicato disattivano quick filter', () {
      for (final entry in [
        (PracticeDirectoryDashboardCard.newLicense, 'new_license'),
        (PracticeDirectoryDashboardCard.renewal, 'renewal'),
        (PracticeDirectoryDashboardCard.duplicate, 'duplicate'),
      ]) {
        final next = const PracticeDirectoryFilterState(
          onlyDocsIncomplete: true,
          onlyMedicalAttention: true,
          onlyWithoutRegistry: true,
        ).applyDashboard(entry.$1);
        expect(next.practiceTypeFilter, entry.$2);
        expect(next.onlyDocsIncomplete, isFalse);
        expect(next.onlyMedicalAttention, isFalse);
        expect(next.onlyWithoutRegistry, isFalse);
        expect(next.activeDashboardCard, entry.$1);
      }
    });

    test('Documenti mancanti azzera type e medico', () {
      final next = const PracticeDirectoryFilterState(
        practiceTypeFilter: 'new_license',
        onlyMedicalAttention: true,
      ).applyDashboard(PracticeDirectoryDashboardCard.docsIncomplete);
      expect(next.onlyDocsIncomplete, isTrue);
      expect(next.practiceTypeFilter, isNull);
      expect(next.onlyMedicalAttention, isFalse);
      expect(
        next.activeDashboardCard,
        PracticeDirectoryDashboardCard.docsIncomplete,
      );
    });

    test('Medico azzera type e documenti', () {
      final next = const PracticeDirectoryFilterState(
        practiceTypeFilter: 'renewal',
        onlyDocsIncomplete: true,
      ).applyDashboard(PracticeDirectoryDashboardCard.medicalAttention);
      expect(next.onlyMedicalAttention, isTrue);
      expect(next.practiceTypeFilter, isNull);
      expect(next.onlyDocsIncomplete, isFalse);
      expect(
        next.activeDashboardCard,
        PracticeDirectoryDashboardCard.medicalAttention,
      );
    });
  });

  group('filterPracticeDirectoryItems', () {
    late List<PracticeListItem> items;

    setUp(() {
      items = [
        _item(
          id: 'nl',
          practiceType: 'new_license',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
          registryNumber: 1,
          registryCode: '2026/1',
        ),
        _item(
          id: 'ren',
          practiceType: 'renewal',
          summary: _summary(
            complete: false,
            missing: 1,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
        ),
        _item(
          id: 'dup',
          practiceType: 'duplicate',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
          ),
        ),
        _item(
          id: 'ok-soon-not',
          practiceType: 'new_license',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
        ),
      ];
    });

    test('Tutte → lista completa', () {
      final filtered = filterPracticeDirectoryItems(
        items: items,
        filters: const PracticeDirectoryFilterState(),
      ).toList();
      expect(filtered, hasLength(4));
    });

    test('Conseguimento → solo new_license', () {
      final filtered = filterPracticeDirectoryItems(
        items: items,
        filters: const PracticeDirectoryFilterState().applyDashboard(
          PracticeDirectoryDashboardCard.newLicense,
        ),
      ).toList();
      expect(filtered.every((i) => i.practiceType == 'new_license'), isTrue);
      expect(filtered, hasLength(2));
    });

    test('Rinnovo → solo renewal', () {
      final filtered = filterPracticeDirectoryItems(
        items: items,
        filters: const PracticeDirectoryFilterState().applyDashboard(
          PracticeDirectoryDashboardCard.renewal,
        ),
      ).toList();
      expect(filtered, hasLength(1));
      expect(filtered.single.practiceType, 'renewal');
    });

    test('Duplicato → solo duplicate', () {
      final filtered = filterPracticeDirectoryItems(
        items: items,
        filters: const PracticeDirectoryFilterState().applyDashboard(
          PracticeDirectoryDashboardCard.duplicate,
        ),
      ).toList();
      expect(filtered, hasLength(1));
      expect(filtered.single.practiceType, 'duplicate');
    });

    test('Documenti mancanti → solo incomplete', () {
      final filtered = filterPracticeDirectoryItems(
        items: items,
        filters: const PracticeDirectoryFilterState().applyDashboard(
          PracticeDirectoryDashboardCard.docsIncomplete,
        ),
      ).toList();
      expect(filtered, hasLength(1));
      expect(filtered.single.isDocumentIncompleteForFilter, isTrue);
    });

    test('Medico → expired + expiringSoon', () {
      final filtered = filterPracticeDirectoryItems(
        items: items,
        filters: const PracticeDirectoryFilterState().applyDashboard(
          PracticeDirectoryDashboardCard.medicalAttention,
        ),
      ).toList();
      expect(filtered, hasLength(2));
      expect(
        filtered.every(
          (i) => practiceNeedsMedicalAttention(i.documentChecklistSummary),
        ),
        isTrue,
      );
      expect(
        filtered.any(
          (i) =>
              i.documentChecklistSummary.medicalCertificate ==
              PracticeMedicalCertificateSummaryKind.ok,
        ),
        isFalse,
      );
    });
  });
}
