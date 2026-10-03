import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/lesson_sheet_catalog_filter.dart';
import '../domain/quiz_sheet_exit_policy.dart';
import '../domain/quiz_sheet_player_navigation.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../repositories/quiz_attempt_repository.dart';
import '../repositories/student_quiz_repository.dart';
import '../repositories/study_access_repository.dart';
import '../services/student_area_context.dart';
import '../theme/quiz_player_density.dart';
import '../theme/quiz_player_visual_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/empty_quiz_sheet_dialog.dart';
import '../widgets/lesson_quiz_sheet_summary_body.dart';
import '../widgets/nautical_answer_marker.dart';
import '../widgets/quiz_answer_result_chip.dart';
import '../widgets/quiz_lesson_sheet_progress_panel.dart';
import '../widgets/quiz_player_answer_tile.dart';
import '../widgets/quiz_question_prompt_panel.dart';
import '../widgets/quiz_question_progress_strip.dart';
import '../widgets/staff_preview_app_bar_badge.dart';

/// Dettaglio scheda quiz per lezione — domande da `quiz_sets` / `quiz_set_items`.
class QuizSheetDetailPage extends StatefulWidget {
  const QuizSheetDetailPage({
    super.key,
    required this.lessonNumber,
    required this.sheetNumber,
    this.categoryId = LicenseCategoryId.motore,
    @visibleForTesting this.studentQuizRepositoryOverride,
    @visibleForTesting this.quizAttemptRepositoryOverride,
  });

  final int lessonNumber;
  final int sheetNumber;
  final LicenseCategoryId categoryId;

  /// Solo test: evita accesso remoto per caricare domande.
  @visibleForTesting
  final StudentQuizRepository? studentQuizRepositoryOverride;

  /// Solo test: evita accesso remoto al salvataggio.
  @visibleForTesting
  final QuizAttemptRepository? quizAttemptRepositoryOverride;

  @override
  State<QuizSheetDetailPage> createState() => _QuizSheetDetailPageState();
}

class _QuizSheetDetailPageState extends State<QuizSheetDetailPage> {
  static const Color _primaryColor = QuizPlayerVisual.accent;
  static const Color _backgroundColor = QuizPlayerVisual.pageBackground;

