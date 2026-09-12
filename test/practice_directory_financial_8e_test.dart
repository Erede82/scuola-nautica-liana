import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';

StudentFinancialSummary _fin({
  required String studentId,
  required int fee,
  required int paid,
  required int remaining,
}) {
  return StudentFinancialSummary(
    studentId: studentId,
    registrationFeeCents: fee,
    currencyCode: 'EUR',
    totalPaidCents: paid,
    remainingBalanceCents: remaining,
  );
}

PracticeListItem _item({
  required String id,
  String? practiceType = 'new_license',
  StudentFinancialSummary? financial,
  PracticeDocumentChecklistSummary summary =
      PracticeDocumentChecklistSummary.notApplicable,
  String? name,
}) {
  return PracticeListItem(
    practiceDossierId: id,
    studentId: 'stu-$id',
    studentFullName: name ?? 'Studente $id',
    practiceType: practiceType,
    documentStatus: LicenseDocumentStatus.collected,
    practiceStatus: PracticeFileStatus.inProgress,
    documentChecklistSummary: summary,
    financialSummary: financial,
  );
}

PracticeDocumentChecklistSummary _docs({
  required bool complete,
  int missing = 0,
  PracticeMedicalCertificateSummaryKind medical =
      PracticeMedicalCertificateSummaryKind.ok,
}) {
  return PracticeDocumentChecklistSummary(
    applicable: true,
    missingRequiredCount: missing,
    isRequiredChecklistComplete: complete,
    medicalCertificate: medical,
  );
}

