import 'package:flutter/foundation.dart';

import '../data/license_catalog.dart';
import '../domain/backoffice/backoffice.dart';
import '../models/license_models.dart';
import '../models/study_content_access.dart';

/// Contratto lettura permessi — implementazione reale = API / Supabase.
abstract class StudyAccessRepository {
  StudyContentAccessSnapshot lessonQuizSheet({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  });

  StudyContentAccessSnapshot examQuiz(LicenseCategoryId categoryId);

  StudyContentAccessSnapshot errorReviewTopic({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  });
}

/// Operazioni di assegnazione manuale (segreteria / admin).
/// In produzione: metodi possono diventare async e chiamare il backend.
abstract class StudyAccessWritableRepository extends StudyAccessRepository {
  /// Forza stato sblocco scheda (sovrascrive il seed demo finché non si fa reset).
  void applyLessonQuizSheetUnlock({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    required bool unlocked,
  });

  void applyExamQuizUnlock({
    required LicenseCategoryId categoryId,
    required bool unlocked,
  });

  void applyErrorReviewTopicUnlock({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required bool unlocked,
  });

  /// Rimuove tutte le assegnazioni mock (torna ai default seed).
  void resetDemoAssignments();

  /// Sostituisce gli override locali con le righe lette da Supabase (`lesson_quiz_sheet_unlocks`, …).
  /// Chiamato al login studente affinché D1 / motore / vela riflettano la segreteria.
  void hydrateFromRemoteStudyProgress(StudentStudyProgressBundle bundle);

  /// Valore esplicito in memoria per la scheda (`null` se non impostato, oltre al seed demo).
  /// Serve alla UI segreteria per segnalare sblocchi **non uniformi** tra schede della stessa lezione.
  bool? storedLessonSheetUnlocked({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  });
}

// --- Singleton demo mutabile (notifiche UI) ---

final MutableMockStudyAccessRepository _studyAccessRepoImpl =
    MutableMockStudyAccessRepository();

StudyAccessRepository get studyAccessRepository => _studyAccessRepoImpl;

StudyAccessWritableRepository get studyAccessWritableRepository =>
    _studyAccessRepoImpl;

/// Ascolta per aggiornare le schermate studente dopo modifiche admin/demo.
Listenable get studyAccessListenable => _studyAccessRepoImpl;

/// Effettivo stato sblocco (dopo override + seed) — utile per UI admin senza duplicare regole.
extension StudyAccessRepositoryEffective on StudyAccessRepository {
  bool effectiveLessonSheetUnlocked(
    LicenseCategoryId categoryId,
    int lessonNumber,
    int sheetNumber,
  ) =>
      lessonQuizSheet(
        categoryId: categoryId,
        lessonNumber: lessonNumber,
        sheetNumber: sheetNumber,
      ).isUnlocked;

  bool effectiveExamUnlocked(LicenseCategoryId categoryId) =>
      examQuiz(categoryId).isUnlocked;

  bool effectiveErrorTopicUnlocked(
    LicenseCategoryId categoryId,
    int lessonNumber,
  ) =>
      errorReviewTopic(
        categoryId: categoryId,
        lessonNumber: lessonNumber,
      ).isUnlocked;
}

