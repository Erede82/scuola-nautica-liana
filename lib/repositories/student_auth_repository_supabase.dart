import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../data/supabase/dto/backoffice_rows.dart';
import '../data/supabase/mappers/backoffice_row_mappers.dart';
import '../domain/course_taxonomy.dart';
import '../domain/enrollment_content_mapping.dart';
import '../models/student_registration.dart';
import '../models/student_session.dart';
import '../services/auth_flow_state.dart';
import '../services/demo_student_enrollment.dart';
import '../services/staff_access_service.dart';
import '../services/student_study_access_sync.dart';
import 'student_auth_repository.dart';

/// Implementazione Supabase Auth + tabella `students` + RPC `register_student_app`.
///
/// Richiede [SupabaseConfig.initialize] e migrazione `register_student_app`.
class StudentAuthRepositorySupabase implements StudentAuthRepository {
  StudentAuthRepositorySupabase._();

  static final StudentAuthRepositorySupabase instance =
      StudentAuthRepositorySupabase._();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non inizializzato.');
    }
    return Supabase.instance.client;
  }

  @override
  Future<StudentRegistrationResult> register(
    StudentRegistrationRequest request,
  ) async {
    final email = request.email.trim().toLowerCase();

    // Evita che AppAuthGate forzi il logout nella finestra tra signUp e
    // l'idratazione della riga students (race → ritorno alla Welcome).
    registrationInProgress.value = true;

    try {
      _regLog('1 signUp start', 'email=$email');
      final authRes = await _client.auth.signUp(
        email: email,
        password: request.password,
      );

      if (authRes.user == null) {
        _regLog('1 signUp abort', 'user=null');
        return StudentRegistrationResult.error(
          'Registrazione non riuscita. Riprova tra poco.',
        );
      }

      _regLog(
        '1 signUp ok',
        'userId=${authRes.user!.id} session=${authRes.session != null}',
      );

      if (authRes.session == null) {
        _regLog('2 session null', 'conferma email richiesta — signOut locale');
        await _safeSignOut();
        return StudentRegistrationResult.error(
          'Registrazione avviata: controlla la tua email per confermare l’account, '
          'poi accedi. Se la conferma email è disattivata nel progetto Supabase, '
          'contatta l’amministratore.',
        );
      }

      try {
        _regLog('3 rpc register_student_app start');
        await _client.rpc(
          'register_student_app',
          params: {
            'p_first_name': request.firstName.trim(),
            'p_last_name': request.lastName.trim(),
            'p_phone': request.phone.trim(),
            'p_email': email,
            'p_enrolled_course_path': EnrollmentCoursePathStorage.toStorage(
              request.enrolledCoursePath,
            ),
            'p_enrolled_license_category':
                EnrollmentContentMapping.primaryLicenseCategory(
                  request.enrolledCoursePath,
                ).name,
          },
        );
        _regLog('3 rpc register_student_app ok');
      } catch (e, st) {
        _regLog('3 rpc FAILED', '$e\n$st');
        await _safeSignOut();
        return StudentRegistrationResult.error(_mapRegisterRpcError(e));
      }

      StudentSession? session;
      try {
        _regLog('4 hydrate students start');
        session = await _hydrateFromCurrentAuth();
        _regLog(
          '4 hydrate end',
          session != null ? 'studentId=${session.studentId}' : 'session=null',
        );
      } on PostgrestException catch (e, st) {
        _regLog(
          '4 hydrate PostgrestException',
          'code=${e.code} message=${e.message}\n$st',
        );
        await _safeSignOut();
        return StudentRegistrationResult.error(_mapHydrateOrReadError(e));
      } catch (e, st) {
        _regLog('4 hydrate FAILED', '$e\n$st');
        await _safeSignOut();
        return StudentRegistrationResult.error(
          _mapUnexpectedAfterAuthUserCreated(e),
        );
      }

      if (session == null) {
        _regLog(
          '5 profilo assente',
          'nessuna riga students per auth.uid (RLS vuoto o RPC non eseguito)',
        );
        await _safeSignOut();
        return StudentRegistrationResult.error(
          'Profilo allievo non creato o non visibile. '
          'L’account potrebbe essere stato creato senza completare l’iscrizione: '
          'contatta la segreteria o riprova ad accedere.',
        );
      }

      try {
        _regLog('6 apply + sync + staff refresh start');
        applyStudentSession(session);
        await syncStudyAccessFromSupabaseForStudent(session.studentId);
        await refreshStaffAccess();
        _regLog('6 completata');
      } catch (e, st) {
        _regLog('6 post-idratazione FAILED', '$e\n$st');
        await _safeSignOut();
        return StudentRegistrationResult.error(
          _mapUnexpectedAfterAuthUserCreated(e),
        );
      }

      return StudentRegistrationResult.ok(session);
    } on AuthException catch (e, st) {
      _regLog('AuthException', '${e.message} (code=${e.statusCode})\n$st');
      return StudentRegistrationResult.error(_mapAuthError(e));
    } catch (e, st) {
      _regLog('register FATAL (fuori dai passi noti)', '$e\n$st');
      await _safeSignOut();
      return StudentRegistrationResult.error(
        _mapUnexpectedRegistrationOuter(e),
      );
    } finally {
      registrationInProgress.value = false;
    }
  }

  @override
  Future<StudentLoginResult> signIn({
    required String email,
    required String password,
  }) async {
    final e = email.trim().toLowerCase();
    try {
      await _client.auth.signInWithPassword(email: e, password: password);
    } on AuthException catch (err) {
      debugPrint(
        '[AUTH signInWithPassword] status=${err.statusCode} message=${err.message}',
      );
      return StudentLoginResult.error(_mapAuthError(err));
    } catch (e, st) {
      _logSignIn('signInWithPassword eccezione non-Auth', '$e\n$st');
      if (_looksLikeNetworkError(e)) {
        return StudentLoginResult.error(_loginNetworkErrorMessage());
      }
      return StudentLoginResult.error(
        'Accesso non riuscito. Riprova tra poco o contatta la segreteria.',
      );
    }

    StudentSession? studentSession;
    Object? hydrateFailure;
    try {
      studentSession = await _hydrateFromCurrentAuth();
    } catch (e, st) {
      hydrateFailure = e;
      if (e is PostgrestException) {
        _logPostgrestException('[AUTH signIn] hydrate catch', e, st);
      } else {
        _logSignIn('hydrate ERRORE', 'runtimeType=${e.runtimeType} | $e\n$st');
      }
      studentSession = null;
    }

    if (studentSession != null) {
      applyStudentSession(studentSession);
      await syncStudyAccessFromSupabaseForStudent(studentSession.studentId);
    } else {
      clearStudentSession();
    }

    await refreshStaffAccess();

    final snap = staffAccessNotifier.value;
    if (studentSession == null && snap.staffRole == null) {
      await _safeSignOut();
      final msg = _loginDeniedNoStudentNoStaffMessage(hydrateFailure);
      _logSignIn('accesso negato', msg);
      return StudentLoginResult.error(msg);
    }

    return StudentLoginResult.ok(studentSession);
  }

  @override
  Future<void> restoreSessionIfAvailable() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        clearStudentSession();
        return;
      }
      final session = await _hydrateFromCurrentAuth();
      if (session != null) {
        applyStudentSession(session);
        await syncStudyAccessFromSupabaseForStudent(session.studentId);
      } else {
        clearStudentSession();
      }
    } catch (e, st) {
      debugPrint('[AUTH session] restoreSessionIfAvailable FAILED: $e\n$st');
      clearStudentSession();
    }
  }

  @override
  Future<void> signOut() async {
    await _safeSignOut();
    clearStudentSession();
    await refreshStaffAccess();
  }

  @override
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: SupabaseConfig.oauthRedirectUrl,
    );
  }

  @override
  Future<String?> requestPasswordReset({required String email}) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) {
      return 'Inserisci l’email.';
    }
    try {
      await _client.auth.resetPasswordForEmail(
        e,
        redirectTo: SupabaseConfig.oauthRedirectUrl,
      );
      return null;
    } on AuthException catch (err) {
      return _mapAuthError(err);
    } catch (_) {
      return 'Impossibile inviare l’email. Verifica la rete e riprova.';
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }

  /// Log diagnostico completo per errori PostgREST (es. 500 sul `select` students).
  void _logPostgrestException(
    String prefix,
    PostgrestException e,
    StackTrace st,
  ) {
    debugPrint(
      '$prefix | PostgrestException '
      'code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}',
    );
    debugPrint('$prefix | stackTrace: $st');
  }

  Future<StudentSession?> _hydrateFromCurrentAuth() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('students')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
    } on PostgrestException catch (e, st) {
      _logPostgrestException('[AUTH hydrate] query students fallita', e, st);
      rethrow;
    }

    if (row == null) {
      return null;
    }

    try {
      final profile = mapStudentRowToProfile(
        StudentRow.fromJson(Map<String, dynamic>.from(row)),
      );
      final session = StudentSession.fromProfile(profile);
      return session;
    } catch (e, st) {
      debugPrint(
        '[AUTH hydrate] ERRORE map/fromJson | runtimeType=${e.runtimeType} | '
        '$e\n$st',
      );
      rethrow;
    }
  }

  String _mapAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    final code = e.statusCode;
    if (msg.contains('invalid login') ||
        msg.contains('invalid_credentials') ||
        msg.contains('invalid credential') ||
        code == 'invalid_credentials' ||
        msg.contains('wrong password') ||
        msg.contains('email or password')) {
      return 'Email o password non corrette';
    }
    if (msg.contains('email not confirmed') ||
        msg.contains('email_not_confirmed')) {
      return _loginEmailNotConfirmedMessage();
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered')) {
      return 'Questa email è già registrata. Accedi o usa il recupero password.';
    }
    if (msg.contains('jwt') || msg.contains('token')) {
      return 'Errore auth Supabase: ${e.message}';
    }
    return 'Email o password non corrette';
  }

  String _mapRegisterRpcError(Object e) {
    if (e is PostgrestException) {
      final m = e.message.toLowerCase();
      final code = e.code;
      if (code == 'PGRST202' ||
          (m.contains('could not find') &&
              m.contains('register_student_app')) ||
          m.contains('schema cache')) {
        return 'Registrazione non disponibile sul server. Contatta la segreteria.';
      }
      if (m.contains('student_already_registered')) {
        return 'Profilo già registrato per questo account.';
      }
      if (m.contains('invalid_enrolled')) {
        return 'Percorso di iscrizione non valido.';
      }
      if (m.contains('not_authenticated')) {
        return 'Sessione scaduta. Riprova dalla registrazione.';
      }
    }
    final raw = e.toString().toLowerCase();
    if (raw.contains('pgrst202') ||
        raw.contains('register_student_app') &&
            raw.contains('could not find')) {
      return 'Registrazione non disponibile sul server. Contatta la segreteria.';
    }
    return 'Registrazione non completata. Contatta la segreteria.';
  }

  void _regLog(String step, [String? detail]) {
    debugPrint('[REG] $step${detail != null ? ' | $detail' : ''}');
  }

  void _logSignIn(String step, [String? detail]) {
    debugPrint('[AUTH signIn] $step${detail != null ? ' | $detail' : ''}');
  }

  /// Lettura `students` dopo RPC: permessi RLS, colonna mancante, ecc.
  String _mapHydrateOrReadError(PostgrestException e) {
    final m = e.message.toLowerCase();
    final code = e.code ?? '';
    if (code == 'PGRST301' ||
        m.contains('permission denied') ||
        m.contains('rls') ||
        m.contains('row-level security')) {
      return _loginStudentsRlsOrPermissionMessage();
    }
    if (_looksLikeNetworkError(e)) {
      return _loginNetworkErrorMessage();
    }
    return 'Errore nel caricamento del profilo (${e.code ?? '?'}). Contatta la segreteria.';
  }

  String _mapUnexpectedAfterAuthUserCreated(Object e) {
    if (_looksLikeNetworkError(e)) {
      return 'Connessione non disponibile durante la registrazione. '
          'Se l’account è stato creato, prova ad accedere oppure contatta la segreteria.';
    }
    return 'Registrazione interrotta: ${e.runtimeType}. '
        'Se l’account risulta già creato, accedi oppure contatta la segreteria.';
  }

  String _mapUnexpectedRegistrationOuter(Object e) {
    if (e is AuthException) {
      return _mapAuthError(e);
    }
    if (_looksLikeNetworkError(e)) {
      return 'Connessione non disponibile. Verifica la rete e riprova.';
    }
    return 'Errore imprevisto (${e.runtimeType}). Riprova o contatta la segreteria.';
  }

  bool _looksLikeNetworkError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('network is unreachable') ||
        s.contains('timed out') ||
        s.contains('timeout') ||
        s.contains('handshake exception') ||
        s.contains('clientexception');
  }

  /// Login: nessuna riga student e nessun ruolo staff (ruolo `student` in DB → null in app).
  String _loginDeniedNoStudentNoStaffMessage(Object? hydrateFailure) {
    if (hydrateFailure != null) {
      if (hydrateFailure is PostgrestException) {
        return _mapHydrateOrReadError(hydrateFailure);
      }
      if (_looksLikeNetworkError(hydrateFailure)) {
        return _loginNetworkErrorMessage();
      }
      return 'Impossibile elaborare il profilo allievo. Contatta la segreteria.';
    }
    return _loginNoStudentRowMessage();
  }

  // --- Messaggi login: un testo per scenario (vedi audit UX) ---

  String _loginEmailNotConfirmedMessage() =>
      'L’email non è ancora confermata. Controlla la posta (anche spam), '
      'apri il link di conferma e riprova ad accedere.';

  String _loginNoStudentRowMessage() =>
      'Nessun profilo allievo associato a questo account. '
      'Contatta la segreteria se pensi che sia un errore.';

  String _loginStudentsRlsOrPermissionMessage() =>
      'Il profilo allievo non è leggibile per permessi sul database (es. regole RLS). '
      'Contatta la segreteria.';

  String _loginNetworkErrorMessage() =>
      'Connessione non disponibile o instabile. Verifica la rete e riprova.';
}
