import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../debug/quiz_flow_debug.dart';
import '../domain/exam_error_review.dart';
import '../domain/exam_question_selection.dart';
import '../domain/exam_quiz_attempt_exception.dart';
import '../domain/exam_quiz_attempt_submission.dart';
import '../domain/exam_quiz_client_token.dart';
import '../domain/exam_quiz_rules.dart';
import '../domain/quiz_sheet_exit_policy.dart';
import '../domain/quiz_sheet_player_navigation.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../pages/quiz_exam_error_review_page.dart';
import '../repositories/exam_quiz_attempt_repository.dart';
import '../repositories/student_quiz_repository.dart';
import '../widgets/nautical_answer_marker.dart';
import '../widgets/quiz_question_progress_strip.dart';
import '../widgets/quiz_question_prompt_panel.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import '../theme/app_visual_tokens.dart';

/// Risultato [Navigator.pop] per avviare subito una nuova simulazione esame.
const String kExamRestartSimulationResult = 'restart_exam_simulation';

/// Risultato [Navigator.pop] per tornare alla home Quiz (dashboard 4 card).
const String kExamExitToQuizHomeResult = 'exit_to_quiz_home';

/// Prefisso pop result: tentativo completato e salvato (`suffix` = attemptId).
const String kExamAttemptCompletedPrefix = 'exam_attempt_completed:';

String examAttemptCompletedPopResult(String attemptId) =>
    '$kExamAttemptCompletedPrefix$attemptId';

bool isExamAttemptCompletedPopResult(String? value) =>
    value != null && value.startsWith(kExamAttemptCompletedPrefix);

String? attemptIdFromExamCompletedPopResult(String? value) {
  if (!isExamAttemptCompletedPopResult(value)) return null;
  return value!.substring(kExamAttemptCompletedPrefix.length);
}

/// Player simulazione esame con submit persistente (P9E.5-A).
class QuizExamPlayerPage extends StatefulWidget {
  const QuizExamPlayerPage({
    super.key,
    required this.categoryId,
    required this.questions,
    required this.clientAttemptToken,
    this.repository,
  });

  final LicenseCategoryId categoryId;
  final List<QuizQuestion> questions;
  final String clientAttemptToken;
  final ExamQuizAttemptRepository? repository;

  @override
  State<QuizExamPlayerPage> createState() => _QuizExamPlayerPageState();
}

