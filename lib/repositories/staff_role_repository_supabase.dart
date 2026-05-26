import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../domain/staff/staff_school_role.dart';
import 'staff_role_repository.dart';

/// Legge `school_user_roles` per `auth.uid()`.
class StaffRoleRepositorySupabase implements StaffRoleRepository {
  StaffRoleRepositorySupabase._();

  static final StaffRoleRepositorySupabase instance =
      StaffRoleRepositorySupabase._();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non configurato.');
    }
    return Supabase.instance.client;
  }

  @override
  Future<StaffSchoolRole?> resolveCurrentUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('school_user_roles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row == null) return null;

    final raw = row['role'] as String?;
    return _mapRole(raw);
  }

  StaffSchoolRole? _mapRole(String? raw) {
    switch (raw) {
      case 'school_admin':
      case 'admin':
        return StaffSchoolRole.schoolAdmin;
      case 'staff':
        return StaffSchoolRole.staff;
      case 'instructor':
        return StaffSchoolRole.instructor;
      case 'student':
      default:
        return null;
    }
  }
}