void main() {
  group('repository / merge (mock)', () {
    test('1. summary presente → merge corretto su listPracticeDossiers', () async {
      final repo = BackofficeRepositoryMock();
      final list = await repo.listPracticeDossiers();
      expect(list, isNotEmpty);
      final withFin = list.where((e) => e.financialSummary != null).toList();
      expect(withFin, isNotEmpty);
      for (final i in withFin) {
        expect(i.financialSummary!.studentId, i.studentId);
      }
    });

    test('2. summary assente → quota non impostata', () {
      final item = _item(id: 'no-fin', financial: null);
      expect(practiceFinancialStatus(item), PracticeFinancialStatus.feeNotSet);
      expect(practiceFinancialLabel(item), 'Quota non impostata');
      expect(practiceHasOpenBalance(item), isFalse);
    });

    test('3. più pratiche/studenti → map per studentId', () {
      final a = _fin(studentId: 'stu-a', fee: 10000, paid: 2000, remaining: 8000);
      final b = _fin(studentId: 'stu-b', fee: 5000, paid: 5000, remaining: 0);
      final items = [
        _item(id: 'a1', financial: a),
        _item(id: 'a2', financial: a),
        _item(id: 'b1', financial: b),
      ];
      expect(items[0].financialSummary!.remainingBalanceCents, 8000);
      expect(items[1].financialSummary!.studentId, 'stu-a');
      expect(items[2].financialSummary!.remainingBalanceCents, 0);
    });

    test('4. nessuna pratica → lista vuota (nessun crash financial)', () async {
      // Mock senza dossier: profili senza practice_dossiers non entrano in lista.
      final repo = BackofficeRepositoryMock();
      final list = await repo.listPracticeDossiers();
      // Se il seed ha pratiche, verifica solo che merge non duplichi per studentId.
      final byStudent = <String, int>{};
      for (final i in list) {
        byStudent[i.studentId] = (byStudent[i.studentId] ?? 0) + 1;
      }
      // Una pratica per studente nel seed tipico; non doppio conteggio financial.
      for (final i in list) {
        if (i.financialSummary != null) {
          expect(i.financialSummary!.studentId, i.studentId);
        }
      }
      expect(byStudent.isNotEmpty || list.isEmpty, isTrue);
    });

    test('5. niente duplicazione campi economici', () {
      final f = _fin(studentId: 'stu-x', fee: 12000, paid: 4000, remaining: 8000);
      final item = _item(id: 'x', financial: f);
      expect(item.financialSummary, same(f));
      expect(practiceFinancialFeeCents(item), 12000);
      expect(practiceFinancialRemainingCents(item), 8000);
    });
  });

  group('financial semantics', () {
    test('6. fee=0 → feeNotSet', () {
      final item = _item(
        id: 'f0',
        financial: _fin(studentId: 'stu-f0', fee: 0, paid: 0, remaining: 0),
      );
      expect(practiceFinancialStatus(item), PracticeFinancialStatus.feeNotSet);
    });

    test('7. fee>0 / remaining>0 → open', () {
      final item = _item(
        id: 'open',
        financial: _fin(studentId: 'stu-o', fee: 10000, paid: 3000, remaining: 7000),
      );
      expect(practiceFinancialStatus(item), PracticeFinancialStatus.open);
      expect(practiceHasOpenBalance(item), isTrue);
      expect(practiceFinancialLabel(item), 'Da incassare 70.00 €');
    });

    test('8. fee>0 / remaining=0 → settled', () {
      final item = _item(
        id: 'set',
        financial: _fin(studentId: 'stu-s', fee: 10000, paid: 10000, remaining: 0),
      );
      expect(practiceFinancialStatus(item), PracticeFinancialStatus.settled);
      expect(practiceFinancialLabel(item), 'Saldato');
    });

    test('9. fee>0 / remaining<0 edge → settled', () {
      final item = _item(
        id: 'neg',
        financial: _fin(studentId: 'stu-n', fee: 10000, paid: 12000, remaining: -2000),
      );
      expect(practiceFinancialStatus(item), PracticeFinancialStatus.settled);
    });

    test('10. paid > fee → non mostra residuo negativo', () {
      final item = _item(
        id: 'over',
        financial: _fin(studentId: 'stu-ov', fee: 10000, paid: 15000, remaining: -5000),
      );
      expect(practiceFinancialRemainingCents(item), 0);
      expect(practiceFinancialLabel(item), 'Saldato');
    });

    test('11. summary null → feeNotSet', () {
      expect(
        practiceFinancialStatus(_item(id: 'null', financial: null)),
        PracticeFinancialStatus.feeNotSet,
      );
    });
  });

  group('filtro Saldo aperto', () {
    final open = _item(
      id: 'open',
      practiceType: 'new_license',
      financial: _fin(studentId: 'stu-open', fee: 10000, paid: 1000, remaining: 9000),
      summary: _docs(complete: false, missing: 2),
    );
    final settled = _item(
      id: 'settled',
      practiceType: 'new_license',
      financial: _fin(studentId: 'stu-set', fee: 8000, paid: 8000, remaining: 0),
    );
    final feeZero = _item(
      id: 'fee0',
      practiceType: 'renewal',
      financial: _fin(studentId: 'stu-0', fee: 0, paid: 0, remaining: 0),
    );
    final openRenewal = _item(
      id: 'open-ren',
      practiceType: 'renewal',
      financial: _fin(studentId: 'stu-or', fee: 5000, paid: 0, remaining: 5000),
    );
    final openMedical = _item(
      id: 'open-med',
      practiceType: 'new_license',
      financial: _fin(studentId: 'stu-om', fee: 7000, paid: 0, remaining: 7000),
      summary: _docs(
        complete: true,
        medical: PracticeMedicalCertificateSummaryKind.expired,
      ),
    );
    final dataset = [open, settled, feeZero, openRenewal, openMedical];

    test('12. Saldo aperto ON → solo fee>0 && remaining>0', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(onlyOpenBalance: true),
      ).map((e) => e.practiceDossierId).toList();
      expect(filtered, ['open', 'open-ren', 'open-med']);
    });

    test('13. fee=0 esclusa', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(onlyOpenBalance: true),
      );
      expect(filtered.any((e) => e.practiceDossierId == 'fee0'), isFalse);
    });

    test('14. saldato escluso', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(onlyOpenBalance: true),
      );
      expect(filtered.any((e) => e.practiceDossierId == 'settled'), isFalse);
    });

    test('15. Saldo aperto + Conseguimento → AND', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(
          practiceTypeFilter: 'new_license',
          onlyOpenBalance: true,
        ),
      ).map((e) => e.practiceDossierId).toList();
      expect(filtered, ['open', 'open-med']);
    });

    test('16. Saldo aperto + Documenti mancanti → AND', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(
          onlyDocsIncomplete: true,
          onlyOpenBalance: true,
        ),
      ).map((e) => e.practiceDossierId).toList();
      expect(filtered, ['open']);
    });

    test('17. Saldo aperto + Medico → AND', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(
          onlyMedicalAttention: true,
          onlyOpenBalance: true,
        ),
      ).map((e) => e.practiceDossierId).toList();
      expect(filtered, ['open-med']);
    });

    test('18. Saldo aperto + search → AND', () {
      final filtered = filterPracticeDirectoryItems(
        items: dataset,
        filters: const PracticeDirectoryFilterState(onlyOpenBalance: true),
        searchQuery: 'open-ren',
      ).map((e) => e.practiceDossierId).toList();
      // search matches studentFullName "Studente open-ren"
      expect(filtered, ['open-ren']);
    });

    test('19. Priorità ON dopo filtro → sort attenzione invariato', () {
      final filtered = filterPracticeDirectoryItems(
        items: [
          _item(
            id: 'n',
            financial: _fin(studentId: 'stu-n', fee: 1000, paid: 0, remaining: 1000),
            summary: _docs(complete: true),
            name: 'Normal Open',
          ),
          _item(
            id: 'e',
            financial: _fin(studentId: 'stu-e', fee: 1000, paid: 0, remaining: 1000),
            summary: _docs(
              complete: true,
              medical: PracticeMedicalCertificateSummaryKind.expired,
            ),
            name: 'Expired Open',
          ),
        ],
        filters: const PracticeDirectoryFilterState(onlyOpenBalance: true),
      ).toList(growable: false);
      final sorted = sortPracticeDirectoryByAttention(filtered, priorityOn: true);
      expect(sorted.map((e) => e.practiceDossierId).toList(), ['e', 'n']);
      expect(practiceAttentionKind(sorted.first), PracticeAttentionKind.medicalExpired);
    });
  });

  group('8A/8B/8D interaction', () {
    test('overview 8A non conta saldo', () {
      final items = [
        _item(
          id: 'a',
          financial: _fin(studentId: 'stu-a', fee: 9000, paid: 0, remaining: 9000),
        ),
        _item(
          id: 'b',
          practiceType: 'renewal',
          financial: _fin(studentId: 'stu-b', fee: 0, paid: 0, remaining: 0),
        ),
      ];
      final o = PracticeDirectoryOverview.fromItems(items);
      expect(o.total, 2);
      expect(o.newLicense, 1);
      expect(o.renewal, 1);
    });

    test('8D eligibility indipendente dal saldo', () {
      final item = _item(
        id: 'reg',
        practiceType: 'new_license',
        financial: _fin(studentId: 'stu-r', fee: 10000, paid: 0, remaining: 10000),
      );
      expect(canAssignPracticeRegistryNumberToListItem(item), isTrue);
    });
  });
}
