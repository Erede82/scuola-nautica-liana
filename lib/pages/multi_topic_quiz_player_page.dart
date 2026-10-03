import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/lesson_quiz_rules.dart';
import '../domain/multi_topic_client_token.dart';
import '../domain/multi_topic_question_selection.dart';
import '../domain/multi_topic_quiz_attempt_exception.dart';
import '../domain/multi_topic_quiz_attempt_submission.dart';
import '../domain/multi_topic_quiz_guards.dart';
import '../domain/multi_topic_quiz_session.dart';
import '../domain/quiz_sheet_exit_policy.dart';
import '../domain/quiz_sheet_player_navigation.dart';
import '../models/quiz_question.dart';
import '../repositories/multi_topic_quiz_attempt_repository.dart';
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
import '../widgets/quiz_question_progress_strip.dart';
import '../widgets/quiz_question_prompt_panel.dart';
import '../widgets/staff_preview_app_bar_badge.dart';

/// Player Multischeda: una scheda alla volta, RPC su conclusione.
class MultiTopicQuizPlayerPage extends StatefulWidget {
  const MultiTopicQuizPlayerPage({
    super.key,
    required this.session,
    @visibleForTesting this.attemptRepositoryOverride,
  });

  final MultiTopicQuizSession session;

  @visibleForTesting
  final MultiTopicQuizAttemptRepository? attemptRepositoryOverride;

  @override
  State<MultiTopicQuizPlayerPage> createState() =>
      _MultiTopicQuizPlayerPageState();
}

enum _SaveStatus { idle, saving, saved, failed }

class _MultiTopicQuizPlayerPageState extends State<MultiTopicQuizPlayerPage> {
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
  late String _clientSubmissionId;
  DateTime? _startedAt;
  int _sheetIndex = 0;
  bool _loading = true;
  bool _loadFailed = false;
  bool _sessionComplete = false;
  int _currentIndex = 0;
  bool _showSummary = false;
  _SaveStatus _saveStatus = _SaveStatus.idle;
  String? _saveErrorMessage;
  MultiTopicQuizAttemptSubmission? _pendingSubmission;
  bool _submitInFlight = false;
  bool _closeInProgress = false;

  MultiTopicQuizAttemptRepository get _repo =>
      widget.attemptRepositoryOverride ?? multiTopicQuizAttemptRepository;

  MultiTopicQuizSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    qfLog(
      'route: MultiTopicQuizPlayerPage session=${_session.sessionId} '
      'total=${_session.totalSheets}',
    );
    _openNextSheet();
  }

  LessonQuizRules? get _rules =>
      lessonQuizRulesForCategory(_session.licenseCategory);

  void _openNextSheet() {
    final nextIndex = _session.nextSheetIndex;
    if (nextIndex > _session.totalSheets) {
      setState(() {
        _sessionComplete = true;
        _loading = false;
        _showSummary = false;
      });
      return;
    }

    final rules = _rules;
    if (rules == null) {
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
      return;
    }

    final pick = pickMultiTopicSheetQuestions(
      poolByLesson: _session.poolByLesson,
      selectedLessonNumbers: _session.selectedLessonNumbers,
      questionsPerSheet: rules.questionsPerSheet,
      sheetIndex: nextIndex,
      usedQuestionIds: _session.usedQuestionIds,
      allowReuse: true,
    );

    if (pick == null || pick.questions.length != rules.questionsPerSheet) {
      setState(() {
        _loading = false;
        _loadFailed = true;
        _questions = const [];
      });
      return;
    }

    setState(() {
      _sheetIndex = nextIndex;
      _clientSubmissionId = generateMultiTopicUuid();
      _questions = pick.questions;
      _userAnswers = List<QuizAnswerOption?>.filled(
        pick.questions.length,
        null,
      );
      _startedAt = DateTime.now();
      _pendingSubmission = null;
      _saveStatus = _SaveStatus.idle;
      _saveErrorMessage = null;
      _submitInFlight = false;
      _closeInProgress = false;
      _currentIndex = 0;
      _showSummary = false;
      _sessionComplete = false;
      _loading = false;
      _loadFailed = false;
    });
  }

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

  bool get _isSaving => _saveStatus == _SaveStatus.saving || _submitInFlight;

  Future<void> _closeSheet() async {
    // Guard doppio tap: claim sincrono prima di qualsiasi await.
    if (!multiTopicCloseSheetMayProceed(
      showSummary: _showSummary,
      submitInFlight: _submitInFlight,
      hasPendingSubmission: _pendingSubmission != null,
      closeInProgress: _closeInProgress,
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

      // Non ricostruire mai se `_pendingSubmission` esiste già.
      final startedAt = _startedAt;
      if (startedAt == null) {
        return;
      }

      final submission = freezeOrReusePendingSubmission(
        pending: _pendingSubmission,
        build: () => buildMultiTopicQuizAttemptSubmission(
          clientSubmissionId: _clientSubmissionId,
          sessionId: _session.sessionId,
          licenseCategory: _session.licenseCategory,
          lessonNumbers: _session.selectedLessonNumbers,
          sheetIndex: _sheetIndex,
          totalSheets: _session.totalSheets,
          startedAt: startedAt,
          completedAt: DateTime.now(),
          questions: _questions,
          userAnswers: _userAnswers,
        ),
      );

      setState(() {
        _showSummary = true;
        _pendingSubmission = submission;
        _saveStatus = _SaveStatus.saving;
      });
      await _saveAttempt();
    } finally {
      // Se pending è stato congelato, i tap successivi restano bloccati dal guard.
      if (_pendingSubmission == null) {
        _closeInProgress = false;
      }
    }
  }

  Future<void> _saveAttempt() async {
    if (StudentAreaContext.blocksWrites(context)) return;
    if (_saveStatus == _SaveStatus.saved) return;
    if (_submitInFlight) return;

    final submission = _pendingSubmission;
    if (submission == null) {
      setState(() {
        _saveStatus = _SaveStatus.failed;
        _saveErrorMessage = 'Submission non disponibile.';
      });
      return;
    }

    _submitInFlight = true;
    setState(() {
      _saveStatus = _SaveStatus.saving;
      _saveErrorMessage = null;
    });

    try {
      // Retry riusa ESATTAMENTE `_pendingSubmission` (stesso oggetto).
      await _repo.submitAttempt(submission);
      if (!mounted) return;
      _session.markSheetConsumed(
        sheetIndex: _sheetIndex,
        questionIds: _questions.map((q) => q.id),
      );
      setState(() {
        _saveStatus = _SaveStatus.saved;
        _saveErrorMessage = null;
      });
    } on MultiTopicQuizAttemptException catch (err) {
      if (!mounted) return;
      setState(() {
        _saveStatus = _SaveStatus.failed;
        _saveErrorMessage = err.message;
      });
    } catch (err, st) {
      debugPrint('MultiTopicQuizPlayer save error: $err\n$st');
      if (!mounted) return;
      setState(() {
        _saveStatus = _SaveStatus.failed;
        _saveErrorMessage = multiTopicQuizAttemptExceptionFrom(err).message;
      });
    } finally {
      _submitInFlight = false;
    }
  }

  bool get _allowsImmediatePop =>
      !_isSaving && allowsImmediateQuizSheetExit(_userAnswers);

  /// Uscita: vuota → pop senza save; ≥1 risposta → conclude (unanswered = errori).
  Future<void> _leaveSheet() async {
    if (multiTopicBlocksExitWhileSaving(isSaving: _isSaving)) return;
    if (_allowsImmediatePop) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }
    // ≥1 risposta: stessa pipeline di Concludi (conferma unanswered → save).
    await _closeSheet();
  }

  void _exitSummary() {
    if (multiTopicBlocksExitWhileSaving(isSaving: _isSaving)) return;
    Navigator.maybePop(context);
  }

  void _goNextOrFinish() {
    if (_session.hasMoreSheets) {
      setState(() => _loading = true);
      _openNextSheet();
      return;
    }
    setState(() {
      _sessionComplete = true;
      _showSummary = false;
    });
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

  String get _progressLabel => 'Scheda $_sheetIndex di ${_session.totalSheets}';

  String get _appBarTitle {
    final name = LicenseCatalog.byId(_session.licenseCategory).name;
    return '$_progressLabel · $name';
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar('Multischeda'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_sessionComplete) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar('Multischeda completata'),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Hai completato tutte le ${_session.totalSheets} schede '
                'di questa Multischeda.',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.maybePop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadFailed || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar('Multischeda'),
        body: AppEmptyState(
          title: 'Impossibile generare la scheda',
          message:
              'Il pool domande non è sufficiente per continuare. '
              'Torna al setup e riprova con altri argomenti.',
          icon: Icons.quiz_outlined,
          primaryActionLabel: 'Indietro',
          primaryActionIcon: Icons.arrow_back_rounded,
          onPrimaryActionPressed: () => Navigator.maybePop(context),
        ),
      );
    }

    if (_showSummary) {
      final hasNext = _session.hasMoreSheets;
      return PopScope(
        canPop: !_isSaving,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // Durante saving: blocca back senza cancellare la RPC.
        },
        child: Scaffold(
          backgroundColor: _backgroundColor,
          appBar: _buildAppBar('Riepilogo · $_progressLabel'),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _progressLabel,
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                LessonQuizSheetSummaryBody(
                  categoryId: _session.licenseCategory,
                  totalQuestions: _questions.length,
                  correctCount: _correctCount,
                  wrongCount: _wrongCount,
                  unansweredCount: _unansweredCount,
                ),
                const SizedBox(height: 6),
                _SaveStatusCard(
                  status: _saveStatus,
                  errorMessage: _saveErrorMessage,
                  onRetry: _saveStatus == _SaveStatus.failed
                      ? _saveAttempt
                      : null,
                ),
                const SizedBox(height: 24),
                if (_saveStatus == _SaveStatus.saved && hasNext)
                  FilledButton.icon(
                    onPressed: _goNextOrFinish,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('PROSSIMA SCHEDA'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                else if (_saveStatus == _SaveStatus.saved && !hasNext)
                  FilledButton(
                    onPressed: _goNextOrFinish,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Termina Multischeda'),
                  ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _exitSummary,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Esci'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
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
        if (didPop) return;
        await _leaveSheet();
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(_appBarTitle),
        body: Column(
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
                if (answer == null) return QuizProgressCellTone.unanswered;
                return answer == _questions[index].correctOption
                    ? QuizProgressCellTone.correct
                    : QuizProgressCellTone.wrong;
              },
              correctCount: _correctCount,
              wrongCount: _wrongCount,
              unansweredCount: _unansweredCount,
              header: _progressLabel,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, viewport) {
                  final compact = QuizPlayerVisual.isCompact(context);
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: QuizPlayerVisual.lessonSheetContentMaxWidth,
                      ),
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) {
                          final density = QuizPlayerDensity.resolve(
                            context: context,
                            prompt: question.prompt,
                            answers: [
                              for (final option in question.options)
                                question.textForOption(option),
                            ],
                            contentWidth: contentConstraints.maxWidth,
                          );
                          final dense =
                              density == QuizPlayerContentDensity.dense;

                          return SingleChildScrollView(
                            padding: QuizPlayerVisual.lessonSheetBodyPadding,
                            child: Column(
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
                                    isCorrect:
                                        selected == question.correctOption,
                                    correctLetter:
                                        question.correctOption.letter,
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
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Material(
            color: _backgroundColor,
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
}

class _SaveStatusCard extends StatelessWidget {
  const _SaveStatusCard({
    required this.status,
    required this.errorMessage,
    this.onRetry,
  });

  final _SaveStatus status;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case _SaveStatus.idle:
        return const SizedBox.shrink();
      case _SaveStatus.saving:
        return const ListTile(
          dense: true,
          leading: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Salvataggio in corso…'),
        );
      case _SaveStatus.saved:
        return ListTile(
          dense: true,
          leading: const Icon(Icons.check_circle, color: Color(0xFF15803D)),
          title: Text(
            'Risultato salvato',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      case _SaveStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              dense: true,
              leading: const Icon(
                Icons.error_outline,
                color: Color(0xFFB91C1C),
              ),
              title: Text(errorMessage ?? 'Salvataggio non riuscito.'),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Riprova')),
          ],
        );
    }
  }
}
