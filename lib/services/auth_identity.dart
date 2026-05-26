import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'demo_student_enrollment.dart';

/// Identità account senza accedere ai widget: email e presenza JWT.
abstract final class AuthIdentity {
  /// Email dell’utente autenticato Supabase, se presente.
  static String? supabaseAuthEmail() {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client.auth.currentUser?.email;
  }

  /// True se c’è un utente JWT Supabase attivo.
  static bool hasSupabaseJwt() {
    if (!SupabaseConfig.isConfigured) return false;
    return Supabase.instance.client.auth.currentUser != null;
  }

  /// Email da mostrare in UI: prima Supabase, poi sessione studente mock.
  static String? resolvedAccountEmail() {
    final supa = supabaseAuthEmail();
    if (supa != null && supa.isNotEmpty) return supa;
    return studentSession.value?.email;
  }
}
