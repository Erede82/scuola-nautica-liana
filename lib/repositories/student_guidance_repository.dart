import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/guida_reminder_mapper.dart';
import '../data/supabase/dto/backoffice_rows.dart';
import '../data/supabase/mappers/backoffice_row_mappers.dart';
import '../models/guida_reminder.dart';

/// Lettura promemoria Guida per l’allievo corrente (tabella `guidance_appointments`).
abstract class StudentGuidanceRepository {
  Future<List<GuidaReminder>> listForStudent(String studentId);
}

class StudentGuidanceRepositorySupabase implements StudentGuidanceRepository {
  StudentGuidanceRepositorySupabase._();

  static final StudentGuidanceRepositorySupabase instance =
      StudentGuidanceRepositorySupabase._();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non inizializzato.');
    }
    return Supabase.instance.client;
  }

  static const _selectColumns =
      'id, student_id, lesson_date, start_time, end_time, instructor_name, '
      'instructor_staff_id, lesson_type, reminder_status, completion_outcome, notes';

  @override
  Future<List<GuidaReminder>> listForStudent(String studentId) async {
    final res = await _client
        .from('guidance_appointments')
        .select(_selectColumns)
        .eq('student_id', studentId)
        .order('lesson_date', ascending: false)
        .order('start_time', ascending: false);

    final rawList = res as List<dynamic>;
    if (rawList.isEmpty) return const [];

    final out = <GuidaReminder>[];
    for (final e in rawList) {
      try {
        final row = GuidanceAppointmentRow.fromJson(
          Map<String, dynamic>.from(e as Map),
        );
        final appointment = mapGuidanceRowToDomain(row);
        out.add(GuidaReminderMapper.fromAppointment(appointment));
      } catch (err, st) {
        debugPrint(
          'StudentGuidanceRepository.listForStudent: riga non mappabile: '
          '$err\n$st',
        );
      }
    }
    return out;
  }
}

class StudentGuidanceRepositoryEmpty implements StudentGuidanceRepository {
  const StudentGuidanceRepositoryEmpty();

  @override
  Future<List<GuidaReminder>> listForStudent(String studentId) async =>
      const [];
}

StudentGuidanceRepository get studentGuidanceRepository {
  if (SupabaseConfig.isConfigured) {
    return StudentGuidanceRepositorySupabase.instance;
  }
  return const StudentGuidanceRepositoryEmpty();
}
