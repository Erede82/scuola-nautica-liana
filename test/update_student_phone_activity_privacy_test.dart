import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/data/backoffice_mock/backoffice_demo_store.dart';
import 'package:scuola_nautica_liana/repositories/backoffice/backoffice_repository_mock.dart';

void main() {
  test(
    'updateStudentPhone: activity log senza numero completo o nazionale',
    () async {
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

      final repo = BackofficeRepositoryMock();
      await repo.updateStudentPhone(
        studentId: studentId,
        phoneE164: '+393331234567',
        phoneCountryIso2: 'IT',
      );

      final view = await repo.getStudentAdmin360(studentId);
      expect(view, isNotNull);
      final events = view!.activityLog
          .where((e) => e.title == 'Cellulare aggiornato')
          .toList();
      expect(events, isNotEmpty);

      final latest = events.first;
      expect(latest.title, 'Cellulare aggiornato');
      expect(latest.description, isNull);

      final blob = '${latest.title}\n${latest.description ?? ''}';
      expect(blob, isNot(contains('+393331234567')));
      expect(blob, isNot(contains('3331234567')));
      expect(blob, isNot(contains(previousPhone ?? '___')));
    },
  );
}
