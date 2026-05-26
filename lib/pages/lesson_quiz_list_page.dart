import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../models/license_models.dart';
import '../models/study_content_access.dart';
import '../repositories/study_access_repository.dart';
import '../widgets/app_empty_state.dart';
import 'quiz_sheet_detail_page.dart';
import '../theme/app_visual_tokens.dart';

class LessonQuizListPage extends StatefulWidget {
  const LessonQuizListPage({
    super.key,
    required this.lessonNumber,
    this.categoryId = LicenseCategoryId.motore,
  });

  final int lessonNumber;
  final LicenseCategoryId categoryId;

  @override
  State<LessonQuizListPage> createState() => _LessonQuizListPageState();
}

class _LessonQuizListPageState extends State<LessonQuizListPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;

  @override
  void initState() {
    super.initState();
    qfLog(
      'route: LessonQuizListPage init lessonNum=${widget.lessonNumber} '
      'categoryId=${widget.categoryId}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final category = LicenseCatalog.byId(widget.categoryId);
      final hasLesson = category.lessons.any(
        (item) => item.number == widget.lessonNumber,
      );
      final lesson = hasLesson
          ? category.lessons
              .firstWhere((item) => item.number == widget.lessonNumber)
          : null;
      qfLog(
        'LessonQuizListPage: first frame (loaded) sheetsInCatalog='
        '${lesson?.quizSheets ?? 0} categoryAvailable=${category.isAvailable}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studyAccessListenable,
      builder: (context, _) => _buildWithAccess(context),
    );
  }

  Widget _buildWithAccess(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final category = LicenseCatalog.byId(widget.categoryId);
    final hasLesson = category.lessons.any(
      (item) => item.number == widget.lessonNumber,
    );
    final lesson = hasLesson
        ? category.lessons.firstWhere(
            (item) => item.number == widget.lessonNumber,
          )
        : const LessonItem(
            number: 0,
            title: 'Lezione non disponibile',
            quizSheets: 0,
            icon: Icons.help_outline_rounded,
          );

    final sheetCount = lesson.quizSheets;

    if (!category.isAvailable) {
      final isVela = widget.categoryId == LicenseCategoryId.vela;
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: Text('Schede Lezione ${widget.lessonNumber}'),
          centerTitle: true,
        ),
        body: AppEmptyState(
          title: isVela
              ? 'Contenuti vela in preparazione'
              : '${category.name} — Disponibile prossimamente',
          message: isVela
              ? 'Le schede quiz per la patente a vela non sono ancora disponibili. '
                  'Disponibile prossimamente, con le stesse regole di abilitazione della scuola.'
              : 'I contenuti di quiz per questa categoria sono in preparazione.',
          icon: Icons.lock_outline_rounded,
          tagLabel: 'Disponibile prossimamente',
          primaryActionLabel: 'Torna indietro',
          primaryActionIcon: Icons.arrow_back_rounded,
          onPrimaryActionPressed: () => Navigator.maybePop(context),
        ),
      );
    }

    if (!hasLesson) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: Text('Schede Lezione ${widget.lessonNumber}'),
          centerTitle: true,
        ),
        body: AppEmptyState(
          title: 'Lezione non disponibile',
          message:
              'Questa lezione non è presente per la categoria selezionata.',
          icon: Icons.help_outline_rounded,
          primaryActionLabel: 'Torna indietro',
          primaryActionIcon: Icons.arrow_back_rounded,
          onPrimaryActionPressed: () => Navigator.maybePop(context),
        ),
      );
    }

    if (sheetCount == 0) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: Text('Schede Lezione ${widget.lessonNumber}'),
          centerTitle: true,
        ),
        body: AppEmptyState(
          title: 'Schede non ancora disponibili',
          message:
              'Questa lezione non ha ancora schede pubblicate nel catalogo. '
              'Contatta la scuola per il programma aggiornato.',
          icon: Icons.quiz_rounded,
          tagLabel: 'In preparazione',
          primaryActionLabel: 'Torna alle lezioni',
          primaryActionIcon: Icons.arrow_back_rounded,
          onPrimaryActionPressed: () => Navigator.maybePop(context),
        ),
      );
    }

    final sheets = List.generate(
      sheetCount,
      (index) => _buildSheetData(
        lessonNumber: widget.lessonNumber,
        sheetNumber: index + 1,
      ),
    );

    final lessonGateSample = studyAccessRepository.lessonQuizSheet(
      categoryId: widget.categoryId,
      lessonNumber: widget.lessonNumber,
      sheetNumber: 1,
    );
    final lessonUnlocked = sheetCount > 0 && lessonGateSample.isUnlocked;
    final enabledCount = lessonUnlocked ? sheetCount : 0;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text('Schede Lezione ${widget.lessonNumber}'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _LessonSummaryCard(
            lessonNumber: widget.lessonNumber,
            totalSheets: sheetCount,
            enabledSheets: enabledCount,
            lessonUnlocked: lessonUnlocked,
            textTheme: textTheme,
          ),
          const SizedBox(height: 14),
          ...List.generate(sheets.length, (index) {
            final sheet = sheets[index];
            final sheetNumber = index + 1;
            final access = studyAccessRepository.lessonQuizSheet(
              categoryId: widget.categoryId,
              lessonNumber: widget.lessonNumber,
              sheetNumber: sheetNumber,
            );

            return _QuizSheetCard(
              sheet: sheet,
              access: access,
              textTheme: textTheme,
              onTap: () {
                qfLog(
                  'LessonQuizList: tap scheda L${widget.lessonNumber} '
                  'sheet=$sheetNumber locked=${access.isLocked}',
                );
                if (access.isLocked) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        access.lockedMessage ??
                            'Questa scheda sarà disponibile quando la scuola la abiliterà.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => QuizSheetDetailPage(
                      lessonNumber: widget.lessonNumber,
                      sheetNumber: sheet.sheetNumber,
                      categoryId: widget.categoryId,
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  static QuizSheetItem _buildSheetData({
    required int lessonNumber,
    required int sheetNumber,
  }) {
    final seed = (lessonNumber * 11 + sheetNumber * 7) % 10;

    if (seed <= 4) {
      return QuizSheetItem(
        sheetNumber: sheetNumber,
        progress: QuizSheetProgress.todo,
      );
    }

    if (seed <= 7) {
      return QuizSheetItem(
        sheetNumber: sheetNumber,
        progress: QuizSheetProgress.completed,
        errorCount: seed - 4,
      );
    }

    return QuizSheetItem(
      sheetNumber: sheetNumber,
      progress: QuizSheetProgress.review,
      errorCount: seed - 6,
    );
  }

}

class _LessonSummaryCard extends StatelessWidget {
  const _LessonSummaryCard({
    required this.lessonNumber,
    required this.totalSheets,
    required this.enabledSheets,
    required this.lessonUnlocked,
    required this.textTheme,
  });

  final int lessonNumber;
  final int totalSheets;
  final int enabledSheets;
  final bool lessonUnlocked;
  final TextTheme textTheme;

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _neutralColor = AppVisual.chipFill;

  @override
  Widget build(BuildContext context) {
    final coverage =
        totalSheets == 0 ? 0.0 : enabledSheets / totalSheets;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lezione $lessonNumber',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: _textPrimaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lessonUnlocked
                ? 'Lezione abilitata dalla scuola: disponibili tutte le $totalSheets schede quiz.'
                : 'Lezione in attesa di abilitazione: nessuna scheda disponibile finché la scuola non abilita l’intera lezione.',
            style: textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor,
              height: 1.35,
            ),
          ),
          if (!lessonUnlocked) ...[
            const SizedBox(height: 4),
            Text(
              'Le abilitazioni sono gestite dalla segreteria a livello di lezione.',
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withOpacity(0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: coverage,
              minHeight: 8,
              backgroundColor: _neutralColor,
              valueColor: const AlwaysStoppedAnimation<Color>(_accentColor),
            ),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Icon(Icons.sailing_rounded, color: _primaryColor, size: 18),
          ),
        ],
      ),
    );
  }
}

