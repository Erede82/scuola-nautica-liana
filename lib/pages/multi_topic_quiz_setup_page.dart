import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/lesson_quiz_rules.dart';
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

/// Setup Multischeda: selezione argomenti (≥2) e numero schede.
///
/// Eligibility: supportedCategory && hasQuestionPool && isUnlocked.
/// NON dipende da `quiz_sets` (a differenza di STUDIO → SCHEDE).
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
  });

  final int number;
  final String title;
  final int poolSize;
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
  final Set<int> _selected = {};
  int _sheetCount = 1;
  int _maxSheets = 1;

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
      // Candidati da catalogo teoria + pool `questions` (NON da quiz_sets).
      final lessonNumbers = [
        for (final lesson in category.lessons) lesson.number,
      ];

      final pools = lessonNumbers.isEmpty
          ? <int, List<QuizQuestion>>{}
          : await _quizRepo.fetchQuestionsForLessons(
              categoryId: widget.categoryId,
              lessonNumbers: lessonNumbers,
            );

      final eligible = <_EligibleLesson>[];
      for (final lesson in category.lessons) {
        final pool = pools[lesson.number] ?? const <QuizQuestion>[];
        final hasPool = pool.isNotEmpty;
        final unlocked = _access
            .lessonQuizSheet(
              categoryId: widget.categoryId,
              lessonNumber: lesson.number,
              sheetNumber: 1,
            )
            .isUnlocked;
        if (!isLessonEligibleForMultiTopic(
          categoryId: widget.categoryId,
          hasQuestionPool: hasPool,
          isUnlocked: unlocked,
        )) {
          continue;
        }
        eligible.add(
          _EligibleLesson(
            number: lesson.number,
            title: lesson.title,
            poolSize: pool.length,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _poolByLesson = pools;
        _eligible = eligible;
        _loading = false;
        _selected.clear();
        _recomputeMaxSheets();
      });
    } catch (err, st) {
      debugPrint('MultiTopicQuizSetupPage load error: $err\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Impossibile caricare gli argomenti. Riprova.';
      });
    }
  }

  LessonQuizRules? get _rules => lessonQuizRulesForCategory(widget.categoryId);

  void _recomputeMaxSheets() {
    final rules = _rules;
    if (rules == null || _selected.length < 2) {
      _maxSheets = 1;
      _sheetCount = 1;
      return;
    }
    final selected = _selected.toList()..sort();
    final max = maxDistinctMultiTopicSheets(
      poolByLesson: _poolByLesson,
      selectedLessonNumbers: selected,
      questionsPerSheet: rules.questionsPerSheet,
    );
    _maxSheets = max < 1 ? 1 : max;
    if (_sheetCount > _maxSheets) _sheetCount = _maxSheets;
    if (_sheetCount < 1) _sheetCount = 1;
  }

  void _toggleLesson(int lessonNumber) {
    setState(() {
      if (_selected.contains(lessonNumber)) {
        _selected.remove(lessonNumber);
      } else {
        _selected.add(lessonNumber);
      }
      _recomputeMaxSheets();
    });
  }

  String? get _selectionHint {
    if (_selected.length < 2) {
      return 'Seleziona almeno 2 argomenti per continuare.';
    }
    final rules = _rules;
    if (rules == null) return 'Categoria non supportata.';
    final selected = _selected.toList()..sort();
    final shortfall = findMultiTopicPoolShortfall(
      poolByLesson: _poolByLesson,
      selectedLessonNumbers: selected,
      questionsPerSheet: rules.questionsPerSheet,
      sheetCount: _sheetCount,
    );
    return shortfall?.message;
  }

  bool get _startEnabled {
    if (_selected.length < 2) return false;
    final rules = _rules;
    if (rules == null) return false;
    final selected = _selected.toList()..sort();
    return findMultiTopicPoolShortfall(
          poolByLesson: _poolByLesson,
          selectedLessonNumbers: selected,
          questionsPerSheet: rules.questionsPerSheet,
          sheetCount: _sheetCount,
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

    setState(() => _starting = true);

    final selected = _selected.toList()..sort();
    final session = MultiTopicQuizSession(
      sessionId: generateMultiTopicUuid(),
      licenseCategory: widget.categoryId,
      selectedLessonNumbers: selected,
      totalSheets: _sheetCount,
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
            'Non ci sono lezioni sbloccate con domande disponibili per '
            'la Multischeda ($categoryName). '
            'Quando la scuola abiliterà le lezioni, potrai combinare gli argomenti.',
        icon: Icons.lock_outline_rounded,
        tagLabel: 'Abilitazione scuola',
        primaryActionLabel: 'Vedi storico',
        primaryActionIcon: Icons.history_rounded,
        onPrimaryActionPressed: _openHistory,
      );
    }

    final rules = _rules;
    final hint = _selectionHint;
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
                lesson.title,
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
          'Numero schede',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: _textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: _cardColor,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  onPressed:
                      !_starting && _selected.length >= 2 && _sheetCount > 1
                      ? () => setState(() {
                          _sheetCount--;
                        })
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: _primaryColor,
                ),
                Expanded(
                  child: Text(
                    '$_sheetCount'
                    '${_selected.length >= 2 ? ' / max $_maxSheets' : ''}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _textPrimaryColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      !_starting &&
                          _selected.length >= 2 &&
                          _sheetCount < _maxSheets
                      ? () => setState(() {
                          _sheetCount++;
                        })
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: _primaryColor,
                ),
              ],
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
