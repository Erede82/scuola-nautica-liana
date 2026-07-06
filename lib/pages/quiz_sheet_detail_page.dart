import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../models/license_models.dart';
import '../models/quiz_question.dart';
import '../repositories/student_quiz_repository.dart';
import '../repositories/study_access_repository.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/quiz_question_image.dart';
import '../theme/app_visual_tokens.dart';

/// Dettaglio scheda quiz per lezione — domande reali da `questions` (read-only).
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
  static const Color _correctColor = Color(0xFF2E9E5B);
  static const Color _wrongColor = Color(0xFFC62828);

  List<QuizQuestion> _questions = const [];
  List<QuizAnswerOption?> _userAnswers = const [];
  bool _loading = true;
  bool _loadFailed = false;
  int _currentIndex = 0;
  bool _revealed = false;
  bool _showSummary = false;

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
      _revealed = false;
    });

    try {
      final loaded = await studentQuizRepository.fetchLessonSheetQuestions(
        categoryId: widget.categoryId,
        lessonNumber: widget.lessonNumber,
        sheetNumber: widget.sheetNumber,
      );
      if (!mounted) return;
      setState(() {
        _questions = loaded;
        _userAnswers = List<QuizAnswerOption?>.filled(loaded.length, null);
        _loading = false;
      });
    } catch (err, st) {
      debugPrint('QuizSheetPlayer load error: $err\n$st');
      if (!mounted) return;
      setState(() {
        _questions = const [];
        _userAnswers = const [];
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _retrySheet() {
    if (_questions.isEmpty) {
      _loadQuestions();
      return;
    }
    setState(() {
      _showSummary = false;
      _currentIndex = 0;
      _revealed = false;
      _userAnswers = List<QuizAnswerOption?>.filled(_questions.length, null);
    });
  }

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

  void _selectAnswer(QuizAnswerOption option) {
    if (_revealed || _showSummary) return;
    setState(() {
      _userAnswers[_currentIndex] = option;
      _revealed = true;
    });
  }

  void _goNext() {
    if (!_revealed) return;
    if (_currentIndex + 1 >= _questions.length) {
      setState(() => _showSummary = true);
      return;
    }
    setState(() {
      _currentIndex++;
      _revealed = _userAnswers[_currentIndex] != null;
    });
  }

  int get _correctCount {
    var n = 0;
    for (var i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] == _questions[i].correctOption) n++;
    }
    return n;
  }

  int get _errorCount => _questions.length - _correctCount;

  int get _percentCorrect {
    if (_questions.isEmpty) return 0;
    return ((_correctCount / _questions.length) * 100).round();
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
                value: '$_errorCount',
                valueColor: _errorCount > 0 ? _wrongColor : _textPrimaryColor,
              ),
              _SummaryStatRow(label: 'Percentuale', value: '$_percentCorrect%'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _retrySheet,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Riprova scheda'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(_appBarTitle),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / _questions.length,
                      minHeight: 6,
                      backgroundColor: _neutralColor,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        _primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_currentIndex + 1}/${_questions.length}',
                  style: textTheme.labelLarge?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
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
                        const SizedBox(height: 10),
                        QuizQuestionImage(imagePath: question.imagePath),
                        Text(
                          question.prompt,
                          style: textTheme.titleMedium?.copyWith(
                            color: _textPrimaryColor,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...question.options.map(
                    (option) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AnswerOptionTile(
                        letter: option.letter,
                        text: question.textForOption(option),
                        onTap: _revealed ? null : () => _selectAnswer(option),
                        backgroundColor: _optionBackground(option, selected),
                        borderColor: _optionBorder(option, selected),
                        textColor: _textPrimaryColor,
                      ),
                    ),
                  ),
                  if (_revealed) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected == question.correctOption
                            ? _correctColor.withValues(alpha: 0.12)
                            : _wrongColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected == question.correctOption
                              ? _correctColor.withValues(alpha: 0.45)
                              : _wrongColor.withValues(alpha: 0.35),
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
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (selected != question.correctOption) ...[
                            const SizedBox(height: 6),
                            Text(
                              'La risposta corretta è ${question.correctOption.letter}.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: _textPrimaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (question.explanation != null &&
                              question.explanation!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              question.explanation!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: _textPrimaryColor.withValues(alpha: 0.9),
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
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _revealed ? _goNext : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primaryColor.withValues(
                      alpha: 0.35,
                    ),
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
            ),
          ),
        ],
      ),
    );
  }

  Color _optionBackground(QuizAnswerOption option, QuizAnswerOption? selected) {
    if (!_revealed) return _cardColor;
    final correct = _currentQuestion!.correctOption;
    if (option == correct) {
      return _correctColor.withValues(alpha: 0.14);
    }
    if (option == selected) {
      return _wrongColor.withValues(alpha: 0.12);
    }
    return _cardColor;
  }

  Color _optionBorder(QuizAnswerOption option, QuizAnswerOption? selected) {
    if (!_revealed) return _neutralColor;
    final correct = _currentQuestion!.correctOption;
    if (option == correct) return _correctColor;
    if (option == selected && option != correct) return _wrongColor;
    return _neutralColor;
  }
}

class _AnswerOptionTile extends StatelessWidget {
  const _AnswerOptionTile({
    required this.letter,
    required this.text,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String letter;
  final String text;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
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
            border: Border.all(color: borderColor, width: 1.2),
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
                    color: borderColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    letter,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
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
