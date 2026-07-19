import 'package:flutter/material.dart';

import '../data/supabase/mappers/assigned_quiz_mapper.dart';
import '../models/assigned_quiz_models.dart';
import '../models/quiz_question.dart';
import '../repositories/assigned_quiz_repository.dart';
import '../services/student_area_context.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/branded_app_bar_title.dart';
import '../widgets/nautical_answer_marker.dart';
import '../widgets/quiz_question_prompt_panel.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import 'assigned_quiz_result_page.dart';

enum _SaveUiStatus { idle, saving, saved, error }

/// Player sicuro per un tentativo di quiz assegnato.
class AssignedQuizPlayerPage extends StatefulWidget {
  const AssignedQuizPlayerPage({
    super.key,
    required this.repository,
    required this.assignment,
    required this.start,
    required this.questions,
  });

  final AssignedQuizRepository repository;
  final AssignedQuizSummary assignment;
  final AssignedQuizAttemptStartResult start;
  final List<AssignedQuizQuestion> questions;

  @override
  State<AssignedQuizPlayerPage> createState() => AssignedQuizPlayerPageState();
}

@visibleForTesting
class AssignedQuizPlayerPageState extends State<AssignedQuizPlayerPage> {
  late List<AssignedQuizQuestion> _questions;
  late final Map<String, String?> _answers;
  late final Map<String, _SaveUiStatus> _saveStatus;
  late final Map<String, int> _saveGeneration;
  int _index = 0;
  bool _submitting = false;
  bool _abandoning = false;
  String? _globalError;

  @override
  void initState() {
    super.initState();
    _questions = List<AssignedQuizQuestion>.from(widget.questions)
      ..sort((a, b) => a.position.compareTo(b.position));
    _answers = {
      for (final q in _questions) q.assignmentItemId: q.selectedOption,
    };
    _saveStatus = {
      for (final q in _questions) q.assignmentItemId: _SaveUiStatus.idle,
    };
    _saveGeneration = {for (final q in _questions) q.assignmentItemId: 0};
  }

  AssignedQuizQuestion get _current => _questions[_index];

  bool get _hasPendingSaves =>
      _saveStatus.values.any((s) => s == _SaveUiStatus.saving);

  bool get _hasSaveErrors =>
      _saveStatus.values.any((s) => s == _SaveUiStatus.error);

  int get _unansweredCount =>
      _questions.where((q) => _answers[q.assignmentItemId] == null).length;

  String get _saveBanner {
    final current =
        _saveStatus[_current.assignmentItemId] ?? _SaveUiStatus.idle;
    switch (current) {
      case _SaveUiStatus.saving:
        return 'Salvataggio…';
      case _SaveUiStatus.saved:
        return 'Salvato';
      case _SaveUiStatus.error:
        return 'Errore di salvataggio';
      case _SaveUiStatus.idle:
        return _answers[_current.assignmentItemId] == null
            ? 'Nessuna risposta'
            : 'Pronto';
    }
  }

