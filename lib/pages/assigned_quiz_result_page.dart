import 'package:flutter/material.dart';

import '../models/assigned_quiz_models.dart';
import '../repositories/assigned_quiz_repository.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/backoffice/assigned_quiz_staff_labels.dart';
import '../widgets/branded_app_bar_title.dart';
import 'assigned_quiz_review_page.dart';

/// Riepilogo dopo submit di un quiz assegnato.
class AssignedQuizResultPage extends StatelessWidget {
  const AssignedQuizResultPage({
    super.key,
    required this.repository,
    required this.assignment,
    required this.result,
  });

  final AssignedQuizRepository repository;
  final AssignedQuizSummary assignment;
  final AssignedQuizSubmitResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppVisual.canvas,
      appBar: AppBar(
        backgroundColor: AppVisual.logoBlue,
        foregroundColor: Colors.white,
        title: const SectionAppBarTitle('Risultato quiz', logoHeight: 28),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    assignment.title,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assignment.publicCode,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppVisual.logoBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ResultRow(
                    label: 'Tentativo',
                    value: '${result.attemptNumber}',
                  ),
                  _ResultRow(
                    label: 'Corrette',
                    value: '${result.correctCount}',
                  ),
                  _ResultRow(label: 'Errate', value: '${result.wrongCount}'),
                  _ResultRow(
                    label: 'Non risposte',
                    value: '${result.unansweredCount}',
                  ),
                  _ResultRow(
                    label: 'Punteggio',
                    value: '${result.scorePercentage.toStringAsFixed(0)}%',
                  ),
                  _ResultRow(
                    label: 'Inviato',
                    value: AssignedQuizStaffLabels.formatDateTime(
                      result.submittedAt,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AssignedQuizReviewPage(
                            repository: repository,
                            attemptId: result.attemptId,
                            assignmentTitle: assignment.title,
                            publicCode: assignment.publicCode,
                          ),
                        ),
                      );
                    },
                    child: const Text('Rivedi risposte'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Torna ai quiz assegnati'),
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

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyLarge?.copyWith(color: AppVisual.inkMuted),
            ),
          ),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
