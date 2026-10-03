import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/lesson_quiz_rules.dart';
import '../domain/lesson_sheet_catalog_filter.dart';
import '../domain/multi_topic_client_token.dart';
import '../domain/multi_topic_question_selection.dart';
import '../domain/multi_topic_quiz_guards.dart';
import '../domain/multi_topic_quiz_history_models.dart';
import '../domain/multi_topic_quiz_session.dart';
import '../domain/multi_topic_quiz_support.dart';
import '../domain/multi_topic_remaining_sheets.dart';
import '../domain/quiz_license_category.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../repositories/multi_topic_quiz_attempt_repository.dart';
import '../repositories/student_quiz_repository.dart';
import '../repositories/study_access_repository.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import 'multi_topic_quiz_history_page.dart';
import 'multi_topic_quiz_player_page.dart';

/// Setup Multischeda: selezione argomenti (≥2).
///
/// Totale schede = schede ancora da svolgere:
/// actionable catalogo − attempt Multischeda completati rilevanti.
class MultiTopicQuizSetupPage extends StatefulWidget {
  const MultiTopicQuizSetupPage({
    super.key,
    required this.categoryId,
    @visibleForTesting this.studentQuizRepositoryOverride,
    @visibleForTesting this.studyAccessOverride,
    @visibleForTesting this.attemptRepositoryOverride,
  });

  final LicenseCategoryId categoryId;

  @visibleForTesting
  final StudentQuizRepository? studentQuizRepositoryOverride;

  @visibleForTesting
  final StudyAccessRepository? studyAccessOverride;

  @visibleForTesting
  final MultiTopicQuizAttemptRepository? attemptRepositoryOverride;

  @override
  State<MultiTopicQuizSetupPage> createState() =>
      _MultiTopicQuizSetupPageState();
}

class _EligibleLesson {
  const _EligibleLesson({
    required this.number,
    required this.title,
    required this.poolSize,
    required this.sheetCount,
  });

  final int number;
  final String title;
  final int poolSize;
  final int sheetCount;
}

