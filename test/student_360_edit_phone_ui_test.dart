import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/domain/international_phone.dart';
import 'package:scuola_nautica_liana/pages/backoffice/student_360_direct_page.dart';
import 'package:scuola_nautica_liana/widgets/international_phone_field.dart';

void main() {
  for (final size in const [Size(390, 844), Size(430, 932), Size(1366, 768)]) {
    testWidgets('Scheda 360 modifica cellulare $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      const studentId = 'stu-demo-lucia-001';
      final before = backofficeDemoStore.profiles.firstWhere(
        (p) => p.id == studentId,
      );
      final previousPhone = before.phone;
      final previousIso = before.phoneCountryIso2;
      addTearDown(() {
        backofficeDemoStore.updateStudentPhone(
          studentId: studentId,
          phoneE164: previousPhone ?? '+393200000001',
          phoneCountryIso2: previousIso ?? 'IT',
        );
      });

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp(
            locale: const Locale('it', 'IT'),
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              ...InternationalPhoneField.localizationsDelegates,
            ],
            home: const Student360DirectPage(studentId: studentId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tab Scheda (indice 0) è quella di default.
      final editBtn = find.byKey(const ValueKey('student-360-edit-phone'));
      expect(editBtn, findsOneWidget);
      await tester.ensureVisible(editBtn);
      await tester.pumpAndSettle();
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Modifica cellulare'), findsWidgets);
      await tester.enterText(find.byType(PhoneFormField), '3331234567');
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('edit-student-phone-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      final profile = backofficeDemoStore.profiles.firstWhere(
        (p) => p.id == studentId,
      );
      expect(profile.phone, '+393331234567');
      expect(profile.phoneCountryIso2, 'IT');
      expect(
        find.text(InternationalPhoneRules.formatForDisplay(profile.phone)),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
