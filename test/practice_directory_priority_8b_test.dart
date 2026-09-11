import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';

PracticeListItem _item({
  required String id,
  String? practiceType = 'new_license',
  PracticeDocumentChecklistSummary summary =
      PracticeDocumentChecklistSummary.notApplicable,
  LicenseDocumentStatus documentStatus = LicenseDocumentStatus.collected,
  PracticeFileStatus practiceStatus = PracticeFileStatus.inProgress,
  DateTime? registrationDate,
}) {
  return PracticeListItem(
    practiceDossierId: id,
    studentId: 'stu-$id',
    studentFullName: 'Studente $id',
    practiceType: practiceType,
    registrationDate: registrationDate,
    documentStatus: documentStatus,
    practiceStatus: practiceStatus,
    documentChecklistSummary: summary,
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
  group('practiceAttention classification', () {
    test('1. expired → critical / medicalExpired', () {
      final item = _item(
        id: 'exp',
        summary: _summary(
          complete: true,
          medical: PracticeMedicalCertificateSummaryKind.expired,
        ),
      );
      expect(practiceAttentionLevel(item), PracticeAttentionLevel.critical);
      expect(practiceAttentionKind(item), PracticeAttentionKind.medicalExpired);
      expect(practiceAttentionLabel(item), 'Medico scaduto');
    });

    test('2. docs incomplete + medical ok → critical / docsIncomplete', () {
      final item = _item(
        id: 'docs',
        summary: _summary(
          complete: false,
          missing: 2,
          medical: PracticeMedicalCertificateSummaryKind.ok,
        ),
      );
      expect(practiceAttentionLevel(item), PracticeAttentionLevel.critical);
      expect(practiceAttentionKind(item), PracticeAttentionKind.docsIncomplete);
      expect(practiceAttentionLabel(item), isNull);
    });

    test('3. expiringSoon + checklist completa → warning', () {
      final item = _item(
        id: 'soon',
        summary: _summary(
          complete: true,
          medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
        ),
      );
      expect(practiceAttentionLevel(item), PracticeAttentionLevel.warning);
      expect(
        practiceAttentionKind(item),
        PracticeAttentionKind.medicalExpiringSoon,
      );
      expect(practiceAttentionLabel(item), 'Medico in scadenza');
    });

    test('4. medical ok → normal', () {
      final item = _item(
        id: 'ok',
        summary: _summary(
          complete: true,
          medical: PracticeMedicalCertificateSummaryKind.ok,
        ),
      );
      expect(practiceAttentionLevel(item), PracticeAttentionLevel.normal);
      expect(practiceAttentionKind(item), PracticeAttentionKind.none);
      expect(practiceAttentionLabel(item), isNull);
    });

    test('5. notApplicable → normal', () {
      final item = _item(
        id: 'na',
        summary: PracticeDocumentChecklistSummary.notApplicable,
      );
      expect(practiceAttentionLevel(item), PracticeAttentionLevel.normal);
      expect(practiceAttentionKind(item), PracticeAttentionKind.none);
    });

    test('10. expired + docs incomplete → solo Medico scaduto', () {
      final item = _item(
        id: 'both',
        summary: _summary(
          complete: false,
          missing: 3,
          medical: PracticeMedicalCertificateSummaryKind.expired,
        ),
      );
      expect(practiceAttentionKind(item), PracticeAttentionKind.medicalExpired);
      expect(practiceAttentionLevel(item), PracticeAttentionLevel.critical);
      expect(practiceAttentionLabel(item), 'Medico scaduto');
    });
  });

  group('comparePracticeAttention ranks', () {
    final expired = _item(
      id: 'e',
      summary: _summary(
        complete: true,
        medical: PracticeMedicalCertificateSummaryKind.expired,
      ),
      registrationDate: DateTime(2024, 1, 1),
    );
    final docsOnly = _item(
      id: 'd',
      summary: _summary(
        complete: false,
        missing: 1,
        medical: PracticeMedicalCertificateSummaryKind.ok,
      ),
      registrationDate: DateTime(2024, 1, 1),
    );
    final soon = _item(
      id: 's',
      summary: _summary(
        complete: true,
        medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
      ),
      registrationDate: DateTime(2024, 1, 1),
    );
    final normal = _item(
      id: 'n',
      summary: _summary(
        complete: true,
        medical: PracticeMedicalCertificateSummaryKind.ok,
      ),
      registrationDate: DateTime(2024, 1, 1),
    );

    test('6. expired > docs-only', () {
      expect(comparePracticeAttention(expired, docsOnly), lessThan(0));
    });

    test('7. docs-only > expiringSoon', () {
      expect(comparePracticeAttention(docsOnly, soon), lessThan(0));
    });

    test('8. expiringSoon > normal', () {
      expect(comparePracticeAttention(soon, normal), lessThan(0));
    });

    test('9. stessa priority: registration_date più recente prima', () {
      final older = _item(
        id: 'old',
        summary: _summary(
          complete: true,
          medical: PracticeMedicalCertificateSummaryKind.expired,
        ),
        registrationDate: DateTime(2023, 6, 1),
      );
      final newer = _item(
        id: 'new',
        summary: _summary(
          complete: true,
          medical: PracticeMedicalCertificateSummaryKind.expired,
        ),
        registrationDate: DateTime(2025, 6, 1),
      );
      expect(comparePracticeAttention(newer, older), lessThan(0));
    });
  });

  group('sortPracticeDirectoryByAttention', () {
    test('12. Priorità OFF: ordine input preservato', () {
      final items = [
        _item(
          id: 'normal',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
        ),
        _item(
          id: 'expired',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
        ),
        _item(
          id: 'soon',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
          ),
        ),
      ];
      final sorted = sortPracticeDirectoryByAttention(
        items,
        priorityOn: false,
      );
      expect(sorted.map((e) => e.practiceDossierId).toList(), [
        'normal',
        'expired',
        'soon',
      ]);
      expect(identical(sorted, items), isTrue);
    });

    test('ON: expired → docs → soon → normal + date DESC', () {
      final items = [
        _item(
          id: 'normal-new',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
          registrationDate: DateTime(2025, 1, 1),
        ),
        _item(
          id: 'soon',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
          ),
          registrationDate: DateTime(2024, 6, 1),
        ),
        _item(
          id: 'docs',
          summary: _summary(
            complete: false,
            missing: 1,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
          registrationDate: DateTime(2024, 1, 1),
        ),
        _item(
          id: 'exp-old',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
          registrationDate: DateTime(2023, 1, 1),
        ),
        _item(
          id: 'exp-new',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
          registrationDate: DateTime(2025, 6, 1),
        ),
      ];
      final sorted = sortPracticeDirectoryByAttention(items, priorityOn: true);
      expect(sorted.map((e) => e.practiceDossierId).toList(), [
        'exp-new',
        'exp-old',
        'docs',
        'soon',
        'normal-new',
      ]);
    });

    test('11. overview counts identici prima/dopo ordinamento', () {
      final items = [
        _item(
          id: 'a',
          practiceType: 'new_license',
          summary: _summary(
            complete: false,
            missing: 1,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
        ),
        _item(
          id: 'b',
          practiceType: 'renewal',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
        ),
        _item(
          id: 'c',
          practiceType: 'duplicate',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
          ),
        ),
      ];
      final before = PracticeDirectoryOverview.fromItems(items);
      final sorted = sortPracticeDirectoryByAttention(items, priorityOn: true);
      final after = PracticeDirectoryOverview.fromItems(sorted);
      expect(after.total, before.total);
      expect(after.newLicense, before.newLicense);
      expect(after.renewal, before.renewal);
      expect(after.duplicate, before.duplicate);
      expect(after.docsIncomplete, before.docsIncomplete);
      expect(after.medicalAttention, before.medicalAttention);
    });
  });

  group('filter then priority', () {
    final dataset = [
      _item(
        id: 'nl-ok',
        practiceType: 'new_license',
        summary: _summary(
          complete: true,
          medical: PracticeMedicalCertificateSummaryKind.ok,
        ),
        registrationDate: DateTime(2025, 1, 1),
      ),
      _item(
        id: 'nl-docs',
        practiceType: 'new_license',
        summary: _summary(
          complete: false,
          missing: 2,
          medical: PracticeMedicalCertificateSummaryKind.ok,
        ),
        registrationDate: DateTime(2024, 1, 1),
      ),
      _item(
        id: 'ren-exp',
        practiceType: 'renewal',
        summary: _summary(
          complete: true,
          medical: PracticeMedicalCertificateSummaryKind.expired,
        ),
        registrationDate: DateTime(2023, 1, 1),
      ),
      _item(
        id: 'ren-soon',
        practiceType: 'renewal',
        summary: _summary(
          complete: true,
          medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
        ),
        registrationDate: DateTime(2024, 6, 1),
      ),
      _item(
        id: 'nl-exp-docs',
        practiceType: 'new_license',
        summary: _summary(
          complete: false,
          missing: 1,
          medical: PracticeMedicalCertificateSummaryKind.expired,
        ),
        registrationDate: DateTime(2022, 1, 1),
      ),
    ];

    test('Medico + Priorità: expired prima di soon', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(
          onlyMedicalAttention: true,
        ),
      ).toList(growable: false);
      final sorted = sortPracticeDirectoryByAttention(
        filtered,
        priorityOn: true,
      );
      expect(sorted.map((e) => e.practiceDossierId).toList(), [
        'ren-exp',
        'nl-exp-docs',
        'ren-soon',
      ]);
    });

    test('Documenti mancanti + Priorità: expired prima degli altri incomplete', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(
          onlyDocsIncomplete: true,
        ),
      ).toList(growable: false);
      final sorted = sortPracticeDirectoryByAttention(
        filtered,
        priorityOn: true,
      );
      expect(sorted.map((e) => e.practiceDossierId).toList(), [
        'nl-exp-docs',
        'nl-docs',
      ]);
    });

    test('Conseguimento + Priorità: solo new_license ordinati per attenzione', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(
          practiceTypeFilter: 'new_license',
        ),
      ).toList(growable: false);
      final sorted = sortPracticeDirectoryByAttention(
        filtered,
        priorityOn: true,
      );
      expect(sorted.map((e) => e.practiceDossierId).toList(), [
        'nl-exp-docs',
        'nl-docs',
        'nl-ok',
      ]);
    });
  });
}
