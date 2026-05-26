import '../data/backoffice_mock/backoffice_demo_store.dart';
import '../domain/backoffice/backoffice.dart';
import '../models/student_registration.dart';
import '../models/student_session.dart';
import '../services/demo_student_enrollment.dart';
import '../services/staff_access_service.dart';
import 'student_auth_repository.dart';

/// Registrazione in memoria: crea [StudentProfile] nel [BackofficeDemoStore] e aggiorna sessione.
///
/// Password tenuta solo in RAM per login mock; **non** usare in produzione così.
class StudentAuthRepositoryMock implements StudentAuthRepository {
  StudentAuthRepositoryMock._({BackofficeDemoStore? store})
      : _store = store ?? backofficeDemoStore;

  static final StudentAuthRepositoryMock instance =
      StudentAuthRepositoryMock._();

  final BackofficeDemoStore _store;

  /// Email (lower) → password — solo per login mock locale.
  final Map<String, String> _registeredPasswords = {};

  @override
  Future<StudentRegistrationResult> register(
    StudentRegistrationRequest request,
  ) async {
    final email = request.email.trim().toLowerCase();
    if (_registeredPasswords.containsKey(email)) {
      return StudentRegistrationResult.error(
        'Questa email risulta già registrata. Accedi o usa un’altra email.',
      );
    }

    final studentId = 'stu-app-${DateTime.now().microsecondsSinceEpoch}';

    final profile = StudentProfile(
      id: studentId,
      firstName: _capitalizeWords(request.firstName.trim()),
      lastName: _capitalizeWords(request.lastName.trim()),
      phone: _normalizePhone(request.phone.trim()),
      email: email,
      enrolledCoursePath: request.enrolledCoursePath,
      registrationStatus: StudentRegistrationStatus.pending,
      onboardingStatus: StudentOnboardingStatus.pendingReview,
      linkedAuthUserId: null,
      internalNotes:
          'Iscrizione da app mobile (ambiente demo / in attesa conferma segreteria).',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      _store.registerStudentProfileFromApp(profile: profile);
    } on DuplicateStudentEmailException {
      return StudentRegistrationResult.error(
        'Questa email risulta già registrata. Accedi o usa un’altra email.',
      );
    }

    _registeredPasswords[email] = request.password;

    final session = StudentSession.fromProfile(profile);
    applyStudentSession(session);

    return StudentRegistrationResult.ok(session);
  }

  @override
  Future<StudentLoginResult> signIn({
    required String email,
    required String password,
  }) async {
    final e = email.trim().toLowerCase();
    if (_registeredPasswords[e] != password) {
      return StudentLoginResult.error('Credenziali non valide.');
    }

    StudentProfile? match;
    for (final p in _store.profiles) {
      if (p.email?.trim().toLowerCase() == e) {
        match = p;
        break;
      }
    }
    if (match == null) {
      return StudentLoginResult.error('Account non trovato.');
    }

    final session = StudentSession.fromProfile(match);
    applyStudentSession(session);
    return StudentLoginResult.ok(session);
  }

  @override
  Future<void> restoreSessionIfAvailable() async {
    // Nessuna persistenza: stato solo in RAM.
  }

  @override
  Future<void> signOut() async {
    clearStudentSession();
    await refreshStaffAccess();
  }

  @override
  Future<String?> requestPasswordReset({required String email}) async {
    return 'Il recupero password non è disponibile senza Supabase collegato.';
  }

  @override
  Future<void> signInWithGoogle() async {
    throw UnsupportedError(
      'Google OAuth non disponibile nel repository mock.',
    );
  }

  String _normalizePhone(String raw) {
    if (raw.isEmpty) return raw;
    return raw;
  }

  String _capitalizeWords(String s) {
    if (s.isEmpty) return s;
    return s.split(RegExp(r'\s+')).map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1).toLowerCase() : ''}';
    }).join(' ');
  }
}
