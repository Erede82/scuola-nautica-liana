import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_supabase_write_helpers.dart';

void main() {
  const studentId = 'stu-demo-lucia-001';
  const validCf = 'BNCLCU98D52F205T';

  group('ALLIEVI.P1A repository / payload', () {
    test('11. update payload contiene SOLO campi anagrafici', () {
      final payload = studentAnagraficaUpdatePayload(
        firstName: 'Lucia',
        lastName: 'Bianchi',
        fiscalCode: validCf,
        birthDate: DateTime(1998, 4, 12),
        birthPlace: 'Milano',
        gender: 'Femmina',
        address: 'Via del Porto 12',
        city: 'Milano',
        province: 'MI',
        cap: '20100',
        phoneE164: '+393331234567',
        phoneCountryIso2: 'IT',
        email: 'lucia@example.com',
      );

      const allowed = {
        'first_name',
        'last_name',
        'fiscal_code',
        'birth_date',
        'birth_place',
        'gender',
        'address',
        'city',
        'province',
        'cap',
        'phone',
        'phone_country_iso2',
        'email',
      };
      expect(payload.keys.toSet(), allowed);
      expect(payload.containsKey('user_id'), isFalse);
      expect(payload.containsKey('auth_user_id'), isFalse);
      expect(payload.containsKey('notes'), isFalse);
      expect(payload.containsKey('onboarding_status'), isFalse);
      expect(payload.containsKey('registration_status'), isFalse);
      expect(payload.containsKey('practice_type'), isFalse);
    });

    test('12. studentId corretto + 15. nessun update auth (mock)', () async {
      final before = backofficeDemoStore.profiles.firstWhere(
        (p) => p.id == studentId,
      );
      final snapshot = _snapshotProfile(before);
      addTearDown(() {
        backofficeDemoStore.updateStudentAnagrafica(
          studentId: studentId,
          firstName: snapshot.firstName,
          lastName: snapshot.lastName,
          fiscalCode: snapshot.taxCode ?? validCf,
          birthDate: snapshot.birthDate ?? DateTime(1998, 4, 12),
          birthPlace: snapshot.birthPlace ?? 'Milano',
          gender: snapshot.gender ?? 'Femmina',
          address: snapshot.address?.streetLine1 ?? 'Via del Porto 12',
          city: snapshot.address?.city ?? 'Milano',
          province: snapshot.address?.provinceCode ?? 'MI',
          cap: snapshot.address?.postalCode ?? '20100',
          phoneE164: snapshot.phone ?? '+393200000001',
          phoneCountryIso2: snapshot.phoneCountryIso2 ?? 'IT',
          email: snapshot.email,
        );
      });

      final repo = BackofficeRepositoryMock();
      await repo.updateStudentAnagrafica(
        studentId: studentId,
        firstName: 'Lucia',
        lastName: 'Rossi',
        fiscalCode: validCf,
        birthDate: DateTime(1998, 4, 12),
        birthPlace: 'Napoli',
        gender: 'Femmina',
        address: 'Via Nuova 1',
        city: 'Napoli',
        province: 'NA',
        cap: '80100',
        phoneE164: '+393331112233',
        phoneCountryIso2: 'IT',
        email: 'nuova@example.com',
      );

      final after = backofficeDemoStore.profiles.firstWhere(
        (p) => p.id == studentId,
      );
      expect(after.id, studentId);
      expect(after.lastName, 'Rossi');
      expect(after.linkedAuthUserId, snapshot.linkedAuthUserId);
      expect(after.enrolledCoursePath, snapshot.enrolledCoursePath);
      expect(after.registrationStatus, snapshot.registrationStatus);
      expect(after.onboardingStatus, snapshot.onboardingStatus);
      expect(after.internalNotes, snapshot.internalNotes);
    });

    test('13. errore repository propagato (failing mock)', () async {
      final spy = _FailingAnagraficaRepo();
      expect(
        () => spy.updateStudentAnagrafica(
          studentId: studentId,
          firstName: 'Lucia',
          lastName: 'Bianchi',
          fiscalCode: validCf,
          birthDate: DateTime(1998, 4, 12),
          birthPlace: 'Milano',
          gender: 'Femmina',
          address: 'Via 1',
          city: 'Milano',
          province: 'MI',
          cap: '20100',
          phoneE164: '+393331234567',
          phoneCountryIso2: 'IT',
          email: 'a@b.it',
        ),
        throwsA(isA<StateError>()),
      );
      expect(spy.updateCalls, 1);
    });

    test('14. nessun update practice_dossiers + isolation', () async {
      final repo = BackofficeRepositoryMock();
      final before = await repo.getStudentAdmin360(studentId);
      expect(before, isNotNull);

      final dossierId = before!.practiceDossier?.id;
      final registry = before.practiceDossier?.registryNumber;
      final fee = before.financialSummary.registrationFeeCents;
      final docCount = before.documents.length;
      final unlockCount = before.studyProgress.sheetUnlocks.length;
      final apptCount = before.appointments.length;
      final examCount = before.examSummary.theoryAttempts.length +
          before.examSummary.practicalAttempts.length;
      final paymentCount = before.payments.length;

      final p = before.profile;
      addTearDown(() {
        backofficeDemoStore.updateStudentAnagrafica(
          studentId: studentId,
          firstName: p.firstName,
          lastName: p.lastName,
          fiscalCode: p.taxCode ?? validCf,
          birthDate: p.birthDate ?? DateTime(1998, 4, 12),
          birthPlace: p.birthPlace ?? 'Milano',
          gender: p.gender ?? 'Femmina',
          address: p.address?.streetLine1 ?? 'Via del Porto 12',
          city: p.address?.city ?? 'Milano',
          province: p.address?.provinceCode ?? 'MI',
          cap: p.address?.postalCode ?? '20100',
          phoneE164: p.phone ?? '+393200000001',
          phoneCountryIso2: p.phoneCountryIso2 ?? 'IT',
          email: p.email,
        );
      });

      await repo.updateStudentAnagrafica(
        studentId: studentId,
        firstName: 'Lucia',
        lastName: 'Bianchi',
        fiscalCode: validCf,
        birthDate: DateTime(1998, 4, 12),
        birthPlace: 'Milano',
        gender: 'Femmina',
        address: 'Via Modificata 9',
        city: 'Milano',
        province: 'MI',
        cap: '20121',
        phoneE164: '+393200000001',
        phoneCountryIso2: 'IT',
        email: p.email,
      );

      final after = await repo.getStudentAdmin360(studentId);
      expect(after!.practiceDossier?.id, dossierId);
      expect(after.practiceDossier?.registryNumber, registry);
      expect(after.financialSummary.registrationFeeCents, fee);
      expect(after.documents.length, docCount);
      expect(after.studyProgress.sheetUnlocks.length, unlockCount);
      expect(after.appointments.length, apptCount);
      expect(
        after.examSummary.theoryAttempts.length +
            after.examSummary.practicalAttempts.length,
        examCount,
      );
      expect(after.payments.length, paymentCount);
      expect(after.profile.address?.streetLine1, 'Via Modificata 9');
      expect(after.profile.address?.postalCode, '20121');

      final events = after.activityLog
          .where((e) => e.title == 'Anagrafica aggiornata')
          .toList();
      expect(events, isNotEmpty);
      final latest = events.first;
      expect(latest.description, isNull);
      final blob = '${latest.title}\n${latest.description ?? ''}';
      expect(blob, isNot(contains(validCf)));
      expect(blob, isNot(contains('lucia')));
      expect(blob, isNot(contains('+39')));
      expect(blob, isNot(contains('Via Modificata')));
    });
  });
}

StudentProfile _snapshotProfile(StudentProfile p) => p;

class _FailingAnagraficaRepo extends BackofficeRepositoryMock {
  int updateCalls = 0;

  @override
  Future<void> updateStudentAnagrafica({
    required StudentId studentId,
    required String firstName,
    required String lastName,
    required String fiscalCode,
    required DateTime birthDate,
    required String birthPlace,
    required String gender,
    required String address,
    required String city,
    required String province,
    required String cap,
    required String phoneE164,
    required String phoneCountryIso2,
    String? email,
  }) async {
    updateCalls++;
    throw StateError('PostgrestException(message: RLS policy violation)');
  }
}
