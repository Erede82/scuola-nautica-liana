import '../config/supabase_config.dart';
import 'staff_role_repository.dart';
import 'staff_role_repository_mock.dart';
import 'staff_role_repository_supabase.dart';

/// Repository ruolo staff — **Supabase** se configurato, altrimenti mock (solo debug).
StaffRoleRepository get staffRoleRepository => SupabaseConfig.isConfigured
    ? StaffRoleRepositorySupabase.instance
    : StaffRoleRepositoryMock.instance;
