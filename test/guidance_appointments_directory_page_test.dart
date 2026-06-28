import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/domain/backoffice/backoffice.dart';
import 'package:scuola_nautica_liana/pages/backoffice/guidance_appointments_directory_page.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository.dart';

void main() {
  testWidgets('renders appointments when student preload fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuidanceAppointmentsDirectoryPage(
            embedded: true,
            repository: _FailingStudentPreloadRepository(),
            onOpenStudent360: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Mario Rossi'), findsOneWidget);
    expect(
      find.textContaining('Impossibile caricare gli appuntamenti'),
      findsNothing,
    );
  });
}

class _FailingStudentPreloadRepository implements BackofficeRepository {
  @override
  Future<List<GuidanceListItem>> listGuidanceAppointments() async {
    final now = DateTime.now();
    final appointmentDay = DateTime(now.year, now.month, now.day);
    return [
      GuidanceListItem(
        appointmentId: 'appt-1',
        studentId: 'student-1',
        studentFullName: 'Mario Rossi',
        lessonDate: appointmentDay,
        startTime: DateTime(
          appointmentDay.year,
          appointmentDay.month,
          appointmentDay.day,
          10,
        ),
        endTime: DateTime(
          appointmentDay.year,
          appointmentDay.month,
          appointmentDay.day,
          11,
        ),
        lessonType: GuidanceLessonType.practiceSea,
        reminderStatus: AppointmentReminderStatus.none,
        completionOutcome: AppointmentCompletionOutcome.pending,
      ),
    ];
  }

  @override
  Future<List<StudentProfile>> listStudentProfiles() {
    return Future<List<StudentProfile>>.error(
      StateError('profiles unavailable'),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