  Future<void> _selectOption(QuizAnswerOption option) async {
    if (_submitting || _abandoning) return;
    if (StudentAreaContext.blocksWrites(context)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(StudentAreaPreviewCopy.quizSaveBlockedMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final itemId = _current.assignmentItemId;
    final letter = option.letter;
    final gen = (_saveGeneration[itemId] ?? 0) + 1;
    _saveGeneration[itemId] = gen;

    setState(() {
      _answers[itemId] = letter;
      _saveStatus[itemId] = _SaveUiStatus.saving;
      _globalError = null;
    });

    try {
      await widget.repository.saveAnswer(
        attemptId: widget.start.attemptId,
        assignmentItemId: itemId,
        selectedOption: letter,
      );
      if (!mounted || _saveGeneration[itemId] != gen) return;
      setState(() => _saveStatus[itemId] = _SaveUiStatus.saved);
    } catch (error) {
      if (!mounted || _saveGeneration[itemId] != gen) return;
      setState(() {
        _saveStatus[itemId] = _SaveUiStatus.error;
        _globalError = assignedQuizExceptionFrom(error).message;
      });
    }
  }

  Future<void> _clearAnswer() async {
    if (_submitting || _abandoning) return;
    if (StudentAreaContext.blocksWrites(context)) return;
    final itemId = _current.assignmentItemId;
    if (_answers[itemId] == null) return;
    final gen = (_saveGeneration[itemId] ?? 0) + 1;
    _saveGeneration[itemId] = gen;
    setState(() {
      _answers[itemId] = null;
      _saveStatus[itemId] = _SaveUiStatus.saving;
    });
    try {
      await widget.repository.saveAnswer(
        attemptId: widget.start.attemptId,
        assignmentItemId: itemId,
        selectedOption: null,
      );
      if (!mounted || _saveGeneration[itemId] != gen) return;
      setState(() => _saveStatus[itemId] = _SaveUiStatus.saved);
    } catch (error) {
      if (!mounted || _saveGeneration[itemId] != gen) return;
      setState(() {
        _saveStatus[itemId] = _SaveUiStatus.error;
        _globalError = assignedQuizExceptionFrom(error).message;
      });
    }
  }

  Future<bool> _awaitPendingSaves() async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (_hasPendingSaves && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return false;
    }
    return !_hasPendingSaves && !_hasSaveErrors;
  }

  Future<void> _submit() async {
    if (_submitting || _abandoning) return;
    if (StudentAreaContext.blocksWrites(context)) return;

    final ready = await _awaitPendingSaves();
    if (!mounted) return;
    if (!ready) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            _hasSaveErrors
                ? 'Alcune risposte non sono sincronizzate. Riprova a salvare.'
                : 'Attendi il salvataggio delle risposte.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final unanswered = _unansweredCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Consegna quiz'),
        content: Text(
          unanswered > 0
              ? 'Hai lasciato $unanswered domande senza risposta. '
                    'Vuoi consegnare comunque?'
              : 'Vuoi consegnare il quiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Consegna'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final result = await widget.repository.submitAttempt(
        widget.start.attemptId,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AssignedQuizResultPage(
            repository: widget.repository,
            assignment: widget.assignment,
            result: result,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _globalError = assignedQuizExceptionFrom(error).message;
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(assignedQuizExceptionFrom(error).message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _abandon() async {
    if (_submitting || _abandoning) return;
    final first = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abbandona tentativo'),
        content: const Text(
          'Il tentativo verrà chiuso come abbandonato e potrà essere '
          'conteggiato nel limite disponibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppVisual.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abbandona'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;

    final second = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma abbandono'),
        content: const Text(
          'Confermi di voler abbandonare definitivamente questo tentativo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppVisual.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sì, abbandona'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;

    setState(() => _abandoning = true);
    try {
      await widget.repository.abandonAttempt(widget.start.attemptId);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _abandoning = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(assignedQuizExceptionFrom(error).message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (_submitting || _abandoning) return false;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Esci dal quiz'),
        content: const Text(
          'Puoi riprendere più tardi: le risposte già salvate restano '
          'disponibili. Oppure abbandona il tentativo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continua quiz'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'exit'),
            child: const Text('Esci e riprendi più tardi'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppVisual.error),
            onPressed: () => Navigator.pop(ctx, 'abandon'),
            child: const Text('Abbandona tentativo'),
          ),
        ],
      ),
    );
    if (choice == 'exit') return true;
    if (choice == 'abandon') {
      await _abandon();
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = _questions.length;
    final selectedLetter = _answers[_current.assignmentItemId];
    final selected = QuizAnswerOptionX.tryParse(selectedLetter);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _onWillPop();
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppVisual.canvas,
        appBar: AppBar(
          backgroundColor: AppVisual.logoBlue,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: 'Esci dal quiz',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final leave = await _onWillPop();
              if (leave && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: SectionAppBarTitle(widget.assignment.title, logoHeight: 26),
          actions: const [StaffPreviewAppBarBadge()],
        ),
        // Layout allineato al player schede lezione (`quiz_sheet_detail_page`):
        // larghezza piena della viewport, padding orizzontale 16/12, senza maxWidth.
        body: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, viewport) {
                  final compact =
                      viewport.maxWidth < 600 ||
                      MediaQuery.sizeOf(context).height < 640;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          key: const Key('assigned_quiz_player_meta'),
                          '${widget.assignment.publicCode} · Tentativo '
                          '${widget.start.attemptNumber} · '
                          'Domanda ${_index + 1}/$total · $_saveBanner',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppVisual.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_globalError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _globalError!,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppVisual.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _ProgressWrap(
                          currentIndex: _index,
                          total: total,
                          isAnswered: (i) =>
                              _answers[_questions[i].assignmentItemId] != null,
                          onTap: (i) => setState(() => _index = i),
                        ),
                        const SizedBox(height: 10),
                        KeyedSubtree(
                          key: const Key('assigned_quiz_player_prompt'),
                          child: QuizQuestionPromptPanel(
                            questionNumber: _index + 1,
                            prompt: _current.prompt,
                            imagePath: _current.imagePath,
                            compact: compact,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final option in QuizAnswerOption.values)
                          Padding(
                            padding: EdgeInsets.only(bottom: compact ? 8 : 10),
                            child: KeyedSubtree(
                              key: Key(
                                'assigned_quiz_player_option_${option.letter}',
                              ),
                              child: _OptionTile(
                                number: assignedQuizOptionToMarkerNumber(
                                  option,
                                ),
                                text: switch (option) {
                                  QuizAnswerOption.a => _current.optionA,
                                  QuizAnswerOption.b => _current.optionB,
                                  QuizAnswerOption.c => _current.optionC,
                                },
                                selected: selected == option,
                                enabled: !_submitting && !_abandoning,
                                compact: compact,
                                onTap: () => _selectOption(option),
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed:
                                selected == null || _submitting || _abandoning
                                ? null
                                : _clearAnswer,
                            child: const Text('Cancella risposta'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                key: const Key('assigned_quiz_player_nav'),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final narrow = c.maxWidth < 420;
                    final prev = OutlinedButton(
                      onPressed: _index == 0 || _submitting
                          ? null
                          : () => setState(() => _index -= 1),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Precedente'),
                    );
                    final nextOrSubmit = _index >= total - 1
                        ? FilledButton(
                            onPressed: _submitting || _abandoning
                                ? null
                                : _submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              _submitting ? 'Consegna…' : 'Concludi quiz',
                            ),
                          )
                        : FilledButton(
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _index += 1),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Successiva'),
                          );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          prev,
                          const SizedBox(height: 8),
                          nextOrSubmit,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: prev),
                        const SizedBox(width: 10),
                        Expanded(child: nextOrSubmit),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressWrap extends StatelessWidget {
  const _ProgressWrap({
    required this.currentIndex,
    required this.total,
    required this.isAnswered,
    required this.onTap,
  });

  final int currentIndex;
  final int total;
  final bool Function(int index) isAnswered;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progresso domande',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(total, (index) {
            final answered = isAnswered(index);
            final current = index == currentIndex;
            return Semantics(
              button: true,
              selected: current,
              label:
                  'Domanda ${index + 1}${answered ? ', risposta' : ', senza risposta'}',
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: answered
                        ? AppVisual.logoBlue
                        : const Color(0xFFF3E8D8),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: current
                          ? const Color(0xFF0B4F78)
                          : Colors.transparent,
                      width: current ? 2 : 0,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.number,
    required this.text,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final int number;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Risposta $number: $text',
      child: Material(
        color: selected ? const Color(0xFFE8F4FA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 52 : 56),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
              vertical: compact ? 10 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppVisual.logoBlue : AppVisual.chipFill,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                NauticalAnswerMarker(
                  answerNumber: number,
                  state: selected
                      ? NauticalAnswerMarkerState.selected
                      : NauticalAnswerMarkerState.neutral,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
