import 'package:flutter/material.dart';

import '../debug/quiz_flow_debug.dart';
import '../domain/multi_topic_history_answer_review.dart';
import '../domain/multi_topic_quiz_attempt_exception.dart';
import '../domain/multi_topic_quiz_history_models.dart';
import '../domain/quiz_license_category.dart';
import '../models/quiz_question.dart';
import '../repositories/multi_topic_quiz_attempt_repository.dart';
import '../theme/app_visual_tokens.dart';
import '../theme/quiz_player_visual_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/quiz_answer_result_chip.dart';
import '../widgets/quiz_question_image.dart';
import '../widgets/staff_preview_app_bar_badge.dart';

/// Review read-only di un tentativo Multischeda (snapshot DB).
class MultiTopicQuizHistoryDetailPage extends StatefulWidget {
  const MultiTopicQuizHistoryDetailPage({
    super.key,
    required this.attemptId,
    this.repository,
  });

  final String attemptId;
  final MultiTopicQuizAttemptRepository? repository;

  @override
  State<MultiTopicQuizHistoryDetailPage> createState() =>
      _MultiTopicQuizHistoryDetailPageState();
}

class _MultiTopicQuizHistoryDetailPageState
    extends State<MultiTopicQuizHistoryDetailPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;

  bool _loading = true;
  String? _error;
  MultiTopicQuizAttemptDetail? _detail;

  MultiTopicQuizAttemptRepository get _repo =>
      widget.repository ?? multiTopicQuizAttemptRepository;

  @override
  void initState() {
    super.initState();
    qfLog(
      'route: MultiTopicQuizHistoryDetailPage attemptId=${widget.attemptId}',
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repo.fetchAttemptDetail(widget.attemptId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on MultiTopicQuizAttemptException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = multiTopicQuizAttemptErrorMessageIt(
          MultiTopicQuizAttemptErrorCode.unknown,
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Dettaglio Multischeda'),
        centerTitle: true,
        actions: const [StaffPreviewAppBarBadge()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppEmptyState(
              title: 'Errore',
              message: _error!,
              icon: Icons.error_outline_rounded,
              primaryActionLabel: 'Riprova',
              primaryActionIcon: Icons.refresh_rounded,
              onPrimaryActionPressed: _load,
            )
          : _buildBody(theme, _detail!),
    );
  }

  Widget _buildBody(ThemeData theme, MultiTopicQuizAttemptDetail detail) {
    final s = detail.summary;
    final dbLabel = dbLicenseCategoryFor(s.licenseCategory) ?? '—';
    final topics = s.lessonNumbers.map((n) => 'L$n').join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          'Multischeda argomento',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Categoria $dbLabel · $topics · ${s.progressLabel}',
          style: theme.textTheme.bodyMedium?.copyWith(color: _textPrimaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          '${s.correctCount}/${s.totalQuestions} corrette · '
          '${s.wrongCount} errate · ${s.unansweredCount} non risposte',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 16),
        ...detail.answers.map((answer) {
          final reviewStatus = multiTopicHistoryAnswerReviewStatus(
            selectedOption: answer.selectedOption,
            isCorrect: answer.isCorrect,
          );
          final unanswered =
              reviewStatus == MultiTopicHistoryAnswerReviewStatus.unanswered;
          final imagePath = answer.imagePath?.trim();
          final explanation = answer.explanation?.trim();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: QuizPlayerVisual.cardSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Domanda ${answer.position} · Lezione ${answer.lessonNumber}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (imagePath != null && imagePath.isNotEmpty) ...[
                    QuizQuestionImage(imagePath: imagePath),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    answer.prompt,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('A) ${answer.optionA}'),
                  Text('B) ${answer.optionB}'),
                  Text('C) ${answer.optionC}'),
                  if (!unanswered && answer.selectedOption != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'La tua risposta: ${answer.selectedOption!.letter}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _textPrimaryColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  QuizAnswerResultChip(
                    isCorrect: answer.isCorrect,
                    unanswered: unanswered,
                    correctLetter: answer.correctOption.letter,
                    explanation: (explanation != null && explanation.isNotEmpty)
                        ? explanation
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
