import '../app_root_navigator.dart';
import '../repositories/student_auth_registry.dart';

/// Logout Supabase + stato locale (già in repository), poi rimuove tutte le route
/// sopra la prima così [AppAuthGate] mostra la Welcome senza schermate residue.
Future<void> signOutAndReturnToWelcome() async {
  await studentAuthRepository.signOut();
  appRootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
}