class _QuizExamPlayerPageState extends State<QuizExamPlayerPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _correctColor = Color(0xFF15803D);
  static const Color _wrongColor = Color(0xFFD32F2F);
  static const Color _passedColor = Color(0xFF15803D);
  static const Color _failedColor = Color(0xFFD32F2F);

  late List<QuizAnswerOption?> _userAnswers;
  late Duration _remaining;
  late final ExamQuizAttemptRepository _repository;
  late final DateTime _startedAt;
  Timer? _timer;
  int _currentIndex = 0;
  bool _showSummary = false;
  ExamQuizSummary? _summary;
  bool _isSubmitting = false;
  bool _submitSucceeded = false;
  String? _submitErrorMessage;
  ExamQuizAttemptSubmission? _pendingSubmission;

  /// Conservato per P9E.5-B (riapertura risultato).
  String? get completedAttemptId => _completedAttemptId;
  String? _completedAttemptId;

  ExamQuizCategoryRules get _rules =>
      examQuizRulesForCategory(widget.categoryId)!;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? examQuizAttemptRepository;
    _startedAt = DateTime.now();
    qfLog(
      'route: QuizExamPlayerPage init categoryId=${widget.categoryId} '
      'questions=${widget.questions.length} token=${widget.clientAttemptToken}',
    );
    _userAnswers = List<QuizAnswerOption?>.filled(
      widget.questions.length,
      null,
    );
    _remaining = Duration(seconds: _rules.durationSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  void _onTimerTick(Timer timer) {
    if (!mounted ||
        _showSummary ||
        _isSubmitting ||
        _pendingSubmission != null) {
      return;
    }
    if (_remaining.inSeconds <= 1) {
      setState(() => _remaining = Duration.zero);
      _finishExam(timeExpired: true);
      return;
    }
    setState(() {
      _remaining -= const Duration(seconds: 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  QuizQuestion get _currentQuestion => widget.questions[_currentIndex];

  QuizAnswerOption? get _selectedAnswer => _userAnswers[_currentIndex];

  int get _unansweredCount =>
      _userAnswers.where((answer) => answer == null).length;

  void _selectAnswer(QuizAnswerOption option) {
    if (_showSummary ||
        _isSubmitting ||
        _submitSucceeded ||
        _pendingSubmission != null) {
      return;
    }
    setState(() => _userAnswers[_currentIndex] = option);
  }

  void _goBack() {
    if (_currentIndex <= 0) return;
    setState(() => _currentIndex--);
  }

  void _goForward() {
    if (!QuizSheetPlayerNavigation.canGoForward(
      currentIndex: _currentIndex,
      questionCount: widget.questions.length,
    )) {
      return;
    }
    setState(() => _currentIndex++);
  }

  Future<void> _completeExamFlow() async {
    if (_isSubmitting || _submitSucceeded) return;
    final unanswered = _unansweredCount;
    if (unanswered > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Domande non completate'),
          content: Text(
            'Hai lasciato $unanswered domande senza risposta. '
            'Puoi ricontrollarle oppure chiudere comunque la simulazione.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Indietro'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Termina esame'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (proceed != true) {
        final firstGap = QuizSheetPlayerNavigation.firstUnansweredIndex(
          _userAnswers,
        );
        if (firstGap != null) {
          setState(() => _currentIndex = firstGap);
        }
        return;
      }
    }

    await _finishExam(timeExpired: false);
  }

  bool get _allowsImmediatePop =>
      _submitSucceeded || allowsImmediateQuizSheetExit(_userAnswers);

  Future<bool> _confirmLeaveExam() async {
    if (_allowsImmediatePop) return true;

    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Uscire dalla simulazione?'),
        content: const Text(
          'Hai risposto ad alcune domande ma non hai completato la simulazione. '
          'Se esci ora, le risposte non verranno salvate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Resta nella simulazione'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Esci senza salvare'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  Future<void> _finishExam({required bool timeExpired}) async {
    if (_isSubmitting || _submitSucceeded) return;

    _pendingSubmission ??= () {
      _timer?.cancel();
      final duration = DateTime.now().difference(_startedAt);
      return buildExamQuizAttemptSubmission(
        licenseCategory: widget.categoryId,
        clientAttemptToken: widget.clientAttemptToken,
        duration: duration,
        timeExpired: timeExpired,
        questions: widget.questions,
        userAnswers: _userAnswers,
      );
    }();

    await _submitPending();
  }

  Future<void> _submitPending() async {
    if (_isSubmitting || _submitSucceeded || _pendingSubmission == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitErrorMessage = null;
    });

    try {
      final result = await _repository.submitAttempt(_pendingSubmission!);
      if (!mounted) return;

      final attempt = result.attempt;
      final summary = attempt.toExamQuizSummary();

      qfLog(
        'QuizExamPlayer: submit ok attemptId=${attempt.id} '
        'idempotent=${result.idempotent} correct=${summary.correctCount} '
        'errors=${summary.errorCount} outcome=${summary.outcome}'
        '${_pendingSubmission!.timeExpired ? ' (time expired)' : ''}',
      );

      setState(() {
        _isSubmitting = false;
        _submitSucceeded = true;
        _showSummary = true;
        _summary = summary;
        _completedAttemptId = attempt.id;
      });
    } on ExamQuizAttemptException catch (error) {
      if (!mounted) return;
      qfLog('QuizExamPlayer: submit error code=${error.code}');
      setState(() {
        _isSubmitting = false;
        _submitErrorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      qfLog('QuizExamPlayer: submit unknown error $error');
      setState(() {
        _isSubmitting = false;
        _submitErrorMessage = examQuizAttemptErrorMessageIt(
          ExamQuizAttemptErrorCode.unknown,
        );
      });
    }
  }

  Future<void> _retrySubmit() async {
    if (_pendingSubmission == null || _isSubmitting || _submitSucceeded) {
      return;
    }
    await _submitPending();
  }

  void _openErrorReview() {
    final entries = buildExamErrorReviewEntries(
      questions: widget.questions,
      userAnswers: _userAnswers,
    );
    if (entries.isEmpty) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuizExamErrorReviewPage(entries: entries),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).width < 600;

    if (_showSummary && _summary != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final attemptId = _completedAttemptId;
          if (attemptId != null) {
            Navigator.pop(context, examAttemptCompletedPopResult(attemptId));
          } else {
            Navigator.pop(context);
          }
        },
        child: _buildSummaryScaffold(context, textTheme, _summary!),
      );
    }

    if (_isSubmitting) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, _) {},
        child: Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            title: const Text('Simulazione esame'),
            centerTitle: true,
            actions: const [StaffPreviewAppBarBadge()],
          ),
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Salvataggio risultato…'),
              ],
            ),
          ),
        ),
      );
    }

    final question = _currentQuestion;
    final selected = _selectedAnswer;

    return PopScope(
      canPop: _allowsImmediatePop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isSubmitting) return;
        final leave = await _confirmLeaveExam();
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: const Text('Simulazione esame'),
          centerTitle: true,
          actions: [
            const StaffPreviewAppBarBadge(),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  formatExamDurationMmSs(_remaining),
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_submitErrorMessage != null)
              MaterialBanner(
                content: Text(_submitErrorMessage!),
                leading: const Icon(Icons.error_outline),
                actions: [
                  TextButton(
                    onPressed: _retrySubmit,
                    child: const Text('Riprova'),
                  ),
                ],
              ),
            _ExamProgressPanel(
              currentIndex: _currentIndex,
              total: widget.questions.length,
              isAnswered: (index) =>
                  QuizSheetPlayerNavigation.isQuestionAnswered(
                    _userAnswers,
                    index,
                  ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _neutralColor),
                      ),
                      child: QuizQuestionPromptPanel(
                        questionNumber: _currentIndex + 1,
                        prompt: question.prompt,
                        imagePath: question.imagePath,
                        compact: compact,
                        labelColor: _primaryColor,
                        textColor: _textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...question.options.map(
                      (option) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ExamAnswerTile(
                          answerNumber: option.index + 1,
                          text: question.textForOption(option),
                          selected: selected == option,
                          compact: compact,
                          onTap: () => _selectAnswer(option),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                              questionCount: widget.questions.length,
                            )
                            ? _goForward
                            : _completeExamFlow,
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          QuizSheetPlayerNavigation.canGoForward(
                                currentIndex: _currentIndex,
                                questionCount: widget.questions.length,
                              )
                              ? 'Avanti'
                              : 'Termina esame',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed:
                          QuizSheetPlayerNavigation.canGoForward(
                            currentIndex: _currentIndex,
                            questionCount: widget.questions.length,
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
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryScaffold(
    BuildContext context,
    TextTheme textTheme,
    ExamQuizSummary summary,
  ) {
    final passed = summary.outcome == ExamQuizOutcome.passed;
    final maxErrors = _rules.maxErrorsToPass;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Riepilogo esame'),
        centerTitle: true,
        actions: const [StaffPreviewAppBarBadge()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              passed ? 'Esame superato' : 'Esame non superato',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: passed ? _passedColor : _failedColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              passed
                  ? 'Hai totalizzato al massimo $maxErrors errori.'
                  : 'Soglia superata: più di $maxErrors errori '
                        '(risposte errate e non risposte).',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 20),
            _SummaryRow(
              label: 'Domande totali',
              value: '${summary.totalQuestions}',
            ),
            _SummaryRow(
              label: 'Risposte corrette',
              value: '${summary.correctCount}',
              valueColor: _correctColor,
            ),
            _SummaryRow(
              label: 'Risposte errate',
              value: '${summary.wrongCount}',
              valueColor: summary.wrongCount > 0
                  ? _wrongColor
                  : _textPrimaryColor,
            ),
            _SummaryRow(
              label: 'Non risposte',
              value: '${summary.unansweredCount}',
            ),
            _SummaryRow(
              label: 'Errori totali (per esito)',
              value: '${summary.errorCount}',
              valueColor: summary.errorCount > maxErrors
                  ? _failedColor
                  : _textPrimaryColor,
            ),
            const SizedBox(height: 24),
            if (summary.errorCount > 0) ...[
              OutlinedButton.icon(
                onPressed: _openErrorReview,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Rivedi errori'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(context, kExamRestartSimulationResult),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Nuova simulazione'),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pop(context, kExamExitToQuizHomeResult),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Torna alla home quiz'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamProgressPanel extends StatelessWidget {
  const _ExamProgressPanel({
    required this.currentIndex,
    required this.total,
    required this.isAnswered,
  });

  final int currentIndex;
  final int total;
  final bool Function(int index) isAnswered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppVisual.chipFill),
      ),
      child: QuizQuestionProgressStrip(
        currentIndex: currentIndex,
        total: total,
        isAnswered: isAnswered,
      ),
    );
  }
}

