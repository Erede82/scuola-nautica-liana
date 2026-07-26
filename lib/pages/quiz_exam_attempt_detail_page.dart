import 'package:flutter/material.dart';

import '../domain/exam_quiz_attempt_exception.dart';
import '../domain/exam_quiz_attempt_result.dart';
import '../domain/exam_quiz_rules.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../repositories/exam_quiz_attempt_repository.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/backoffice/assigned_quiz_staff_labels.dart';
import '../widgets/nautical_answer_marker.dart';
import '../widgets/quiz_question_image.dart';
import '../widgets/quiz_question_prompt_panel.dart';
import '../widgets/staff_preview_app_bar_badge.dart';

/// Dettaglio read-only di un tentativo esame persistito (header + N snapshot).
class QuizExamAttemptDetailPage extends StatefulWidget {
  const QuizExamAttemptDetailPage({
    super.key,
    required this.attemptId,
    required this.categoryId,
    this.repository,
    this.onStartNewSimulation,
  });

  final String attemptId;
  final LicenseCategoryId categoryId;
  final ExamQuizAttemptRepository? repository;
  final VoidCallback? onStartNewSimulation;

  @override
  State<QuizExamAttemptDetailPage> createState() =>
      _QuizExamAttemptDetailPageState();
}

class _QuizExamAttemptDetailPageState extends State<QuizExamAttemptDetailPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;

  late final ExamQuizAttemptRepository _repository;
  bool _loading = true;
  String? _error;
  ExamQuizAttemptResult? _result;
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? examQuizAttemptRepository;
    _load();
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repository.fetchAttemptDetail(widget.attemptId);
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _result = detail;
        _loading = false;
      });
    } on ExamQuizAttemptException catch (error) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = examQuizAttemptErrorMessageIt(
          ExamQuizAttemptErrorCode.unknown,
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Risultato simulazione'),
        centerTitle: true,
        actions: const [StaffPreviewAppBarBadge()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorBody(message: _error!, onRetry: _load)
          : _result == null
          ? _ErrorBody(
              message: examQuizAttemptErrorMessageIt(
                ExamQuizAttemptErrorCode.attemptNotFound,
              ),
              onRetry: _load,
            )
          : _DetailBody(
              result: _result!,
              textTheme: textTheme,
              onStartNewSimulation: widget.onStartNewSimulation,
            ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: AppVisual.error),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.result,
    required this.textTheme,
    this.onStartNewSimulation,
  });

  final ExamQuizAttemptResult result;
  final TextTheme textTheme;
  final VoidCallback? onStartNewSimulation;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _correctColor = Color(0xFF15803D);
  static const Color _wrongColor = Color(0xFFD32F2F);
  static const Color _passedColor = Color(0xFF15803D);
  static const Color _failedColor = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final passed = result.passed;
    final summary = examQuizSummaryFromResult(result);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
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
          AssignedQuizStaffLabels.formatDateTime(result.completedAt),
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.9),
          ),
        ),
        if (result.timeExpired) ...[
          const SizedBox(height: 6),
          Text(
            'Simulazione chiusa per scadenza del timer.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
          ),
        ],
        const SizedBox(height: 16),
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
          valueColor: summary.wrongCount > 0 ? _wrongColor : _textPrimaryColor,
        ),
        _SummaryRow(label: 'Non risposte', value: '${summary.unansweredCount}'),
        _SummaryRow(
          label: 'Durata',
          value: formatExamDurationMmSs(result.duration),
        ),
        const SizedBox(height: 20),
        Text(
          'Domande (${result.answers.length})',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: _textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...result.answers.map(
          (snapshot) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PersistedReviewCard(snapshot: snapshot),
          ),
        ),
        const SizedBox(height: 8),
        if (onStartNewSimulation != null)
          FilledButton.icon(
            onPressed: onStartNewSimulation,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Nuova simulazione'),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: _DetailBody._textPrimaryColor,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: valueColor ?? _DetailBody._textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersistedReviewCard extends StatelessWidget {
  const _PersistedReviewCard({required this.snapshot});

  final ExamQuizAttemptAnswerSnapshot snapshot;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _correctColor = Color(0xFF15803D);
  static const Color _wrongColor = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final options = QuizAnswerOption.values;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppVisual.chipFill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Domanda ${snapshot.position}',
            style: textTheme.labelLarge?.copyWith(
              color: _primaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (snapshot.imagePath?.trim().isNotEmpty == true) ...[
            QuizQuestionImage(imagePath: snapshot.imagePath, maxHeight: 120),
            const SizedBox(height: 8),
          ],
          Text(
            snapshot.prompt,
            style: textTheme.titleSmall?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReviewOptionTile(
                answerNumber: option.index + 1,
                text: snapshot.textForOption(option),
                markerState: _markerState(option),
                isCorrectRow: option == snapshot.correctOption,
                isWrongRow:
                    snapshot.selectedOption != null &&
                    option == snapshot.selectedOption &&
                    option != snapshot.correctOption,
              ),
            ),
          ),
        ],
      ),
    );
  }

  NauticalAnswerMarkerState _markerState(QuizAnswerOption option) {
    if (option == snapshot.correctOption) {
      return NauticalAnswerMarkerState.correct;
    }
    if (snapshot.selectedOption != null && option == snapshot.selectedOption) {
      return NauticalAnswerMarkerState.wrong;
    }
    return NauticalAnswerMarkerState.neutral;
  }
}

class _ReviewOptionTile extends StatelessWidget {
  const _ReviewOptionTile({
    required this.answerNumber,
    required this.text,
    required this.markerState,
    required this.isCorrectRow,
    required this.isWrongRow,
  });

  final int answerNumber;
  final String text;
  final NauticalAnswerMarkerState markerState;
  final bool isCorrectRow;
  final bool isWrongRow;

  @override
  Widget build(BuildContext context) {
    final answerStyle = QuizAnswerTextStyle.answer(context, compact: false);

    Color background = Colors.white;
    Color border = AppVisual.chipFill;
    var borderWidth = 1.2;

    if (isCorrectRow) {
      background = const Color(0xFFE8F7EE);
      border = _PersistedReviewCard._correctColor;
      borderWidth = 2.2;
    } else if (isWrongRow) {
      background = const Color(0xFFFDECEC);
      border = _PersistedReviewCard._wrongColor;
      borderWidth = 2.2;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: borderWidth),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(text, style: answerStyle)),
          const SizedBox(width: 10),
          NauticalAnswerMarker(answerNumber: answerNumber, state: markerState),
        ],
      ),
    );
  }
}
