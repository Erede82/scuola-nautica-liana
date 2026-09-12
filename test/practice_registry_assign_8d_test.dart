import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/assign_practice_registry_dialog.dart';

PracticeListItem _listItem({
  required String id,
  String? practiceType = 'new_license',
  int? registryNumber,
  String? registryCode,
  DateTime? registrationDate,
}) {
  return PracticeListItem(
    practiceDossierId: id,
    studentId: 'stu-$id',
    studentFullName: 'Studente $id',
    practiceType: practiceType,
    registrationDate: registrationDate ?? DateTime(2024, 3, 10),
    registryNumber: registryNumber,
    registryCode: registryCode,
    documentStatus: LicenseDocumentStatus.collected,
    practiceStatus: PracticeFileStatus.inProgress,
  );
}

PracticeLicenseDossier _dossier({
  required String id,
  String? practiceType = 'new_license',
  int? registryNumber,
  String? registryCode,
  DateTime? registrationDate,
}) {
  return PracticeLicenseDossier(
    id: id,
    studentId: 'stu-$id',
    practiceType: practiceType,
    registrationDate: registrationDate ?? DateTime(2024, 3, 10),
    registryNumber: registryNumber,
    registryCode: registryCode,
    documentStatus: LicenseDocumentStatus.collected,
    practiceStatus: PracticeFileStatus.inProgress,
  );
}

class _SpyAssignRepo extends BackofficeRepositoryMock {
  int assignCalls = 0;
  Object? failWith;
  DateTime? lastRegistrationDate;
  PracticeDossierId? lastDossierId;

  @override
  Future<PracticeRegistryAssignment> assignPracticeRegistryNumber({
    required PracticeDossierId practiceDossierId,
    required DateTime registrationDate,
  }) async {
    assignCalls++;
    lastDossierId = practiceDossierId;
    lastRegistrationDate = registrationDate;
    if (failWith != null) {
      throw failWith!;
    }
    return super.assignPracticeRegistryNumber(
      practiceDossierId: practiceDossierId,
      registrationDate: registrationDate,
    );
  }
}

