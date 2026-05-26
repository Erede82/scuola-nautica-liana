import '../models/student_registration.dart';

/// Registrazione e sessione studente — implementazione mock o Supabase.
///
/// **Supabase:** `signUp` / `signInWithPassword`, RPC `register_student_app`, fetch `students`.
///
/// Il profilo allievo è **opzionale**: account solo staff possono accedere senza riga in `students`
/// (vedi [StudentLoginResult.hasStudentProfile] e [bootstrapAppAuth]).
abstract class StudentAuthRepository {
  Future<StudentRegistrationResult> register(StudentRegistrationRequest request);

  /// Accesso con email e password (Supabase Auth o mock).
  Future<StudentLoginResult> signIn({
    required String email,
    required String password,
  });

  /// Ripristina sessione app se Supabase ha già una sessione persistita (avvio app).
  Future<void> restoreSessionIfAvailable();

  /// Invalida sessione (Supabase `signOut` o mock).
  Future<void> signOut();

  /// Invio email di recupero password (solo Supabase operativo).
  /// Esito: `null` = richiesta accettata; altrimenti messaggio errore da mostrare.
  Future<String?> requestPasswordReset({required String email});

  /// OAuth Google (solo Supabase). Su mobile apre il browser; la sessione arriva al ritorno.
  Future<void> signInWithGoogle();
}
