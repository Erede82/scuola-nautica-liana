import 'package:flutter/foundation.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../domain/course_taxonomy.dart';
import '../../models/license_models.dart';
import '../../repositories/study_access_repository.dart';
import 'backoffice_demo_seed.dart';
import 'school_backoffice_demo_data.dart';

/// Store mutabile demo backoffice — sostituibile con repository Supabase.
///
/// Le modifiche aggiornano le viste che ascoltano [notifyListeners].
/// Per l’allievo demo collegato all’app ([SchoolBackofficeDemoData.demoStudentLucia]),
/// le azioni su studio propagano anche a [studyAccessWritableRepository].
class BackofficeDemoStore extends ChangeNotifier {
  BackofficeDemoStore._fromSeed(BackofficeDemoSeed seed)
    : _profiles = List<StudentProfile>.from(seed.profiles),
      _progressBundles = List<StudentStudyProgressBundle>.from(
        seed.progressBundles,
      ),
      _appointments = List<GuidanceAppointment>.from(seed.appointments),
      _exams = List<ExamAttempt>.from(seed.exams),
      _payments = List<PaymentReceived>.from(seed.payments),
      _financial = Map<StudentId, StudentFinancialSummary>.from(seed.financial),
      _practice = Map<StudentId, PracticeLicenseDossier?>.from(seed.practice),
      _documents = List<StudentDocument>.from(seed.documents),
      _photos = List<StudentPhoto>.from(seed.photos),
      _documentWaivers = List<PracticeDocumentWaiver>.from(seed.documentWaivers),
      _staffNotes = <StaffInternalNote>[],
      _activityLog = <BackofficeActivityEvent>[];

  /// Istanza singleton usata dal backoffice scuola (mock locale).
  factory BackofficeDemoStore.initial() => BackofficeDemoStore._fromSeed(
    SchoolBackofficeDemoData.cloneSeedForMutableStore(),
  );

  List<StudentProfile> _profiles;
  List<StudentStudyProgressBundle> _progressBundles;
  List<GuidanceAppointment> _appointments;
  List<ExamAttempt> _exams;
  List<PaymentReceived> _payments;
  Map<StudentId, StudentFinancialSummary> _financial;
  Map<StudentId, PracticeLicenseDossier?> _practice;
  final List<StudentDocument> _documents;
  final List<StudentPhoto> _photos;
  final List<PracticeDocumentWaiver> _documentWaivers;
  final List<StaffInternalNote> _staffNotes;
  final List<BackofficeActivityEvent> _activityLog;
  final Map<int, int> _mockRegistrySeqByYear = {};

  List<StudentProfile> get profiles => List.unmodifiable(_profiles);

  /// Profili arricchiti con `practice_dossiers.practice_type` per l’elenco sidebar.
  List<StudentProfile> get profilesForList => _profiles
      .map((p) {
        final pt = _practice[p.id]?.practiceType;
        return pt == null ? p : p.copyWith(practiceDossierType: pt);
      })
      .toList(growable: false);

  /// Incassi globali per directory contabile mock (data ricezione discendente).
  List<AccountingPaymentListItem> listAccountingPaymentDirectoryItems() {
    final byId = {for (final p in _profiles) p.id: p};
    final out = <AccountingPaymentListItem>[];
    for (final pay in _payments) {
      final prof = byId[pay.studentId];
      final name = prof == null
          ? 'Allievo'
          : '${prof.firstName} ${prof.lastName}'.trim();
      out.add(
        AccountingPaymentListItem(
          paymentId: pay.id,
          studentId: pay.studentId,
          studentFullName: name.isEmpty ? 'Allievo' : name,
          studentEmail: prof?.email,
          studentPhone: prof?.phone,
          amountCents: pay.amountCents,
          currencyCode: pay.currencyCode,
          receivedAt: pay.receivedAt,
          method: pay.method,
          receiptReference: pay.receiptReference,
          fiscalReceiptNumber: pay.fiscalReceiptNumber,
          notes: pay.notes,
          recordedByStaffId: pay.recordedByStaffId,
        ),
      );
    }
    out.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return out;
  }

  void _appendActivity({
    required StudentId studentId,
    required BackofficeActivityType type,
    required String title,
    String? description,
  }) {
    _activityLog.add(
      BackofficeActivityEvent(
        id: 'act-${DateTime.now().microsecondsSinceEpoch}',
        studentId: studentId,
        occurredAt: DateTime.now(),
        type: type,
        title: title,
        description: description,
      ),
    );
  }

