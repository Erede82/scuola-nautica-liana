import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../models/license_models.dart';
import '../repositories/study_access_repository.dart';
import '../widgets/app_empty_state.dart';
import '../theme/app_visual_tokens.dart';

/// Dettaglio scheda quiz per lezione — chiavi allineate a DB (`license_category`, `lesson_number`, `sheet_number`).
class QuizSheetDetailPage extends StatefulWidget {
  const QuizSheetDetailPage({
    super.key,
    required this.lessonNumber,
    required this.sheetNumber,
    this.categoryId = LicenseCategoryId.motore,
  });

  final int lessonNumber;
  final int sheetNumber;
  final LicenseCategoryId categoryId;

  @override
  State<QuizSheetDetailPage> createState() => _QuizSheetDetailPageState();
}

class _QuizSheetDetailPageState extends State<QuizSheetDetailPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _accentColor = Color(0xFF44BBCA);

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
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final category = LicenseCatalog.byId(widget.categoryId);
    final lessonMatch = category.lessons
        .where((l) => l.number == widget.lessonNumber)
        .toList();
    final LessonItem? lesson =
        lessonMatch.isEmpty ? null : lessonMatch.first;

    final access = studyAccessRepository.lessonQuizSheet(
      categoryId: widget.categoryId,
      lessonNumber: widget.lessonNumber,
      sheetNumber: widget.sheetNumber,
    );

    final pathLine = _pathHeadline(widget.categoryId);

    if (access.isLocked) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: Text(
            _appBarTitle(
              category.name,
              widget.lessonNumber,
              widget.sheetNumber,
            ),
          ),
          centerTitle: true,
        ),
        body: AppEmptyState(
          title: 'Lezione non ancora abilitata',
          message: access.lockedMessage ??
              'Quando la scuola abiliterà la lezione, potrai accedere a tutte le schede quiz.',
          icon: Icons.lock_outline_rounded,
          tagLabel: 'Schede abilitate dalla scuola',
          primaryActionLabel: 'Torna alle schede',
          primaryActionIcon: Icons.arrow_back_rounded,
          onPrimaryActionPressed: () => Navigator.maybePop(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          _appBarTitle(
            category.name,
            widget.lessonNumber,
            widget.sheetNumber,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accentColor.withValues(alpha: 0.35)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pathLine,
                    style: textTheme.labelLarge?.copyWith(
                      color: _primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (lesson != null)
                    Text(
                      lesson.title,
                      style: textTheme.titleMedium?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Scheda ${widget.sheetNumber} di ${lesson?.quizSheets ?? '—'} · ${category.name}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                  if (access.unlockMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        access.unlockMessage!,
                        textAlign: TextAlign.center,
                        style: textTheme.labelLarge?.copyWith(
                          color: _primaryColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.categoryId == LicenseCategoryId.d1
                  ? 'Questa è l’area di studio per la scheda D1 selezionata. '
                      'Le domande e le risposte sono gestite dalla piattaforma didattica '
                      'della scuola: usa questa schermata per confermare che la scheda è '
                      'abilitata e per accedere al materiale quando sarà collegato in app.'
                  : 'Area di studio per la scheda selezionata. '
                      'Le domande e il tracciamento dei risultati saranno collegati al tuo '
                      'account quando il flusso quiz sarà integrato end-to-end.',
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.88),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Torna alle schede',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  String _appBarTitle(String categoryName, int lessonNumber, int sheetNumber) {
    return 'Lezione $lessonNumber · Scheda $sheetNumber · $categoryName';
  }

  static String _pathHeadline(LicenseCategoryId id) {
    switch (id) {
      case LicenseCategoryId.d1:
        return 'Percorso D1 attivo';
      case LicenseCategoryId.motore:
        return 'Entro le 12 miglia motore · percorso attivo';
      case LicenseCategoryId.vela:
        return 'Patente a vela';
    }
  }
}
