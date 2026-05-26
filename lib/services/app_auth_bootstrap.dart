import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../repositories/student_auth_registry.dart';
import 'staff_access_service.dart';

/// Avvio sessione: JWT aggiornato se scaduto, poi ripristino profilo studente, poi permessi staff.
///
/// Ordine fisso per evitare race: dopo [Supabase.initialize], [recoverSession] del package
/// può essere ancora in corso; con access token scaduto le letture DB falliscono senza
/// un refresh esplicito. Poi [StudentAuthRepository.restoreSessionIfAvailable],
/// infine [initializeStaffAccess].
Future<void> bootstrapAppAuth() async {
  if (SupabaseConfig.isConfigured) {
    await refreshSupabaseSessionIfExpired();
  }
  await studentAuthRepository.restoreSessionIfAvailable();
  await initializeStaffAccess();
}

/// Se la sessione locale ha JWT scaduto, rinfresca prima delle query protette.
///
/// Chiamare dopo [Supabase.initialize]: il package avvia [recoverSession] in background
/// senza attendere; senza refresh esplicito le letture iniziali possono fallire.
Future<void> refreshSupabaseSessionIfExpired() async {
  if (!SupabaseConfig.isConfigured) return;
  final auth = Supabase.instance.client.auth;
  final session = auth.currentSession;
  if (session == null) return;
  if (!session.isExpired) return;
  try {
    await auth.refreshSession();
  } catch (e, st) {
    debugPrint('[AUTH bootstrap] refreshSession: $e\n$st');
  }
}