class _MultiTopicQuizSetupPageState extends State<MultiTopicQuizSetupPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;

  bool _loading = true;
  bool _historyRefreshing = false;
  bool _starting = false;
  String? _loadError;

  /// Storico attempts affidabile solo se true (successo esplicito).
  /// false = loading / failed → remaining non usabile, Start off.
  bool _historyReady = false;
  bool _historyFailed = false;

  List<_EligibleLesson> _eligible = const [];
  Map<int, List<QuizQuestion>> _poolByLesson = const {};
  Map<int, int> _actionableSheetCountByLesson = const {};
  List<MultiTopicQuizAttemptSummary> _completedAttempts = const [];
  final Set<int> _selected = {};

  /// Generazione load: scarta risposte stale di fetch async precedenti.
  int _loadGeneration = 0;

  StudentQuizRepository get _quizRepo =>
      widget.studentQuizRepositoryOverride ?? studentQuizRepository;

  StudyAccessRepository get _access =>
      widget.studyAccessOverride ?? studyAccessRepository;

  MultiTopicQuizAttemptRepository get _attemptRepo =>
      widget.attemptRepositoryOverride ?? multiTopicQuizAttemptRepository;

  @override
  void initState() {
    super.initState();
    qfLog('route: MultiTopicQuizSetupPage categoryId=${widget.categoryId}');
    _load();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _historyRefreshing = false;
      _loadError = null;
      _historyReady = false;
      _historyFailed = false;
    });

    if (!isMultiTopicCategorySupported(widget.categoryId)) {
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _loading = false;
        _eligible = const [];
        _loadError = 'Multischeda non disponibile per questa categoria.';
      });
      return;
    }

    final dbCategory = dbLicenseCategoryFor(widget.categoryId);
    if (dbCategory == null) {
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _loading = false;
        _eligible = const [];
        _loadError = 'Multischeda non disponibile per questa categoria.';
      });
      return;
    }

    try {
      final category = LicenseCatalog.byId(widget.categoryId);
      final lessonNumbers = [
        for (final lesson in category.lessons) lesson.number,
      ];

      final poolsFuture = lessonNumbers.isEmpty
          ? Future.value(<int, List<QuizQuestion>>{})
          : _quizRepo.fetchQuestionsForLessons(
              categoryId: widget.categoryId,
              lessonNumbers: lessonNumbers,
            );
      final sheetNumbersFuture = _quizRepo.fetchLessonSheetNumbersByLesson(
        categoryId: widget.categoryId,
      );

      final catalogResults = await Future.wait([
        poolsFuture,
        sheetNumbersFuture,
      ]);
      if (!_isCurrentGeneration(generation)) return;

      final pools = catalogResults[0] as Map<int, List<QuizQuestion>>;
      final sheetNumbersByLesson = catalogResults[1] as Map<int, List<int>>;
      final actionableCounts = actionableLessonSheetCountsByLesson(
        sheetNumbersByLesson: sheetNumbersByLesson,
        isSheetUnlocked: (lessonNumber, sheetNumber) => _access
            .lessonQuizSheet(
              categoryId: widget.categoryId,
              lessonNumber: lessonNumber,
              sheetNumber: sheetNumber,
            )
            .isUnlocked,
      );

      final eligible = <_EligibleLesson>[];
      for (final lesson in category.lessons) {
        final pool = pools[lesson.number] ?? const <QuizQuestion>[];
        final hasPool = pool.isNotEmpty;
        final sheetCount = actionableCounts[lesson.number] ?? 0;
        final unlocked = sheetCount > 0;
        if (!isLessonEligibleForMultiTopic(
          categoryId: widget.categoryId,
          hasQuestionPool: hasPool,
          isUnlocked: unlocked,
          availableSheetCount: sheetCount,
        )) {
          continue;
        }
        eligible.add(
          _EligibleLesson(
            number: lesson.number,
            title: lesson.title,
            poolSize: pool.length,
            sheetCount: sheetCount,
          ),
        );
      }

      List<MultiTopicQuizAttemptSummary> completedAttempts =
          const <MultiTopicQuizAttemptSummary>[];
      var historyReady = false;
      var historyFailed = false;
      try {
        completedAttempts = await _attemptRepo.fetchCurrentUserAttempts(
          category: widget.categoryId,
        );
        historyReady = true;
      } catch (err, st) {
        debugPrint('MultiTopicQuizSetupPage history load error: $err\n$st');
        historyFailed = true;
        historyReady = false;
        completedAttempts = const [];
      }

      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _poolByLesson = pools;
        _actionableSheetCountByLesson = actionableCounts;
        _completedAttempts = completedAttempts;
        _historyReady = historyReady;
        _historyFailed = historyFailed;
        _eligible = eligible;
        _loading = false;
        _selected.removeWhere(
          (n) => !eligible.any((lesson) => lesson.number == n),
        );
      });
    } catch (err, st) {
      debugPrint('MultiTopicQuizSetupPage load error: $err\n$st');
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _loading = false;
        _loadError = 'Impossibile caricare gli argomenti. Riprova.';
        _eligible = const [];
        _actionableSheetCountByLesson = const {};
        _completedAttempts = const [];
        _historyReady = false;
        _historyFailed = false;
        _selected.clear();
      });
    }
  }

  /// Retry solo dello storico (catalogo già in memoria).
  Future<void> _retryHistory() async {
    final generation = ++_loadGeneration;
    setState(() {
      _historyRefreshing = true;
      _historyReady = false;
      // Mantieni `_historyFailed` finché non c'è successo: la UI Riprova resta visibile.
    });

    try {
      final completedAttempts = await _attemptRepo.fetchCurrentUserAttempts(
        category: widget.categoryId,
      );
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _completedAttempts = completedAttempts;
        _historyReady = true;
        _historyFailed = false;
        _historyRefreshing = false;
      });
    } catch (err, st) {
      debugPrint('MultiTopicQuizSetupPage history retry error: $err\n$st');
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _historyReady = false;
        _historyFailed = true;
        _historyRefreshing = false;
      });
    }
  }

  bool _isCurrentGeneration(int generation) =>
      mounted && generation == _loadGeneration;

  LessonQuizRules? get _rules => lessonQuizRulesForCategory(widget.categoryId);

  int get _catalogActionableTotal {
    if (_selected.length < 2) return 0;
    return sumSelectedLessonSheetCounts(
      sheetCountByLesson: _actionableSheetCountByLesson,
      selectedLessonNumbers: _selected,
    );
  }

  int get _completedRelevantCount {
    if (!_historyReady || _selected.length < 2) return 0;
    return countCompletedRelevantMultiTopicSheets(
      attempts: _completedAttempts,
      currentLicenseCategory: widget.categoryId,
      selectedLessonNumbers: _selected,
    );
  }

  /// Totale residuo solo se history ready; altrimenti null (non affidabile).
  int? get _totalSheetsOrNull {
    if (!_historyReady) return null;
    return remainingMultiTopicSheets(
      catalogActionableTotal: _catalogActionableTotal,
      completedRelevantCount: _completedRelevantCount,
    );
  }

  void _toggleLesson(int lessonNumber) {
    setState(() {
      if (_selected.contains(lessonNumber)) {
        _selected.remove(lessonNumber);
      } else {
        _selected.add(lessonNumber);
      }
    });
  }

  String? get _selectionHint {
    if (_loadError != null) return _loadError;
    if (_historyFailed) {
      return 'Impossibile calcolare le schede ancora da svolgere.';
    }
    if (!_historyReady) {
      return 'Calcolo delle schede residue in corso…';
    }
    if (_selected.length < 2) {
      return 'Seleziona almeno 2 argomenti per continuare.';
    }
    final catalog = _catalogActionableTotal;
    if (catalog < 1) {
      return 'Nessuna scheda disponibile per gli argomenti selezionati.';
    }
    final total = _totalSheetsOrNull ?? 0;
    if (total < 1) {
      return 'Hai completato tutte le schede disponibili.';
    }
    final rules = _rules;
    if (rules == null) return 'Categoria non supportata.';
    final selected = _selected.toList()..sort();
    final shortfall = findMultiTopicPoolShortfall(
      poolByLesson: _poolByLesson,
      selectedLessonNumbers: selected,
      questionsPerSheet: rules.questionsPerSheet,
      sheetCount: total,
    );
    return shortfall?.message;
  }

  bool get _startEnabled {
    if (_loadError != null) return false;
    if (!_historyReady || _historyFailed) return false;
    if (_selected.length < 2) return false;
    final total = _totalSheetsOrNull;
    if (total == null || total < 1) return false;
    final rules = _rules;
    if (rules == null) return false;
    final selected = _selected.toList()..sort();
    return findMultiTopicPoolShortfall(
          poolByLesson: _poolByLesson,
          selectedLessonNumbers: selected,
          questionsPerSheet: rules.questionsPerSheet,
          sheetCount: total,
        ) ==
        null;
  }

  Future<void> _startSession() async {
    if (!multiTopicStartSessionMayProceed(
      starting: _starting,
      startEnabled: _startEnabled,
    )) {
      return;
    }
    final rules = _rules;
    if (rules == null) return;

    final total = _totalSheetsOrNull;
    if (total == null || total < 1) return;

    setState(() => _starting = true);

    final selected = _selected.toList()..sort();
    final session = MultiTopicQuizSession(
      sessionId: generateMultiTopicUuid(),
      licenseCategory: widget.categoryId,
      selectedLessonNumbers: selected,
      totalSheets: total,
      poolByLesson: {
        for (final lesson in selected)
          lesson: List<QuizQuestion>.from(
            _poolByLesson[lesson] ?? const <QuizQuestion>[],
          ),
      },
    );

    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MultiTopicQuizPlayerPage(session: session),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _starting = false);
        // Ricarica residue dopo la sessione (attempts aggiornati).
        await _load();
      }
    }
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            MultiTopicQuizHistoryPage(categoryId: widget.categoryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = LicenseCatalog.byId(widget.categoryId);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Multischede argomento'),
        centerTitle: true,
        actions: [
          if (isMultiTopicCategorySupported(widget.categoryId))
            IconButton(
              tooltip: 'Storico Multischeda',
              onPressed: _openHistory,
              icon: const Icon(Icons.history_rounded),
            ),
          const StaffPreviewAppBarBadge(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(theme, category.name),
    );
  }

  Widget _buildBody(ThemeData theme, String categoryName) {
    if (!isMultiTopicCategorySupported(widget.categoryId)) {
      return AppEmptyState(
        title: 'Non disponibile',
        message:
            'La Multischeda è disponibile solo per Patente Motore (A12) e D1.',
        icon: Icons.block_rounded,
        primaryActionLabel: 'Indietro',
        primaryActionIcon: Icons.arrow_back_rounded,
        onPrimaryActionPressed: () => Navigator.maybePop(context),
      );
    }

    if (_loadError != null) {
      return AppEmptyState(
        title: 'Errore',
        message: _loadError!,
        icon: Icons.error_outline_rounded,
        primaryActionLabel: 'Riprova',
        primaryActionIcon: Icons.refresh_rounded,
        onPrimaryActionPressed: _load,
      );
    }

    if (_eligible.isEmpty) {
      return AppEmptyState(
        title: 'Nessun argomento disponibile',
        message:
            'Non ci sono lezioni sbloccate con schede e domande disponibili '
            'per la Multischeda ($categoryName). '
            'Quando la scuola abiliterà le schede, potrai combinare gli argomenti.',
        icon: Icons.lock_outline_rounded,
        tagLabel: 'Abilitazione scuola',
        primaryActionLabel: 'Vedi storico',
        primaryActionIcon: Icons.history_rounded,
        onPrimaryActionPressed: _openHistory,
      );
    }

    final rules = _rules;
    final hint = _selectionHint;
    final total = _totalSheetsOrNull;
    final canStart = multiTopicStartSessionMayProceed(
      starting: _starting,
      startEnabled: _startEnabled,
    );
    final historyBusy =
        _historyRefreshing || (!_historyReady && !_historyFailed);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          'Combina più argomenti e allenati con schede miste ($categoryName).',
          style: theme.textTheme.bodyMedium?.copyWith(color: _textPrimaryColor),
        ),
        if (rules != null) ...[
          const SizedBox(height: 6),
          Text(
            'Ogni scheda contiene ${rules.questionsPerSheet} domande.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.75),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Argomenti',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: _textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        ..._eligible.map((lesson) {
          final selected = _selected.contains(lesson.number);
          return Card(
            color: _cardColor,
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: selected
                  ? const BorderSide(color: _primaryColor, width: 1.5)
                  : BorderSide.none,
            ),
            child: CheckboxListTile(
              value: selected,
              onChanged: (_starting || _historyRefreshing)
                  ? null
                  : (_) => _toggleLesson(lesson.number),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              title: Text(
                'Lezione ${lesson.number}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _textPrimaryColor,
                ),
              ),
              subtitle: Text(
                '${lesson.title} · ${lesson.sheetCount} schede',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.8),
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: _primaryColor,
            ),
          );
        }),
        const SizedBox(height: 12),
        Text(
          'Schede da svolgere',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: _textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          key: const Key('multi_topic_total_sheets'),
          color: _cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: _buildTotalSheetsLabel(theme, total, historyBusy),
          ),
        ),
        if (_historyFailed) ...[
          const SizedBox(height: 12),
          Text(
            key: const Key('multi_topic_history_error'),
            'Impossibile calcolare le schede ancora da svolgere.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFFB45309),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('multi_topic_history_retry'),
            // Sempre abilitato: una nuova richiesta invalida la precedente (generation).
            onPressed: _retryHistory,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_historyRefreshing ? 'RICARICO…' : 'Riprova'),
          ),
        ] else if (hint != null) ...[
          const SizedBox(height: 12),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _startEnabled
                  ? _textPrimaryColor.withValues(alpha: 0.75)
                  : const Color(0xFFB45309),
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('multi_topic_start_button'),
          onPressed: canStart ? _startSession : null,
          style: FilledButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(_starting ? 'AVVIO…' : 'INIZIA MULTISCHEDA'),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _openHistory,
          icon: const Icon(Icons.history_rounded),
          label: const Text('Storico Multischeda'),
        ),
      ],
    );
  }

  Widget _buildTotalSheetsLabel(ThemeData theme, int? total, bool historyBusy) {
    final style = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: _textPrimaryColor,
    );
    if (_selected.length < 2) {
      return Text(
        'Seleziona almeno 2 argomenti',
        textAlign: TextAlign.center,
        style: style,
      );
    }
    if (historyBusy || (!_historyReady && !_historyFailed)) {
      return Text(
        key: const Key('multi_topic_total_sheets_loading'),
        'Calcolo in corso…',
        textAlign: TextAlign.center,
        style: style,
      );
    }
    if (_historyFailed || !_historyReady || total == null) {
      return Text(
        key: const Key('multi_topic_total_sheets_unavailable'),
        'Conteggio non disponibile',
        textAlign: TextAlign.center,
        style: style,
      );
    }
    return Text(
      total == 1 ? '1 scheda da svolgere' : '$total schede da svolgere',
      key: Key('multi_topic_total_sheets_value_$total'),
      textAlign: TextAlign.center,
      style: style,
    );
  }
}
