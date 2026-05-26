import '../constants/admin_dashboard_privileged_login.dart';
import '../domain/staff/staff_school_role.dart';

class AdminAccessUtils {
  static String normalizeEmail(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  static bool isPrivilegedEmail(String? email) {
    return normalizeEmail(email) ==
        normalizeEmail(AdminDashboardPrivilegedLogin.email);
  }

  static bool isSchoolAdmin({
    required String? email,
    required StaffSchoolRole? staffRole,
  }) {
    return isPrivilegedEmail(email) || staffRole == StaffSchoolRole.schoolAdmin;
  }
}
