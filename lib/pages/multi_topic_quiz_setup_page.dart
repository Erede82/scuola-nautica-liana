import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/lesson_quiz_rules.dart';
import '../domain/lesson_sheet_catalog_filter.dart';
import '../domain/multi_topic_client_token.dart';
import '../domain/multi_topic_question_selection.dart';
import '../domain/multi_topic_quiz_guards.dart';
import '../domain/multi_topic_quiz_session.dart';
import '../domain/multi_topic_quiz_support.dart';
import '../domain/quiz_license_category.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../repositories/student_quiz_repository.dart';
import '../repositories/study_access_repository.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import 'multi_topic_quiz_history_page.dart';
import 'multi_topic_quiz_player_page.dart';

/// Setup Multischeda: selezione argomenti (≥2).
///
/// Totale schede = somma schede actionable reali:
/// `quiz_sets` (kind=lesson, DISTINCT sheet_number) ∩ unlock per-scheda.
class MultiTopicQuizSetupPage extends StatefulWidget {
  const MultiTopicQuizSetupPage({
    super.key,
    required this.categoryId,
    @visibleForTesting this.studentQuizRepositoryOverride,
    @visibleForTesting this.studyAccessOverride,
  });

  final LicenseCategoryId categoryId;

  @visibleForTesting
  final StudentQuizRepository? studentQuizRepositoryOverride;

  @visibleForTesting
  final StudyAccessRepository? studyAccessOverride;

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
  bool _starting = false;
  String? _loadError;
  List<_EligibleLesson> _eligible = const [];
  Map<int, List<QuizQuestion>> _poolByLesson = const {};
  Map<int, int> _actionableSheetCountByLesson = const {};
  final Set<int> _selected = {};

  StudentQuizRepository get _quizRepo =>
      widget.studentQuizRepositoryOverride ?? studentQuizRepository;

  StudyAccessRepository get _access =>
      widget.studyAccessOverride ?? studyAccessRepository;

  @override
  void initState() {
    super.initState();
    qfLog('route: MultiTopicQuizSetupPage categoryId=${widget.categoryId}');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    if (!isMultiTopicCategorySupported(widget.categoryId)) {
      setState(() {
        _loading = false;
        _eligible = const [];
        _loadError = 'Multischeda non disponibile per questa categoria.';
      });
      return;
    }

    final dbCategory = dbLicenseCategoryFor(widget.categoryId);
    if (dbCategory == null) {
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

      final results = await Future.wait([poolsFuture, sheetNumbersFuture]);
      final pools = results[0] as Map<int, List<QuizQuestion>>;
      final sheetNumbersByLesson = results[1] as Map<int, List<int>>;
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

      if (!mounted) return;
      setState(() {
        _poolByLesson = pools;
        _actionableSheetCountByLesson = actionableCounts;
        _eligible = eligible;
        _loading = false;
        _selected.removeWhere(
          (n) => !eligible.any((lesson) => lesson.number == n),
        );
      });
    } catch (err, st) {
      debugPrint('MultiTopicQuizSetupPage load error: $err\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Impossibile caricare gli argomenti. Riprova.';
        _eligible = const [];
        _actionableSheetCountByLesson = const {};
        _selected.clear();
      });
    }
  }

  LessonQuizRules? get _rules => lessonQuizRulesForCategory(widget.categoryId);

  int get _totalSheets {
    if (_selected.length < 2) return 0;
    return sumSelectedLessonSheetCounts(
      sheetCountByLesson: _actionableSheetCountByLesson,
      selectedLessonNumbers: _selected,
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
    if (_selected.length < 2) {
      return 'Seleziona almeno 2 argomenti per continuare.';
    }
    final total = _totalSheets;
    if (total < 1) {
      return 'Nessuna scheda disponibile per gli argomenti selezionati.';
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
    if (_selected.length < 2) return false;
    final total = _totalSheets;
    if (total < 1) return false;
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

    final total = _totalSheets;
    if (total < 1) return;

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
    final total = _totalSheets;
    final canStart = multiTopicStartSessionMayProceed(
      starting: _starting,
      startEnabled: _startEnabled,
    );

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
              onChanged: _starting ? null : (_) => _toggleLesson(lesson.number),
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
          'Totale schede',
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
            child: Text(
              _selected.length < 2
                  ? 'Seleziona almeno 2 argomenti'
                  : '$total schede (somma delle schede disponibili selezionate)',
              key: Key('multi_topic_total_sheets_value_$total'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: _textPrimaryColor,
              ),
            ),
          ),
        ),
        if (hint != null) ...[
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
}
