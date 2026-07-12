import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/course_taxonomy.dart';
import 'package:scuola_nautica_liana/domain/staff/staff_school_role.dart';
import 'package:scuola_nautica_liana/models/license_models.dart';
import 'package:scuola_nautica_liana/pages/account_profile_page.dart';
import 'package:scuola_nautica_liana/pages/extra_page.dart';
import 'package:scuola_nautica_liana/services/demo_student_enrollment.dart';
import 'package:scuola_nautica_liana/services/staff_access_service.dart';
import 'package:scuola_nautica_liana/services/student_area_context.dart';
import 'package:scuola_nautica_liana/services/student_content_navigation.dart';
import 'package:scuola_nautica_liana/widgets/nautical_answer_marker.dart';

void main() {
  group('StudentContentNavigation staff preview', () {
    tearDown(() {
      studentAreaPreviewActiveMode.value = null;
      staffAccessNotifier.value = StaffAccessSnapshot.initial().copyWith(
        isLoading: false,
        hasAuthSession: true,
        staffRole: null,
        clearError: true,
      );
    });

    test('staff fuori preview non bypassa categoria lezioni', () {
      staffAccessNotifier.value = staffAccessNotifier.value.copyWith(
        isLoading: false,
        staffRole: StaffSchoolRole.staff,
        hasAuthSession: true,
        clearError: true,
      );

      expect(
        StudentContentNavigation.directLessonsCategoryForCurrentUser(),
        isNull,
      );
    });

    test('staff in preview bypassa verso percorso demo/default', () {
      staffAccessNotifier.value = staffAccessNotifier.value.copyWith(
        isLoading: false,
        staffRole: StaffSchoolRole.staff,
        hasAuthSession: true,
        clearError: true,
      );
      studentAreaPreviewActiveMode.value = StudentAreaMode.staffPreview;
      demoStudentEnrollmentPath.value = EnrollmentCoursePath.entro12Miglia;

      expect(
        StudentContentNavigation.directLessonsCategoryForCurrentUser(),
        LicenseCategoryId.motore,
      );
    });
  });

  group('NauticalAnswerMarker sempre visibile', () {
    testWidgets('mostra 1 2 3 prima della selezione', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                NauticalAnswerMarker(answerNumber: 1),
                NauticalAnswerMarker(answerNumber: 2),
                NauticalAnswerMarker(answerNumber: 3),
              ],
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('mostra tutti i marker dopo risposta errata', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                NauticalAnswerMarker(
                  answerNumber: 1,
                  state: NauticalAnswerMarkerState.wrong,
                ),
                NauticalAnswerMarker(
                  answerNumber: 2,
                  state: NauticalAnswerMarkerState.neutral,
                ),
                NauticalAnswerMarker(
                  answerNumber: 3,
                  state: NauticalAnswerMarkerState.correct,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('Account preview read-only', () {
    testWidgets('non mostra erede82 e mantiene layout profilo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StudentAreaContext(
            mode: StudentAreaMode.staffPreview,
            readOnly: true,
            child: AccountProfilePage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('erede82'), findsNothing);
      expect(find.text('Anteprima allievo'), findsWidgets);
      expect(find.text('Dati non disponibili in anteprima'), findsWidgets);
      expect(find.text('Dettagli'), findsOneWidget);
      expect(find.text('Esci dall’account'), findsNothing);
    });
  });

  group('Extra preview catalogo', () {
    testWidgets('catalogo non mostra CTA Acquista attiva', (tester) async {
      studentAreaPreviewActiveMode.value = StudentAreaMode.staffPreview;
      addTearDown(() => studentAreaPreviewActiveMode.value = null);

      await tester.pumpWidget(const MaterialApp(home: ExtraPage()));
      await tester.pump();

      expect(find.text('Acquista'), findsNothing);
      expect(find.text('Anteprima'), findsWidgets);
    });
  });

  test('preview mode si resetta dopo tearDown notifier', () {
    studentAreaPreviewActiveMode.value = StudentAreaMode.staffPreview;
    expect(studentAreaPreviewActiveMode.value, StudentAreaMode.staffPreview);
    studentAreaPreviewActiveMode.value = null;
    expect(studentAreaPreviewActiveMode.value, isNull);
  });
}
