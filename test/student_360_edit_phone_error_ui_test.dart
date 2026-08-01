import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/edit_student_phone_dialog.dart';
import 'package:scuola_nautica_liana/widgets/international_phone_field.dart';

class _FailingPhoneRepo extends BackofficeRepositoryMock {
  int updateCalls = 0;

  @override
  Future<void> updateStudentPhone({
    required StudentId studentId,
    required String phoneE164,
    required String phoneCountryIso2,
  }) async {
    updateCalls++;
    throw StateError(
      'PostgrestException(message: RLS policy violation on students, code: 42501)',
    );
  }
}

void main() {
  testWidgets(
    'Modifica cellulare: errore update generico, dialog aperto, no leak',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      const studentId = 'stu-demo-lucia-001';
      final spy = _FailingPhoneRepo();
      final before = backofficeDemoStore.profiles.firstWhere(
        (p) => p.id == studentId,
      );
      final originalPhone = before.phone;
      var dialogResult = false;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            locale: const Locale('it', 'IT'),
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              ...InternationalPhoneField.localizationsDelegates,
            ],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    dialogResult = await showEditStudentPhoneDialog(
                      context: context,
                      repository: spy,
                      studentId: studentId,
                      currentPhone: originalPhone,
                      currentPhoneCountryIso2: before.phoneCountryIso2,
                    );
                  },
                  child: const Text('Apri'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apri'));
      await tester.pumpAndSettle();

      expect(find.text('Modifica cellulare'), findsWidgets);
      await tester.enterText(find.byType(PhoneFormField), '3331234567');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('edit-student-phone-save')));
      await tester.pumpAndSettle();

      expect(spy.updateCalls, 1);
      expect(dialogResult, isFalse);
      expect(find.text('Modifica cellulare'), findsWidgets);
      expect(
        find.text('Impossibile aggiornare il cellulare. Riprova tra poco.'),
        findsOneWidget,
      );
      expect(find.textContaining('Postgrest'), findsNothing);
      expect(find.textContaining('RLS'), findsNothing);
      expect(find.textContaining('42501'), findsNothing);

      final field = tester.widget<PhoneFormField>(find.byType(PhoneFormField));
      expect(field.controller!.value.nsn, contains('3331234567'));

      final after = backofficeDemoStore.profiles.firstWhere(
        (p) => p.id == studentId,
      );
      expect(after.phone, originalPhone);

      final view = await BackofficeRepositoryMock().getStudentAdmin360(
        studentId,
      );
      final phoneEvents = view!.activityLog.where(
        (e) => e.title == 'Cellulare aggiornato',
      );
      for (final e in phoneEvents) {
        final blob = '${e.title}\n${e.description ?? ''}';
        expect(blob, isNot(contains('+393331234567')));
        expect(blob, isNot(contains('3331234567')));
      }

      expect(tester.takeException(), isNull);
    },
  );
}
