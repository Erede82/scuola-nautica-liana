import 'package:flutter/material.dart';

import '../pages/admin_home_page.dart';
import '../pages/backoffice/backoffice_entry_page.dart';
import '../services/auth_identity.dart';
import '../services/staff_access_service.dart';
import 'admin_access_utils.dart';

/// Ritorno dall'area allievo al pannello staff/admin (preview area cliente).
void returnToAdministrativePanel(
  BuildContext context,
  StaffAccessSnapshot snap,
) {
  final isAdmin = AdminAccessUtils.isSchoolAdmin(
    email: AuthIdentity.resolvedAccountEmail(),
    staffRole: snap.staffRole,
  );

  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
    return;
  }

  nav.pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => isAdmin
          ? const AdminHomePage()
          : const BackofficeEntryPage(),
    ),
  );
}