class _QuizSheetCard extends StatelessWidget {
  const _QuizSheetCard({
    required this.sheet,
    required this.access,
    required this.onTap,
    required this.textTheme,
  });

  final QuizSheetItem sheet;
  final StudyContentAccessSnapshot access;
  final VoidCallback onTap;
  final TextTheme textTheme;

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _secondaryColor = Color(0xFF44BBCA);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _primaryColor = AppVisual.logoBlue;

  @override
  Widget build(BuildContext context) {
    final locked = access.isLocked;
    final borderColor = locked
        ? _secondaryColor.withOpacity(0.35)
        : _neutralColor;

    return Opacity(
      opacity: locked ? 0.92 : 1,
      child: Card(
        color: _cardColor,
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1.1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: locked
                  ? _secondaryColor.withOpacity(0.12)
                  : _primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              locked ? Icons.lock_outline_rounded : Icons.quiz_rounded,
              color: locked ? _secondaryColor : _primaryColor,
            ),
          ),
          title: Text(
            'Scheda ${sheet.sheetNumber}',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: _textPrimaryColor,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (locked) ...[
                  Text(
                    'Lezione non ancora abilitata',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withOpacity(0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    access.lockedMessage ??
                        'Quando la scuola abiliterà la lezione, tutte le schede saranno disponibili.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withOpacity(0.65),
                      height: 1.35,
                    ),
                  ),
                ] else ...[
                  if (access.unlockMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        access.unlockMessage!,
                        style: textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF2E9E5B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  Text(
                    'Rafforza la preparazione su questa scheda.',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withOpacity(0.78),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (locked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppVisual.chipFill.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Bloccata',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _textPrimaryColor,
                    ),
                  ),
                )
              else
                const _DaSvolgereChip(),
              const SizedBox(height: 6),
              Icon(
                locked ? Icons.info_outline_rounded : Icons.arrow_forward_ios_rounded,
                size: 16,
                color: _secondaryColor,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Stato unico in elenco — evita “Completata/In corso” per un tono più professionale.
class _DaSvolgereChip extends StatelessWidget {
  const _DaSvolgereChip();

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Da svolgere',
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: _textPrimaryColor,
        ),
      ),
    );
  }
}