class _ExamAnswerTile extends StatelessWidget {
  const _ExamAnswerTile({
    required this.answerNumber,
    required this.text,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final int answerNumber;
  final String text;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final answerStyle = QuizAnswerTextStyle.answer(context, compact: compact);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 14,
            compact ? 12 : 14,
            compact ? 10 : 12,
            compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppVisual.chipFill, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(text, style: answerStyle)),
              const SizedBox(width: 10),
              NauticalAnswerMarker(
                answerNumber: answerNumber,
                state: selected
                    ? NauticalAnswerMarkerState.selected
                    : NauticalAnswerMarkerState.neutral,
                compact: compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carica e avvia simulazione esame per la categoria indicata.
///
/// Restituisce `true` se almeno un tentativo è stato completato e salvato
/// nella sessione (per refresh storico sulla landing).
Future<bool> startExamSimulation({
  required BuildContext context,
  required LicenseCategoryId categoryId,
  ExamQuizAttemptRepository? repository,
}) async {
  final rules = examQuizRulesForCategory(categoryId);
  if (rules == null) return false;

  var completedInSession = false;

  while (context.mounted) {
    final pool = await studentQuizRepository.fetchExamQuestionsByTopic(
      categoryId: categoryId,
    );

    if (!context.mounted) return completedInSession;

    final shortfall = findExamTopicPoolShortfall(
      poolByTopic: pool,
      topicQuotas: rules.topicQuotas,
    );
    if (shortfall != null) {
      qfLog(
        'startExamSimulation: pool insufficiente topic=${shortfall.topic} '
        'required=${shortfall.required} available=${shortfall.available}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non ci sono abbastanza domande per creare questa simulazione.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return completedInSession;
    }

    final questions = pickExamQuestions(
      poolByTopic: pool,
      topicQuotas: rules.topicQuotas,
      random: Random(),
    );

    if (!context.mounted) return completedInSession;

    if (questions.length < rules.totalQuestions) {
      qfLog(
        'startExamSimulation: selezione incompleta '
        'picked=${questions.length} required=${rules.totalQuestions}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non ci sono abbastanza domande per creare questa simulazione.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return completedInSession;
    }

    final clientAttemptToken = generateExamClientAttemptToken();
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute<String?>(
        builder: (_) => QuizExamPlayerPage(
          categoryId: categoryId,
          questions: questions,
          clientAttemptToken: clientAttemptToken,
          repository: repository,
        ),
      ),
    );

    if (result == kExamExitToQuizHomeResult) {
      if (context.mounted) Navigator.pop(context);
      return completedInSession;
    }

    if (result == kExamRestartSimulationResult) {
      completedInSession = true;
      continue;
    }

    if (isExamAttemptCompletedPopResult(result)) {
      return true;
    }

    return completedInSession;
  }

  return completedInSession;
}
