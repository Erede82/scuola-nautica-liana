import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import 'dto/staff_student_quiz_statistics_rpc_payload.dart';

const String kStaffStudentQuizStatisticsRpcName =
    'get_staff_student_quiz_statistics_inputs';

/// Lettura staff stats inputs — SOLO via RPC SECURITY DEFINER.
abstract class StaffStudentQuizStatisticsDataSource {
  Future<StaffStudentQuizStatisticsRpcPayload> fetchInputs({
    required String studentId,
    required String licenseCategoryDb,
  });
}

class StaffStudentQuizStatisticsDataSourceSupabase
    implements StaffStudentQuizStatisticsDataSource {
  StaffStudentQuizStatisticsDataSourceSupabase({SupabaseClient? client})
    : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolved {
    final injected = _client;
    if (injected != null) return injected;
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non configurato');
    }
    return Supabase.instance.client;
  }

  @override
  Future<StaffStudentQuizStatisticsRpcPayload> fetchInputs({
    required String studentId,
    required String licenseCategoryDb,
  }) async {
    final raw = await _resolved.rpc(
      kStaffStudentQuizStatisticsRpcName,
      params: {
        'p_student_id': studentId,
        'p_license_category': licenseCategoryDb,
      },
    );
    return StaffStudentQuizStatisticsRpcPayload.fromJson(raw);
  }
}
