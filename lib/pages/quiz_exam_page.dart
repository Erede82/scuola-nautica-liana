import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/exam_quiz_rules.dart';
import '../domain/quiz_sheet_player_navigation.dart';
import '../models/license_models.dart';
import '../repositories/study_access_repository.dart';
import '../services/student_area_context.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/category_content_state.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import 'quiz_exam_player_page.dart';
import '../theme/app_visual_tokens.dart';

class QuizExamPage extends StatefulWidget {
  const QuizExamPage({super.key, this.categoryId = LicenseCategoryId.motore});

  final LicenseCategoryId categoryId;

  @override
  State<QuizExamPage> createState() => _QuizExamPageState();
}

class _QuizExamPageState extends State<QuizExamPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;

  bool _startingExam = false;

  @override
  void initState() {
    super.initState();
    qfLog('route: QuizExamPage init categoryId=${widget.categoryId}');
  }

  Future<void> _onStartSimulation() async {
    if (_startingExam) return;
    setState(() => _startingExam = true);
    qfLog(
      'QuizExamPage: tap Avvia simulazione categoryId=${widget.categoryId}',
    );
    try {
      await startExamSimulation(
        context: context,
        categoryId: widget.categoryId,
      );
    } finally {
      if (mounted) setState(() => _startingExam = false);
    }
  }

  Widget _motoreExamBody(TextTheme textTheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Simulazione esame',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Patente entro le 12 miglia (motore): ${ExamQuizRules.questionCount} '
            'quesiti, ${ExamQuizRules.durationMinutes} minuti, massimo '
            '${ExamQuizRules.maxErrorsToPass} errori per superare. '
            'Le domande non risposte contano come errore.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _startingExam ? null : _onStartSimulation,
            icon: _startingExam
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_startingExam ? 'Caricamento…' : 'Avvia simulazione'),
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studyAccessListenable,
      builder: (context, _) {
        final category = LicenseCatalog.byId(widget.categoryId);
        final examGate = studyAccessRepository.examQuiz(widget.categoryId);
        final isPreview = StudentAreaContext.of(context).isStaffPreview;
        final examLocked = !isExamQuizUiAccessible(
          isStaffPreview: isPreview,
          gateLocked: examGate.isLocked,
        );
        final textTheme = Theme.of(context).textTheme;

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            title: Text('Quiz esame — ${category.name}'),
            centerTitle: true,
            actions: const [StaffPreviewAppBarBadge()],
          ),
          body: !category.isAvailable
              ? CategoryContentState(
                  category: category,
                  availableTitle: 'Quiz esame — ${category.name}',
                  availableMessage:
                      'La modalità esame per ${category.name} sarà disponibile con i contenuti didattici.',
                  availableIcon: Icons.quiz_rounded,
                  unavailableTitle: null,
                  unavailableMessage: null,
                  unavailableIcon: Icons.anchor_rounded,
                )
              : examLocked
              ? AppEmptyState(
                  title: 'Quiz esame',
                  message:
                      examGate.lockedMessage ??
                      'Quiz esame disponibile solo quando la scuola lo abilita '
                          '(schede abilitate dalla scuola).',
                  icon: Icons.lock_outline_rounded,
                  tagLabel: 'Abilitazione scuola',
                  primaryActionLabel: 'Torna indietro',
                  primaryActionIcon: Icons.arrow_back_rounded,
                  onPrimaryActionPressed: () => Navigator.maybePop(context),
                )
              : widget.categoryId == LicenseCategoryId.motore
              ? _motoreExamBody(textTheme)
              : CategoryContentState(
                  category: category,
                  availableTitle: widget.categoryId == LicenseCategoryId.d1
                      ? 'Quiz esame D1'
                      : 'Quiz esame — ${category.name}',
                  availableMessage:
                      'Simulazione esame per ${category.name}: regole e '
                      'selezione domande in preparazione. Usa le schede lezione '
                      'per allenarti.',
                  availableIcon: Icons.quiz_rounded,
                  unavailableTitle: null,
                  unavailableMessage: null,
                  unavailableIcon: Icons.anchor_rounded,
                ),
        );
      },
    );
  }
}
