import '../domain/staff/staff_school_role.dart';
import 'staff_role_repository.dart';

/// Nessun backend: [resolveCurrentUserRole] non è usato quando la logica è nel
/// [StaffAccessService] (modalità senza Supabase). Mantenuto per coerenza registry.
class StaffRoleRepositoryMock implements StaffRoleRepository {
  StaffRoleRepositoryMock._();

  static final StaffRoleRepositoryMock instance = StaffRoleRepositoryMock._();

  @override
  Future<StaffSchoolRole?> resolveCurrentUserRole() async => null;
}
