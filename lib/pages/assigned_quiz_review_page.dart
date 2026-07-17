import 'package:flutter/material.dart';

import '../data/supabase/mappers/assigned_quiz_mapper.dart';
import '../models/assigned_quiz_models.dart';
import '../models/quiz_question.dart';
import '../repositories/assigned_quiz_repository.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/branded_app_bar_title.dart';
import '../widgets/nautical_answer_marker.dart';
import '../widgets/quiz_question_prompt_panel.dart';
import '../widgets/staff_preview_app_bar_badge.dart';

/// Review post-submit (soluzioni disponibili soltanto qui).
class AssignedQuizReviewPage extends StatefulWidget {
  const AssignedQuizReviewPage({
    super.key,
    required this.repository,
    required this.attemptId,
    required this.assignmentTitle,
    required this.publicCode,
  });

  final AssignedQuizRepository repository;
  final String attemptId;
  final String assignmentTitle;
  final String publicCode;

  @override
  State<AssignedQuizReviewPage> createState() => AssignedQuizReviewPageState();
}

@visibleForTesting
class AssignedQuizReviewPageState extends State<AssignedQuizReviewPage> {
  bool _loading = true;
  String? _error;
  List<AssignedQuizReviewItem> _items = const [];
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.repository.loadAttemptReview(widget.attemptId);
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _items = List<AssignedQuizReviewItem>.from(items)
          ..sort((a, b) => a.position.compareTo(b.position));
        _loading = false;
      });
    } catch (error) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = assignedQuizExceptionFrom(error).message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppVisual.canvas,
      appBar: AppBar(
        backgroundColor: AppVisual.logoBlue,
        foregroundColor: Colors.white,
        title: const SectionAppBarTitle('Rivedi risposte', logoHeight: 28),
        actions: const [StaffPreviewAppBarBadge()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: AppVisual.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: _load,
                      child: const Text('Riprova'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: _items.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.assignmentTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.publicCode,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppVisual.logoBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                }
                return _ReviewCard(item: _items[index - 1]);
              },
            ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item});

  final AssignedQuizReviewItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final selected = QuizAnswerOptionX.tryParse(item.selectedOption);
    final correct = QuizAnswerOptionX.tryParse(item.correctOption);
    final isCorrect =
        item.isCorrect ??
        (selected != null && correct != null && selected == correct);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppVisual.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppVisual.chipFill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCorrect ? 'Corretta' : 'Da ripassare',
            style: textTheme.labelLarge?.copyWith(
              color: isCorrect ? AppVisual.success : AppVisual.error,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lezione ${item.lessonNumber}',
            style: textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
          ),
          const SizedBox(height: 8),
          QuizQuestionPromptPanel(
            questionNumber: item.position,
            prompt: item.prompt,
            imagePath: item.imagePath,
            compact: true,
          ),
          const SizedBox(height: 8),
          for (final option in QuizAnswerOption.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ReviewOption(
                number: assignedQuizOptionToMarkerNumber(option),
                text: switch (option) {
                  QuizAnswerOption.a => item.optionA,
                  QuizAnswerOption.b => item.optionB,
                  QuizAnswerOption.c => item.optionC,
                },
                state: _markerState(
                  option: option,
                  selected: selected,
                  correct: correct,
                ),
              ),
            ),
          if (item.explanation != null && item.explanation!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item.explanation!,
                style: textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
            ),
        ],
      ),
    );
  }

  NauticalAnswerMarkerState _markerState({
    required QuizAnswerOption option,
    required QuizAnswerOption? selected,
    required QuizAnswerOption? correct,
  }) {
    if (correct != null && option == correct) {
      return NauticalAnswerMarkerState.correct;
    }
    if (selected != null && option == selected && option != correct) {
      return NauticalAnswerMarkerState.wrong;
    }
    if (selected != null && option == selected) {
      return NauticalAnswerMarkerState.selected;
    }
    return NauticalAnswerMarkerState.neutral;
  }
}

class _ReviewOption extends StatelessWidget {
  const _ReviewOption({
    required this.number,
    required this.text,
    required this.state,
  });

  final int number;
  final String text;
  final NauticalAnswerMarkerState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppVisual.chipFill),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          NauticalAnswerMarker(
            answerNumber: number,
            state: state,
            compact: true,
          ),
        ],
      ),
    );
  }
}