  StudentProfile _patchProfile(
    StudentProfile p, {
    StudentOnboardingStatus? onboardingStatus,
    DateTime? firstContactedAt,
    String? onboardingNotes,
    bool updateOnboardingNotes = false,
    StudentRegistrationStatus? registrationStatus,
    bool updateInternalNotes = false,
    String? internalNotes,
  }) {
    final String? nextOnboardingNotes;
    if (!updateOnboardingNotes) {
      nextOnboardingNotes = p.onboardingNotes;
    } else if (onboardingNotes == null) {
      nextOnboardingNotes = p.onboardingNotes;
    } else {
      final t = onboardingNotes.trim();
      nextOnboardingNotes = t.isEmpty ? null : t;
    }

    return StudentProfile(
      id: p.id,
      firstName: p.firstName,
      lastName: p.lastName,
      phone: p.phone,
      email: p.email,
      birthDate: p.birthDate,
      taxCode: p.taxCode,
      birthPlace: p.birthPlace,
      gender: p.gender,
      address: p.address,
      enrolledCoursePath: p.enrolledCoursePath,
      registrationStatus: registrationStatus ?? p.registrationStatus,
      onboardingStatus: onboardingStatus ?? p.onboardingStatus,
      firstContactedAt: firstContactedAt ?? p.firstContactedAt,
      onboardingNotes: nextOnboardingNotes,
      linkedAuthUserId: p.linkedAuthUserId,
      internalNotes: updateInternalNotes ? internalNotes : p.internalNotes,
      createdAt: p.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Inserimento evento audit manuale (test / integrazione); in produzione tipicamente via API.
  void appendActivityEvent(BackofficeActivityEvent event) {
    _activityLog.add(event);
    notifyListeners();
  }

  StudentAdmin360View? aggregateFor(StudentId studentId) {
    final profileMatch = _profiles.where((e) => e.id == studentId).toList();
    if (profileMatch.isEmpty) return null;
    final profile = profileMatch.first;

    final progMatch = _progressBundles
        .where((e) => e.studentId == studentId)
        .toList();
    if (progMatch.isEmpty) return null;
    final prog = progMatch.first;

    final ap = _appointments
        .where((e) => e.studentId == studentId)
        .toList(growable: false);
    final ex = _exams
        .where((e) => e.studentId == studentId)
        .toList(growable: false);
    final pay = _payments.where((e) => e.studentId == studentId).toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    final theory = ex
        .where((e) => e.examType == ExamAttemptType.theory)
        .toList();
    final pract = ex
        .where((e) => e.examType == ExamAttemptType.practical)
        .toList();

    final fin = _financial[studentId];
    if (fin == null) return null;

    final apSorted = List<GuidanceAppointment>.from(ap)
      ..sort((a, b) => a.lessonDate.compareTo(b.lessonDate));

    final notes = _staffNotes.where((n) => n.studentId == studentId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final acts = _activityLog.where((e) => e.studentId == studentId).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final docs = _documents.where((e) => e.studentId == studentId).toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
    final photos = _photos.where((e) => e.studentId == studentId).toList()
      ..sort(
        (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );

    final dossier = _practice[studentId];
    final waivers = dossier == null
        ? const <PracticeDocumentWaiver>[]
        : documentWaiversForDossier(dossier.id);

    return StudentAdmin360View(
      profile: profile,
      studyProgress: prog,
      appointments: apSorted,
      examSummary: StudentExamSummary(
        studentId: studentId,
        theoryAttempts: theory,
        practicalAttempts: pract,
      ),
      financialSummary: fin,
      payments: pay,
      practiceDossier: dossier,
      documents: docs,
      photos: photos,
      documentWaivers: waivers,
      staffNotes: notes,
      activityLog: acts,
    );
  }

  List<PracticeDocumentWaiver> documentWaiversForDossier(
    PracticeDossierId practiceDossierId,
  ) {
    return _documentWaivers
        .where((w) => w.practiceDossierId == practiceDossierId)
        .toList(growable: false);
  }

  void setPracticeDocumentRequirementWaived({
    required PracticeDossierId practiceDossierId,
    required PracticeDocumentRequirementId requirementId,
    String? note,
    StaffId? waivedByStaffId,
  }) {
    final now = DateTime.now();
    final index = _documentWaivers.indexWhere(
      (w) =>
          w.practiceDossierId == practiceDossierId &&
          w.requirementId == requirementId,
    );
    if (index >= 0) {
      final existing = _documentWaivers[index];
      _documentWaivers[index] = PracticeDocumentWaiver(
        id: existing.id,
        practiceDossierId: practiceDossierId,
        requirementId: requirementId,
        note: note,
        waivedByStaffId: waivedByStaffId ?? existing.waivedByStaffId,
        createdAt: existing.createdAt,
        updatedAt: now,
      );
    } else {
      _documentWaivers.add(
        PracticeDocumentWaiver(
          id: 'waiver-mock-$practiceDossierId-${requirementId.name}',
          practiceDossierId: practiceDossierId,
          requirementId: requirementId,
          note: note,
          waivedByStaffId: waivedByStaffId,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    notifyListeners();
  }

  void clearPracticeDocumentRequirementWaiver({
    required PracticeDossierId practiceDossierId,
    required PracticeDocumentRequirementId requirementId,
  }) {
    _documentWaivers.removeWhere(
      (w) =>
          w.practiceDossierId == practiceDossierId &&
          w.requirementId == requirementId,
    );
    notifyListeners();
  }

  StudentDocument uploadStudentDocument({
    required StudentId studentId,
    PracticeDossierId? practiceDossierId,
    required String documentType,
    required String title,
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    DateTime? expiresAt,
    String? notes,
  }) {
    final now = DateTime.now();
    final document = StudentDocument(
      id: 'doc-${now.microsecondsSinceEpoch}',
      studentId: studentId,
      practiceDossierId: practiceDossierId,
      documentType: StudentDocumentTypes.documentTypeToDb(documentType),
      title: title.trim().isEmpty ? fileName : title.trim(),
      storagePath: 'mock/student-documents/$studentId/$fileName',
      fileName: fileName,
      mimeType: mimeType,
      status: 'pending',
      expiresAt: expiresAt,
      notes: notes,
      uploadedByStaffId: 'mock-staff',
      createdAt: now,
      updatedAt: now,
    );
    _documents.add(document);
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.practiceDossierUpdated,
      title: 'Documento caricato',
      description: document.title,
    );
    notifyListeners();
    return document;
  }

  void deleteStudentDocument({
    required String documentId,
    String? storagePath,
  }) {
    _documents.removeWhere((d) => d.id == documentId);
    notifyListeners();
  }

  StudentPhoto uploadStudentPhoto({
    required StudentId studentId,
    required String photoKind,
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    String? notes,
  }) {
    final now = DateTime.now();
    final photo = StudentPhoto(
      id: 'photo-${now.microsecondsSinceEpoch}',
      studentId: studentId,
      photoKind: StudentDocumentTypes.photoKindToDb(photoKind),
      storagePath: 'mock/student-photos/$studentId/$fileName',
      fileName: fileName,
      mimeType: mimeType,
      notes: notes,
      uploadedByStaffId: 'mock-staff',
      createdAt: now,
      updatedAt: now,
    );
    _photos.add(photo);
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.practiceDossierUpdated,
      title: 'Foto allievo caricata',
      description: fileName,
    );
    notifyListeners();
    return photo;
  }

  void _updateProgressBundle(
    StudentId id,
    StudentStudyProgressBundle Function(StudentStudyProgressBundle b) updater,
  ) {
    final i = _progressBundles.indexWhere((e) => e.studentId == id);
    if (i < 0) return;
    _progressBundles[i] = updater(_progressBundles[i]);
  }

  void _syncStudyAccessRepoIfDemoStudent(
    StudentId studentId,
    void Function() apply,
  ) {
    if (studentId == SchoolBackofficeDemoData.demoStudentLucia) {
      apply();
    }
  }

  void addInternalNote({
    required StudentId studentId,
    required String body,
    String? authorStaffName,
    StaffNoteCategory category = StaffNoteCategory.general,
  }) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    final id = 'note-${DateTime.now().microsecondsSinceEpoch}';
    _staffNotes.add(
      StaffInternalNote(
        id: id,
        studentId: studentId,
        body: trimmed,
        createdAt: DateTime.now(),
        authorStaffName: authorStaffName?.trim().isEmpty ?? true
            ? null
            : authorStaffName!.trim(),
        category: category,
      ),
    );
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.internalNoteAdded,
      title: 'Nota interna aggiunta',
      description:
          '${BackofficeFormattersBridge.staffNoteCategory(category)} · '
          '${trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed}',
    );
    notifyListeners();
  }

  /// Aggiorna il campo testuale legacy [StudentProfile.internalNotes] (anagrafica).
  void updateProfileLegacyInternalNote({
    required StudentId studentId,
    String? internalNotes,
  }) {
    final i = _profiles.indexWhere((p) => p.id == studentId);
    if (i < 0) return;
    final p = _profiles[i];
    final trimmed = internalNotes?.trim();
    _profiles[i] = _patchProfile(
      p,
      updateInternalNotes: true,
      internalNotes: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.profileInternalNoteUpdated,
      title: 'Note anagrafiche interne aggiornate',
    );
    notifyListeners();
  }

  int _nextExamAttemptNumber(StudentId studentId, ExamAttemptType type) {
    final forStudent = _exams.where(
      (e) => e.studentId == studentId && e.examType == type,
    );
    if (forStudent.isEmpty) return 1;
    return forStudent
            .map((e) => e.attemptNumber)
            .reduce((a, b) => a > b ? a : b) +
        1;
  }

  void addExamAttemptRecord({
    required StudentId studentId,
    required ExamAttemptType examType,
    required ExamAttemptResult result,
    DateTime? examDate,
    String? scoreOrLabel,
    String? notes,
  }) {
    final attemptNumber = _nextExamAttemptNumber(studentId, examType);
    final id = 'exam-lcl-${DateTime.now().microsecondsSinceEpoch}';
    _exams.add(
      ExamAttempt(
        id: id,
        studentId: studentId,
        examType: examType,
        attemptNumber: attemptNumber,
        result: result,
        examDate: examDate,
        scoreOrLabel: scoreOrLabel?.trim().isEmpty ?? true
            ? null
            : scoreOrLabel!.trim(),
        notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
        createdAt: DateTime.now(),
      ),
    );
    final typeLabel = examType == ExamAttemptType.theory ? 'Teoria' : 'Pratica';
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.examResultRecorded,
      title: 'Esito esame registrato ($typeLabel)',
      description:
          '${BackofficeFormattersBridge.examResult(result)} · n. $attemptNumber',
    );
    notifyListeners();
  }

  void updatePracticeDossier({
    required StudentId studentId,
    String? practiceNumber,
    String? licenseNumber,
    DateTime? issueDate,
    DateTime? expirationDate,
    LicenseDocumentStatus? documentStatus,
    PracticeFileStatus? practiceStatus,
    String? authorityNotes,
  }) {
    final existing = _practice[studentId];
    final docStatus =
        documentStatus ??
        existing?.documentStatus ??
        LicenseDocumentStatus.notStarted;
    final prStatus =
        practiceStatus ??
        existing?.practiceStatus ??
        PracticeFileStatus.notOpen;

    final merged = PracticeLicenseDossier(
      id: existing?.id ?? 'prac-lcl-${DateTime.now().microsecondsSinceEpoch}',
      studentId: studentId,
      practiceType: existing?.practiceType,
      registrationDate: existing?.registrationDate,
      registryYear: existing?.registryYear,
      registryNumber: existing?.registryNumber,
      registryCode: existing?.registryCode,
      practiceNumber: practiceNumber?.trim().isEmpty ?? true
          ? existing?.practiceNumber
          : practiceNumber!.trim(),
      licenseNumber: licenseNumber?.trim().isEmpty ?? true
          ? existing?.licenseNumber
          : licenseNumber!.trim(),
      issueDate: issueDate ?? existing?.issueDate,
      expirationDate: expirationDate ?? existing?.expirationDate,
      documentStatus: docStatus,
      practiceStatus: prStatus,
      authorityNotes: authorityNotes?.trim().isEmpty ?? true
          ? existing?.authorityNotes
          : authorityNotes!.trim(),
      lastCheckedAt: existing?.lastCheckedAt,
      updatedByStaffId: existing?.updatedByStaffId,
    );

    _practice[studentId] = merged;
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.practiceDossierUpdated,
      title: 'Pratica / documenti aggiornati',
      description:
          'Stato doc.: ${BackofficeFormattersBridge.documentStatus(docStatus)}',
    );
    notifyListeners();
  }

  /// Allinea stato scheda quiz al dominio backoffice e, se applicabile, al repo accessi studio.
  void setLessonSheetUnlocked({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    required bool unlocked,
  }) {
    final now = DateTime.now();
    _updateProgressBundle(studentId, (b) {
      final list = List<LessonQuizSheetUnlock>.from(b.sheetUnlocks);
      final ix = list.indexWhere(
        (u) =>
            u.categoryId == categoryId &&
            u.lessonNumber == lessonNumber &&
            u.sheetNumber == sheetNumber,
      );
      if (ix >= 0) {
        final old = list[ix];
        list[ix] = LessonQuizSheetUnlock(
          studentId: studentId,
          categoryId: categoryId,
          lessonNumber: lessonNumber,
          sheetNumber: sheetNumber,
          unlocked: unlocked,
          unlockedAt: unlocked ? (old.unlockedAt ?? now) : old.unlockedAt,
          unlockedByStaffId: old.unlockedByStaffId,
          revokedAt: unlocked ? null : now,
        );
      } else {
        list.add(
          LessonQuizSheetUnlock(
            studentId: studentId,
            categoryId: categoryId,
            lessonNumber: lessonNumber,
            sheetNumber: sheetNumber,
            unlocked: unlocked,
            unlockedAt: unlocked ? now : null,
          ),
        );
      }
      return StudentStudyProgressBundle(
        studentId: b.studentId,
        assignedLessons: b.assignedLessons,
        sheetUnlocks: list,
        examAccessByCategory: b.examAccessByCategory,
        errorReviewAssignments: b.errorReviewAssignments,
        globalProgressNotes: b.globalProgressNotes,
      );
    });

    _syncStudyAccessRepoIfDemoStudent(
      studentId,
      () => studyAccessWritableRepository.applyLessonQuizSheetUnlock(
        categoryId: categoryId,
        lessonNumber: lessonNumber,
        sheetNumber: sheetNumber,
        unlocked: unlocked,
      ),
    );
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.studyAccessChanged,
      title: 'Accesso studio: scheda quiz',
      description:
          'Lezione $lessonNumber · scheda $sheetNumber · ${unlocked ? 'sbloccata' : 'revocata'}',
    );
    notifyListeners();
  }

