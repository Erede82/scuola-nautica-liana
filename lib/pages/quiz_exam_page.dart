import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../models/license_models.dart';
import '../repositories/study_access_repository.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/category_content_state.dart';
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

  @override
  void initState() {
    super.initState();
    qfLog('route: QuizExamPage init categoryId=${widget.categoryId}');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studyAccessListenable,
      builder: (context, _) {
        final category = LicenseCatalog.byId(widget.categoryId);
        final examGate = studyAccessRepository.examQuiz(widget.categoryId);

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            title: Text('Quiz esame — ${category.name}'),
            centerTitle: true,
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
              : examGate.isLocked
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
              : CategoryContentState(
                  category: category,
                  availableTitle: widget.categoryId == LicenseCategoryId.d1
                      ? 'Quiz esame D1'
                      : 'Quiz esame — ${category.name}',
                  availableMessage:
                      'Percorso attivo: simulazione esame sbloccata '
                      '(${examGate.unlockMessage ?? 'abilitazione scuola'}). '
                      'Allenati con le schede lezione fino al giorno dell’esame.',
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
