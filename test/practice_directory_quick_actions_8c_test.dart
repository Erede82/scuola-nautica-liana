import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/student_360_detail_view.dart';

PracticeListItem _item({
  required String id,
  String? phone,
  String? email,
  String? practiceType = 'new_license',
  PracticeDocumentChecklistSummary summary =
      PracticeDocumentChecklistSummary.notApplicable,
  DateTime? registrationDate,
}) {
  return PracticeListItem(
    practiceDossierId: id,
    studentId: 'stu-$id',
    studentFullName: 'Studente $id',
    studentPhone: phone,
    studentEmail: email,
    practiceType: practiceType,
    registrationDate: registrationDate,
    documentStatus: LicenseDocumentStatus.collected,
    practiceStatus: PracticeFileStatus.inProgress,
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
  group('availablePracticeQuickActions', () {
    test('1. phone + email → Scheda, Documenti, Chiama, Email', () {
      final item = _item(
        id: 'both',
        phone: '+393331112233',
        email: 'a@example.com',
      );
      expect(
        availablePracticeQuickActions(item),
        [
          PracticeQuickAction.openOverview,
          PracticeQuickAction.openDocuments,
          PracticeQuickAction.call,
          PracticeQuickAction.email,
        ],
      );
    });

    test('2. phone presente / email assente → no Email', () {
      final item = _item(id: 'p', phone: '3331112233', email: null);
      expect(
        availablePracticeQuickActions(item),
        [
          PracticeQuickAction.openOverview,
          PracticeQuickAction.openDocuments,
          PracticeQuickAction.call,
        ],
      );
    });

    test('3. email presente / phone assente → no Chiama', () {
      final item = _item(id: 'e', phone: null, email: 'b@example.com');
      expect(
        availablePracticeQuickActions(item),
        [
          PracticeQuickAction.openOverview,
          PracticeQuickAction.openDocuments,
          PracticeQuickAction.email,
        ],
      );
    });

    test('4. phone/email assenti → solo Scheda + Documenti', () {
      final item = _item(id: 'none', phone: null, email: null);
      expect(
        availablePracticeQuickActions(item),
        [
          PracticeQuickAction.openOverview,
          PracticeQuickAction.openDocuments,
        ],
      );
    });

    test('5. trim: "   " considerato assente', () {
      final item = _item(id: 'blank', phone: '   ', email: '  \t');
      expect(practiceContactFieldPresent(item.studentPhone), isFalse);
      expect(practiceContactFieldPresent(item.studentEmail), isFalse);
      expect(
        availablePracticeQuickActions(item),
        [
          PracticeQuickAction.openOverview,
          PracticeQuickAction.openDocuments,
        ],
      );
    });
  });

  group('practiceQuickActionInitialTabIndex', () {
    test('6. Apri Documenti → tab Documenti', () {
      expect(
        practiceQuickActionInitialTabIndex(PracticeQuickAction.openDocuments),
        Student360DetailView.tabIndexDocumenti,
      );
      expect(
        practiceQuickActionInitialTabIndex(PracticeQuickAction.openDocuments),
        practiceQuickActionTabDocumenti,
      );
    });

    test('7. Apri Scheda → tab Scheda', () {
      expect(
        practiceQuickActionInitialTabIndex(PracticeQuickAction.openOverview),
        Student360DetailView.tabIndexScheda,
      );
      expect(
        practiceQuickActionInitialTabIndex(PracticeQuickAction.openOverview),
        practiceQuickActionTabScheda,
      );
    });

    test('call/email non hanno tab 360', () {
      expect(
        practiceQuickActionInitialTabIndex(PracticeQuickAction.call),
        isNull,
      );
      expect(
        practiceQuickActionInitialTabIndex(PracticeQuickAction.email),
        isNull,
      );
    });
  });

  group('8C non altera 8A/8B / item', () {
    test('8. available actions non modifica PracticeListItem', () {
      final item = _item(
        id: 'immutable',
        phone: '+39111',
        email: 'x@y.z',
      );
      final beforePhone = item.studentPhone;
      final beforeEmail = item.studentEmail;
      availablePracticeQuickActions(item);
      expect(item.studentPhone, beforePhone);
      expect(item.studentEmail, beforeEmail);
    });

    test('9. 8A overview invariata rispetto a quick actions', () {
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
          phone: '+39333',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
        ),
      ];
      final before = PracticeDirectoryOverview.fromItems(items);
      for (final i in items) {
        availablePracticeQuickActions(i);
      }
      final after = PracticeDirectoryOverview.fromItems(items);
      expect(after.total, before.total);
      expect(after.newLicense, before.newLicense);
      expect(after.renewal, before.renewal);
      expect(after.docsIncomplete, before.docsIncomplete);
      expect(after.medicalAttention, before.medicalAttention);
    });

    test('10. 8B priority sort invariato', () {
      final items = [
        _item(
          id: 'normal',
          email: 'n@e.it',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.ok,
          ),
          registrationDate: DateTime(2025, 1, 1),
        ),
        _item(
          id: 'expired',
          phone: '333',
          summary: _summary(
            complete: true,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
          registrationDate: DateTime(2024, 1, 1),
        ),
      ];
      for (final i in items) {
        availablePracticeQuickActions(i);
      }
      final sorted = sortPracticeDirectoryByAttention(items, priorityOn: true);
      expect(sorted.map((e) => e.practiceDossierId).toList(), [
        'expired',
        'normal',
      ]);
      final off = sortPracticeDirectoryByAttention(items, priorityOn: false);
      expect(off.map((e) => e.practiceDossierId).toList(), [
        'normal',
        'expired',
      ]);
    });
  });
}
