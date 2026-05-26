import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../data/supabase/dto/backoffice_rows.dart';
import '../../data/supabase/mappers/backoffice_row_mappers.dart';
import '../../data/supabase/mappers/study_progress_row_mappers.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../domain/course_taxonomy.dart';
import '../../domain/enrollment_content_mapping.dart';
import '../../models/license_models.dart';
import '../../repositories/study_access_repository.dart';
import '../../services/demo_student_enrollment.dart';
import 'backoffice_repository.dart';
import 'backoffice_supabase_write_helpers.dart';

/// Lettura e **scrittura** backoffice su Supabase (PostgREST).
///
/// Richiede JWT con `is_school_staff()` = true per INSERT/UPDATE sulle tabelle operative.
class BackofficeRepositorySupabase implements BackofficeRepository {
  BackofficeRepositorySupabase._();

  static final BackofficeRepositorySupabase instance =
      BackofficeRepositorySupabase._();

  SupabaseClient get _client {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase non configurato.');
    }
    return Supabase.instance.client;
  }

  String? get _staffUserId => _client.auth.currentUser?.id;

  /// Log temporaneo collaudo Scheda 360 — rimuovere dopo chiusura bug Agenda/Contabilità.
  static const bool _kDebugStudentAdmin360 = true;

  Future<T> _load360SectionSafe<T>({
    required StudentId studentId,
    required String section,
    required Future<T> Function() load,
    required T fallback,
  }) async {
    try {
      final result = await load();
      if (_kDebugStudentAdmin360) {
        debugPrint('getStudentAdmin360 DEBUG [$section] OK');
      }
      return result;
    } catch (e, st) {
      debugPrint(
        'getStudentAdmin360 WARNING $section load failed for studentId=$studentId: $e\n$st',
      );
      if (_kDebugStudentAdmin360) {
        debugPrint('getStudentAdmin360 DEBUG [$section] FAIL: $e');
      }
      return fallback;
    }
  }

  void _debug360Summary({
    required StudentId studentId,
    required StudentProfile profile,
    required List<dynamic> guidanceRaw,
    required List<dynamic> paymentsRaw,
    required Object? finRaw,
    required List<GuidanceAppointment> appointments,
    required List<PaymentReceived> payments,
    required StudentFinancialSummary financial,
    required bool usedFinancialFallback,
  }) {
    if (!_kDebugStudentAdmin360) return;
    final guidanceIds = guidanceRaw
        .map((e) => (e as Map)['id']?.toString())
        .whereType<String>()
        .toList();
    final paymentIds = paymentsRaw
        .map((e) => (e as Map)['id']?.toString())
        .whereType<String>()
        .toList();
    final finMap = finRaw is Map ? Map<String, dynamic>.from(finRaw) : null;
    final paymentTotalCents = payments.fold<int>(0, (s, p) => s + p.amountCents);
    debugPrint(
      'getStudentAdmin360 DEBUG studentId=$studentId '
      'profile=${profile.firstName} ${profile.lastName} <${profile.email ?? 'no-email'}>',
    );
    debugPrint(
      'getStudentAdmin360 DEBUG guidance raw rows count=${guidanceRaw.length}',
    );
    debugPrint(
      'getStudentAdmin360 DEBUG guidance mapped count=${appointments.length}',
    );
    debugPrint('getStudentAdmin360 DEBUG guidance ids=$guidanceIds');
    debugPrint(
      'getStudentAdmin360 DEBUG payments raw rows count=${paymentsRaw.length}',
    );
    debugPrint(
      'getStudentAdmin360 DEBUG payments mapped count=${payments.length}',
    );
    debugPrint('getStudentAdmin360 DEBUG payment ids=$paymentIds');
    debugPrint(
      'getStudentAdmin360 DEBUG payment total cents=$paymentTotalCents',
    );
    debugPrint(
      'getStudentAdmin360 DEBUG summary totalPaidCents=${finMap?['total_paid_cents']} '
      '(view financial.totalPaidCents=${financial.totalPaidCents} fallbackUsed=$usedFinancialFallback)',
    );
    if (guidanceRaw.length != appointments.length) {
      debugPrint(
        'getStudentAdmin360 DEBUG ATTENZIONE: mapping guide ha perso '
        '${guidanceRaw.length - appointments.length} righe (vedi log "riga non mappabile")',
      );
    }
    if (paymentsRaw.length != payments.length) {
      debugPrint(
        'getStudentAdmin360 DEBUG ATTENZIONE: mapping pagamenti ha perso '
        '${paymentsRaw.length - payments.length} righe (vedi log "riga non mappabile")',
      );
    }
  }

  /// Evita che una riga malformata faccia fallire l’intera Scheda 360.
  List<T> _mapRowsSafe<T>(
    List<dynamic> raw,
    T Function(Map<String, dynamic>) parse,
    String label,
  ) {
    final out = <T>[];
    for (final item in raw) {
      try {
        out.add(parse(Map<String, dynamic>.from(item as Map)));
      } catch (e, st) {
        debugPrint('$label: riga non mappabile: $e\n$st');
      }
    }
    return out;
  }

  /// Se la segreteria modifica lo stesso allievo attualmente loggato nell’app studente,
  /// aggiorna subito il repository in memoria (D1, motore, vela con righe DB).
  void _syncStudyAccessIfCurrentStudent({
    required StudentId studentId,
    required void Function() apply,
  }) {
    final current = studentSession.value?.studentId;
    if (current != null && current == studentId) {
      apply();
    }
  }

  Future<void> _insertActivity({
    required StudentId studentId,
    required BackofficeActivityType type,
    required String title,
    String? description,
    DateTime? occurredAt,
  }) async {
    if (!isActivityEventTypePersisted(type)) return;
    await _client.from('backoffice_activity_events').insert({
      'student_id': studentId,
      'event_type': type.name,
      'title': title,
      'description': description,
      'occurred_at': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
      'actor_staff_id': _staffUserId,
    });
  }

  @override
  Future<List<StudentProfile>> listStudentProfiles() async {
    final res = await _client
        .from('students')
        .select()
        .order('last_name', ascending: true);

    final list = res as List<dynamic>;
    final out = <StudentProfile>[];
    for (final e in list) {
      try {
        out.add(
          mapStudentRowToProfile(
            StudentRow.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
      } catch (err, st) {
        debugPrint(
          'listStudentProfiles: saltata riga non mappabile: $err\n$st',
        );
      }
    }
    return out;
  }

  String _formatCreateStudentError(Object e) {
    if (e is PostgrestException) {
      final code = e.code?.toString() ?? '';
      final msg = e.message;
      if (code == '23505' ||
          msg.toLowerCase().contains('unique') ||
          msg.toLowerCase().contains('duplicate')) {
        return 'Esiste già un allievo con gli stessi dati univoci (es. email).';
      }
      return msg;
    }
    return e.toString();
  }

  @override
  Future<PracticeRegistryAssignment> assignPracticeRegistryNumber({
    required PracticeDossierId practiceDossierId,
    required DateTime registrationDate,
  }) async {
    final iso = dateOnlyIso(registrationDate);
    if (iso == null) {
      throw ArgumentError('Data iscrizione non valida.');
    }
    try {
      final raw = await _client.rpc(
        'assign_practice_registry_number',
        params: <String, dynamic>{
          'p_practice_dossier_id': practiceDossierId,
          'p_registration_date': iso,
        },
      );
      return PracticeRegistryAssignment.fromRpc(raw);
    } on PostgrestException catch (e) {
      throw StateError(e.message);
    }
  }

  @override
  Future<BackofficeNewStudentOutcome> createBackofficeStudent({
    required String firstName,
    required String lastName,
    String? phone,
    String? email,
    String? fiscalCode,
    DateTime? birthDate,
    String? birthPlace,
    String? gender,
    String? address,
    String? city,
    String? province,
    String? cap,
    String? enrolledCoursePath,
    String? enrolledLicenseCategory,
    String? notes,
    bool createPracticeDossier = true,
    String? practiceType,
    DateTime? registrationDate,
  }) async {
    final fn = firstName.trim();
    final ln = lastName.trim();
    if (fn.isEmpty || ln.isEmpty) {
      throw ArgumentError('Nome e cognome sono obbligatori.');
    }

    final path =
        EnrollmentCoursePathStorage.tryParse(enrolledCoursePath?.trim()) ??
        EnrollmentCoursePath.entro12Miglia;
    final pathStr = EnrollmentCoursePathStorage.toStorage(path);

    final licRaw = enrolledLicenseCategory?.trim();
    final String licenseCat;
    if (licRaw != null && licRaw.isNotEmpty) {
      final valid = LicenseCategoryId.values.any((e) => e.name == licRaw);
      if (!valid) {
        throw ArgumentError('Categoria patente non riconosciuta.');
      }
      licenseCat = licRaw;
    } else {
      licenseCat = EnrollmentContentMapping.primaryLicenseCategory(path).name;
    }

    void putNonEmpty(Map<String, dynamic> map, String key, String? v) {
      final t = v?.trim();
      if (t != null && t.isNotEmpty) {
        map[key] = t;
      }
    }

    final insertPayload = <String, dynamic>{
      'first_name': fn,
      'last_name': ln,
      'enrolled_course_path': pathStr,
      'enrolled_license_category': licenseCat,
      'registration_status': 'pending',
      'onboarding_status': studentOnboardingStatusDbValue(
        StudentOnboardingStatus.pendingReview,
      ),
    };
    putNonEmpty(insertPayload, 'phone', phone);
    putNonEmpty(insertPayload, 'email', email);
    putNonEmpty(insertPayload, 'fiscal_code', fiscalCode);
    putNonEmpty(insertPayload, 'notes', notes);
    putNonEmpty(insertPayload, 'birth_place', birthPlace);
    putNonEmpty(insertPayload, 'gender', gender);
    putNonEmpty(insertPayload, 'address', address);
    putNonEmpty(insertPayload, 'city', city);
    putNonEmpty(insertPayload, 'province', province);
    putNonEmpty(insertPayload, 'cap', cap);
    final bd = dateOnlyIso(birthDate);
    if (bd != null) {
      insertPayload['birth_date'] = bd;
    }

    if (createPracticeDossier) {
      const allowed = {'new_license', 'renewal', 'duplicate'};
      final pt = practiceType?.trim();
      if (pt == null || !allowed.contains(pt)) {
        throw ArgumentError('Tipo pratica registro obbligatorio e non valido.');
      }
      if (registrationDate == null) {
        throw ArgumentError('Data iscrizione al registro obbligatoria.');
      }
    }

    late final Map<String, dynamic> row;
    try {
      row = await _client
          .from('students')
          .insert(insertPayload)
          .select()
          .single();
    } catch (e) {
      throw StateError(_formatCreateStudentError(e));
    }

    final studentId = row['id'] as String;

    String? assignedRegistryCode;
    String? registryAssignmentNote;

    if (createPracticeDossier) {
      final regIso = dateOnlyIso(registrationDate);
      final pt = practiceType!.trim();
      try {
        final inserted = await _client
            .from('practice_dossiers')
            .insert(<String, dynamic>{
              'student_id': studentId,
              'practice_type': pt,
              'registration_date': regIso,
            })
            .select('id')
            .single();
        final dossierId = inserted['id'] as String;
        try {
          final assign = await assignPracticeRegistryNumber(
            practiceDossierId: dossierId,
            registrationDate: registrationDate!,
          );
          assignedRegistryCode = assign.registryCode;
        } catch (e) {
          registryAssignmentNote = e is StateError ? e.message : e.toString();
        }
      } catch (e) {
        try {
          await _client.from('students').delete().eq('id', studentId);
        } catch (_) {}
        throw StateError(
          'Impossibile creare il fascicolo pratica per il nuovo allievo. '
          'Nessuna anagrafica è stata lasciata a metà: riprova o crea senza dossier.',
        );
      }
    }

    return BackofficeNewStudentOutcome(
      profile: mapStudentRowToProfile(
        StudentRow.fromJson(Map<String, dynamic>.from(row)),
      ),
      assignedRegistryCode: assignedRegistryCode,
      registryAssignmentNote: registryAssignmentNote,
    );
  }

  String _humanizeAppAccessError(String raw, int status) {
    final low = raw.toLowerCase();
    if (low.contains('already') ||
        low.contains('registered') ||
        low.contains('exists') ||
        low.contains('duplicate') ||
        low.contains('unique')) {
      return 'Questa email è già registrata per un altro account. '
          'Usa un’indirizzo diverso o gestisci l’utente da console.';
    }
    if (low.contains('password') &&
        (low.contains('8') ||
            low.contains('short') ||
            low.contains('length'))) {
      return 'Password non accettata: serve almeno 8 caratteri.';
    }
    if (low.contains('missing bearer') || low.contains('invalid token')) {
      return 'Sessione non valida. Effettua di nuovo l’accesso al pannello.';
    }
    if (low.contains('forbidden') || low.contains('staff')) {
      return 'Non hai i permessi per creare accessi app (ruolo staff richiesto).';
    }
    if (status == 401) {
      return 'Sessione non valida. Effettua di nuovo l’accesso al pannello.';
    }
    if (status == 403) {
      return 'Non hai i permessi per creare accessi app.';
    }
    if (status == 404) {
      return 'Servizio accesso app non disponibile (funzione non trovata o non deployata).';
    }
    if (raw.trim().isEmpty) {
      return 'Impossibile creare l’accesso app. Riprova più tardi.';
    }
    return raw;
  }

  String _parseFunctionExceptionToAppAccessMessage(FunctionException e) {
    final details = e.details;
    if (details is Map) {
      final err = details['error'];
      if (err != null) {
        return _humanizeAppAccessError(err.toString(), e.status);
      }
    }
    if (details is String && details.isNotEmpty) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map && decoded['error'] != null) {
          return _humanizeAppAccessError(decoded['error'].toString(), e.status);
        }
      } catch (_) {
        return _humanizeAppAccessError(details, e.status);
      }
    }
    return _humanizeAppAccessError('', e.status);
  }

  @override
  Future<StudentAppAccessCredentials> createStudentAppAccess({
    required StudentId studentId,
    required String email,
    required String temporaryPassword,
  }) async {
    if (temporaryPassword.length < 8) {
      throw ArgumentError(
        'La password temporanea deve avere almeno 8 caratteri.',
      );
    }
    final em = email.trim().toLowerCase();
    if (em.isEmpty || !em.contains('@')) {
      throw ArgumentError('Email non valida.');
    }
    try {
      final res = await _client.functions.invoke(
        'create-student-app-access',
        body: <String, dynamic>{
          'studentId': studentId,
          'email': em,
          'password': temporaryPassword,
        },
      );
      final data = res.data;
      if (data is! Map) {
        throw StateError('Risposta accesso app non valida.');
      }
      final map = Map<String, dynamic>.from(data);
      if (map['success'] != true) {
        final err =
            map['error']?.toString() ?? 'Creazione accesso app non riuscita.';
        throw StateError(_humanizeAppAccessError(err, res.status));
      }
      return StudentAppAccessCredentials.fromEdgeJson(map);
    } on FunctionException catch (e) {
      throw StateError(_parseFunctionExceptionToAppAccessMessage(e));
    } catch (e, st) {
      if (e is StateError || e is ArgumentError) rethrow;
      debugPrint('createStudentAppAccess: $e\n$st');
      throw StateError(
        'Impossibile contattare il servizio accesso app. Verifica la rete e che la funzione sia deployata.',
      );
    }
  }

  @override
  Future<StudentAdmin360View?> getStudentAdmin360(StudentId studentId) async {
    final profileRow = await _client
        .from('students')
        .select()
        .eq('id', studentId)
        .maybeSingle();

    if (profileRow == null) return null;

    final profile = mapStudentRowToProfile(
      StudentRow.fromJson(Map<String, dynamic>.from(profileRow)),
    );

    if (_kDebugStudentAdmin360) {
      debugPrint(
        'getStudentAdmin360 DEBUG start studentId=$studentId '
        'profile=${profile.firstName} ${profile.lastName}',
      );
    }

    return _loadStudentAdmin360Detail(studentId, profile);
  }

  @override
  Future<List<PracticeListItem>> listPracticeDossiers() async {
    final dossiersRes = await _client.from('practice_dossiers').select(
          'id, student_id, practice_type, registration_date, registry_year, '
          'registry_number, registry_code, practice_number, document_status, practice_status',
        ).order('registration_date', ascending: false);

    final rawList = dossiersRes as List<dynamic>;
    if (rawList.isEmpty) return [];

    final dossierRows = <PracticeDossierRow>[];
    for (final e in rawList) {
      try {
        dossierRows.add(
          PracticeDossierRow.fromJson(Map<String, dynamic>.from(e as Map)),
        );
      } catch (err, st) {
        debugPrint(
          'listPracticeDossiers: riga dossier non mappabile: $err\n$st',
        );
      }
    }

    final studentIds =
        dossierRows.map((d) => d.studentId).toSet().toList(growable: false);
    final studentById = <String, StudentRow>{};
    if (studentIds.isNotEmpty) {
      final studentsRes = await _client
          .from('students')
          .select('id, first_name, last_name, email, phone')
          .inFilter('id', studentIds);
      final sList = studentsRes as List<dynamic>;
      for (final e in sList) {
        try {
          final r = StudentRow.fromJson(Map<String, dynamic>.from(e as Map));
          studentById[r.id] = r;
        } catch (err, st) {
          debugPrint(
            'listPracticeDossiers: riga studente non mappabile: $err\n$st',
          );
        }
      }
    }

    final out = <PracticeListItem>[];
    for (final d in dossierRows) {
      try {
        out.add(mapPracticeListItemFromRows(d, studentById[d.studentId]));
      } catch (err, st) {
        debugPrint('listPracticeDossiers: voce lista non mappabile: $err\n$st');
      }
    }
    return out;
  }

  @override
  Future<List<GuidanceListItem>> listGuidanceAppointments() async {
    final res = await _client.from('guidance_appointments').select(
          'id, student_id, lesson_date, start_time, end_time, instructor_name, '
          'instructor_staff_id, lesson_type, reminder_status, completion_outcome, notes',
        ).order('lesson_date', ascending: false).order('start_time', ascending: false);

    final rawList = res as List<dynamic>;
    if (rawList.isEmpty) return [];

    final rows = <GuidanceAppointmentRow>[];
    for (final e in rawList) {
      try {
        rows.add(
          GuidanceAppointmentRow.fromJson(Map<String, dynamic>.from(e as Map)),
        );
      } catch (err, st) {
        debugPrint(
          'listGuidanceAppointments: riga non mappabile: $err\n$st',
        );
      }
    }

    final studentIds =
        rows.map((d) => d.studentId).toSet().toList(growable: false);
    final studentById = <String, StudentRow>{};
    if (studentIds.isNotEmpty) {
      final studentsRes = await _client
          .from('students')
          .select('id, first_name, last_name, email, phone')
          .inFilter('id', studentIds);
      final sList = studentsRes as List<dynamic>;
      for (final e in sList) {
        try {
          final r = StudentRow.fromJson(Map<String, dynamic>.from(e as Map));
          studentById[r.id] = r;
        } catch (err, st) {
          debugPrint(
            'listGuidanceAppointments: riga studente non mappabile: $err\n$st',
          );
        }
      }
    }

    final out = <GuidanceListItem>[];
    for (final d in rows) {
      try {
        out.add(mapGuidanceListItemFromRows(d, studentById[d.studentId]));
      } catch (err, st) {
        debugPrint(
          'listGuidanceAppointments: voce lista non mappabile: $err\n$st',
        );
      }
    }
    return out;
  }

  @override
  Future<List<AccountingPaymentListItem>> listAccountingPayments() async {
    final payRes = await _client
        .from('payments')
        .select(
          'id, student_id, amount_cents, currency_code, received_at, method, '
          'receipt_reference, fiscal_receipt_number, notes, recorded_by_staff_id',
        )
        .order('received_at', ascending: false);

    final rawList = payRes as List<dynamic>;
    if (rawList.isEmpty) return [];

    final payRows = <PaymentRow>[];
    for (final e in rawList) {
      try {
        payRows.add(PaymentRow.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (err, st) {
        debugPrint(
          'listAccountingPayments: riga pagamento non mappabile: $err\n$st',
        );
      }
    }
    if (payRows.isEmpty) return [];

    final studentIds =
        payRows.map((p) => p.studentId).toSet().toList(growable: false);
    final studentById = <String, StudentRow>{};
    if (studentIds.isNotEmpty) {
      final studentsRes = await _client
          .from('students')
          .select('id, first_name, last_name, email, phone')
          .inFilter('id', studentIds);
      final sList = studentsRes as List<dynamic>;
      for (final e in sList) {
        try {
          final r = StudentRow.fromJson(Map<String, dynamic>.from(e as Map));
          studentById[r.id] = r;
        } catch (err, st) {
          debugPrint(
            'listAccountingPayments: riga studente non mappabile: $err\n$st',
          );
        }
      }
    }

    final out = <AccountingPaymentListItem>[];
    for (final p in payRows) {
      try {
        out.add(
          mapPaymentAndStudentToAccountingListItem(p, studentById[p.studentId]),
        );
      } catch (err, st) {
        debugPrint(
          'listAccountingPayments: voce lista non mappabile: $err\n$st',
        );
      }
    }
    return out;
  }

  Future<StudentAdmin360View> _loadStudentAdmin360Detail(
    StudentId studentId,
    StudentProfile profile,
  ) async {
    // Ogni sezione è isolata: un errore su documenti/esami/studio non svuota guide/pagamenti.
    final finRaw = await _load360SectionSafe<Object?>(
      studentId: studentId,
      section: 'student_financial_summaries',
      fallback: null,
      load: () => _client
          .from('student_financial_summaries')
          .select()
          .eq('student_id', studentId)
          .maybeSingle(),
    );

    final paymentsRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'payments',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('payments')
            .select(
              'id, student_id, amount_cents, currency_code, received_at, method, '
              'receipt_reference, fiscal_receipt_number, notes, recorded_by_staff_id',
            )
            .eq('student_id', studentId)
            .order('received_at', ascending: false);
        return res as List<dynamic>;
      },
    );

    final guidanceRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'guidance_appointments',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('guidance_appointments')
            .select(
              'id, student_id, lesson_date, start_time, end_time, instructor_name, '
              'instructor_staff_id, lesson_type, reminder_status, completion_outcome, '
              'notes, created_at, updated_at',
            )
            .eq('student_id', studentId)
            .order('lesson_date', ascending: true);
        return res as List<dynamic>;
      },
    );

    final examsRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'exam_attempts',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('exam_attempts')
            .select()
            .eq('student_id', studentId);
        return res as List<dynamic>;
      },
    );

    final practiceRaw = await _load360SectionSafe<Object?>(
      studentId: studentId,
      section: 'practice_dossiers',
      fallback: null,
      load: () => _client
          .from('practice_dossiers')
          .select()
          .eq('student_id', studentId)
          .maybeSingle(),
    );

    final documentsRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'student_documents',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('student_documents')
            .select(
              'id, student_id, practice_dossier_id, document_type, title, '
              'storage_path, file_name, mime_type, status, expires_at, notes, '
              'uploaded_by_staff_id, created_at, updated_at',
            )
            .eq('student_id', studentId)
            .order('created_at', ascending: false);
        return res as List<dynamic>;
      },
    );

    final photosRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'student_photos',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('student_photos')
            .select(
              'id, student_id, photo_kind, storage_path, file_name, mime_type, '
              'notes, uploaded_by_staff_id, created_at, updated_at',
            )
            .eq('student_id', studentId)
            .order('created_at', ascending: false);
        return res as List<dynamic>;
      },
    );

    final staffNotesRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'staff_internal_notes',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('staff_internal_notes')
            .select()
            .eq('student_id', studentId)
            .order('created_at', ascending: false);
        return res as List<dynamic>;
      },
    );

    final activityRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'backoffice_activity_events',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('backoffice_activity_events')
            .select()
            .eq('student_id', studentId)
            .order('occurred_at', ascending: false);
        return res as List<dynamic>;
      },
    );

    final sheetUnlocksRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'lesson_quiz_sheet_unlocks',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('lesson_quiz_sheet_unlocks')
            .select()
            .eq('student_id', studentId);
        return res as List<dynamic>;
      },
    );

    final examAccessRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'exam_quiz_access',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('exam_quiz_access')
            .select()
            .eq('student_id', studentId);
        return res as List<dynamic>;
      },
    );

    final errorReviewRaw = await _load360SectionSafe<List<dynamic>>(
      studentId: studentId,
      section: 'error_review_topic_assignments',
      fallback: const [],
      load: () async {
        final res = await _client
            .from('error_review_topic_assignments')
            .select()
            .eq('student_id', studentId);
        return res as List<dynamic>;
      },
    );

    StudentFinancialSummary financial;
    if (finRaw == null) {
      financial = StudentFinancialSummary(
        studentId: studentId,
        registrationFeeCents: 0,
        currencyCode: 'EUR',
        totalPaidCents: 0,
        remainingBalanceCents: 0,
      );
    } else {
      try {
        financial = mapFinancialRowToSummary(
          StudentFinancialSummaryRow.fromJson(
            Map<String, dynamic>.from(finRaw as Map<dynamic, dynamic>),
          ),
        );
      } catch (e, st) {
        debugPrint(
          'getStudentAdmin360: riepilogo finanziario non mappabile: $e\n$st',
        );
        financial = StudentFinancialSummary(
          studentId: studentId,
          registrationFeeCents: 0,
          currencyCode: 'EUR',
          totalPaidCents: 0,
          remainingBalanceCents: 0,
        );
      }
    }

    final payments = _mapRowsSafe(
      paymentsRaw,
      (j) => mapPaymentRowToDomain(PaymentRow.fromJson(j)),
      'getStudentAdmin360 payments',
    );

    var usedFinancialFallback = false;
    if (payments.isNotEmpty) {
      final paidSum = payments.fold<int>(0, (s, p) => s + p.amountCents);
      if (paidSum != financial.totalPaidCents) {
        usedFinancialFallback = true;
        debugPrint(
          'getStudentAdmin360: fallback client-side riepilogo contabilità '
          '(studentId=$studentId, summary.totalPaidCents=${financial.totalPaidCents}, '
          'paidSumFromPayments=$paidSum) — uso somma incassi da lista payments.',
        );
        financial = StudentFinancialSummary(
          studentId: financial.studentId,
          registrationFeeCents: financial.registrationFeeCents,
          currencyCode: financial.currencyCode,
          totalPaidCents: paidSum,
          remainingBalanceCents:
              (financial.registrationFeeCents - paidSum).clamp(0, 1 << 31),
          accountingNotes: financial.accountingNotes,
          lastUpdatedAt: financial.lastUpdatedAt,
        );
      }
    }

    final appointments = _mapRowsSafe(
      guidanceRaw,
      (j) => mapGuidanceRowToDomain(GuidanceAppointmentRow.fromJson(j)),
      'getStudentAdmin360 guidance',
    );

    _debug360Summary(
      studentId: studentId,
      profile: profile,
      guidanceRaw: guidanceRaw,
      paymentsRaw: paymentsRaw,
      finRaw: finRaw,
      appointments: appointments,
      payments: payments,
      financial: financial,
      usedFinancialFallback: usedFinancialFallback,
    );

    final exams = _mapRowsSafe(
      examsRaw,
      (j) => mapExamAttemptRowToDomain(ExamAttemptRow.fromJson(j)),
      'getStudentAdmin360 exams',
    );

    final theory = exams
        .where((e) => e.examType == ExamAttemptType.theory)
        .toList();
    final pract = exams
        .where((e) => e.examType == ExamAttemptType.practical)
        .toList();

    final practiceRawValue = practiceRaw;
    PracticeLicenseDossier? practice;
    if (practiceRawValue != null) {
      try {
        practice = mapPracticeRowToDomain(
          PracticeDossierRow.fromJson(
            Map<String, dynamic>.from(practiceRawValue as Map),
          ),
        );
      } catch (e, st) {
        debugPrint(
          'getStudentAdmin360 WARNING practice_dossiers mapping failed for '
          'studentId=$studentId: $e\n$st',
        );
        practice = null;
      }
    }

    final documents = _mapRowsSafe(
      documentsRaw,
      (j) => mapStudentDocumentRowToDomain(StudentDocumentRow.fromJson(j)),
      'getStudentAdmin360 documents',
    );

    final photos = _mapRowsSafe(
      photosRaw,
      (j) => mapStudentPhotoRowToDomain(StudentPhotoRow.fromJson(j)),
      'getStudentAdmin360 photos',
    );

    final staffNotes = _mapRowsSafe(
      staffNotesRaw,
      (j) => mapStaffNoteRowToDomain(StaffInternalNoteRow.fromJson(j)),
      'getStudentAdmin360 staff_notes',
    );

    final activityLog = _mapRowsSafe(
      activityRaw,
      (j) => mapActivityRowToDomain(BackofficeActivityEventRow.fromJson(j)),
      'getStudentAdmin360 activity',
    );

    final sheetUnlocks = _mapRowsSafe(
      sheetUnlocksRaw,
      mapLessonQuizSheetUnlockFromJson,
      'getStudentAdmin360 sheet_unlocks',
    );

    final examAccessByCategory = _mapRowsSafe(
      examAccessRaw,
      mapExamQuizAccessFromJson,
      'getStudentAdmin360 exam_access',
    );

    final errorReviewAssignments = _mapRowsSafe(
      errorReviewRaw,
      mapErrorReviewTopicFromJson,
      'getStudentAdmin360 error_review',
    );

    final studyProgress = StudentStudyProgressBundle(
      studentId: studentId,
      assignedLessons: const [],
      sheetUnlocks: sheetUnlocks,
      examAccessByCategory: examAccessByCategory,
      errorReviewAssignments: errorReviewAssignments,
    );

    return StudentAdmin360View(
      profile: profile,
      studyProgress: studyProgress,
      appointments: appointments,
      examSummary: StudentExamSummary(
        studentId: studentId,
        theoryAttempts: theory,
        practicalAttempts: pract,
      ),
      financialSummary: financial,
      payments: payments,
      practiceDossier: practice,
      documents: documents,
      photos: photos,
      staffNotes: staffNotes,
      activityLog: activityLog,
    );
  }

  @override
  Future<String> createStudentDocumentSignedUrl(String storagePath) {
    return _createPrivateFileSignedUrl(
      bucket: 'student-documents',
      storagePath: storagePath,
    );
  }

  @override
  Future<String> createStudentPhotoSignedUrl(String storagePath) {
    return _createPrivateFileSignedUrl(
      bucket: 'student-photos',
      storagePath: storagePath,
    );
  }

  Future<String> _createPrivateFileSignedUrl({
    required String bucket,
    required String storagePath,
  }) {
    return _client.storage.from(bucket).createSignedUrl(storagePath, 60);
  }

  @override
  Future<StudentDocument> uploadStudentDocument({
    required StudentId studentId,
    PracticeDossierId? practiceDossierId,
    required String documentType,
    required String title,
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    DateTime? expiresAt,
    String? notes,
  }) async {
    final safeFileName = _sanitizeFileName(fileName);
    final storagePath =
        'students/$studentId/documents/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';

    await _client.storage
        .from('student-documents')
        .uploadBinary(
          storagePath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final metadata = <String, dynamic>{
      'student_id': studentId,
      'document_type': documentType,
      'title': title.trim().isEmpty ? fileName : title.trim(),
      'storage_path': storagePath,
      'file_name': fileName,
      'status': 'pending',
    };
    if (practiceDossierId != null) {
      metadata['practice_dossier_id'] = practiceDossierId;
    }
    if (mimeType != null && mimeType.isNotEmpty) {
      metadata['mime_type'] = mimeType;
    }
    if (expiresAt != null) {
      metadata['expires_at'] = _dateOnlyIso(expiresAt);
    }
    if (notes != null && notes.trim().isNotEmpty) {
      metadata['notes'] = notes.trim();
    }
    if (_staffUserId != null) {
      metadata['uploaded_by_staff_id'] = _staffUserId;
    }

    final row = await _client
        .from('student_documents')
        .insert(metadata)
        .select()
        .single();

    return mapStudentDocumentRowToDomain(
      StudentDocumentRow.fromJson(Map<String, dynamic>.from(row)),
    );
  }

  @override
  Future<StudentPhoto> uploadStudentPhoto({
    required StudentId studentId,
    required String photoKind,
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    String? notes,
  }) async {
    final safeFileName = _sanitizeFileName(fileName);
    final storagePath =
        'students/$studentId/photos/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';

    await _client.storage
        .from('student-photos')
        .uploadBinary(
          storagePath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );

    final metadata = <String, dynamic>{
      'student_id': studentId,
      'photo_kind': photoKind,
      'storage_path': storagePath,
      'file_name': fileName,
    };
    if (mimeType != null && mimeType.isNotEmpty) {
      metadata['mime_type'] = mimeType;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      metadata['notes'] = notes.trim();
    }
    if (_staffUserId != null) {
      metadata['uploaded_by_staff_id'] = _staffUserId;
    }

    final row = await _client
        .from('student_photos')
        .insert(metadata)
        .select()
        .single();

    return mapStudentPhotoRowToDomain(
      StudentPhotoRow.fromJson(Map<String, dynamic>.from(row)),
    );
  }

  String _sanitizeFileName(String fileName) {
    final withoutPath = fileName.split(RegExp(r'[/\\]+')).last.trim();
    final normalized = withoutPath
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final cleaned = normalized.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
    return cleaned.isEmpty ? 'file' : cleaned;
  }

  String _dateOnlyIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Future<void> setLessonSheetUnlocked({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    required bool unlocked,
  }) async {
    final now = DateTime.now().toUtc();
    final cat = licenseCategoryColumn(categoryId);
    await _client.from('lesson_quiz_sheet_unlocks').upsert({
      'student_id': studentId,
      'license_category': cat,
      'lesson_number': lessonNumber,
      'sheet_number': sheetNumber,
      'unlocked': unlocked,
      'unlocked_at': unlocked ? now.toIso8601String() : null,
      'revoked_at': unlocked ? null : now.toIso8601String(),
      'unlocked_by_staff_id': unlocked ? _staffUserId : null,
    }, onConflict: 'student_id,license_category,lesson_number,sheet_number');

    _syncStudyAccessIfCurrentStudent(
      studentId: studentId,
      apply: () => studyAccessWritableRepository.applyLessonQuizSheetUnlock(
        categoryId: categoryId,
        lessonNumber: lessonNumber,
        sheetNumber: sheetNumber,
        unlocked: unlocked,
      ),
    );

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.studyAccessChanged,
      title: 'Accesso studio: scheda quiz',
      description:
          'Lezione $lessonNumber · scheda $sheetNumber · ${unlocked ? 'sbloccata' : 'revocata'}',
    );
  }

  @override
  Future<void> setExamQuizAccessForCategory({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required bool examUnlocked,
  }) async {
    final now = DateTime.now().toUtc();
    final cat = licenseCategoryColumn(categoryId);
    await _client.from('exam_quiz_access').upsert({
      'student_id': studentId,
      'license_category': cat,
      'exam_unlocked': examUnlocked,
      'updated_at': now.toIso8601String(),
      'updated_by_staff_id': _staffUserId,
    }, onConflict: 'student_id,license_category');

    _syncStudyAccessIfCurrentStudent(
      studentId: studentId,
      apply: () => studyAccessWritableRepository.applyExamQuizUnlock(
        categoryId: categoryId,
        unlocked: examUnlocked,
      ),
    );

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.studyAccessChanged,
      title: 'Accesso studio: quiz esame',
      description: examUnlocked ? 'Abilitato' : 'Disabilitato',
    );
  }

  @override
  Future<void> setErrorReviewTopicAssignment({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required bool topicUnlocked,
    String? didacticNote,
  }) async {
    final now = DateTime.now().toUtc();
    final cat = licenseCategoryColumn(categoryId);

    final existing = await _client
        .from('error_review_topic_assignments')
        .select()
        .eq('student_id', studentId)
        .eq('license_category', cat)
        .eq('lesson_number', lessonNumber)
        .maybeSingle();

    final mergedNote =
        didacticNote ??
        (existing != null ? existing['didactic_note'] as String? : null);

    await _client.from('error_review_topic_assignments').upsert({
      'student_id': studentId,
      'license_category': cat,
      'lesson_number': lessonNumber,
      'topic_unlocked': topicUnlocked,
      'didactic_note': mergedNote,
      'updated_at': now.toIso8601String(),
      'updated_by_staff_id': _staffUserId,
    }, onConflict: 'student_id,license_category,lesson_number');

    _syncStudyAccessIfCurrentStudent(
      studentId: studentId,
      apply: () => studyAccessWritableRepository.applyErrorReviewTopicUnlock(
        categoryId: categoryId,
        lessonNumber: lessonNumber,
        unlocked: topicUnlocked,
      ),
    );

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.studyAccessChanged,
      title: 'Accesso studio: ripasso errori',
      description:
          'Lezione $lessonNumber · ${topicUnlocked ? 'assegnato' : 'revocato'}',
    );
  }

  Future<StudentFinancialSummaryRow> _ensureFinancialRow(
    StudentId studentId,
  ) async {
    final finRaw = await _client
        .from('student_financial_summaries')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();

    if (finRaw != null) {
      return StudentFinancialSummaryRow.fromJson(
        Map<String, dynamic>.from(finRaw as Map),
      );
    }

    await _client.from('student_financial_summaries').insert({
      'student_id': studentId,
      'registration_fee_cents': 0,
      'currency_code': 'EUR',
      'total_paid_cents': 0,
      'remaining_balance_cents': 0,
    });

    final again = await _client
        .from('student_financial_summaries')
        .select()
        .eq('student_id', studentId)
        .single();

    return StudentFinancialSummaryRow.fromJson(
      Map<String, dynamic>.from(again as Map),
    );
  }

  @override
  Future<void> addPayment({
    required StudentId studentId,
    required int amountCents,
    required PaymentMethod method,
    required DateTime receivedAt,
    String? notes,
    String? receiptReference,
    String? idempotencyKey,
  }) async {
    if (amountCents <= 0) {
      throw ArgumentError.value(amountCents, 'amountCents', 'must be > 0');
    }

    await _client.rpc(
      'record_payment',
      params: {
        'p_student_id': studentId,
        'p_amount_cents': amountCents,
        'p_method': method.name,
        'p_received_at': receivedAt.toUtc().toIso8601String(),
        'p_notes': notes,
        'p_receipt_reference': receiptReference,
        'p_activity_title': 'Pagamento registrato',
        'p_activity_description':
            '${(amountCents / 100).toStringAsFixed(2)} € · ${_methodLabel(method)}',
        'p_idempotency_key': idempotencyKey,
      },
    );
  }

  String _methodLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.card:
        return 'Carta';
      case PaymentMethod.sepaBankTransfer:
        return 'Bonifico';
      case PaymentMethod.cash:
        return 'Contanti';
      case PaymentMethod.check:
        return 'Assegno';
      case PaymentMethod.other:
        return 'Altro';
    }
  }

  @override
  Future<void> addGuidanceAppointment({
    required StudentId studentId,
    required DateTime lessonDate,
    DateTime? startTime,
    DateTime? endTime,
    String? instructorName,
    required GuidanceLessonType lessonType,
    String? notes,
  }) async {
    final day = DateTime(lessonDate.year, lessonDate.month, lessonDate.day);
    await _client.from('guidance_appointments').insert({
      'student_id': studentId,
      'lesson_date': dateOnlyIso(day),
      'start_time': startTime?.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'instructor_name': instructorName,
      'lesson_type': lessonType.name,
      'reminder_status': AppointmentReminderStatus.scheduled.name,
      'completion_outcome': AppointmentCompletionOutcome.pending.name,
      'notes': notes,
    });

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.guidanceAppointmentAdded,
      title: 'Guida / appuntamento registrato',
      description: '${instructorName ?? '—'} · ${_lessonTypeLabel(lessonType)}',
    );
  }

  @override
  Future<void> updateGuidanceAppointmentOutcome({
    required AppointmentId appointmentId,
    required AppointmentCompletionOutcome outcome,
  }) async {
    if (outcome != AppointmentCompletionOutcome.attended &&
        outcome != AppointmentCompletionOutcome.absent) {
      throw ArgumentError('Esito non supportato in V1: ${outcome.name}');
    }
    await _client
        .from('guidance_appointments')
        .update({'completion_outcome': outcome.name})
        .eq('id', appointmentId);
  }

  @override
  Future<void> updateGuidanceAppointment({
    required AppointmentId appointmentId,
    required StudentId studentId,
    required DateTime lessonDate,
    DateTime? startTime,
    DateTime? endTime,
    String? instructorName,
    String? notes,
  }) async {
    final day = DateTime(lessonDate.year, lessonDate.month, lessonDate.day);
    await _client.from('guidance_appointments').update({
      'student_id': studentId,
      'lesson_date': dateOnlyIso(day),
      'start_time': startTime?.toUtc().toIso8601String(),
      'end_time': endTime?.toUtc().toIso8601String(),
      'instructor_name': instructorName,
      'notes': notes,
    }).eq('id', appointmentId);
  }

  @override
  Future<void> deleteGuidanceAppointment({
    required AppointmentId appointmentId,
  }) async {
    await _client
        .from('guidance_appointments')
        .delete()
        .eq('id', appointmentId);
  }

  String _lessonTypeLabel(GuidanceLessonType t) {
    switch (t) {
      case GuidanceLessonType.theory:
        return 'Teoria';
      case GuidanceLessonType.practiceSea:
        return 'Pratica mare';
      case GuidanceLessonType.practiceSimulator:
        return 'Simulatore';
      case GuidanceLessonType.officeMeeting:
        return 'Segreteria';
      case GuidanceLessonType.examPrep:
        return 'Pre-esame';
      case GuidanceLessonType.other:
        return 'Altro';
    }
  }

  @override
  Future<void> addInternalNote({
    required StudentId studentId,
    required String body,
    String? authorStaffName,
    StaffNoteCategory category = StaffNoteCategory.general,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final authorName = authorStaffName?.trim().isEmpty ?? true
        ? null
        : authorStaffName!.trim();

    await _client.from('staff_internal_notes').insert({
      'student_id': studentId,
      'body': trimmed,
      'category': category.name,
      'author_staff_id': _staffUserId,
      'author_display_name': authorName,
    });

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.internalNoteAdded,
      title: 'Nota interna aggiunta',
      description:
          '${_staffNoteCategoryLabel(category)} · '
          '${trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed}',
    );
  }

  String _staffNoteCategoryLabel(StaffNoteCategory c) {
    switch (c) {
      case StaffNoteCategory.general:
        return 'Generale';
      case StaffNoteCategory.accounting:
        return 'Contabilità';
      case StaffNoteCategory.study:
        return 'Studio';
      case StaffNoteCategory.exam:
        return 'Esami';
    }
  }

  @override
  Future<void> updateProfileLegacyInternalNote({
    required StudentId studentId,
    String? internalNotes,
  }) async {
    final v = internalNotes?.trim().isEmpty ?? true
        ? null
        : internalNotes!.trim();

    await _client.from('students').update({'notes': v}).eq('id', studentId);

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.profileInternalNoteUpdated,
      title: 'Note anagrafiche interne aggiornate',
    );
  }

  Future<int> _nextExamAttemptNumber(
    StudentId studentId,
    ExamAttemptType examType,
  ) async {
    final r = await _client
        .from('exam_attempts')
        .select('attempt_number')
        .eq('student_id', studentId)
        .eq('exam_type', examType.name)
        .order('attempt_number', ascending: false)
        .limit(1)
        .maybeSingle();

    if (r == null) return 1;
    final n = (r['attempt_number'] as num?)?.toInt() ?? 0;
    return n + 1;
  }

  @override
  Future<void> addExamAttemptRecord({
    required StudentId studentId,
    required ExamAttemptType examType,
    required ExamAttemptResult result,
    DateTime? examDate,
    String? scoreOrLabel,
    String? notes,
  }) async {
    final attemptNumber = await _nextExamAttemptNumber(studentId, examType);

    await _client.from('exam_attempts').insert({
      'student_id': studentId,
      'exam_type': examType.name,
      'attempt_number': attemptNumber,
      'result': result.name,
      'exam_date': dateOnlyIso(examDate),
      'score_or_label': scoreOrLabel?.trim().isEmpty ?? true
          ? null
          : scoreOrLabel!.trim(),
      'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      'recorded_by_staff_id': _staffUserId,
    });

    final typeLabel = examType == ExamAttemptType.theory ? 'Teoria' : 'Pratica';
    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.examResultRecorded,
      title: 'Esito esame registrato ($typeLabel)',
      description: '${_examResultLabel(result)} · n. $attemptNumber',
    );
  }

  String _examResultLabel(ExamAttemptResult r) {
    switch (r) {
      case ExamAttemptResult.pending:
        return 'In attesa';
      case ExamAttemptResult.scheduled:
        return 'Programmato';
      case ExamAttemptResult.passed:
        return 'Superato';
      case ExamAttemptResult.failed:
        return 'Non superato';
      case ExamAttemptResult.exempt:
        return 'Esente';
      case ExamAttemptResult.noShow:
        return 'Assente';
    }
  }

  @override
  Future<void> updatePracticeDossier({
    required StudentId studentId,
    String? practiceNumber,
    String? licenseNumber,
    DateTime? issueDate,
    DateTime? expirationDate,
    LicenseDocumentStatus? documentStatus,
    PracticeFileStatus? practiceStatus,
    String? authorityNotes,
  }) async {
    final existing = await _client
        .from('practice_dossiers')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();

    PracticeDossierRow? row;
    if (existing != null) {
      row = PracticeDossierRow.fromJson(
        Map<String, dynamic>.from(existing as Map),
      );
    }

    final ds =
        documentStatus ??
        (row != null
            ? _enumDocumentFromString(row.documentStatus)
            : LicenseDocumentStatus.notStarted);
    final ps =
        practiceStatus ??
        (row != null
            ? _enumPracticeFromString(row.practiceStatus)
            : PracticeFileStatus.notOpen);

    final mergedPractice = practiceNumber?.trim().isEmpty ?? true
        ? row?.practiceNumber
        : practiceNumber!.trim();
    final mergedLicense = licenseNumber?.trim().isEmpty ?? true
        ? row?.licenseNumber
        : licenseNumber!.trim();
    final mergedIssue = issueDate ?? row?.issueDate;
    final mergedExpiry = expirationDate ?? row?.expirationDate;
    final mergedAuth = authorityNotes?.trim().isEmpty ?? true
        ? row?.authorityNotes
        : authorityNotes!.trim();

    await _client.from('practice_dossiers').upsert({
      'student_id': studentId,
      'practice_type': row?.practiceType ?? 'new_license',
      'registration_date': dateOnlyIso(row?.registrationDate),
      'registry_year': row?.registryYear,
      'registry_number': row?.registryNumber,
      'registry_code': row?.registryCode,
      'practice_number': mergedPractice,
      'license_number': mergedLicense,
      'issue_date': dateOnlyIso(mergedIssue),
      'expiration_date': dateOnlyIso(mergedExpiry),
      'document_status': ds.name,
      'practice_status': ps.name,
      'authority_notes': mergedAuth,
      'updated_by_staff_id': _staffUserId,
      'last_checked_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'student_id');

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.practiceDossierUpdated,
      title: 'Pratica / documenti aggiornati',
      description: 'Stato doc.: ${_documentStatusLabel(ds)}',
    );
  }

  LicenseDocumentStatus _enumDocumentFromString(String raw) {
    for (final v in LicenseDocumentStatus.values) {
      if (v.name == raw) return v;
    }
    return LicenseDocumentStatus.notStarted;
  }

  PracticeFileStatus _enumPracticeFromString(String raw) {
    for (final v in PracticeFileStatus.values) {
      if (v.name == raw) return v;
    }
    return PracticeFileStatus.notOpen;
  }

  String _documentStatusLabel(LicenseDocumentStatus s) {
    switch (s) {
      case LicenseDocumentStatus.notStarted:
        return 'Non avviato';
      case LicenseDocumentStatus.collected:
        return 'Raccolta doc.';
      case LicenseDocumentStatus.submittedToAuthority:
        return 'Inviato';
      case LicenseDocumentStatus.issued:
        return 'Rilasciato';
      case LicenseDocumentStatus.revoked:
        return 'Revocato';
      case LicenseDocumentStatus.expired:
        return 'Scaduto';
    }
  }

  @override
  Future<void> appendActivityEvent(BackofficeActivityEvent event) async {
    if (!isActivityEventTypePersisted(event.type)) return;
    await _client.from('backoffice_activity_events').insert({
      'student_id': event.studentId,
      'event_type': event.type.name,
      'title': event.title,
      'description': event.description,
      'occurred_at': event.occurredAt.toUtc().toIso8601String(),
      'actor_staff_id': _staffUserId,
    });
  }

  @override
  Future<void> updateStudentOnboardingStatus({
    required StudentId studentId,
    required StudentOnboardingStatus status,
    String? onboardingNotes,
  }) async {
    final existing = await _client
        .from('students')
        .select('onboarding_status, onboarding_notes')
        .eq('id', studentId)
        .maybeSingle();

    final oldRaw = existing == null
        ? null
        : existing['onboarding_status'] as String?;
    final old = studentOnboardingStatusFromDb(oldRaw ?? 'pending_review');

    final notesUpdate = onboardingNotes == null
        ? null
        : onboardingNotes.trim().isEmpty
        ? null
        : onboardingNotes.trim();

    final patch = <String, dynamic>{
      'onboarding_status': studentOnboardingStatusDbValue(status),
    };
    if (onboardingNotes != null) {
      patch['onboarding_notes'] = notesUpdate;
    }

    await _client.from('students').update(patch).eq('id', studentId);

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.onboardingStatusChanged,
      title: 'Onboarding aggiornato',
      description:
          '${studentOnboardingStatusLabelIt(old)} → '
          '${studentOnboardingStatusLabelIt(status)}',
    );
  }

  @override
  Future<void> markStudentFirstContacted(StudentId studentId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('students')
        .update({'first_contacted_at': now})
        .eq('id', studentId);

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.onboardingStatusChanged,
      title: 'Primo contatto registrato',
      description: 'Data/ora aggiornata in anagrafica.',
    );
  }

  @override
  Future<void> setStudentRegistrationFeeCents({
    required StudentId studentId,
    required int registrationFeeCents,
  }) async {
    if (registrationFeeCents < 0) {
      throw ArgumentError.value(
        registrationFeeCents,
        'registrationFeeCents',
        'must be >= 0',
      );
    }

    final fin = await _ensureFinancialRow(studentId);
    final newRemaining = (registrationFeeCents - fin.totalPaidCents).clamp(
      0,
      1 << 30,
    );

    await _client
        .from('student_financial_summaries')
        .update({
          'registration_fee_cents': registrationFeeCents,
          'remaining_balance_cents': newRemaining,
          'last_updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('student_id', studentId);

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.onboardingStatusChanged,
      title: 'Quota iscrizione aggiornata',
      description:
          '${(registrationFeeCents / 100).toStringAsFixed(2)} € attesi · '
          'residuo ${(newRemaining / 100).toStringAsFixed(2)} €',
    );
  }

  @override
  Future<void> activateStudentCourse(StudentId studentId) async {
    await _client
        .from('students')
        .update({
          'registration_status': StudentRegistrationStatus.active.name,
          'onboarding_status': studentOnboardingStatusDbValue(
            StudentOnboardingStatus.activeCourse,
          ),
        })
        .eq('id', studentId);

    await _insertActivity(
      studentId: studentId,
      type: BackofficeActivityType.onboardingStatusChanged,
      title: 'Percorso attivato',
      description: 'Iscrizione attiva · onboarding “in corso”.',
    );
  }
}
