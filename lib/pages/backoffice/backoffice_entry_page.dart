import 'package:flutter/material.dart';

import '../../widgets/staff/staff_access_gate.dart';
import 'school_management_shell_page.dart';

/// Ingresso protetto al backoffice allievi (ruolo staff + sessione).
class BackofficeEntryPage extends StatelessWidget {
  const BackofficeEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StaffAccessGate(
      showStaffWelcomeSnack: true,
      gateTitle: 'Backoffice scuola',
      child: const SchoolManagementShellPage(),
    );
  }
}
