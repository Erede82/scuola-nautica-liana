import '../models/student_registration.dart';
import 'student_auth_repository.dart';

/// Backend assente: nessun login reale finché non si compilano `SUPABASE_URL` e `SUPABASE_ANON_KEY`.
class StudentAuthRepositoryUnavailable implements StudentAuthRepository {
  StudentAuthRepositoryUnavailable._();

  static final StudentAuthRepositoryUnavailable instance =
      StudentAuthRepositoryUnavailable._();

  static const String _msg =
      'Supabase non è configurato. Aggiungi SUPABASE_URL e SUPABASE_ANON_KEY '
      'alla build (es. flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...).';

  @override
  Future<StudentRegistrationResult> register(
    StudentRegistrationRequest request,
  ) async {
    return StudentRegistrationResult.error(_msg);
  }

  @override
  Future<StudentLoginResult> signIn({
    required String email,
    required String password,
  }) async {
    return StudentLoginResult.error(_msg);
  }

  @override
  Future<void> restoreSessionIfAvailable() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> requestPasswordReset({required String email}) async {
    return _msg;
  }

  @override
  Future<void> signInWithGoogle() async {
    throw UnsupportedError(_msg);
  }
}
