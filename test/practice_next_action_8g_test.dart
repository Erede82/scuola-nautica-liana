import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/domain/course_taxonomy.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/student_360_detail_view.dart';

PracticeDocumentChecklistSummary _docs({
  int missing = 0,
  PracticeMedicalCertificateSummaryKind medical =
      PracticeMedicalCertificateSummaryKind.ok,
  bool applicable = true,
}) {
  return PracticeDocumentChecklistSummary(
    applicable: applicable,
    missingRequiredCount: missing,
    isRequiredChecklistComplete: missing == 0,
    medicalCertificate: medical,
  );
}

PracticeNextAction _resolve({
  PracticeDocumentChecklistSummary? docs,
  bool registryAssignable = false,
  PracticeFinancialStatus financial = PracticeFinancialStatus.settled,
}) {
  return resolvePracticeNextAction(
    docs: docs ?? _docs(),
    registryAssignable: registryAssignable,
    financial: financial,
  );
}

StudentDocument _doc({
  required String id,
  required String type,
  String status = 'uploaded',
  DateTime? expiresAt,
}) {
  return StudentDocument(
    id: id,
    studentId: 'stu-8g',
    practiceDossierId: 'prac-8g',
    documentType: type,
    title: type,
    storagePath: 'mock/$id.pdf',
    fileName: '$id.pdf',
    mimeType: 'application/pdf',
    status: status,
    expiresAt: expiresAt,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

StudentAdmin360View _view({
  String practiceType = 'new_license',
  int? registryNumber,
  String? registryCode,
  List<StudentDocument> documents = const [],
  List<StudentPhoto> photos = const [],
  int fee = 10000,
  int remaining = 0,
}) {
  return StudentAdmin360View(
    profile: StudentProfile(
      id: 'stu-8g',
      firstName: 'Anna',
      lastName: 'Test',
      enrolledCoursePath: EnrollmentCoursePath.entro12Miglia,
      registrationStatus: StudentRegistrationStatus.active,
    ),
    studyProgress: const StudentStudyProgressBundle(
      studentId: 'stu-8g',
      assignedLessons: [],
      sheetUnlocks: [],
      examAccessByCategory: [],
      errorReviewAssignments: [],
    ),
    appointments: const [],
    examSummary: const StudentExamSummary(
      studentId: 'stu-8g',
      theoryAttempts: [],
      practicalAttempts: [],
    ),
    financialSummary: StudentFinancialSummary(
      studentId: 'stu-8g',
      registrationFeeCents: fee,
      currencyCode: 'EUR',
      totalPaidCents: fee - remaining,
      remainingBalanceCents: remaining,
    ),
    payments: const [],
    practiceDossier: PracticeLicenseDossier(
      id: 'prac-8g',
      studentId: 'stu-8g',
      practiceType: practiceType,
      registrationDate: DateTime(2026, 3, 1),
      registryYear: registryNumber != null ? 2026 : null,
      registryNumber: registryNumber,
      registryCode: registryCode,
      documentStatus: LicenseDocumentStatus.collected,
      practiceStatus: PracticeFileStatus.inProgress,
    ),
    documents: documents,
    photos: photos,
  );
}

void _prepareSurface(WidgetTester tester, {Size size = const Size(1280, 1800)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('PRATICHE.8G — priority first-match', () {
    test('1. medico expired + docs missing → Rinnova certificato medico', () {
      final a = _resolve(
        docs: _docs(
          missing: 3,
          medical: PracticeMedicalCertificateSummaryKind.expired,
        ),
        registryAssignable: true,
        financial: PracticeFinancialStatus.feeNotSet,
      );
      expect(a.kind, PracticeNextActionKind.medicalExpired);
      expect(a.label, 'Rinnova certificato medico');
      expect(a.targetTabIndex, kPracticeNextActionTabDocumenti);
    });

    test('2. docs missing + registro missing → Completa documenti', () {
      final a = _resolve(
        docs: _docs(missing: 2),
        registryAssignable: true,
        financial: PracticeFinancialStatus.feeNotSet,
      );
      expect(a.kind, PracticeNextActionKind.documentsIncomplete);
      expect(a.label, 'Completa documenti (2)');
      expect(a.optionalCount, 2);
    });

    test('3. registro missing + fee zero → Assegna numero registro', () {
      final a = _resolve(
        docs: _docs(missing: 0),
        registryAssignable: true,
        financial: PracticeFinancialStatus.feeNotSet,
      );
      expect(a.kind, PracticeNextActionKind.registryMissing);
      expect(a.label, 'Assegna numero registro');
      expect(a.targetTabIndex, kPracticeNextActionTabScheda);
    });

    test('4. fee zero + medico soon → Imposta quota', () {
      final a = _resolve(
        docs: _docs(
          missing: 0,
          medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
        ),
        registryAssignable: false,
        financial: PracticeFinancialStatus.feeNotSet,
      );
      expect(a.kind, PracticeNextActionKind.feeNotSet);
      expect(a.label, 'Imposta quota');
      expect(a.targetTabIndex, kPracticeNextActionTabContabilita);
    });

    test('5. medico soon + saldo aperto → Certificato medico in scadenza', () {
      final a = _resolve(
        docs: _docs(
          missing: 0,
          medical: PracticeMedicalCertificateSummaryKind.expiringSoon,
        ),
        registryAssignable: false,
        financial: PracticeFinancialStatus.open,
      );
      expect(a.kind, PracticeNextActionKind.medicalExpiringSoon);
      expect(a.label, 'Certificato medico in scadenza');
    });

    test('6. solo saldo aperto → Saldo da incassare', () {
      final a = _resolve(
        docs: _docs(missing: 0),
        registryAssignable: false,
        financial: PracticeFinancialStatus.open,
      );
      expect(a.kind, PracticeNextActionKind.openBalance);
      expect(a.label, 'Saldo da incassare');
      expect(a.targetTabIndex, kPracticeNextActionTabContabilita);
    });

    test('7. nessun segnale → Nessuna azione urgente', () {
      final a = _resolve(
        docs: _docs(missing: 0),
        registryAssignable: false,
        financial: PracticeFinancialStatus.settled,
      );
      expect(a.kind, PracticeNextActionKind.none);
      expect(a.label, 'Nessuna azione urgente');
      expect(a.isClickable, isFalse);
    });
  });

  group('PRATICHE.8G — practice types / FromView', () {
    test('8. new_license senza registro → registry', () {
      final view = _view(
        practiceType: 'new_license',
        documents: [
          _doc(id: 'ci', type: 'identityCard'),
          _doc(id: 'cf', type: 'taxCode'),
          _doc(
            id: 'med',
            type: 'medicalCertificate',
            expiresAt: DateTime.now().add(const Duration(days: 120)),
          ),
          _doc(id: 'form', type: 'practiceForm'),
        ],
        photos: [
          StudentPhoto(
            id: 'ph1',
            studentId: 'stu-8g',
            photoKind: 'license',
            storagePath: 'mock/ph.jpg',
            fileName: 'ph.jpg',
            mimeType: 'image/jpeg',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
        fee: 10000,
        remaining: 0,
      );
      final a = derivePracticeNextActionFromView(view);
      expect(a.kind, PracticeNextActionKind.registryMissing);
    });

    test('9. renewal senza registro → NO registro', () {
      final view = _view(
        practiceType: 'renewal',
        fee: 10000,
        remaining: 0,
        documents: [
          _doc(id: 'lic', type: 'currentNauticalLicense'),
          _doc(id: 'ci', type: 'identityCard'),
          _doc(id: 'cf', type: 'taxCode'),
          _doc(
            id: 'med',
            type: 'medicalCertificate',
            expiresAt: DateTime.now().add(const Duration(days: 120)),
          ),
        ],
      );
      final a = derivePracticeNextActionFromView(view);
      expect(a.kind, isNot(PracticeNextActionKind.registryMissing));
      expect(canAssignPracticeRegistryNumberToDossier(view.practiceDossier), isFalse);
    });

    test('10. duplicate senza registro → NO registro', () {
      final view = _view(
        practiceType: 'duplicate',
        fee: 10000,
        remaining: 0,
        documents: [
          _doc(id: 'ci', type: 'identityCard'),
          _doc(id: 'cf', type: 'taxCode'),
        ],
        photos: [
          StudentPhoto(
            id: 'ph1',
            studentId: 'stu-8g',
            photoKind: 'license',
            storagePath: 'mock/ph.jpg',
            fileName: 'ph.jpg',
            mimeType: 'image/jpeg',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      final a = derivePracticeNextActionFromView(view);
      expect(a.kind, isNot(PracticeNextActionKind.registryMissing));
      expect(canAssignPracticeRegistryNumberToDossier(view.practiceDossier), isFalse);
    });

    test('11. duplicate senza medical requirement → no medical action inventata', () {
      final view = _view(
        practiceType: 'duplicate',
        registryNumber: 1,
        registryCode: '2026/00001',
        fee: 10000,
        remaining: 0,
        documents: [
          _doc(id: 'ci', type: 'identityCard'),
          _doc(id: 'cf', type: 'taxCode'),
        ],
        photos: [
          StudentPhoto(
            id: 'ph1',
            studentId: 'stu-8g',
            photoKind: 'license',
            storagePath: 'mock/ph.jpg',
            fileName: 'ph.jpg',
            mimeType: 'image/jpeg',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      final checklist = evaluatePracticeDocumentChecklist(
        practiceType: 'duplicate',
        documents: view.documents,
        photos: view.photos,
      );
      expect(checklist.medicalCertificateItem, isNull);
      final a = derivePracticeNextActionFromView(view);
      expect(a.kind, isNot(PracticeNextActionKind.medicalExpired));
      expect(a.kind, isNot(PracticeNextActionKind.medicalExpiringSoon));
    });
  });

  group('PRATICHE.8G — navigation targets', () {
    test('12–15. tab mapping + none non cliccabile', () {
      expect(
        _resolve(
          docs: _docs(
            missing: 1,
            medical: PracticeMedicalCertificateSummaryKind.expired,
          ),
        ).targetTabIndex,
        kPracticeNextActionTabDocumenti,
      );
      expect(
        _resolve(docs: _docs(missing: 1)).targetTabIndex,
        kPracticeNextActionTabDocumenti,
      );
      expect(
        _resolve(registryAssignable: true).targetTabIndex,
        kPracticeNextActionTabScheda,
      );
      expect(
        _resolve(financial: PracticeFinancialStatus.feeNotSet).targetTabIndex,
        kPracticeNextActionTabContabilita,
      );
      expect(
        _resolve(financial: PracticeFinancialStatus.open).targetTabIndex,
        kPracticeNextActionTabContabilita,
      );
      expect(_resolve().isClickable, isFalse);
    });
  });

  group('PRATICHE.8G — refresh semantics (snapshot successivi)', () {
    test('docs incomplete → complete → next signal', () {
      var a = _resolve(
        docs: _docs(missing: 2),
        registryAssignable: true,
        financial: PracticeFinancialStatus.feeNotSet,
      );
      expect(a.kind, PracticeNextActionKind.documentsIncomplete);

      a = _resolve(
        docs: _docs(missing: 0),
        registryAssignable: true,
        financial: PracticeFinancialStatus.feeNotSet,
      );
      expect(a.kind, PracticeNextActionKind.registryMissing);
    });

    test('registry missing → assigned → feeNotSet', () {
      var a = _resolve(
        registryAssignable: true,
        financial: PracticeFinancialStatus.feeNotSet,
      );
      expect(a.kind, PracticeNextActionKind.registryMissing);

      a = _resolve(
        registryAssignable: false,
        financial: PracticeFinancialStatus.feeNotSet,
      );
      expect(a.kind, PracticeNextActionKind.feeNotSet);
    });

    test('fee zero → fee set settled → none', () {
      var a = _resolve(financial: PracticeFinancialStatus.feeNotSet);
      expect(a.kind, PracticeNextActionKind.feeNotSet);

      a = _resolve(financial: PracticeFinancialStatus.settled);
      expect(a.kind, PracticeNextActionKind.none);
    });

    test('fee set open → Saldo da incassare', () {
      final a = _resolve(financial: PracticeFinancialStatus.open);
      expect(a.kind, PracticeNextActionKind.openBalance);
    });
  });

  group('PRATICHE.8G — UI strip', () {
    testWidgets('strip presente e none non naviga', (tester) async {
      _prepareSurface(tester);
      final view = _view(
        practiceType: 'duplicate',
        registryNumber: 1,
        registryCode: '2026/00001',
        fee: 10000,
        remaining: 0,
        documents: [
          _doc(id: 'ci', type: 'identityCard'),
          _doc(id: 'cf', type: 'taxCode'),
        ],
        photos: [
          StudentPhoto(
            id: 'ph1',
            studentId: 'stu-8g',
            photoKind: 'license',
            storagePath: 'mock/ph.jpg',
            fileName: 'ph.jpg',
            mimeType: 'image/jpeg',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Student360DetailView(
              view: view,
              repository: BackofficeRepositoryMock(),
              onRefreshDetail: ([_]) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('student-360-next-action')), findsOneWidget);
      expect(find.textContaining('Prossima azione:'), findsOneWidget);
      expect(find.textContaining('Nessuna azione urgente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap docs → tab Documenti', (tester) async {
      _prepareSurface(tester);
      final view = _view(
        practiceType: 'new_license',
        registryNumber: 1,
        registryCode: '2026/00001',
        fee: 10000,
        remaining: 0,
        documents: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Student360DetailView(
              view: view,
              repository: BackofficeRepositoryMock(),
              onRefreshDetail: ([_]) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Completa documenti'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('student-360-next-action')));
      await tester.pumpAndSettle();
      final controller = DefaultTabController.of(
        tester.element(find.byKey(const ValueKey('student-360-next-action'))),
      );
      expect(controller.index, Student360DetailView.tabIndexDocumenti);
    });

    testWidgets('tap fee → tab Contabilità', (tester) async {
      _prepareSurface(tester);
      // Complete docs + registry assigned + fee 0
      final view = _view(
        practiceType: 'new_license',
        registryNumber: 2,
        registryCode: '2026/00002',
        fee: 0,
        remaining: 0,
        documents: [
          _doc(id: 'ci', type: 'identityCard'),
          _doc(id: 'cf', type: 'taxCode'),
          _doc(
            id: 'med',
            type: 'medicalCertificate',
            expiresAt: DateTime.now().add(const Duration(days: 120)),
          ),
          _doc(id: 'form', type: 'practiceForm'),
        ],
        photos: [
          StudentPhoto(
            id: 'ph1',
            studentId: 'stu-8g',
            photoKind: 'license',
            storagePath: 'mock/ph.jpg',
            fileName: 'ph.jpg',
            mimeType: 'image/jpeg',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Student360DetailView(
              view: view,
              repository: BackofficeRepositoryMock(),
              onRefreshDetail: ([_]) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Imposta quota'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('student-360-next-action')));
      await tester.pumpAndSettle();
      final controller = DefaultTabController.of(
        tester.element(find.byKey(const ValueKey('student-360-next-action'))),
      );
      expect(controller.index, Student360DetailView.tabIndexContabilita);
    });

    testWidgets('responsive 390 senza overflow', (tester) async {
      _prepareSurface(tester, size: const Size(390, 844));
      final view = _view(fee: 0, documents: const []);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            home: Scaffold(
              body: Student360DetailView(
                view: view,
                repository: BackofficeRepositoryMock(),
                onRefreshDetail: ([_]) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('student-360-next-action')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Summary Cards frozen + Prenota guida 8F ancora in Guide', (
      tester,
    ) async {
      _prepareSurface(tester);
      final view = _view(
        practiceType: 'duplicate',
        registryNumber: 1,
        registryCode: '2026/00001',
        fee: 10000,
        remaining: 0,
        documents: [
          _doc(id: 'ci', type: 'identityCard'),
          _doc(id: 'cf', type: 'taxCode'),
        ],
        photos: [
          StudentPhoto(
            id: 'ph1',
            studentId: 'stu-8g',
            photoKind: 'license',
            storagePath: 'mock/ph.jpg',
            fileName: 'ph.jpg',
            mimeType: 'image/jpeg',
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Student360DetailView(
              view: view,
              repository: BackofficeRepositoryMock(),
              onRefreshDetail: ([_]) async {},
              initialTabIndex: Student360DetailView.tabIndexGuide,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stato pratica'), findsOneWidget);
      expect(find.text('Saldo residuo'), findsOneWidget);
      expect(find.text('Prossima guida'), findsOneWidget);
      expect(find.text('Ultimo esame'), findsOneWidget);
      expect(find.text('Prenota guida'), findsOneWidget);
    });
  });

  group('PRATICHE.8G — financial helper 8E', () {
    test('fee==0 / open / settled', () {
      expect(
        practiceFinancialStatusFromSummary(
          const StudentFinancialSummary(
            studentId: 'x',
            registrationFeeCents: 0,
            currencyCode: 'EUR',
            totalPaidCents: 0,
            remainingBalanceCents: 0,
          ),
        ),
        PracticeFinancialStatus.feeNotSet,
      );
      expect(
        practiceFinancialStatusFromSummary(
          const StudentFinancialSummary(
            studentId: 'x',
            registrationFeeCents: 10000,
            currencyCode: 'EUR',
            totalPaidCents: 2000,
            remainingBalanceCents: 8000,
          ),
        ),
        PracticeFinancialStatus.open,
      );
      expect(
        practiceFinancialStatusFromSummary(
          const StudentFinancialSummary(
            studentId: 'x',
            registrationFeeCents: 10000,
            currencyCode: 'EUR',
            totalPaidCents: 12000,
            remainingBalanceCents: -2000,
          ),
        ),
        PracticeFinancialStatus.settled,
      );
    });
  });
}