  void setLessonSheetsUnlockedForLesson({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetCount,
    required bool unlocked,
  }) {
    for (var s = 1; s <= sheetCount; s++) {
      final now = DateTime.now();
      _updateProgressBundle(studentId, (b) {
        final list = List<LessonQuizSheetUnlock>.from(b.sheetUnlocks);
        final ix = list.indexWhere(
          (u) =>
              u.categoryId == categoryId &&
              u.lessonNumber == lessonNumber &&
              u.sheetNumber == s,
        );
        if (ix >= 0) {
          final old = list[ix];
          list[ix] = LessonQuizSheetUnlock(
            studentId: studentId,
            categoryId: categoryId,
            lessonNumber: lessonNumber,
            sheetNumber: s,
            unlocked: unlocked,
            unlockedAt: unlocked ? (old.unlockedAt ?? now) : old.unlockedAt,
            unlockedByStaffId: old.unlockedByStaffId,
            revokedAt: unlocked ? null : now,
          );
        } else {
          list.add(
            LessonQuizSheetUnlock(
              studentId: studentId,
              categoryId: categoryId,
              lessonNumber: lessonNumber,
              sheetNumber: s,
              unlocked: unlocked,
              unlockedAt: unlocked ? now : null,
            ),
          );
        }
        return StudentStudyProgressBundle(
          studentId: b.studentId,
          assignedLessons: b.assignedLessons,
          sheetUnlocks: list,
          examAccessByCategory: b.examAccessByCategory,
          errorReviewAssignments: b.errorReviewAssignments,
          globalProgressNotes: b.globalProgressNotes,
        );
      });
    }

    _syncStudyAccessRepoIfDemoStudent(
      studentId,
      () {
        for (var s = 1; s <= sheetCount; s++) {
          studyAccessWritableRepository.applyLessonQuizSheetUnlock(
            categoryId: categoryId,
            lessonNumber: lessonNumber,
            sheetNumber: s,
            unlocked: unlocked,
          );
        }
      },
    );
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.studyAccessChanged,
      title: 'Accesso studio: scheda quiz',
      description:
          'Lezione $lessonNumber · tutte le schede · ${unlocked ? 'sbloccate' : 'revocate'}',
    );
    notifyListeners();
  }

  void setExamQuizAccessForCategory({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required bool examUnlocked,
  }) {
    final now = DateTime.now();
    _updateProgressBundle(studentId, (b) {
      final list = List<ExamQuizAccess>.from(b.examAccessByCategory);
      final ix = list.indexWhere((e) => e.categoryId == categoryId);
      if (ix >= 0) {
        list[ix] = ExamQuizAccess(
          studentId: studentId,
          categoryId: categoryId,
          examUnlocked: examUnlocked,
          updatedAt: now,
        );
      } else {
        list.add(
          ExamQuizAccess(
            studentId: studentId,
            categoryId: categoryId,
            examUnlocked: examUnlocked,
            updatedAt: now,
          ),
        );
      }
      return StudentStudyProgressBundle(
        studentId: b.studentId,
        assignedLessons: b.assignedLessons,
        sheetUnlocks: b.sheetUnlocks,
        examAccessByCategory: list,
        errorReviewAssignments: b.errorReviewAssignments,
        globalProgressNotes: b.globalProgressNotes,
      );
    });

    _syncStudyAccessRepoIfDemoStudent(
      studentId,
      () => studyAccessWritableRepository.applyExamQuizUnlock(
        categoryId: categoryId,
        unlocked: examUnlocked,
      ),
    );
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.studyAccessChanged,
      title: 'Accesso studio: quiz esame',
      description: examUnlocked ? 'Abilitato' : 'Disabilitato',
    );
    notifyListeners();
  }

  void setErrorReviewTopicAssignment({
    required StudentId studentId,
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required bool topicUnlocked,
    String? didacticNote,
  }) {
    final now = DateTime.now();
    _updateProgressBundle(studentId, (b) {
      final list = List<ErrorReviewTopicAssignment>.from(
        b.errorReviewAssignments,
      );
      final ix = list.indexWhere(
        (e) => e.categoryId == categoryId && e.lessonNumber == lessonNumber,
      );
      if (ix >= 0) {
        final old = list[ix];
        list[ix] = ErrorReviewTopicAssignment(
          studentId: studentId,
          categoryId: categoryId,
          lessonNumber: lessonNumber,
          topicUnlocked: topicUnlocked,
          updatedAt: now,
          didacticNote: didacticNote ?? old.didacticNote,
        );
      } else {
        list.add(
          ErrorReviewTopicAssignment(
            studentId: studentId,
            categoryId: categoryId,
            lessonNumber: lessonNumber,
            topicUnlocked: topicUnlocked,
            didacticNote: didacticNote,
            updatedAt: now,
          ),
        );
      }
      return StudentStudyProgressBundle(
        studentId: b.studentId,
        assignedLessons: b.assignedLessons,
        sheetUnlocks: b.sheetUnlocks,
        examAccessByCategory: b.examAccessByCategory,
        errorReviewAssignments: list,
        globalProgressNotes: b.globalProgressNotes,
      );
    });

    _syncStudyAccessRepoIfDemoStudent(
      studentId,
      () => studyAccessWritableRepository.applyErrorReviewTopicUnlock(
        categoryId: categoryId,
        lessonNumber: lessonNumber,
        unlocked: topicUnlocked,
      ),
    );
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.studyAccessChanged,
      title: 'Accesso studio: ripasso errori',
      description:
          'Lezione $lessonNumber · ${topicUnlocked ? 'assegnato' : 'revocato'}',
    );
    notifyListeners();
  }

  /// Registra un incasso e ricalcola il riepilogo economico (modello semplificato quota − incassato).
  void addPayment({
    required StudentId studentId,
    required int amountCents,
    required PaymentMethod method,
    required DateTime receivedAt,
    String? notes,
    String? receiptReference,
  }) {
    if (amountCents <= 0) return;
    final fin = _financial[studentId];
    if (fin == null) return;

    final id = 'pay-lcl-${DateTime.now().microsecondsSinceEpoch}';
    _payments.add(
      PaymentReceived(
        id: id,
        studentId: studentId,
        amountCents: amountCents,
        currencyCode: fin.currencyCode,
        receivedAt: receivedAt,
        method: method,
        receiptReference: receiptReference,
        notes: notes,
      ),
    );

    final newTotal = fin.totalPaidCents + amountCents;
    final newRemaining = (fin.registrationFeeCents - newTotal).clamp(
      0,
      1 << 30,
    );

    _financial[studentId] = StudentFinancialSummary(
      studentId: fin.studentId,
      registrationFeeCents: fin.registrationFeeCents,
      currencyCode: fin.currencyCode,
      totalPaidCents: newTotal,
      remainingBalanceCents: newRemaining,
      accountingNotes: fin.accountingNotes,
      lastUpdatedAt: DateTime.now(),
    );

    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.paymentAdded,
      title: 'Pagamento registrato',
      description:
          '${(amountCents / 100).toStringAsFixed(2)} € · ${_methodLabel(method)}',
    );
    notifyListeners();
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
        return 'Welfare';
    }
  }

  void addGuidanceAppointment({
    required StudentId studentId,
    required DateTime lessonDate,
    DateTime? startTime,
    DateTime? endTime,
    String? instructorName,
    required GuidanceLessonType lessonType,
    String? notes,
  }) {
    final day = DateTime(lessonDate.year, lessonDate.month, lessonDate.day);
    final id = 'appt-lcl-${DateTime.now().microsecondsSinceEpoch}';
    final created = DateTime.now();
    _appointments.add(
      GuidanceAppointment(
        id: id,
        studentId: studentId,
        lessonDate: day,
        startTime: startTime,
        endTime: endTime,
        instructorName: instructorName,
        lessonType: lessonType,
        reminderStatus: AppointmentReminderStatus.scheduled,
        completionOutcome: AppointmentCompletionOutcome.pending,
        notes: notes,
        createdAt: created,
      ),
    );
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.guidanceAppointmentAdded,
      title: 'Guida / appuntamento registrato',
      description: '${instructorName ?? '—'} · ${_lessonTypeLabel(lessonType)}',
    );
    notifyListeners();
  }

  void updateGuidanceAppointmentOutcome({
    required AppointmentId appointmentId,
    required AppointmentCompletionOutcome outcome,
  }) {
    final idx = _appointments.indexWhere((a) => a.id == appointmentId);
    if (idx < 0) {
      throw StateError('Appuntamento guida non trovato.');
    }
    final old = _appointments[idx];
    _appointments[idx] = GuidanceAppointment(
      id: old.id,
      studentId: old.studentId,
      lessonDate: old.lessonDate,
      startTime: old.startTime,
      endTime: old.endTime,
      instructorName: old.instructorName,
      instructorStaffId: old.instructorStaffId,
      lessonType: old.lessonType,
      reminderStatus: old.reminderStatus,
      completionOutcome: outcome,
      notes: old.notes,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void updateGuidanceAppointment({
    required AppointmentId appointmentId,
    required StudentId studentId,
    required DateTime lessonDate,
    DateTime? startTime,
    DateTime? endTime,
    String? instructorName,
    String? notes,
  }) {
    final idx = _appointments.indexWhere((a) => a.id == appointmentId);
    if (idx < 0) {
      throw StateError('Appuntamento guida non trovato.');
    }
    final old = _appointments[idx];
    final day = DateTime(lessonDate.year, lessonDate.month, lessonDate.day);
    _appointments[idx] = GuidanceAppointment(
      id: old.id,
      studentId: studentId,
      lessonDate: day,
      startTime: startTime,
      endTime: endTime,
      instructorName: instructorName,
      instructorStaffId: old.instructorStaffId,
      lessonType: old.lessonType,
      reminderStatus: old.reminderStatus,
      completionOutcome: old.completionOutcome,
      notes: notes,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void deleteGuidanceAppointment({required AppointmentId appointmentId}) {
    final removed = _appointments.length;
    _appointments.removeWhere((a) => a.id == appointmentId);
    if (_appointments.length == removed) {
      throw StateError('Appuntamento guida non trovato.');
    }
    notifyListeners();
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

  void updateStudentOnboardingStatus({
    required StudentId studentId,
    required StudentOnboardingStatus status,
    String? onboardingNotes,
    String? activityTitle,
    String? activityDescription,
  }) {
    final i = _profiles.indexWhere((p) => p.id == studentId);
    if (i < 0) return;
    final p = _profiles[i];
    final old = p.onboardingStatus;
    if (old == status && onboardingNotes == null) return;
    _profiles[i] = _patchProfile(
      p,
      onboardingStatus: status,
      updateOnboardingNotes: onboardingNotes != null,
      onboardingNotes: onboardingNotes,
    );
    if (old != status) {
      final logTitle = activityTitle ?? 'Onboarding aggiornato';
      final logDescription = activityDescription ??
          (activityTitle != null
              ? null
              : '${studentOnboardingStatusLabelIt(old)} → '
                  '${studentOnboardingStatusLabelIt(status)}');
      _appendActivity(
        studentId: studentId,
        type: BackofficeActivityType.onboardingStatusChanged,
        title: logTitle,
        description: logDescription,
      );
    }
    notifyListeners();
  }

  void markStudentFirstContacted(StudentId studentId) {
    final i = _profiles.indexWhere((p) => p.id == studentId);
    if (i < 0) return;
    final p = _profiles[i];
    _profiles[i] = _patchProfile(p, firstContactedAt: DateTime.now());
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.onboardingStatusChanged,
      title: 'Primo contatto registrato',
      description: 'Data/ora aggiornata in anagrafica.',
    );
    notifyListeners();
  }

  void setStudentRegistrationFeeCents({
    required StudentId studentId,
    required int registrationFeeCents,
  }) {
    final fin = _financial[studentId];
    if (fin == null) return;
    final newRemaining = (registrationFeeCents - fin.totalPaidCents).clamp(
      0,
      1 << 30,
    );
    _financial[studentId] = StudentFinancialSummary(
      studentId: studentId,
      registrationFeeCents: registrationFeeCents,
      currencyCode: fin.currencyCode,
      totalPaidCents: fin.totalPaidCents,
      remainingBalanceCents: newRemaining,
      accountingNotes: fin.accountingNotes,
      lastUpdatedAt: DateTime.now(),
    );
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.onboardingStatusChanged,
      title: 'Quota iscrizione aggiornata',
      description:
          '${(registrationFeeCents / 100).toStringAsFixed(2)} € attesi · '
          'residuo ${(newRemaining / 100).toStringAsFixed(2)} €',
    );
    notifyListeners();
  }

  void activateStudentCourse(StudentId studentId) {
    final i = _profiles.indexWhere((p) => p.id == studentId);
    if (i < 0) return;
    final p = _profiles[i];
    final old = p.onboardingStatus;
    _profiles[i] = _patchProfile(
      p,
      registrationStatus: StudentRegistrationStatus.active,
      onboardingStatus: StudentOnboardingStatus.activeCourse,
    );
    _appendActivity(
      studentId: studentId,
      type: BackofficeActivityType.onboardingStatusChanged,
      title: 'Percorso attivato',
      description:
          '${studentOnboardingStatusLabelIt(old)} → '
          '${studentOnboardingStatusLabelIt(StudentOnboardingStatus.activeCourse)}',
    );
    notifyListeners();
  }

  /// Mock: progressivo annuale in memoria (stesso significato della RPC Supabase).
  PracticeRegistryAssignment assignPracticeRegistryNumber({
    required PracticeDossierId practiceDossierId,
    required DateTime registrationDate,
  }) {
    StudentId? sid;
    PracticeLicenseDossier? cur;
    for (final e in _practice.entries) {
      final d = e.value;
      if (d != null && d.id == practiceDossierId) {
        sid = e.key;
        cur = d;
        break;
      }
    }
    if (sid == null || cur == null) {
      throw StateError('practice_dossier_not_found');
    }
    if (cur.registryYear != null && cur.registryNumber != null) {
      final rd = cur.registrationDate ?? registrationDate;
      final code = (cur.registryCode != null && cur.registryCode!.isNotEmpty)
          ? cur.registryCode!
          : '${cur.registryYear}/${cur.registryNumber.toString().padLeft(5, '0')}';
      return PracticeRegistryAssignment(
        practiceDossierId: cur.id,
        registrationDate: DateTime(rd.year, rd.month, rd.day),
        registryYear: cur.registryYear!,
        registryNumber: cur.registryNumber!,
        registryCode: code,
      );
    }

    final y = registrationDate.year;
    final mo = registrationDate.month;
    final da = registrationDate.day;
    _mockRegistrySeqByYear[y] = (_mockRegistrySeqByYear[y] ?? 0) + 1;
    final n = _mockRegistrySeqByYear[y]!;
    final code = '$y/${n.toString().padLeft(5, '0')}';
    final regOnly = DateTime(y, mo, da);
    _practice[sid] = PracticeLicenseDossier(
      id: cur.id,
      studentId: cur.studentId,
      practiceType: cur.practiceType,
      registrationDate: regOnly,
      registryYear: y,
      registryNumber: n,
      registryCode: code,
      practiceNumber: cur.practiceNumber,
      licenseNumber: cur.licenseNumber,
      issueDate: cur.issueDate,
      expirationDate: cur.expirationDate,
      documentStatus: cur.documentStatus,
      practiceStatus: cur.practiceStatus,
      authorityNotes: cur.authorityNotes,
      lastCheckedAt: cur.lastCheckedAt,
      updatedByStaffId: cur.updatedByStaffId,
    );
    notifyListeners();
    return PracticeRegistryAssignment(
      practiceDossierId: cur.id,
      registrationDate: regOnly,
      registryYear: y,
      registryNumber: n,
      registryCode: code,
    );
  }

  /// Nuova anagrafica da gestionale (mock): senza Auth, strutture minime collegate.
  BackofficeNewStudentOutcome createBackofficeStudent({
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
    bool assignRegistryNumber = true,
  }) {
    final fn = firstName.trim();
    final ln = lastName.trim();
    if (fn.isEmpty || ln.isEmpty) {
      throw ArgumentError('Nome e cognome sono obbligatori.');
    }

    final emailNorm = email?.trim().toLowerCase();
    if (emailNorm != null && emailNorm.isNotEmpty) {
      final dup = _profiles.any(
        (p) => p.email?.trim().toLowerCase() == emailNorm,
      );
      if (dup) {
        throw DuplicateStudentEmailException(emailNorm);
      }
    }

    final licRaw = enrolledLicenseCategory?.trim();
    if (licRaw != null && licRaw.isNotEmpty) {
      final valid = LicenseCategoryId.values.any((e) => e.name == licRaw);
      if (!valid) {
        throw ArgumentError('Categoria patente non riconosciuta.');
      }
    }

    final pathRaw = enrolledCoursePath?.trim();
    final EnrollmentCoursePath path;
    if (pathRaw != null && pathRaw.isNotEmpty) {
      path =
          EnrollmentCoursePathStorage.tryParse(pathRaw) ??
          EnrollmentCoursePath.entro12Miglia;
    } else {
      path = EnrollmentCoursePath.entro12Miglia;
    }

    final id = 'stu-mock-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();

    final st = address?.trim();
    final c = city?.trim();
    final prov = province?.trim();
    final ca = cap?.trim();
    PostalAddress? addr;
    if ((st != null && st.isNotEmpty) ||
        (c != null && c.isNotEmpty) ||
        (prov != null && prov.isNotEmpty) ||
        (ca != null && ca.isNotEmpty)) {
      addr = PostalAddress(
        streetLine1: (st != null && st.isNotEmpty) ? st : null,
        city: (c != null && c.isNotEmpty) ? c : null,
        provinceCode: (prov != null && prov.isNotEmpty) ? prov : null,
        postalCode: (ca != null && ca.isNotEmpty) ? ca : null,
        countryCode: 'IT',
      );
    }

    final bp = birthPlace?.trim();
    final g = gender?.trim();
    final profile = StudentProfile(
      id: id,
      firstName: fn,
      lastName: ln,
      phone: phone == null || phone.trim().isEmpty ? null : phone.trim(),
      email: email == null || email.trim().isEmpty ? null : email.trim(),
      birthDate: birthDate,
      taxCode: fiscalCode == null || fiscalCode.trim().isEmpty
          ? null
          : fiscalCode.trim(),
      birthPlace: bp == null || bp.isEmpty ? null : bp,
      gender: g == null || g.isEmpty ? null : g,
      address: addr,
      enrolledCoursePath: path,
      registrationStatus: StudentRegistrationStatus.pending,
      onboardingStatus: StudentOnboardingStatus.pendingReview,
      onboardingNotes: null,
      linkedAuthUserId: null,
      internalNotes: notes == null || notes.trim().isEmpty
          ? null
          : notes.trim(),
      createdAt: now,
      updatedAt: now,
    );

    _profiles.add(profile);
    _progressBundles.add(
      StudentStudyProgressBundle(
        studentId: id,
        assignedLessons: const [],
        sheetUnlocks: const [],
        examAccessByCategory: const [],
        errorReviewAssignments: const [],
      ),
    );
    _financial[id] = StudentFinancialSummary(
      studentId: id,
      registrationFeeCents: 0,
      currencyCode: 'EUR',
      totalPaidCents: 0,
      remainingBalanceCents: 0,
      accountingNotes: null,
      lastUpdatedAt: now,
    );
    if (createPracticeDossier) {
      const allowed = {'new_license', 'renewal', 'duplicate'};
      final pt = practiceType?.trim();
      if (pt == null || !allowed.contains(pt)) {
        throw ArgumentError('Tipo pratica registro obbligatorio e non valido.');
      }
      if (registrationDate == null) {
        throw ArgumentError('Data iscrizione al registro obbligatoria.');
      }
      final dossierId = 'pd-mock-${DateTime.now().microsecondsSinceEpoch}';
      final reg = DateTime(
        registrationDate.year,
        registrationDate.month,
        registrationDate.day,
      );
      _practice[id] = PracticeLicenseDossier(
        id: dossierId,
        studentId: id,
        practiceType: pt,
        registrationDate: reg,
        documentStatus: LicenseDocumentStatus.notStarted,
        practiceStatus: PracticeFileStatus.notOpen,
      );
      String? assignedRegistryCode;
      String? registryAssignmentNote;
      if (assignRegistryNumber) {
        try {
          final assign = assignPracticeRegistryNumber(
            practiceDossierId: dossierId,
            registrationDate: reg,
          );
          assignedRegistryCode = assign.registryCode;
        } catch (e) {
          registryAssignmentNote = e.toString();
        }
      }
      _appendActivity(
        studentId: id,
        type: BackofficeActivityType.backofficeStudentCreated,
        title: 'Nuova pratica (gestionale)',
        description: '$fn $ln',
      );
      notifyListeners();
      return BackofficeNewStudentOutcome(
        profile: profile,
        assignedRegistryCode: assignedRegistryCode,
        registryAssignmentNote: registryAssignmentNote,
      );
    } else {
      _practice[id] = null;
    }

    _appendActivity(
      studentId: id,
      type: BackofficeActivityType.backofficeStudentCreated,
      title: 'Nuova pratica (gestionale)',
      description: '$fn $ln',
    );
    notifyListeners();
    return BackofficeNewStudentOutcome(profile: profile);
  }

  /// Inserisce un nuovo allievo dall’onboarding app (mock) con strutture minime collegate.
  ///
  /// Lancia [DuplicateStudentEmailException] se esiste già un profilo con la stessa email.
  StudentProfile registerStudentProfileFromApp({
    required StudentProfile profile,
  }) {
    final email = profile.email?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      final dup = _profiles.any((p) => p.email?.trim().toLowerCase() == email);
      if (dup) throw DuplicateStudentEmailException(email);
    }

    _profiles.add(profile);
    _progressBundles.add(
      StudentStudyProgressBundle(
        studentId: profile.id,
        assignedLessons: const [],
        sheetUnlocks: const [],
        examAccessByCategory: const [],
        errorReviewAssignments: const [],
      ),
    );
    _financial[profile.id] = StudentFinancialSummary(
      studentId: profile.id,
      registrationFeeCents: 0,
      currencyCode: 'EUR',
      totalPaidCents: 0,
      remainingBalanceCents: 0,
      accountingNotes: 'Profilo creato da registrazione app (demo).',
      lastUpdatedAt: DateTime.now(),
    );
    _practice[profile.id] = null;

    _appendActivity(
      studentId: profile.id,
      type: BackofficeActivityType.studentRegisteredFromApp,
      title: 'Nuova iscrizione da app',
      description:
          '${profile.firstName} ${profile.lastName} · ${profile.email ?? '—'} · '
          '${profile.enrolledCoursePath.name}',
    );
    notifyListeners();
    return profile;
  }
}

/// Email già presente in anagrafica mock.
class DuplicateStudentEmailException implements Exception {
  DuplicateStudentEmailException(this.email);
  final String email;

  @override
  String toString() => 'DuplicateStudentEmailException: $email';
}

/// Piccolo helper per stringhe nel store senza import `widgets/backoffice_formatters.dart`
/// (evita dipendenza Flutter dal data layer).
abstract final class BackofficeFormattersBridge {
  static String examResult(ExamAttemptResult r) {
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

  static String staffNoteCategory(StaffNoteCategory c) {
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

  static String documentStatus(LicenseDocumentStatus s) {
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
}

/// Singleton store mock backoffice (memoria processo).
final BackofficeDemoStore backofficeDemoStore = BackofficeDemoStore.initial();
