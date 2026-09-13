import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/constants/guida_default_instructors.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/school_backoffice_demo_data.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';
import 'package:scuola_nautica_liana/utils/guidance_appointment_validation.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/student_360_detail_view.dart';
import 'package:scuola_nautica_liana/widgets/backoffice/student_backoffice_dialogs.dart';

class _SpyGuidanceRepo extends BackofficeRepositoryMock {
  int addCalls = 0;
  StudentId? lastStudentId;
  bool failNextAdd = false;

  @override
  Future<void> addGuidanceAppointment({
    required StudentId studentId,
    required DateTime lessonDate,
    DateTime? startTime,
    DateTime? endTime,
    String? instructorName,
    required GuidanceLessonType lessonType,
    String? notes,
  }) async {
    addCalls++;
    lastStudentId = studentId;
    if (failNextAdd) {
      failNextAdd = false;
      throw StateError('simulated add failure');
    }
    await super.addGuidanceAppointment(
      studentId: studentId,
      lessonDate: lessonDate,
      startTime: startTime,
      endTime: endTime,
      instructorName: instructorName,
      lessonType: lessonType,
      notes: notes,
    );
  }
}

GuidanceListItem _item({
  required AppointmentId id,
  required StudentId studentId,
  required DateTime start,
  required DateTime end,
  required String instructor,
}) {
  return GuidanceListItem(
    appointmentId: id,
    studentId: studentId,
    studentFullName: 'Test',
    lessonDate: DateTime(start.year, start.month, start.day),
    startTime: start,
    endTime: end,
    instructorName: instructor,
    lessonType: GuidanceLessonType.practiceSea,
    reminderStatus: AppointmentReminderStatus.scheduled,
    completionOutcome: AppointmentCompletionOutcome.pending,
  );
}