  @override
  void initState() {
    super.initState();
    qfLog(
      'route: QuizSheetDetailPage L${widget.lessonNumber} '
      'S${widget.sheetNumber} category=${widget.categoryId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studyAccessListenable,
      builder: (context, _) {
        final access = studyAccessRepository.lessonQuizSheet(
          categoryId: widget.categoryId,
          lessonNumber: widget.lessonNumber,
          sheetNumber: widget.sheetNumber,
        );
        final category = LicenseCatalog.byId(widget.categoryId);

        if (access.isLocked) {
          return Scaffold(
            backgroundColor: _backgroundColor,
            appBar: _buildAppBar(category.name),
            body: AppEmptyState(
              title: 'Scheda non ancora abilitata',
              message:
                  access.lockedMessage ??
                  'Quando la scuola abiliterà questa scheda, potrai svolgerla.',
              icon: Icons.lock_outline_rounded,
              tagLabel: 'Scheda abilitata dalla scuola',
              primaryActionLabel: 'Torna alle schede',
              primaryActionIcon: Icons.arrow_back_rounded,
              onPrimaryActionPressed: () => Navigator.maybePop(context),
            ),
          );
        }

        return _QuizSheetPlayer(
          lessonNumber: widget.lessonNumber,
          sheetNumber: widget.sheetNumber,
          categoryId: widget.categoryId,
          categoryName: category.name,
          studentQuizRepository:
              widget.studentQuizRepositoryOverride ?? studentQuizRepository,
          quizAttemptRepository:
              widget.quizAttemptRepositoryOverride ?? quizAttemptRepository,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(String categoryName) {
    return AppBar(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      title: Text(_appBarTitle(categoryName)),
      centerTitle: true,
    );
  }

  String _appBarTitle(String categoryName) {
    return 'Lezione ${widget.lessonNumber} · Scheda ${widget.sheetNumber} · $categoryName';
  }
}

class _QuizSheetPlayer extends StatefulWidget {
  const _QuizSheetPlayer({
    required this.lessonNumber,
    required this.sheetNumber,
    required this.categoryId,
    required this.categoryName,
    required this.studentQuizRepository,
    required this.quizAttemptRepository,
  });

  final int lessonNumber;
  final int sheetNumber;
  final LicenseCategoryId categoryId;
  final String categoryName;
  final StudentQuizRepository studentQuizRepository;
  final QuizAttemptRepository quizAttemptRepository;

  @override
  State<_QuizSheetPlayer> createState() => _QuizSheetPlayerState();
}

class _QuizSheetPlayerState extends State<_QuizSheetPlayer> {
  static const Color _primaryColor = QuizPlayerVisual.accent;
  static const Color _backgroundColor = QuizPlayerVisual.pageBackground;
  static const Color _cardColor = QuizPlayerVisual.cardSurface;
  static const Color _textPrimaryColor = QuizPlayerVisual.ink;
  static const Color _neutralColor = QuizPlayerVisual.cardBorder;
  static const Color _correctColor = QuizPlayerVisual.correctBorder;
  static const Color _wrongColor = QuizPlayerVisual.wrongBorder;
  static const Color _correctBg = QuizPlayerVisual.correctFill;
  static const Color _wrongBg = QuizPlayerVisual.wrongFill;

  List<QuizQuestion> _questions = const [];
  List<QuizAnswerOption?> _userAnswers = const [];
  String? _quizSetId;
  DateTime? _startedAt;
  DateTime? _completedAt;
  bool _loading = true;
  bool _loadFailed = false;
  int _currentIndex = 0;
  bool _showSummary = false;
  List<int> _lessonSheetNumbers = const [];

  /// Claim sincrono anti double-submit (filosofia Multischeda `_closeInProgress`).
  bool _closeInProgress = false;
  _AttemptSaveStatus _saveStatus = _AttemptSaveStatus.idle;
  String? _saveErrorMessage;
  String? _partialQuizResultId;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _showSummary = false;
      _currentIndex = 0;
    });

    try {
      final contentFuture = widget.studentQuizRepository
          .fetchLessonSheetContent(
            categoryId: widget.categoryId,
            lessonNumber: widget.lessonNumber,
            sheetNumber: widget.sheetNumber,
          );
      final sheetsFuture = widget.studentQuizRepository
          .fetchLessonSheetNumbersByLesson(categoryId: widget.categoryId);
      final content = await contentFuture;
      final sheetsByLesson = await sheetsFuture;
      if (!mounted) return;
      final loaded = content?.questions ?? const [];
      final lessonSheets = List<int>.from(
        sheetsByLesson[widget.lessonNumber] ?? const [],
      )..sort();
      setState(() {
        _quizSetId = loaded.isEmpty ? null : content?.quizSetId;
        _questions = loaded;
        _userAnswers = List<QuizAnswerOption?>.filled(loaded.length, null);
        _startedAt = loaded.isEmpty ? null : DateTime.now();
        _completedAt = null;
        _saveStatus = _AttemptSaveStatus.idle;
        _saveErrorMessage = null;
        _partialQuizResultId = null;
        _lessonSheetNumbers = lessonSheets;
        _loading = false;
      });
    } catch (err, st) {
      debugPrint('QuizSheetPlayer load error: $err\n$st');
      if (!mounted) return;
      setState(() {
        _questions = const [];
        _userAnswers = const [];
        _quizSetId = null;
        _startedAt = null;
        _lessonSheetNumbers = const [];
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// Prossima scheda actionable: catalogo reale ∩ unlock per-scheda.
  /// Usa [_lessonSheetNumbers] già caricato (nessuna query aggiuntiva).
  int? get _nextSheetNumber => nextActionableLessonSheetNumber(
    catalogSheetNumbers: _lessonSheetNumbers,
    currentSheetNumber: widget.sheetNumber,
    isSheetUnlocked: (sheetNumber) => studyAccessRepository
        .lessonQuizSheet(
          categoryId: widget.categoryId,
          lessonNumber: widget.lessonNumber,
          sheetNumber: sheetNumber,
        )
        .isUnlocked,
  );

  bool get _hasNextSheet => _nextSheetNumber != null;

  QuizQuestion? get _currentQuestion {
    if (_currentIndex < 0 || _currentIndex >= _questions.length) return null;
    return _questions[_currentIndex];
  }

  QuizAnswerOption? get _selectedAnswer {
    if (_currentIndex < 0 || _currentIndex >= _userAnswers.length) {
      return null;
    }
    return _userAnswers[_currentIndex];
  }

  bool get _isCurrentAnswered => _selectedAnswer != null;

  int get _correctCount {
    var n = 0;
    for (var i = 0; i < _questions.length; i++) {
      final answer = _userAnswers[i];
      if (answer != null && answer == _questions[i].correctOption) n++;
    }
    return n;
  }

  int get _wrongCount {
    var n = 0;
    for (var i = 0; i < _questions.length; i++) {
      final answer = _userAnswers[i];
      if (answer != null && answer != _questions[i].correctOption) n++;
    }
    return n;
  }

  int get _unansweredCount =>
      _userAnswers.where((answer) => answer == null).length;

  void _selectAnswer(QuizAnswerOption option) {
    if (_showSummary || _isCurrentAnswered) return;
    setState(() => _userAnswers[_currentIndex] = option);
  }

  void _goBack() {
    if (_currentIndex <= 0) return;
    setState(() => _currentIndex--);
  }

  void _goForward() {
    if (!QuizSheetPlayerNavigation.canGoForward(
      currentIndex: _currentIndex,
      questionCount: _questions.length,
    )) {
      return;
    }
    setState(() => _currentIndex++);
  }

  Future<void> _closeSheet() async {
    // Claim sincrono PRIMA di qualsiasi await (anti double-submit / Esci+Concludi).
    if (!quizSheetCloseMayProceed(
      showSummary: _showSummary,
      closeInProgress: _closeInProgress,
      isSaving: _saveStatus == _AttemptSaveStatus.saving,
      isSaved: _saveStatus == _AttemptSaveStatus.saved,
    )) {
      return;
    }
    _closeInProgress = true;

    try {
      // STUDIO.QUIZ.UNANSWERED.1: scheda vuota → nessun salvataggio.
      if (!quizSheetMayPersistAttempt(_userAnswers)) {
        final action = await showEmptyQuizSheetDialog(context);
        if (!mounted) return;
        if (action == EmptyQuizSheetDialogAction.exit) {
          Navigator.of(context).pop();
        }
        return;
      }

      final unanswered = _unansweredCount;
      if (unanswered > 0) {
        final closeAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Concludere la scheda?'),
            content: Text(
              'Hai lasciato $unanswered domande senza risposta. '
              'Le domande non risposte saranno considerate errori. '
              'Vuoi concludere la scheda?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Concludi'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (closeAnyway != true) {
          final firstGap = QuizSheetPlayerNavigation.firstUnansweredIndex(
            _userAnswers,
          );
          if (firstGap != null) {
            setState(() => _currentIndex = firstGap);
          }
          return;
        }
      }

      if (StudentAreaContext.blocksWrites(context)) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Anteprima staff'),
            content: const Text(StudentAreaPreviewCopy.quizSaveBlockedMessage),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _showSummary = true;
        _completedAt = DateTime.now();
      });
      await _saveAttempt();
    } finally {
      // Successo: `_showSummary` (e saved/saving) bloccano un secondo submit.
      // Cancel / empty / errori pre-summary: rilascia il claim per consentire retry.
      if (!_showSummary) {
        _closeInProgress = false;
      }
    }
  }

  Future<void> _saveAttempt() async {
    if (StudentAreaContext.blocksWrites(context)) {
      return;
    }

    // Impossibile iniziare una seconda persistenza mentre `_saveStatus == saving`.
    if (!quizSheetSaveMayProceed(
      isSaving: _saveStatus == _AttemptSaveStatus.saving,
      isSaved: _saveStatus == _AttemptSaveStatus.saved,
    )) {
      return;
    }

    final quizSetId = _quizSetId;
    final startedAt = _startedAt;
    final completedAt = _completedAt;
    if (quizSetId == null || startedAt == null || completedAt == null) {
      setState(() {
        _saveStatus = _AttemptSaveStatus.failed;
        _saveErrorMessage =
            'Scheda non collegata al database: impossibile salvare il risultato.';
      });
      return;
    }

    // Claim sincrono prima di qualsiasi await.
    setState(() {
      _saveStatus = _AttemptSaveStatus.saving;
      _saveErrorMessage = null;
    });

    try {
      final result = await widget.quizAttemptRepository
          .submitLessonSheetAttempt(
            quizSetId: quizSetId,
            questions: _questions,
            answers: _userAnswers,
            startedAt: startedAt,
            completedAt: completedAt,
            existingQuizResultId: _partialQuizResultId,
          );
      if (!mounted) return;
      setState(() {
        _saveStatus = _AttemptSaveStatus.saved;
        _partialQuizResultId = null;
        _saveErrorMessage = null;
      });
      qfLog('quiz attempt saved: ${result.quizResultId}');
    } on QuizAttemptAnswersPartialFailure catch (err, st) {
      debugPrint('QuizSheetPlayer partial save: ${err.message}\n$st');
      if (!mounted) return;
      setState(() {
        _partialQuizResultId = err.quizResultId;
        _saveStatus = _AttemptSaveStatus.failed;
        _saveErrorMessage = err.message;
      });
    } catch (err, st) {
      debugPrint('QuizSheetPlayer save error: $err\n$st');
      if (!mounted) return;
      setState(() {
        _saveStatus = _AttemptSaveStatus.failed;
        _saveErrorMessage = err is StateError
            ? err.message
            : 'Salvataggio non riuscito. Riprova.';
      });
    }
  }

  bool get _allowsImmediatePop => allowsImmediateQuizSheetExit(_userAnswers);

  /// Uscita: vuota → pop senza save; ≥1 risposta → conclude (unanswered = errori).
  Future<void> _leaveSheet() async {
    if (_allowsImmediatePop) {
      if (!mounted) return;
      qfLog('QuizSheetPlayer: exit empty without save');
      Navigator.of(context).pop();
      return;
    }
    qfLog('QuizSheetPlayer: exit with answers → conclude path');
    await _closeSheet();
  }

  void _openNextSheet() {
    final next = _nextSheetNumber;
    if (next == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuizSheetDetailPage(
          lessonNumber: widget.lessonNumber,
          sheetNumber: next,
          categoryId: widget.categoryId,
          studentQuizRepositoryOverride: widget.studentQuizRepository,
          quizAttemptRepositoryOverride: widget.quizAttemptRepository,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      title: Text(title),
      centerTitle: true,
      actions: const [StaffPreviewAppBarBadge()],
    );
  }

  String get _appBarTitle =>
      'Lezione ${widget.lessonNumber} · Scheda ${widget.sheetNumber} · ${widget.categoryName}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(_appBarTitle),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadFailed || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(_appBarTitle),
        body: AppEmptyState(
          title: 'Nessuna domanda disponibile',
          message: widget.categoryId == LicenseCategoryId.vela
              ? 'I contenuti quiz vela non sono ancora disponibili.'
              : 'Non ci sono domande per questa scheda al momento. '
                    'Riprova più tardi o contatta la scuola se il problema persiste.',
          icon: Icons.quiz_outlined,
          primaryActionLabel: 'Torna alle schede',
          primaryActionIcon: Icons.arrow_back_rounded,
          onPrimaryActionPressed: () => Navigator.maybePop(context),
        ),
      );
    }

    if (_showSummary) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar('Riepilogo scheda'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LessonQuizSheetSummaryBody(
                categoryId: widget.categoryId,
                totalQuestions: _questions.length,
                correctCount: _correctCount,
                wrongCount: _wrongCount,
                unansweredCount: _unansweredCount,
              ),
              const SizedBox(height: 6),
              _AttemptSaveStatusCard(
                status: _saveStatus,
                errorMessage: _saveErrorMessage,
                onRetry: _saveStatus == _AttemptSaveStatus.failed
                    ? _saveAttempt
                    : null,
              ),
              const SizedBox(height: 24),
              if (_hasNextSheet)
                FilledButton.icon(
                  onPressed: _openNextSheet,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text('Prossima scheda ($_nextSheetNumber)'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _neutralColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Non ci sono altre schede abilitate da svolgere '
                    'in questa lezione.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Torna alle schede'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final question = _currentQuestion!;
    final selected = _selectedAnswer;
    final revealed = _isCurrentAnswered;

    return PopScope(
      canPop: _allowsImmediatePop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          qfLog('QuizSheetPlayer: immediate exit (no answers selected)');
          return;
        }
        await _leaveSheet();
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(_appBarTitle),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: QuizPlayerVisual.lessonSheetContentMaxWidth,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  QuizLessonSheetProgressPanel(
                    currentIndex: _currentIndex,
                    total: _questions.length,
                    isAnswered: (index) =>
                        QuizSheetPlayerNavigation.isQuestionAnswered(
                          _userAnswers,
                          index,
                        ),
                    cellTone: (index) {
                      final answer = _userAnswers[index];
                      if (answer == null) {
                        return QuizProgressCellTone.unanswered;
                      }
                      return answer == _questions[index].correctOption
                          ? QuizProgressCellTone.correct
                          : QuizProgressCellTone.wrong;
                    },
                    correctCount: _correctCount,
                    wrongCount: _wrongCount,
                    unansweredCount: _unansweredCount,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, contentConstraints) {
                        final compact = QuizPlayerVisual.isCompact(context);
                        final density = QuizPlayerDensity.resolve(
                          context: context,
                          prompt: question.prompt,
                          answers: [
                            for (final option in question.options)
                              question.textForOption(option),
                          ],
                          contentWidth: contentConstraints.maxWidth,
                        );
                        final dense = density == QuizPlayerContentDensity.dense;

                        return SingleChildScrollView(
                          padding: QuizPlayerVisual.lessonSheetBodyPadding,
                          child: Column(
                            key: QuizPlayerDensity.densityKey(density),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  QuizPlayerDensity.cardPadding(density),
                                ),
                                decoration: BoxDecoration(
                                  color: _cardColor,
                                  borderRadius: BorderRadius.circular(
                                    QuizPlayerVisual.cardRadius,
                                  ),
                                  border: Border.all(color: _neutralColor),
                                ),
                                child: QuizQuestionPromptPanel(
                                  questionNumber: _currentIndex + 1,
                                  prompt: question.prompt,
                                  imagePath: question.imagePath,
                                  compact: compact,
                                  dense: dense,
                                  labelColor: _primaryColor,
                                  textColor: _textPrimaryColor,
                                ),
                              ),
                              SizedBox(
                                height: QuizPlayerDensity.sectionSpacing(
                                  density,
                                ),
                              ),
                              ...question.options.map(
                                (option) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: QuizPlayerDensity.answerSpacing(
                                      density,
                                    ),
                                  ),
                                  child: QuizPlayerAnswerTile(
                                    answerNumber: option.index + 1,
                                    text: question.textForOption(option),
                                    onTap: revealed
                                        ? null
                                        : () => _selectAnswer(option),
                                    backgroundColor: _optionBackground(
                                      option,
                                      selected,
                                      revealed,
                                    ),
                                    borderColor: _optionBorder(
                                      option,
                                      selected,
                                      revealed,
                                    ),
                                    borderWidth: _optionBorderWidth(
                                      option,
                                      selected,
                                      revealed,
                                    ),
                                    markerState: _markerState(
                                      option,
                                      selected,
                                      revealed,
                                    ),
                                    density: density,
                                  ),
                                ),
                              ),
                              if (revealed) ...[
                                const SizedBox(height: 2),
                                QuizAnswerResultChip(
                                  isCorrect: selected == question.correctOption,
                                  correctLetter: question.correctOption.letter,
                                  explanation: question.explanation,
                                  dense: dense || compact,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Material(
            color: _backgroundColor,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                QuizPlayerVisual.bottomBarPaddingV,
                12,
                12,
              ),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _currentIndex > 0 ? _goBack : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Domanda precedente',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          QuizSheetPlayerNavigation.canGoForward(
                            currentIndex: _currentIndex,
                            questionCount: _questions.length,
                          )
                          ? _goForward
                          : _closeSheet,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: QuizPlayerVisual.bottomButtonPaddingV,
                        ),
                      ),
                      child: Text(
                        QuizSheetPlayerNavigation.primaryButtonLabel(
                          currentIndex: _currentIndex,
                          questionCount: _questions.length,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed:
                        QuizSheetPlayerNavigation.canGoForward(
                          currentIndex: _currentIndex,
                          questionCount: _questions.length,
                        )
                        ? _goForward
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Domanda successiva',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  NauticalAnswerMarkerState _markerState(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
  ) {
    final correct = _currentQuestion!.correctOption;
    if (revealed) {
      if (option == correct) return NauticalAnswerMarkerState.correct;
      if (option == selected) return NauticalAnswerMarkerState.wrong;
      return NauticalAnswerMarkerState.neutral;
    }
    if (option == selected) return NauticalAnswerMarkerState.selected;
    return NauticalAnswerMarkerState.neutral;
  }

  Color _optionBackground(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
  ) {
    if (!revealed) {
      if (option == selected) return QuizPlayerVisual.selectedFill;
      return _cardColor;
    }
    final correct = _currentQuestion!.correctOption;
    if (option == correct) return _correctBg;
    if (option == selected) return _wrongBg;
    return _cardColor;
  }

  Color _optionBorder(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
  ) {
    if (!revealed) {
      if (option == selected) return QuizPlayerVisual.selectedBorder;
      return _neutralColor;
    }
    final correct = _currentQuestion!.correctOption;
    if (option == correct) return _correctColor;
    if (option == selected && option != correct) return _wrongColor;
    return _neutralColor;
  }

  double _optionBorderWidth(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
  ) {
    if (!revealed) {
      if (option == selected) return 2.0;
      return 1.2;
    }
    final correct = _currentQuestion!.correctOption;
    if (option == correct || option == selected) return 2.4;
    return 1.2;
  }
}

enum _AttemptSaveStatus { idle, saving, saved, failed }

class _AttemptSaveStatusCard extends StatelessWidget {
  const _AttemptSaveStatusCard({
    required this.status,
    this.errorMessage,
    this.onRetry,
  });

  final _AttemptSaveStatus status;
  final String? errorMessage;
  final VoidCallback? onRetry;

  static const Color _primaryColor = QuizPlayerVisual.accent;
  static const Color _textPrimaryColor = QuizPlayerVisual.ink;
  static const Color _savedColor = QuizPlayerVisual.correctBorder;
  static const Color _wrongColor = QuizPlayerVisual.wrongBorder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    late final IconData icon;
    late final String title;
    late final String message;
    late final Color accent;
    late final Color background;

    switch (status) {
      case _AttemptSaveStatus.idle:
      case _AttemptSaveStatus.saving:
        icon = Icons.cloud_upload_outlined;
        title = 'Salvataggio in corso';
        message = 'Stiamo registrando il risultato sul tuo account…';
        accent = _primaryColor;
        background = const Color(0xFFE8F4FA);
      case _AttemptSaveStatus.saved:
        icon = Icons.check_circle_outline_rounded;
        title = 'Risultato salvato';
        message =
            'Il tentativo è stato registrato. Potrai rivederlo nelle statistiche quando saranno disponibili.';
        accent = _savedColor;
        background = const Color(0xFFDFF5E8);
      case _AttemptSaveStatus.failed:
        icon = Icons.error_outline_rounded;
        title = 'Risultato non salvato';
        message =
            errorMessage ??
            'Non è stato possibile salvare il tentativo. Puoi riprovare.';
        accent = _wrongColor;
        background = const Color(0xFFFDE8E8);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (status == _AttemptSaveStatus.saving)
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 10),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(icon, color: accent),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: _textPrimaryColor.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == _AttemptSaveStatus.failed && onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova salvataggio'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