void main() {
  group('canAssignPracticeRegistryNumber eligibility', () {
    test('1. new_license senza registro → true', () {
      final item = _listItem(id: 'nl-open');
      expect(canAssignPracticeRegistryNumberToListItem(item), isTrue);
      expect(canAssignPracticeRegistryNumberToDossier(_dossier(id: 'nl-open')), isTrue);
    });

    test('2. new_license con registro → false', () {
      final item = _listItem(
        id: 'nl-done',
        registryNumber: 12,
        registryCode: '2024/00012',
      );
      expect(canAssignPracticeRegistryNumberToListItem(item), isFalse);
      expect(
        canAssignPracticeRegistryNumberToDossier(
          _dossier(
            id: 'nl-done',
            registryNumber: 12,
            registryCode: '2024/00012',
          ),
        ),
        isFalse,
      );
    });

    test('3. renewal senza registro → false', () {
      expect(
        canAssignPracticeRegistryNumberToListItem(
          _listItem(id: 'ren', practiceType: 'renewal'),
        ),
        isFalse,
      );
      expect(
        canAssignPracticeRegistryNumberToDossier(
          _dossier(id: 'ren', practiceType: 'renewal'),
        ),
        isFalse,
      );
    });

    test('4. duplicate senza registro → false', () {
      expect(
        canAssignPracticeRegistryNumberToListItem(
          _listItem(id: 'dup', practiceType: 'duplicate'),
        ),
        isFalse,
      );
    });

    test('5. Directory quick action presente solo se eleggibile', () {
      final eligible = _listItem(id: 'e');
      expect(
        availablePracticeQuickActions(eligible),
        contains(PracticeQuickAction.assignRegistry),
      );

      final renewal = _listItem(id: 'r', practiceType: 'renewal');
      expect(
        availablePracticeQuickActions(renewal),
        isNot(contains(PracticeQuickAction.assignRegistry)),
      );

      final assigned = _listItem(
        id: 'a',
        registryNumber: 1,
        registryCode: '2024/00001',
      );
      expect(
        availablePracticeQuickActions(assigned),
        isNot(contains(PracticeQuickAction.assignRegistry)),
      );
    });

    test('6. Scheda 360 action solo se eleggibile (helper dossier)', () {
      expect(
        canAssignPracticeRegistryNumberToDossier(_dossier(id: 'ok')),
        isTrue,
      );
      expect(
        canAssignPracticeRegistryNumberToDossier(null),
        isFalse,
      );
      expect(
        canAssignPracticeRegistryNumberToDossier(
          _dossier(id: 'ren', practiceType: 'renewal'),
        ),
        isFalse,
      );
    });
  });

  group('PracticeRegistryAssignController mutation', () {
    test('12. anno/data passati = registrationDate create flow', () async {
      final repo = _SpyAssignRepo();
      final outcome = await repo.createBackofficeStudent(
        firstName: 'Ada',
        lastName: 'Lovelace',
        createPracticeDossier: true,
        practiceType: 'new_license',
        registrationDate: DateTime(2023, 11, 5),
        assignRegistryNumber: false,
      );
      final view = await repo.getStudentAdmin360(outcome.profile.id);
      final dossier = view!.practiceDossier!;
      expect(canAssignPracticeRegistryNumberToDossier(dossier), isTrue);

      final ctrl = PracticeRegistryAssignController(repository: repo);
      final regDate = dossier.registrationDate!;
      expect(practiceRegistryYearFromRegistrationDate(regDate), 2023);

      final assignment = await ctrl.assign(
        practiceDossierId: dossier.id,
        registrationDate: regDate,
      );
      expect(repo.assignCalls, 1);
      expect(repo.lastRegistrationDate, regDate);
      expect(assignment.registryYear, 2023);
      expect(assignment.registryCode, isNotEmpty);
    });

    test('9. doppio tap / busy → seconda chiamata bloccata', () async {
      final repo = _SpyAssignRepo();
      final outcome = await repo.createBackofficeStudent(
        firstName: 'Double',
        lastName: 'Tap',
        createPracticeDossier: true,
        practiceType: 'new_license',
        registrationDate: DateTime(2025, 1, 2),
        assignRegistryNumber: false,
      );
      final view = await repo.getStudentAdmin360(outcome.profile.id);
      final dossierId = view!.practiceDossier!.id;
      final ctrl = PracticeRegistryAssignController(repository: repo);

      late final Future<PracticeRegistryAssignment> first;
      first = ctrl.assign(
        practiceDossierId: dossierId,
        registrationDate: DateTime(2025, 1, 2),
      );
      expect(ctrl.isBusy, isTrue);
      await expectLater(
        ctrl.assign(
          practiceDossierId: dossierId,
          registrationDate: DateTime(2025, 1, 2),
        ),
        throwsA(isA<StateError>()),
      );
      await first;
      expect(repo.assignCalls, 1);
    });

    test('11. failure → nessun fake locale + retry possibile', () async {
      final repo = _SpyAssignRepo();
      final outcome = await repo.createBackofficeStudent(
        firstName: 'Fail',
        lastName: 'Retry',
        createPracticeDossier: true,
        practiceType: 'new_license',
        registrationDate: DateTime(2024, 8, 1),
        assignRegistryNumber: false,
      );
      final view = await repo.getStudentAdmin360(outcome.profile.id);
      final dossier = view!.practiceDossier!;
      expect(dossier.registryNumber, isNull);

      final ctrl = PracticeRegistryAssignController(repository: repo);
      repo.failWith = StateError('rpc_failed');
      await expectLater(
        ctrl.assign(
          practiceDossierId: dossier.id,
          registrationDate: dossier.registrationDate!,
        ),
        throwsA(isA<StateError>()),
      );
      expect(ctrl.isBusy, isFalse);

      final afterFail = await repo.getStudentAdmin360(outcome.profile.id);
      expect(afterFail!.practiceDossier!.registryNumber, isNull);
      expect(canAssignPracticeRegistryNumberToDossier(afterFail.practiceDossier), isTrue);

      repo.failWith = null;
      final ok = await ctrl.assign(
        practiceDossierId: dossier.id,
        registrationDate: dossier.registrationDate!,
      );
      expect(ok.registryCode, isNotEmpty);
      expect(repo.assignCalls, 2);

      final afterOk = await repo.getStudentAdmin360(outcome.profile.id);
      expect(canAssignPracticeRegistryNumberToDossier(afterOk!.practiceDossier), isFalse);
    });
  });

  group('assign dialog UI', () {
    testWidgets('8. annulla → assign NON chiamato', (tester) async {
      final repo = _SpyAssignRepo();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  showAssignPracticeRegistryNumberDialog(
                    context: context,
                    repository: repo,
                    practiceDossierId: 'dos-1',
                    registrationDate: DateTime(2024, 1, 1),
                    studentFullName: 'Test Allievo',
                    controller: PracticeRegistryAssignController(repository: repo),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Assegna n. registro'), findsWidgets);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(repo.assignCalls, 0);
    });

    testWidgets('7. conferma → assign chiamato una volta', (tester) async {
      final repo = _SpyAssignRepo();
      final outcome = await repo.createBackofficeStudent(
        firstName: 'Confirm',
        lastName: 'Once',
        createPracticeDossier: true,
        practiceType: 'new_license',
        registrationDate: DateTime(2022, 4, 9),
        assignRegistryNumber: false,
      );
      final view = await repo.getStudentAdmin360(outcome.profile.id);
      final dossier = view!.practiceDossier!;

      PracticeRegistryAssignment? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showAssignPracticeRegistryNumberDialog(
                    context: context,
                    repository: repo,
                    practiceDossierId: dossier.id,
                    registrationDate: dossier.registrationDate!,
                    studentFullName: 'Confirm Once',
                    controller: PracticeRegistryAssignController(repository: repo),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Anno registro previsto: 2022'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Assegna'));
      await tester.pumpAndSettle();
      expect(repo.assignCalls, 1);
      expect(result, isNotNull);
      expect(result!.registryYear, 2022);
    });

    testWidgets('10. success → azione eleggibilità sparisce dopo refresh dati', (
      tester,
    ) async {
      final repo = _SpyAssignRepo();
      final outcome = await repo.createBackofficeStudent(
        firstName: 'Gone',
        lastName: 'Action',
        createPracticeDossier: true,
        practiceType: 'new_license',
        registrationDate: DateTime(2021, 5, 5),
        assignRegistryNumber: false,
      );
      final before = await repo.getStudentAdmin360(outcome.profile.id);
      expect(canAssignPracticeRegistryNumberToDossier(before!.practiceDossier), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await showAssignPracticeRegistryNumberDialog(
                    context: context,
                    repository: repo,
                    practiceDossierId: before.practiceDossier!.id,
                    registrationDate: before.practiceDossier!.registrationDate!,
                    controller: PracticeRegistryAssignController(repository: repo),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Assegna'));
      await tester.pumpAndSettle();

      final after = await repo.getStudentAdmin360(outcome.profile.id);
      expect(canAssignPracticeRegistryNumberToDossier(after!.practiceDossier), isFalse);
      expect(
        availablePracticeQuickActions(
          _listItem(
            id: after.practiceDossier!.id,
            registryNumber: after.practiceDossier!.registryNumber,
            registryCode: after.practiceDossier!.registryCode,
          ),
        ),
        isNot(contains(PracticeQuickAction.assignRegistry)),
      );
    });
  });
}
