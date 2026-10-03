import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/lesson_sheet_catalog_filter.dart';
import '../models/lesson_sheet_completion_snapshot.dart';
import '../models/license_models.dart';
import '../models/study_content_access.dart';
import '../repositories/student_quiz_repository.dart';
import '../repositories/study_access_repository.dart';
import '../widgets/app_empty_state.dart';
import 'quiz_sheet_detail_page.dart';
import '../theme/app_visual_tokens.dart';

class LessonQuizListPage extends StatefulWidget {
  const LessonQuizListPage({
    super.key,
    required this.lessonNumber,
    this.categoryId = LicenseCategoryId.motore,
    @visibleForTesting this.studentQuizRepositoryOverride,
  });

  final int lessonNumber;
  final LicenseCategoryId categoryId;

  @visibleForTesting
  final StudentQuizRepository? studentQuizRepositoryOverride;

  @override
  State<LessonQuizListPage> createState() => _LessonQuizListPageState();
}

class _LessonQuizListPageState extends State<LessonQuizListPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;

  LessonSheetCompletionSnapshot _completion =
      LessonSheetCompletionSnapshot.empty;
  List<int> _catalogSheetNumbers = const [];
  bool _loadingSheets = true;
  String? _loadError;

  StudentQuizRepository get _quizRepo =>
      widget.studentQuizRepositoryOverride ?? studentQuizRepository;

  @override
  void initState() {
    super.initState();
    qfLog(
      'route: LessonQuizListPage init lessonNum=${widget.lessonNumber} '
      'categoryId=${widget.categoryId}',
    );
    _loadSheets();
  }

  Future<void> _loadSheets() async {
    setState(() {
      _loadingSheets = true;
      _loadError = null;
    });
    try {
      final numbersByLesson = await _quizRepo.fetchLessonSheetNumbersByLesson(
        categoryId: widget.categoryId,
      );
      final catalogSheets = List<int>.from(
        numbersByLesson[widget.lessonNumber] ?? const [],
      )..sort();

      LessonSheetCompletionSnapshot completion =
          LessonSheetCompletionSnapshot.empty;
      try {
        completion = await _quizRepo.fetchLessonSheetCompletion(
          categoryId: widget.categoryId,
          lessonNumber: widget.lessonNumber,
        );
      } catch (err, st) {
        debugPrint('LessonQuizListPage completion load error: $err\n$st');
      }

      // Preferisci i sheet numbers dal catalogo dedicato; fallback sul
      // completion snapshot (stessa tabella quiz_sets, DISTINCT via map key).
      final sheets = catalogSheets.isNotEmpty
          ? catalogSheets
          : (completion.quizSetIdBySheet.keys.toList()..sort());

      if (!mounted) return;
      setState(() {
        _catalogSheetNumbers = sheets;
        _completion = completion;
        _loadingSheets = false;
      });
      qfLog(
        'LessonQuizListPage: loaded realSheets=${sheets.length} '
        'categoryId=${widget.categoryId}',
      );
    } catch (err, st) {
      debugPrint('LessonQuizListPage sheet catalog load error: $err\n$st');
      if (!mounted) return;
      setState(() {
        _loadingSheets = false;
        _loadError = 'Impossibile caricare le schede di questa lezione.';
        _catalogSheetNumbers = const [];
      });
    }
  }

  Future<void> _onSheetTap({
    required BuildContext context,
    required int sheetNumber,
    required StudyContentAccessSnapshot access,
  }) async {
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

    if (_completion.isSheetCompleted(sheetNumber)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Scheda già svolta'),
          content: const Text(
            'Scheda già svolta. Rivolgiti alla scuola se vuoi ripeterla.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuizSheetDetailPage(
          lessonNumber: widget.lessonNumber,
          sheetNumber: sheetNumber,
          categoryId: widget.categoryId,
        ),
      ),
    );
    if (!mounted) return;
    await _loadSheets();
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

    if (_loadingSheets) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: Text('Schede Lezione ${widget.lessonNumber}'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          title: Text('Schede Lezione ${widget.lessonNumber}'),
          centerTitle: true,
        ),
        body: AppEmptyState(
          title: 'Errore',
          message: _loadError!,
          icon: Icons.error_outline_rounded,
          primaryActionLabel: 'Riprova',
          primaryActionIcon: Icons.refresh_rounded,
          onPrimaryActionPressed: _loadSheets,
        ),
      );
    }

    final catalogSheets = _catalogSheetNumbers;
    if (catalogSheets.isEmpty) {
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

    final actionable = actionableLessonSheetNumbers(
      catalogSheetNumbers: catalogSheets,
      isSheetUnlocked: (sheetNumber) => studyAccessRepository
          .lessonQuizSheet(
            categoryId: widget.categoryId,
            lessonNumber: widget.lessonNumber,
            sheetNumber: sheetNumber,
          )
          .isUnlocked,
    );

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
            totalSheets: catalogSheets.length,
            enabledSheets: actionable.length,
            textTheme: textTheme,
          ),
          const SizedBox(height: 14),
          ...catalogSheets.map((sheetNumber) {
            final access = studyAccessRepository.lessonQuizSheet(
              categoryId: widget.categoryId,
              lessonNumber: widget.lessonNumber,
              sheetNumber: sheetNumber,
            );
            final sheet = QuizSheetItem(
              sheetNumber: sheetNumber,
              progress: _completion.isSheetCompleted(sheetNumber)
                  ? QuizSheetProgress.completed
                  : QuizSheetProgress.todo,
            );
            return _QuizSheetCard(
              sheet: sheet,
              access: access,
              isCompleted: _completion.isSheetCompleted(sheetNumber),
              textTheme: textTheme,
              onTap: () => _onSheetTap(
                context: context,
                sheetNumber: sheetNumber,
                access: access,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LessonSummaryCard extends StatelessWidget {
  const _LessonSummaryCard({
    required this.lessonNumber,
    required this.totalSheets,
    required this.enabledSheets,
    required this.textTheme,
  });

  final int lessonNumber;
  final int totalSheets;
  final int enabledSheets;
  final TextTheme textTheme;

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _neutralColor = AppVisual.chipFill;

  @override
  Widget build(BuildContext context) {
    final coverage = totalSheets == 0 ? 0.0 : enabledSheets / totalSheets;

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
            enabledSheets == 0
                ? 'Nessuna scheda abilitata: attendi l’abilitazione della scuola.'
                : enabledSheets == totalSheets
                ? 'Disponibili $enabledSheets schede quiz (catalogo reale).'
                : 'Abilitate $enabledSheets di $totalSheets schede del catalogo.',
            style: textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor,
              height: 1.35,
            ),
          ),
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
    required this.isCompleted,
    required this.onTap,
    required this.textTheme,
  });

  final QuizSheetItem sheet;
  final StudyContentAccessSnapshot access;
  final bool isCompleted;
  final VoidCallback onTap;
  final TextTheme textTheme;

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _secondaryColor = Color(0xFF44BBCA);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _completedColor = Color(0xFF15803D);

  @override
  Widget build(BuildContext context) {
    final locked = access.isLocked;
    final borderColor = locked
        ? _secondaryColor.withValues(alpha: 0.35)
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: locked
                  ? _secondaryColor.withValues(alpha: 0.12)
                  : _primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              locked
                  ? Icons.lock_outline_rounded
                  : isCompleted
                  ? Icons.check_circle_outline_rounded
                  : Icons.quiz_rounded,
              color: locked
                  ? _secondaryColor
                  : isCompleted
                  ? _completedColor
                  : _primaryColor,
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
                    'Scheda non ancora abilitata',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    access.lockedMessage ??
                        'Quando la scuola abiliterà questa scheda, potrai svolgerla.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.65),
                      height: 1.35,
                    ),
                  ),
                ] else if (isCompleted) ...[
                  Text(
                    'Tentativo registrato sul tuo account.',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.78),
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
                      color: _textPrimaryColor.withValues(alpha: 0.78),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
              else if (isCompleted)
                const _SvoltaChip()
              else
                const _DaSvolgereChip(),
              const SizedBox(height: 6),
              Icon(
                locked
                    ? Icons.info_outline_rounded
                    : Icons.arrow_forward_ios_rounded,
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
        color: _primaryColor.withValues(alpha: 0.1),
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

class _SvoltaChip extends StatelessWidget {
  const _SvoltaChip();

  static const Color _completedColor = Color(0xFF15803D);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _completedColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Svolta',
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: _completedColor,
        ),
      ),
    );
  }
}
