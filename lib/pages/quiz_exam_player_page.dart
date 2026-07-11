import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../debug/quiz_flow_debug.dart';
import '../domain/exam_question_selection.dart';
import '../domain/exam_quiz_rules.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../repositories/student_quiz_repository.dart';
import '../widgets/nautical_answer_marker.dart';
import '../widgets/quiz_question_image.dart';
import '../theme/app_visual_tokens.dart';

/// Risultato [Navigator.pop] per avviare subito una nuova simulazione esame.
const String kExamRestartSimulationResult = 'restart_exam_simulation';

/// Player simulazione esame con domande reali (nessun salvataggio DB in P9C.4-A).
class QuizExamPlayerPage extends StatefulWidget {
  const QuizExamPlayerPage({
    super.key,
    required this.categoryId,
    required this.questions,
  });

  final LicenseCategoryId categoryId;
  final List<QuizQuestion> questions;

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
  Timer? _timer;
  int _currentIndex = 0;
  bool _showSummary = false;
  ExamQuizSummary? _summary;

  @override
  void initState() {
    super.initState();
    qfLog(
      'route: QuizExamPlayerPage init categoryId=${widget.categoryId} '
      'questions=${widget.questions.length}',
    );
    _userAnswers = List<QuizAnswerOption?>.filled(
      widget.questions.length,
      null,
    );
    _remaining = const Duration(minutes: ExamQuizRules.durationMinutes);
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  void _onTimerTick(Timer timer) {
    if (!mounted || _showSummary) return;
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

  int get _correctCount {
    var n = 0;
    for (var i = 0; i < widget.questions.length; i++) {
      final answer = _userAnswers[i];
      if (answer != null && answer == widget.questions[i].correctOption) {
        n++;
      }
    }
    return n;
  }

  int get _wrongCount {
    var n = 0;
    for (var i = 0; i < widget.questions.length; i++) {
      final answer = _userAnswers[i];
      if (answer != null && answer != widget.questions[i].correctOption) {
        n++;
      }
    }
    return n;
  }

  int get _unansweredCount =>
      _userAnswers.where((answer) => answer == null).length;

  void _selectAnswer(QuizAnswerOption option) {
    if (_showSummary) return;
    setState(() => _userAnswers[_currentIndex] = option);
  }

  void _goBack() {
    if (_currentIndex <= 0) return;
    setState(() => _currentIndex--);
  }

  void _goForward() {
    if (_currentIndex + 1 >= widget.questions.length) {
      _finishExam(timeExpired: false);
      return;
    }
    setState(() => _currentIndex++);
  }

  void _finishExam({required bool timeExpired}) {
    _timer?.cancel();
    final summary = buildExamQuizSummary(
      totalQuestions: widget.questions.length,
      correctCount: _correctCount,
      wrongCount: _wrongCount,
      unansweredCount: _unansweredCount,
    );
    qfLog(
      'QuizExamPlayer: summary correct=${summary.correctCount} '
      'errors=${summary.errorCount} outcome=${summary.outcome}'
      '${timeExpired ? ' (time expired)' : ''}',
    );
    setState(() {
      _showSummary = true;
      _summary = summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_showSummary && _summary != null) {
      return _buildSummaryScaffold(context, textTheme, _summary!);
    }

    final question = _currentQuestion;
    final selected = _selectedAnswer;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Simulazione esame'),
        centerTitle: true,
        actions: [
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
          _ExamProgressPanel(
            currentIndex: _currentIndex,
            total: widget.questions.length,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Domanda ${_currentIndex + 1}',
                          style: textTheme.labelLarge?.copyWith(
                            color: _primaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        QuizQuestionImage(imagePath: question.imagePath),
                        Text(
                          question.prompt,
                          style: textTheme.titleMedium?.copyWith(
                            color: _textPrimaryColor,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ],
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
                      onPressed: _goForward,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _currentIndex + 1 >= widget.questions.length
                            ? 'Vedi riepilogo'
                            : 'Avanti',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _goForward,
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Domanda successiva',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryScaffold(
    BuildContext context,
    TextTheme textTheme,
    ExamQuizSummary summary,
  ) {
    final passed = summary.outcome == ExamQuizOutcome.passed;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Riepilogo esame'),
        centerTitle: true,
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
                  ? 'Hai totalizzato al massimo ${ExamQuizRules.maxErrorsToPass} errori.'
                  : 'Soglia superata: più di ${ExamQuizRules.maxErrorsToPass} errori '
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
              valueColor: summary.errorCount > ExamQuizRules.maxErrorsToPass
                  ? _failedColor
                  : _textPrimaryColor,
            ),
            const SizedBox(height: 24),
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
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Torna al quiz esame'),
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
  const _ExamProgressPanel({required this.currentIndex, required this.total});

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppVisual.chipFill),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : (currentIndex + 1) / total,
                minHeight: 7,
                backgroundColor: AppVisual.chipFill,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppVisual.logoBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${currentIndex + 1}/$total',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
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
  });

  final int answerNumber;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).width < 420;

    return Material(
      color: selected ? const Color(0xFFE8F4FA) : Colors.white,
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
            border: Border.all(
              color: selected ? AppVisual.logoBlue : AppVisual.chipFill,
              width: selected ? 2.2 : 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  text,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
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
Future<void> startExamSimulation({
  required BuildContext context,
  required LicenseCategoryId categoryId,
}) async {
  final dbCategory = categoryId == LicenseCategoryId.motore ? 'A12' : 'D1';
  final quotas = examTopicQuotasForCategory(dbCategory);
  if (quotas == null) return;

  while (context.mounted) {
    final pool = await studentQuizRepository.fetchExamQuestionsByTopic(
      categoryId: categoryId,
    );

    final questions = pickExamQuestions(
      poolByTopic: pool,
      topicQuotas: quotas,
      random: Random(),
    );

    if (!context.mounted) return;

    if (questions.length < ExamQuizRules.questionCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Domande insufficienti per la simulazione '
            '(${questions.length}/${ExamQuizRules.questionCount}).',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute<String?>(
        builder: (_) =>
            QuizExamPlayerPage(categoryId: categoryId, questions: questions),
      ),
    );

    if (result != kExamRestartSimulationResult) return;
  }
}