/// Dati locali mutabili: simula assegnazioni manuali della scuola.
/// Sostituibile con `RemoteStudyAccessRepository` che estende [ChangeNotifier]
/// o con uno store iniettato.
class MutableMockStudyAccessRepository extends ChangeNotifier
    implements StudyAccessWritableRepository {
  /// Default seed quando non c’è override (come prima dell’intro admin).
  /// Si applica a categorie con catalogo teoria completo (motore entro 12, D1).
  static const bool kDemoUnlockEntireExamForTheory = false;

  final Map<String, bool> _lessonSheetOverrides = {};
  final Map<LicenseCategoryId, bool> _examOverrides = {};
  final Map<String, bool> _errorTopicOverrides = {};

  static String _sheetStoreKey(
    LicenseCategoryId categoryId,
    int lessonNumber,
    int sheetNumber,
  ) =>
      '${categoryId.name}:L$lessonNumber:S$sheetNumber';

  static String _topicStoreKey(LicenseCategoryId categoryId, int lessonNumber) =>
      '${categoryId.name}:L$lessonNumber';

  @override
  void applyLessonQuizSheetUnlock({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
    required bool unlocked,
  }) {
    _lessonSheetOverrides[
        _sheetStoreKey(categoryId, lessonNumber, sheetNumber)] = unlocked;
    notifyListeners();
  }

  @override
  void applyExamQuizUnlock({
    required LicenseCategoryId categoryId,
    required bool unlocked,
  }) {
    _examOverrides[categoryId] = unlocked;
    notifyListeners();
  }

  @override
  void applyErrorReviewTopicUnlock({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required bool unlocked,
  }) {
    _errorTopicOverrides[_topicStoreKey(categoryId, lessonNumber)] = unlocked;
    notifyListeners();
  }

  bool? _lessonSheetOverride(
    LicenseCategoryId categoryId,
    int lessonNumber,
    int sheetNumber,
  ) {
    final k = _sheetStoreKey(categoryId, lessonNumber, sheetNumber);
    return _lessonSheetOverrides.containsKey(k) ? _lessonSheetOverrides[k] : null;
  }

  bool? _examOverride(LicenseCategoryId categoryId) =>
      _examOverrides.containsKey(categoryId) ? _examOverrides[categoryId] : null;

  bool? _errorTopicOverride(LicenseCategoryId categoryId, int lessonNumber) {
    final k = _topicStoreKey(categoryId, lessonNumber);
    return _errorTopicOverrides.containsKey(k) ? _errorTopicOverrides[k] : null;
  }

  @override
  void resetDemoAssignments() {
    _lessonSheetOverrides.clear();
    _examOverrides.clear();
    _errorTopicOverrides.clear();
    notifyListeners();
  }

  @override
  bool? storedLessonSheetUnlocked({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) {
    return _lessonSheetOverride(categoryId, lessonNumber, sheetNumber);
  }

  @override
  void hydrateFromRemoteStudyProgress(StudentStudyProgressBundle bundle) {
    resetDemoAssignments();
    for (final u in bundle.sheetUnlocks) {
      applyLessonQuizSheetUnlock(
        categoryId: u.categoryId,
        lessonNumber: u.lessonNumber,
        sheetNumber: u.sheetNumber,
        unlocked: u.unlocked,
      );
    }
    for (final e in bundle.examAccessByCategory) {
      applyExamQuizUnlock(
        categoryId: e.categoryId,
        unlocked: e.examUnlocked,
      );
    }
    for (final t in bundle.errorReviewAssignments) {
      applyErrorReviewTopicUnlock(
        categoryId: t.categoryId,
        lessonNumber: t.lessonNumber,
        unlocked: t.topicUnlocked,
      );
    }
  }

  static String _sheetUnlockedLabel(LicenseCategoryId categoryId) {
    switch (categoryId) {
      case LicenseCategoryId.d1:
        return 'Schede abilitate dalla scuola · percorso D1 attivo';
      case LicenseCategoryId.motore:
        return 'Sbloccata dalla scuola';
      case LicenseCategoryId.vela:
        return 'Schede abilitate dalla scuola';
    }
  }

  static String _examUnlockedLabel(LicenseCategoryId categoryId) {
    switch (categoryId) {
      case LicenseCategoryId.d1:
        return 'Quiz esame D1 · abilitato dalla scuola';
      case LicenseCategoryId.motore:
        return 'Sbloccato dalla scuola';
      case LicenseCategoryId.vela:
        return 'Abilitato dalla scuola';
    }
  }

  static String _errorTopicUnlockedLabel(LicenseCategoryId categoryId) {
    switch (categoryId) {
      case LicenseCategoryId.d1:
        return 'Ripasso D1 · abilitato dalla scuola';
      case LicenseCategoryId.motore:
        return 'Sbloccato dalla scuola';
      case LicenseCategoryId.vela:
        return 'Assegnato dalla scuola';
    }
  }

  static String _examLockedTheoryMessage(LicenseCategoryId categoryId) {
    switch (categoryId) {
      case LicenseCategoryId.d1:
        return 'Quiz esame D1 disponibile su assegnazione della scuola. '
            'La segreteria abiliterà questa sezione quando sarai pronto, '
            'in coordinamento con il percorso in aula.';
      case LicenseCategoryId.motore:
        return 'Quiz esame disponibile su assegnazione della scuola. '
            'La scuola abiliterà questa sezione quando sarai pronto, '
            'in coordinamento con il percorso in aula.';
      case LicenseCategoryId.vela:
        return '';
    }
  }

  /// Motore entro 12 e D1: catalogo lezioni + stesse regole di sblocco progressivo / scuola.
  static bool _isTheoryCatalogCategory(LicenseCategoryId id) =>
      id == LicenseCategoryId.motore || id == LicenseCategoryId.d1;

  /// Vela: contenuti non ancora in catalogo app — solo ciò che la scuola abilita in DB.
  static bool _isVelaPlaceholderCategory(LicenseCategoryId id) =>
      id == LicenseCategoryId.vela;

  @override
  StudyContentAccessSnapshot lessonQuizSheet({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
    required int sheetNumber,
  }) {
    final contentId = 'lesson:$lessonNumber:sheet:$sheetNumber';
    if (_isVelaPlaceholderCategory(categoryId)) {
      final override =
          _lessonSheetOverride(categoryId, lessonNumber, sheetNumber);
      if (override == true) {
        return StudyContentAccessSnapshot(
          contentType: StudyContentType.lessonQuizSheet,
          categoryId: categoryId,
          contentId: contentId,
          isUnlocked: true,
          unlockSource: StudyUnlockSource.manualBySchool,
          unlockMessage: 'Schede abilitate dalla scuola',
        );
      }
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.lessonQuizSheet,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage:
            'Contenuti vela in preparazione. Le schede saranno abilitate dalla scuola quando disponibili.',
      );
    }

    if (!_isTheoryCatalogCategory(categoryId)) {
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.lessonQuizSheet,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage: 'Categoria non supportata.',
      );
    }

    final category = LicenseCatalog.byId(categoryId);
    final match =
        category.lessons.where((l) => l.number == lessonNumber).toList();
    if (match.isEmpty) {
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.lessonQuizSheet,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage: 'Lezione non trovata nel catalogo.',
      );
    }

    final lesson = match.first;
    final maxSheets = lesson.quizSheets;
    if (maxSheets <= 0) {
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.lessonQuizSheet,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage: 'Nessuna scheda pubblicata per questa lezione.',
      );
    }

    /// Sblocco a **livello lezione**: basta un’abilitazione scuola (true su almeno una scheda)
    /// oppure, se la segreteria non ha mai impostato righe per questa lezione, il seed demo.
    /// Se esiste **qualsiasi** override memorizzato per la lezione (`true` o `false`), il demo
    /// non si applica: così «Blocca tutta la lezione» (tutte le schede a `false`) resta effettivo.
    final schoolUnlockedLesson = _anyLessonSheetOverrideTrue(
      categoryId,
      lessonNumber,
      maxSheets,
    );
    final schoolStoredAnySheetForLesson = _lessonHasAnyStoredSheetOverride(
      categoryId,
      lessonNumber,
      maxSheets,
    );
    final demoLessonUnlocked = !schoolStoredAnySheetForLesson &&
        _demoEntireLessonUnlockedForStudent(category, lessonNumber);
    final lessonUnlocked = schoolUnlockedLesson || demoLessonUnlocked;

    if (lessonUnlocked) {
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.lessonQuizSheet,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: true,
        unlockSource: StudyUnlockSource.manualBySchool,
        unlockMessage: _sheetUnlockedLabel(categoryId),
      );
    }

    return StudyContentAccessSnapshot(
      contentType: StudyContentType.lessonQuizSheet,
      categoryId: categoryId,
      contentId: contentId,
      isUnlocked: false,
      lockedMessage:
          'Lezione in attesa di abilitazione da parte della scuola. '
          'Quando la scuola abiliterà la lezione, potrai accedere a tutte le sue schede quiz.',
    );
  }

  /// `true` se **almeno una** scheda della lezione ha override esplicito `unlocked == true`
  /// (tipico: righe Supabase / gestione interna).
  bool _anyLessonSheetOverrideTrue(
    LicenseCategoryId categoryId,
    int lessonNumber,
    int maxSheets,
  ) {
    for (var s = 1; s <= maxSheets; s++) {
      if (_lessonSheetOverride(categoryId, lessonNumber, s) == true) {
        return true;
      }
    }
    return false;
  }

  /// `true` se per almeno una scheda della lezione c’è una chiave in `_lessonSheetOverrides`
  /// (valore `true` o `false`). Serve a spegnere il seed demo dopo intervento segreteria / sync DB.
  bool _lessonHasAnyStoredSheetOverride(
    LicenseCategoryId categoryId,
    int lessonNumber,
    int maxSheets,
  ) {
    for (var s = 1; s <= maxSheets; s++) {
      final k = _sheetStoreKey(categoryId, lessonNumber, s);
      if (_lessonSheetOverrides.containsKey(k)) return true;
    }
    return false;
  }

  /// Demo: prime N lezioni del catalogo interamente sbloccate (stessa “porzione” del vecchio seed).
  bool _demoEntireLessonUnlockedForStudent(
    LicenseCategory category,
    int lessonNumber,
  ) {
    if (category.lessons.isEmpty) return false;
    final sortedNums = category.lessons.map((l) => l.number).toList()..sort();
    final idx = sortedNums.indexOf(lessonNumber);
    if (idx < 0) return false;
    final n = sortedNums.length;
    final fraction = 0.35 + (n % 5) * 0.06;
    final unlockedLessonCount = (n * fraction).ceil().clamp(1, n);
    return idx < unlockedLessonCount;
  }

  @override
  StudyContentAccessSnapshot examQuiz(LicenseCategoryId categoryId) {
    const contentId = 'exam';
    if (_isVelaPlaceholderCategory(categoryId)) {
      final o = _examOverride(categoryId);
      if (o == true) {
        return StudyContentAccessSnapshot(
          contentType: StudyContentType.examQuiz,
          categoryId: categoryId,
          contentId: contentId,
          isUnlocked: true,
          unlockSource: StudyUnlockSource.manualBySchool,
          unlockMessage: 'Abilitato dalla scuola',
        );
      }
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.examQuiz,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage:
            'Contenuti vela in preparazione. Il quiz esame sarà disponibile prossimamente.',
      );
    }

    if (!_isTheoryCatalogCategory(categoryId)) {
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.examQuiz,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage: 'Categoria non supportata.',
      );
    }

    final o = _examOverride(categoryId);
    if (o != null) {
      if (o) {
        return StudyContentAccessSnapshot(
          contentType: StudyContentType.examQuiz,
          categoryId: categoryId,
          contentId: contentId,
          isUnlocked: true,
          unlockSource: StudyUnlockSource.manualBySchool,
          unlockMessage: _examUnlockedLabel(categoryId),
        );
      }
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.examQuiz,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage: _examLockedTheoryMessage(categoryId),
      );
    }

    if (!kDemoUnlockEntireExamForTheory) {
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.examQuiz,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage: _examLockedTheoryMessage(categoryId),
      );
    }

    return StudyContentAccessSnapshot(
      contentType: StudyContentType.examQuiz,
      categoryId: categoryId,
      contentId: contentId,
      isUnlocked: true,
      unlockSource: StudyUnlockSource.manualBySchool,
      unlockMessage: _examUnlockedLabel(categoryId),
    );
  }

  @override
  StudyContentAccessSnapshot errorReviewTopic({
    required LicenseCategoryId categoryId,
    required int lessonNumber,
  }) {
    final contentId = 'topic:L$lessonNumber';
    if (_isVelaPlaceholderCategory(categoryId)) {
      final o = _errorTopicOverride(categoryId, lessonNumber);
      if (o == true) {
        return StudyContentAccessSnapshot(
          contentType: StudyContentType.errorReviewTopic,
          categoryId: categoryId,
          contentId: contentId,
          isUnlocked: true,
          unlockSource: StudyUnlockSource.manualBySchool,
          unlockMessage: 'Assegnato dalla scuola',
        );
      }
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.errorReviewTopic,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage:
            'Contenuti vela in preparazione. Il ripasso sarà disponibile prossimamente.',
      );
    }

    if (!_isTheoryCatalogCategory(categoryId)) {
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.errorReviewTopic,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: false,
        lockedMessage: 'Categoria non supportata.',
      );
    }

    final o = _errorTopicOverride(categoryId, lessonNumber);
    final unlocked = o ?? (lessonNumber != 7);

    if (unlocked) {
      return StudyContentAccessSnapshot(
        contentType: StudyContentType.errorReviewTopic,
        categoryId: categoryId,
        contentId: contentId,
        isUnlocked: true,
        unlockSource: StudyUnlockSource.manualBySchool,
        unlockMessage: _errorTopicUnlockedLabel(categoryId),
      );
    }

    return StudyContentAccessSnapshot(
      contentType: StudyContentType.errorReviewTopic,
      categoryId: categoryId,
      contentId: contentId,
      isUnlocked: false,
      lockedMessage: categoryId == LicenseCategoryId.d1
          ? 'Argomento consigliato per il ripasso D1, ma ancora non abilitato. '
              'La scuola ti abiliterà questo ripasso quando opportuno.'
          : 'Argomento consigliato dalle statistiche, ma ancora non abilitato. '
              'La scuola ti abiliterà questo ripasso quando opportuno.',
    );
  }
}
