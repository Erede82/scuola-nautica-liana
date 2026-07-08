import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/quiz_sheet_exit_policy.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../repositories/quiz_attempt_repository.dart';
import '../repositories/student_quiz_repository.dart';
import '../repositories/study_access_repository.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/quiz_question_image.dart';
import '../theme/app_visual_tokens.dart';

/// Dettaglio scheda quiz per lezione — domande da `quiz_sets` / `quiz_set_items`.
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
      builder: (context, _) {
        final access = studyAccessRepository.lessonQuizSheet(
          categoryId: widget.categoryId,
          lessonNumber: widget.lessonNumber,
          sheetNumber: widget.sheetNumber,
        );
        final category = LicenseCatalog.byId(widget.categoryId);

        if (access.isLocked) {
          return Scaffold(
            backgroundColor: _backgroundColor,
            appBar: _buildAppBar(category.name),
            body: AppEmptyState(
              title: 'Lezione non ancora abilitata',
              message:
                  access.lockedMessage ??
                  'Quando la scuola abiliterà la lezione, potrai accedere a tutte le schede quiz.',
              icon: Icons.lock_outline_rounded,
              tagLabel: 'Schede abilitate dalla scuola',
              primaryActionLabel: 'Torna alle schede',
              primaryActionIcon: Icons.arrow_back_rounded,
              onPrimaryActionPressed: () => Navigator.maybePop(context),
            ),
          );
        }

        return _QuizSheetPlayer(
          lessonNumber: widget.lessonNumber,
          sheetNumber: widget.sheetNumber,
          categoryId: widget.categoryId,
          categoryName: category.name,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(String categoryName) {
    return AppBar(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      title: Text(_appBarTitle(categoryName)),
      centerTitle: true,
    );
  }

  String _appBarTitle(String categoryName) {
    return 'Lezione ${widget.lessonNumber} · Scheda ${widget.sheetNumber} · $categoryName';
  }
}

class _QuizSheetPlayer extends StatefulWidget {
  const _QuizSheetPlayer({
    required this.lessonNumber,
    required this.sheetNumber,
    required this.categoryId,
    required this.categoryName,
  });

  final int lessonNumber;
  final int sheetNumber;
  final LicenseCategoryId categoryId;
  final String categoryName;

  @override
  State<_QuizSheetPlayer> createState() => _QuizSheetPlayerState();
}

class _QuizSheetPlayerState extends State<_QuizSheetPlayer> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _correctColor = Color(0xFF15803D);
  static const Color _wrongColor = Color(0xFFD32F2F);
  static const Color _correctBg = Color(0xFFDFF5E8);
  static const Color _wrongBg = Color(0xFFFDE8E8);
  static const Color _unansweredColor = Color(0xFF6B7280);

  List<QuizQuestion> _questions = const [];
  List<QuizAnswerOption?> _userAnswers = const [];
  String? _quizSetId;
  DateTime? _startedAt;
  DateTime? _completedAt;
  bool _loading = true;
  bool _loadFailed = false;
  int _currentIndex = 0;
  bool _showSummary = false;
  _AttemptSaveStatus _saveStatus = _AttemptSaveStatus.idle;
  String? _saveErrorMessage;
  String? _partialQuizResultId;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
      _showSummary = false;
      _currentIndex = 0;
    });

    try {
      final content = await studentQuizRepository.fetchLessonSheetContent(
        categoryId: widget.categoryId,
        lessonNumber: widget.lessonNumber,
        sheetNumber: widget.sheetNumber,
      );
      if (!mounted) return;
      final loaded = content?.questions ?? const [];
      setState(() {
        _quizSetId = loaded.isEmpty ? null : content?.quizSetId;
        _questions = loaded;
        _userAnswers = List<QuizAnswerOption?>.filled(loaded.length, null);
        _startedAt = loaded.isEmpty ? null : DateTime.now();
        _completedAt = null;
        _saveStatus = _AttemptSaveStatus.idle;
        _saveErrorMessage = null;
        _partialQuizResultId = null;
        _loading = false;
      });
    } catch (err, st) {
      debugPrint('QuizSheetPlayer load error: $err\n$st');
      if (!mounted) return;
      setState(() {
        _questions = const [];
        _userAnswers = const [];
        _quizSetId = null;
        _startedAt = null;
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  int get _totalSheetsInLesson {
    final category = LicenseCatalog.byId(widget.categoryId);
    for (final lesson in category.lessons) {
      if (lesson.number == widget.lessonNumber) return lesson.quizSheets;
    }
    return 0;
  }

  bool get _hasNextSheet => widget.sheetNumber < _totalSheetsInLesson;

  QuizQuestion? get _currentQuestion {
    if (_currentIndex < 0 || _currentIndex >= _questions.length) return null;
    return _questions[_currentIndex];
  }

  QuizAnswerOption? get _selectedAnswer {
    if (_currentIndex < 0 || _currentIndex >= _userAnswers.length) {
      return null;
    }
    return _userAnswers[_currentIndex];
  }

  bool get _isCurrentAnswered => _selectedAnswer != null;

  int get _correctCount {
    var n = 0;
    for (var i = 0; i < _questions.length; i++) {
      final answer = _userAnswers[i];
      if (answer != null && answer == _questions[i].correctOption) n++;
    }
    return n;
  }

  int get _wrongCount {
    var n = 0;
    for (var i = 0; i < _questions.length; i++) {
      final answer = _userAnswers[i];
      if (answer != null && answer != _questions[i].correctOption) n++;
    }
    return n;
  }

  int get _unansweredCount =>
      _userAnswers.where((answer) => answer == null).length;

  int get _percentCorrect {
    if (_questions.isEmpty) return 0;
    return ((_correctCount / _questions.length) * 100).round();
  }

  void _selectAnswer(QuizAnswerOption option) {
    if (_showSummary || _isCurrentAnswered) return;
    setState(() => _userAnswers[_currentIndex] = option);
  }

  void _goBack() {
    if (_currentIndex <= 0) return;
    setState(() => _currentIndex--);
  }

  void _goForward() {
    if (_currentIndex + 1 >= _questions.length) {
      _tryShowSummary();
      return;
    }
    setState(() => _currentIndex++);
  }

  Future<void> _tryShowSummary() async {
    final unanswered = _unansweredCount;
    if (unanswered > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Domande senza risposta'),
          content: Text(
            'Hai ancora $unanswered domande senza risposta. '
            'Vuoi completarle prima di vedere il riepilogo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Torna alle domande'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Vedi riepilogo comunque'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    setState(() {
      _showSummary = true;
      _completedAt = DateTime.now();
      _saveStatus = _AttemptSaveStatus.saving;
    });
    await _saveAttempt();
  }

  Future<void> _saveAttempt() async {
    if (_saveStatus == _AttemptSaveStatus.saved) {
      return;
    }

    final quizSetId = _quizSetId;
    final startedAt = _startedAt;
    final completedAt = _completedAt;
    if (quizSetId == null || startedAt == null || completedAt == null) {
      setState(() {
        _saveStatus = _AttemptSaveStatus.failed;
        _saveErrorMessage =
            'Scheda non collegata al database: impossibile salvare il risultato.';
      });
      return;
    }

    setState(() {
      _saveStatus = _AttemptSaveStatus.saving;
      _saveErrorMessage = null;
    });

    try {
      final result = await quizAttemptRepository.submitLessonSheetAttempt(
        quizSetId: quizSetId,
        questions: _questions,
        answers: _userAnswers,
        startedAt: startedAt,
        completedAt: completedAt,
        existingQuizResultId: _partialQuizResultId,
      );
      if (!mounted) return;
      setState(() {
        _saveStatus = _AttemptSaveStatus.saved;
        _partialQuizResultId = null;
        _saveErrorMessage = null;
      });
      qfLog('quiz attempt saved: ${result.quizResultId}');
    } on QuizAttemptAnswersPartialFailure catch (err, st) {
      debugPrint('QuizSheetPlayer partial save: ${err.message}\n$st');
      if (!mounted) return;
      setState(() {
        _partialQuizResultId = err.quizResultId;
        _saveStatus = _AttemptSaveStatus.failed;
        _saveErrorMessage = err.message;
      });
    } catch (err, st) {
      debugPrint('QuizSheetPlayer save error: $err\n$st');
      if (!mounted) return;
      setState(() {
        _saveStatus = _AttemptSaveStatus.failed;
        _saveErrorMessage = err is StateError
            ? err.message
            : 'Salvataggio non riuscito. Riprova.';
      });
    }
  }

  bool get _allowsImmediatePop => allowsImmediateQuizSheetExit(_userAnswers);

  Future<bool> _confirmLeaveSheet() async {
    if (_allowsImmediatePop) {
      return true;
    }

    final leave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Uscire dalla scheda?'),
        content: const Text(
          'Hai risposto ad alcune domande ma non hai completato la scheda. '
          'Se esci ora, nessun risultato verrà salvato e la scheda resterà da svolgere.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Resta nella scheda'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Esci senza salvare'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  /// Uscita dal player senza salvataggio (dopo conferma se necessaria).
  Future<void> _leaveSheet() async {
    if (!await _confirmLeaveSheet()) {
      qfLog('QuizSheetPlayer: stay on sheet (exit cancelled)');
      return;
    }
    if (!mounted) return;
    qfLog('QuizSheetPlayer: exit without save');
    Navigator.of(context).pop();
  }

  void _openNextSheet() {
    if (!_hasNextSheet) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => QuizSheetDetailPage(
          lessonNumber: widget.lessonNumber,
          sheetNumber: widget.sheetNumber + 1,
          categoryId: widget.categoryId,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String title) {
    return AppBar(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      title: Text(title),
      centerTitle: true,
    );
  }

  String get _appBarTitle =>
      'Lezione ${widget.lessonNumber} · Scheda ${widget.sheetNumber} · ${widget.categoryName}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(_appBarTitle),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadFailed || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(_appBarTitle),
        body: AppEmptyState(
          title: 'Nessuna domanda disponibile',
          message: widget.categoryId == LicenseCategoryId.vela
              ? 'I contenuti quiz vela non sono ancora disponibili.'
              : 'Non ci sono domande per questa scheda al momento. '
                    'Riprova più tardi o contatta la scuola se il problema persiste.',
          icon: Icons.quiz_outlined,
          primaryActionLabel: 'Torna alle schede',
          primaryActionIcon: Icons.arrow_back_rounded,
          onPrimaryActionPressed: () => Navigator.maybePop(context),
        ),
      );
    }

    if (_showSummary) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar('Riepilogo scheda'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scheda completata',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              _SummaryStatRow(
                label: 'Domande totali',
                value: '${_questions.length}',
              ),
              _SummaryStatRow(
                label: 'Risposte corrette',
                value: '$_correctCount',
                valueColor: _correctColor,
              ),
              _SummaryStatRow(
                label: 'Errori',
                value: '$_wrongCount',
                valueColor: _wrongCount > 0 ? _wrongColor : _textPrimaryColor,
              ),
              if (_unansweredCount > 0)
                _SummaryStatRow(
                  label: 'Non risposte',
                  value: '$_unansweredCount',
                  valueColor: _unansweredColor,
                ),
              _SummaryStatRow(label: 'Percentuale', value: '$_percentCorrect%'),
              const SizedBox(height: 16),
              _AttemptSaveStatusCard(
                status: _saveStatus,
                errorMessage: _saveErrorMessage,
                onRetry: _saveStatus == _AttemptSaveStatus.failed
                    ? _saveAttempt
                    : null,
              ),
              const SizedBox(height: 24),
              if (_hasNextSheet)
                FilledButton.icon(
                  onPressed: _openNextSheet,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text('Prossima scheda (${widget.sheetNumber + 1})'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _neutralColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Hai completato l’ultima scheda di questa lezione.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Torna alle schede'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final question = _currentQuestion!;
    final selected = _selectedAnswer;
    final revealed = _isCurrentAnswered;

    return PopScope(
      canPop: _allowsImmediatePop,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          qfLog('QuizSheetPlayer: immediate exit (no answers selected)');
          return;
        }
        await _leaveSheet();
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: _buildAppBar(_appBarTitle),
        body: Column(
          children: [
            _QuizSheetProgressPanel(
              currentIndex: _currentIndex,
              total: _questions.length,
              correctCount: _correctCount,
              wrongCount: _wrongCount,
              unansweredCount: _unansweredCount,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, viewport) {
                  final compact =
                      viewport.maxWidth < 600 ||
                      MediaQuery.sizeOf(context).height < 640;
                  final cardPadding = compact ? 14.0 : 16.0;
                  final promptStyle = compact
                      ? textTheme.titleSmall
                      : textTheme.titleMedium;

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: EdgeInsets.all(cardPadding),
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
                              SizedBox(height: compact ? 8 : 10),
                              QuizQuestionImage(imagePath: question.imagePath),
                              Text(
                                question.prompt,
                                style: promptStyle?.copyWith(
                                  color: _textPrimaryColor,
                                  fontWeight: FontWeight.w700,
                                  height: compact ? 1.35 : 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...question.options.map(
                          (option) => Padding(
                            padding: EdgeInsets.only(bottom: compact ? 8 : 10),
                            child: _AnswerOptionTile(
                              letter: option.letter,
                              text: question.textForOption(option),
                              onTap: revealed
                                  ? null
                                  : () => _selectAnswer(option),
                              backgroundColor: _optionBackground(
                                option,
                                selected,
                                revealed,
                              ),
                              borderColor: _optionBorder(
                                option,
                                selected,
                                revealed,
                              ),
                              borderWidth: _optionBorderWidth(
                                option,
                                selected,
                                revealed,
                              ),
                              textColor: _textPrimaryColor,
                            ),
                          ),
                        ),
                        if (revealed) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(compact ? 12 : 14),
                            decoration: BoxDecoration(
                              color: selected == question.correctOption
                                  ? _correctBg
                                  : _wrongBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected == question.correctOption
                                    ? _correctColor
                                    : _wrongColor,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selected == question.correctOption
                                      ? 'Risposta corretta'
                                      : 'Risposta errata',
                                  style: textTheme.titleSmall?.copyWith(
                                    color: selected == question.correctOption
                                        ? _correctColor
                                        : _wrongColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: compact ? 15 : 16,
                                  ),
                                ),
                                if (selected != question.correctOption) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'La risposta corretta è ${question.correctOption.letter}.',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: _textPrimaryColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                if (question.explanation != null &&
                                    question.explanation!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    question.explanation!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: _textPrimaryColor.withValues(
                                        alpha: 0.9,
                                      ),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
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
                          _currentIndex + 1 >= _questions.length
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
      ),
    );
  }

  Color _optionBackground(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
  ) {
    if (!revealed) return _cardColor;
    final correct = _currentQuestion!.correctOption;
    if (option == correct) return _correctBg;
    if (option == selected) return _wrongBg;
    return _cardColor;
  }

  Color _optionBorder(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
  ) {
    if (!revealed) return _neutralColor;
    final correct = _currentQuestion!.correctOption;
    if (option == correct) return _correctColor;
    if (option == selected && option != correct) return _wrongColor;
    return _neutralColor;
  }

  double _optionBorderWidth(
    QuizAnswerOption option,
    QuizAnswerOption? selected,
    bool revealed,
  ) {
    if (!revealed) return 1.2;
    final correct = _currentQuestion!.correctOption;
    if (option == correct || option == selected) return 2.4;
    return 1.2;
  }
}

class _QuizSheetProgressPanel extends StatelessWidget {
  const _QuizSheetProgressPanel({
    required this.currentIndex,
    required this.total,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
  });

  final int currentIndex;
  final int total;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _correctColor = Color(0xFF15803D);
  static const Color _wrongColor = Color(0xFFD32F2F);
  static const Color _unansweredColor = Color(0xFF6B7280);

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
        border: Border.all(color: _neutralColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : (currentIndex + 1) / total,
                    minHeight: 7,
                    backgroundColor: _neutralColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${currentIndex + 1}/$total',
                style: textTheme.titleSmall?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _StatChip(
                label: 'Corrette',
                value: '$correctCount',
                color: _correctColor,
                background: const Color(0xFFDFF5E8),
              ),
              _StatChip(
                label: 'Errori',
                value: '$wrongCount',
                color: _wrongColor,
                background: const Color(0xFFFDE8E8),
              ),
              _StatChip(
                label: 'Non risposte',
                value: '$unansweredCount',
                color: _unansweredColor,
                background: const Color(0xFFF3F4F6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$label: $value',
        style: textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AnswerOptionTile extends StatelessWidget {
  const _AnswerOptionTile({
    required this.letter,
    required this.text,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.textColor,
  });

  final String letter;
  final String text;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Text(
                    letter,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _AttemptSaveStatus { idle, saving, saved, failed }

class _AttemptSaveStatusCard extends StatelessWidget {
  const _AttemptSaveStatusCard({
    required this.status,
    this.errorMessage,
    this.onRetry,
  });

  final _AttemptSaveStatus status;
  final String? errorMessage;
  final VoidCallback? onRetry;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _savedColor = Color(0xFF15803D);
  static const Color _wrongColor = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    late final IconData icon;
    late final String title;
    late final String message;
    late final Color accent;
    late final Color background;

    switch (status) {
      case _AttemptSaveStatus.idle:
      case _AttemptSaveStatus.saving:
        icon = Icons.cloud_upload_outlined;
        title = 'Salvataggio in corso';
        message = 'Stiamo registrando il risultato sul tuo account…';
        accent = _primaryColor;
        background = const Color(0xFFE8F4FA);
      case _AttemptSaveStatus.saved:
        icon = Icons.check_circle_outline_rounded;
        title = 'Risultato salvato';
        message =
            'Il tentativo è stato registrato. Potrai rivederlo nelle statistiche quando saranno disponibili.';
        accent = _savedColor;
        background = const Color(0xFFDFF5E8);
      case _AttemptSaveStatus.failed:
        icon = Icons.error_outline_rounded;
        title = 'Risultato non salvato';
        message =
            errorMessage ??
            'Non è stato possibile salvare il tentativo. Puoi riprovare.';
        accent = _wrongColor;
        background = const Color(0xFFFDE8E8);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (status == _AttemptSaveStatus.saving)
                const Padding(
                  padding: EdgeInsets.only(top: 2, right: 10),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(icon, color: accent),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: _textPrimaryColor.withValues(alpha: 0.9),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == _AttemptSaveStatus.failed && onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova salvataggio'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryStatRow extends StatelessWidget {
  const _SummaryStatRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _neutralColor = AppVisual.chipFill;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutralColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyLarge?.copyWith(color: _textPrimaryColor),
            ),
          ),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              color: valueColor ?? _textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
