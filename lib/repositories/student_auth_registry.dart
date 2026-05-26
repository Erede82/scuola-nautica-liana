import '../config/supabase_config.dart';
import 'student_auth_repository.dart';
import 'student_auth_repository_supabase.dart';
import 'student_auth_repository_unavailable.dart';

/// Punto unico per ottenere l’implementazione [StudentAuthRepository].
///
/// - **Supabase** se `SUPABASE_URL` e `SUPABASE_ANON_KEY` sono definiti (vedi [SupabaseConfig]).
/// - Altrimenti [StudentAuthRepositoryUnavailable] (messaggi espliciti, nessun mock silenzioso).
StudentAuthRepository get studentAuthRepository =>
    SupabaseConfig.isConfigured
        ? StudentAuthRepositorySupabase.instance
        : StudentAuthRepositoryUnavailable.instance;