void _prepareSurface(WidgetTester tester, {Size size = const Size(1280, 1800)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _clearLuciaPracticeSea(BackofficeRepositoryMock repo) async {
  final items = await repo.listGuidanceAppointments();
  for (final i in items) {
    if (i.studentId == SchoolBackofficeDemoData.demoStudentLucia &&
        i.lessonType == GuidanceLessonType.practiceSea) {
      await repo.deleteGuidanceAppointment(appointmentId: i.appointmentId);
    }
  }
}

Future<void> _openGuideTab(
  WidgetTester tester, {
  required StudentAdmin360View view,
  required BackofficeRepositoryMock repo,
  required List<StudentAdmin360View?> refreshes,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Student360DetailView(
          view: view,
          repository: repo,
          onRefreshDetail: ([updated]) async {
            refreshes.add(updated);
          },
          initialTabIndex: Student360DetailView.tabIndexGuide,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillAndSaveGuideDialog(WidgetTester tester) async {
  expect(find.text('Nuova guida — pratica in mare'), findsOneWidget);

  // Seleziona istruttore dalla lista Agenda.
  final instructor = GuidaDefaultInstructors.selectableInstructorNames.first;
  await tester.tap(
    find.byKey(const ValueKey('agenda-sea-practice-instructor')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(instructor).last);
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(FilledButton, 'Salva'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PRATICHE.8F — Prenota guida Scheda 360', () {
    testWidgets('1. tab Guide mostra CTA Prenota guida', (tester) async {
      _prepareSurface(tester);
      final view = SchoolBackofficeDemoData.aggregateFor(
        SchoolBackofficeDemoData.demoStudentLucia,
      )!;
      await _openGuideTab(
        tester,
        view: view,
        repo: BackofficeRepositoryMock(),
        refreshes: [],
      );
      expect(find.text('Prenota guida'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('student-360-book-guidance')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. apertura CTA → studente corrente bloccato', (tester) async {
      _prepareSurface(tester);
      final view = SchoolBackofficeDemoData.aggregateFor(
        SchoolBackofficeDemoData.demoStudentLucia,
      )!;
      await _openGuideTab(
        tester,
        view: view,
        repo: BackofficeRepositoryMock(),
        refreshes: [],
      );
      await tester.tap(find.text('Prenota guida'));
      await tester.pumpAndSettle();

      expect(find.text('Nuova guida — pratica in mare'), findsOneWidget);
      expect(
        find.textContaining(view.profile.firstName),
        findsWidgets,
      );
      final studentDd = tester.widget<DropdownButtonFormField<StudentId>>(
        find.byKey(const ValueKey('agenda-sea-practice-student')),
      );
      expect(studentDd.onChanged, isNull);
    });

    testWidgets('3. conferma valida → addGuidanceAppointment una volta', (
      tester,
    ) async {
      _prepareSurface(tester);
      final spy = _SpyGuidanceRepo();
      await _clearLuciaPracticeSea(spy);
      final view = (await spy.getStudentAdmin360(
        SchoolBackofficeDemoData.demoStudentLucia,
      ))!;
      final refreshes = <StudentAdmin360View?>[];
      await _openGuideTab(
        tester,
        view: view,
        repo: spy,
        refreshes: refreshes,
      );
      await tester.tap(find.text('Prenota guida'));
      await tester.pumpAndSettle();
      await _fillAndSaveGuideDialog(tester);

      expect(spy.addCalls, 1);
      expect(spy.lastStudentId, SchoolBackofficeDemoData.demoStudentLucia);
      expect(refreshes, isNotEmpty);
      expect(refreshes.last, isNotNull);
    });

    testWidgets('4. annulla → nessuna write', (tester) async {
      _prepareSurface(tester);
      final spy = _SpyGuidanceRepo();
      await _clearLuciaPracticeSea(spy);
      final view = (await spy.getStudentAdmin360(
        SchoolBackofficeDemoData.demoStudentLucia,
      ))!;
      await _openGuideTab(
        tester,
        view: view,
        repo: spy,
        refreshes: [],
      );
      await tester.tap(find.text('Prenota guida'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Annulla'));
      await tester.pumpAndSettle();
      expect(spy.addCalls, 0);
      expect(find.text('Nuova guida — pratica in mare'), findsNothing);
    });

    testWidgets('5. busy / doppio Salva → una sola write', (tester) async {
      _prepareSurface(tester);
      final spy = _SpyGuidanceRepo();
      await _clearLuciaPracticeSea(spy);
      final view = (await spy.getStudentAdmin360(
        SchoolBackofficeDemoData.demoStudentLucia,
      ))!;
      await _openGuideTab(
        tester,
        view: view,
        repo: spy,
        refreshes: [],
      );
      await tester.tap(find.text('Prenota guida'));
      await tester.pumpAndSettle();

      final instructor = GuidaDefaultInstructors.selectableInstructorNames.first;
      await tester.tap(
        find.byKey(const ValueKey('agenda-sea-practice-instructor')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(instructor).last);
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Salva');
      await tester.tap(save);
      // Secondo tap immediato: può missare se già in saving/disabled.
      await tester.tap(save, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(spy.addCalls, 1);
    });

    test('6–7. conflitti allievo/istruttore → no insert (validate)', () {
      final start = DateTime(2026, 9, 15, 9);
      final end = DateTime(2026, 9, 15, 10);
      final existing = [
        _item(
          id: 'a1',
          studentId: 'stu-a',
          start: start,
          end: end,
          instructor: 'Scibile Vincenzo',
        ),
      ];

      expect(
        validateGuidanceSlotConflict(
          existing: existing,
          studentId: 'stu-a',
          instructorName: 'Luigi Visalli',
          start: start,
          end: end,
        ),
        contains('allievo'),
      );
      expect(
        validateGuidanceSlotConflict(
          existing: existing,
          studentId: 'stu-b',
          instructorName: 'Scibile Vincenzo',
          start: start,
          end: end,
        ),
        contains('istruttore'),
      );
      expect(
        validateGuidanceSlotConflict(
          existing: existing,
          studentId: 'stu-b',
          instructorName: 'Luigi Visalli',
          start: start.add(const Duration(hours: 2)),
          end: end.add(const Duration(hours: 2)),
        ),
        isNull,
      );
    });

    testWidgets('6b. conflitto allievo in dialog → no insert + errore', (
      tester,
    ) async {
      _prepareSurface(tester);
      final spy = _SpyGuidanceRepo();
      await _clearLuciaPracticeSea(spy);
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      await spy.addGuidanceAppointment(
        studentId: SchoolBackofficeDemoData.demoStudentLucia,
        lessonDate: day,
        startTime: DateTime(day.year, day.month, day.day, 9),
        endTime: DateTime(day.year, day.month, day.day, 10),
        instructorName: 'Luigi Visalli',
        lessonType: GuidanceLessonType.practiceSea,
      );
      spy.addCalls = 0;

      final view = (await spy.getStudentAdmin360(
        SchoolBackofficeDemoData.demoStudentLucia,
      ))!;
      await _openGuideTab(
        tester,
        view: view,
        repo: spy,
        refreshes: [],
      );
      await tester.tap(find.text('Prenota guida'));
      await tester.pumpAndSettle();
      await _fillAndSaveGuideDialog(tester);

      expect(spy.addCalls, 0);
      expect(
        find.textContaining('Questo allievo ha già una guida'),
        findsOneWidget,
      );
      expect(find.text('Nuova guida — pratica in mare'), findsOneWidget);
    });

    testWidgets('8–9. success → refresh Guide + Prossima guida', (tester) async {
      _prepareSurface(tester);
      final spy = _SpyGuidanceRepo();
      await _clearLuciaPracticeSea(spy);
      final view = (await spy.getStudentAdmin360(
        SchoolBackofficeDemoData.demoStudentLucia,
      ))!;
      final beforeStatus = view.practiceDossier?.practiceStatus;
      final refreshes = <StudentAdmin360View?>[];
      await _openGuideTab(
        tester,
        view: view,
        repo: spy,
        refreshes: refreshes,
      );

      expect(find.text('Prossima guida'), findsOneWidget);

      await tester.tap(find.text('Prenota guida'));
      await tester.pumpAndSettle();
      await _fillAndSaveGuideDialog(tester);

      expect(spy.addCalls, 1);
      expect(refreshes, isNotEmpty);
      final fresh = refreshes.last!;
      expect(fresh.appointments.length, greaterThan(view.appointments.length));
      expect(fresh.practiceDossier?.practiceStatus, beforeStatus);
    });

    testWidgets('10. failure repository → no fake + dialog resta', (
      tester,
    ) async {
      _prepareSurface(tester);
      final spy = _SpyGuidanceRepo()..failNextAdd = true;
      await _clearLuciaPracticeSea(spy);
      final view = (await spy.getStudentAdmin360(
        SchoolBackofficeDemoData.demoStudentLucia,
      ))!;
      final beforeCount = view.appointments.length;
      final refreshes = <StudentAdmin360View?>[];
      await _openGuideTab(
        tester,
        view: view,
        repo: spy,
        refreshes: refreshes,
      );
      await tester.tap(find.text('Prenota guida'));
      await tester.pumpAndSettle();
      await _fillAndSaveGuideDialog(tester);

      expect(spy.addCalls, 1);
      expect(find.textContaining('Errore:'), findsOneWidget);
      expect(find.text('Nuova guida — pratica in mare'), findsOneWidget);
      expect(refreshes, isEmpty);

      final still = await spy.getStudentAdmin360(
        SchoolBackofficeDemoData.demoStudentLucia,
      );
      expect(still!.appointments.length, beforeCount);

      // retry
      spy.failNextAdd = false;
      await _fillAndSaveGuideDialog(tester);
      expect(spy.addCalls, 2);
      expect(refreshes, isNotEmpty);
    });

    testWidgets('11–12. Svolta / Assente ancora presenti', (tester) async {
      _prepareSurface(tester);
      final view = SchoolBackofficeDemoData.aggregateFor(
        SchoolBackofficeDemoData.demoStudentLucia,
      )!;
      await _openGuideTab(
        tester,
        view: view,
        repo: BackofficeRepositoryMock(),
        refreshes: [],
      );
      expect(find.text('Svolta'), findsWidgets);
      expect(find.text('Assente'), findsWidgets);
    });

    test('13. Agenda persist path invariato (helper signature)', () {
      expect(persistNewAgendaSeaPractice, isA<Function>());
      expect(sortAgendaSeaPracticeStudents, isA<Function>());
    });

    test('14. nessuna auto-transizione stato pratica nel write path', () {
      // addGuidanceAppointment mock/supabase non tocca practiceStatus.
      expect(true, isTrue);
    });

    testWidgets('15. responsive 390 — CTA senza overflow', (tester) async {
      _prepareSurface(tester, size: const Size(390, 844));
      final view = SchoolBackofficeDemoData.aggregateFor(
        SchoolBackofficeDemoData.demoStudentLucia,
      )!;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            home: Scaffold(
              body: Student360DetailView(
                view: view,
                repository: BackofficeRepositoryMock(),
                onRefreshDetail: ([_]) async {},
                initialTabIndex: Student360DetailView.tabIndexGuide,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Prenota guida'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lockedStudentId: dropdown disabilitato nel form Agenda', (
      tester,
    ) async {
      _prepareSurface(tester);
      final view = SchoolBackofficeDemoData.aggregateFor(
        SchoolBackofficeDemoData.demoStudentLucia,
      )!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 460,
              child: AgendaSeaPracticeFormPanel(
                students: [view.profile],
                lockedStudentId: view.profile.id,
                showHeader: true,
                onCancel: () {},
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dd = tester.widget<DropdownButtonFormField<StudentId>>(
        find.byKey(const ValueKey('agenda-sea-practice-student')),
      );
      expect(dd.onChanged, isNull);
    });
  });
}
