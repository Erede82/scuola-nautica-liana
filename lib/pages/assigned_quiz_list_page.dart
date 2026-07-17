import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../models/assigned_quiz_models.dart';
import '../repositories/assigned_quiz_repository.dart';
import '../services/student_area_context.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/backoffice/assigned_quiz_staff_labels.dart';
import '../widgets/branded_app_bar_title.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import 'assigned_quiz_player_page.dart';
import 'assigned_quiz_review_page.dart';

/// Lista studente dei quiz assegnati dalla scuola.
class AssignedQuizListPage extends StatefulWidget {
  const AssignedQuizListPage({super.key, this.repository});

  final AssignedQuizRepository? repository;

  @override
  State<AssignedQuizListPage> createState() => AssignedQuizListPageState();
}

@visibleForTesting
class AssignedQuizListPageState extends State<AssignedQuizListPage> {
  late final AssignedQuizRepository _repository;
  bool _loading = true;
  String? _error;
  List<AssignedQuizSummary> _items = const [];
  final Set<String> _startingIds = {};
  final Map<String, _AttemptsState> _attempts = {};
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? assignedQuizRepository;
    _reload();
  }

  Future<void> _reload() async {
    final gen = ++_loadGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.loadMine();
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _items = items;
        _loading = false;
        _attempts.clear();
      });
    } catch (error) {
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _error = assignedQuizExceptionFrom(error).message;
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  bool _isExpired(AssignedQuizSummary item) =>
      AssignedQuizStaffLabels.isExpired(item.expiresAt);

  bool _limitReached(AssignedQuizSummary item) {
    if (item.repeatPolicy != AssignedQuizRepeatPolicy.limited) return false;
    final max = item.maxAttempts;
    final used = item.submittedAttemptsCount;
    if (max == null || used == null) return false;
    final inProgress = item.hasInProgressAttempt == true;
    return used >= max && !inProgress;
  }

  String _primaryCtaLabel(AssignedQuizSummary item) {
    if (_isExpired(item)) return 'Scaduto';
    if (_limitReached(item)) return 'Tentativi terminati';
    if (item.hasInProgressAttempt == true) return 'Riprendi quiz';
    return 'Inizia quiz';
  }

  bool _canStart(AssignedQuizSummary item) {
    if (_isExpired(item) || _limitReached(item)) return false;
    if (StudentAreaContext.blocksWrites(context)) return false;
    // Con repository di produzione non configurato: nessuna azione reale.
    if (!SupabaseConfig.isConfigured && widget.repository == null) return false;
    return true;
  }

  Future<void> _startOrResume(AssignedQuizSummary item) async {
    if (!_canStart(item) || _startingIds.contains(item.id)) return;
    setState(() => _startingIds.add(item.id));
    try {
      final start = await _repository.startOrResume(item.id);
      final questions = await _repository.loadAttemptQuestions(start.attemptId);
      if (!mounted) return;
      if (start.resumed) {
        _snack('Riprendiamo il tentativo dal punto in cui eri rimasto.');
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AssignedQuizPlayerPage(
            repository: _repository,
            assignment: item,
            start: start,
            questions: questions,
          ),
        ),
      );
      if (mounted) await _reload();
    } catch (error) {
      if (!mounted) return;
      _snack(assignedQuizExceptionFrom(error).message);
    } finally {
      if (mounted) {
        setState(() => _startingIds.remove(item.id));
      }
    }
  }

  Future<void> _toggleAttempts(AssignedQuizSummary item) async {
    final current = _attempts[item.id];
    if (current != null && current.expanded) {
      setState(() {
        _attempts[item.id] = current.copyWith(expanded: false);
      });
      return;
    }
    setState(() {
      _attempts[item.id] = const _AttemptsState(expanded: true, loading: true);
    });
    try {
      final list = await _repository.loadAttempts(item.id);
      if (!mounted) return;
      setState(() {
        _attempts[item.id] = _AttemptsState(
          expanded: true,
          loading: false,
          items: list,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _attempts[item.id] = _AttemptsState(
          expanded: true,
          loading: false,
          error: assignedQuizExceptionFrom(error).message,
        );
      });
    }
  }

  Future<void> _openReview(
    AssignedQuizSummary assignment,
    AssignedQuizAttemptSummary attempt,
  ) async {
    if (attempt.status != AssignedQuizAttemptStatus.submitted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AssignedQuizReviewPage(
          repository: _repository,
          attemptId: attempt.id,
          assignmentTitle: assignment.title,
          publicCode: assignment.publicCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Con Fake/repo iniettato (test) non mostrare lo stato “non collegato”.
    final unconfigured =
        !SupabaseConfig.isConfigured && widget.repository == null;

    return Scaffold(
      backgroundColor: AppVisual.canvas,
      appBar: AppBar(
        backgroundColor: AppVisual.logoBlue,
        foregroundColor: Colors.white,
        title: const SectionAppBarTitle(
          'Quiz assegnati dalla scuola',
          logoHeight: 28,
        ),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const StaffPreviewAppBarBadge(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Esercitazioni personalizzate preparate dalla scuola '
              'in base ai tuoi errori.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppVisual.inkMuted,
                height: 1.35,
              ),
            ),
            if (unconfigured) ...[
              const SizedBox(height: 16),
              Text(
                'Connessione non disponibile. I quiz assegnati compariranno '
                'quando l’app è collegata alla scuola.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppVisual.inkMuted,
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppVisual.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Riprova'),
                  ),
                ],
              )
            else if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Text(
                      'Nessun quiz assegnato',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quando la scuola preparerà un’esercitazione '
                      'personalizzata, la troverai qui.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppVisual.inkMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._items.map((item) {
                final attempts = _attempts[item.id];
                final busy = _startingIds.contains(item.id);
                final cta = _primaryCtaLabel(item);
                final canStart = _canStart(item);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AssignmentCard(
                    item: item,
                    expired: _isExpired(item),
                    ctaLabel: cta,
                    canStart: canStart && !busy,
                    busy: busy,
                    attempts: attempts,
                    onStart: () => _startOrResume(item),
                    onToggleAttempts: () => _toggleAttempts(item),
                    onResumeAttempt: (attempt) => _startOrResume(item),
                    onOpenReview: (attempt) => _openReview(item, attempt),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _AttemptsState {
  const _AttemptsState({
    required this.expanded,
    this.loading = false,
    this.items = const [],
    this.error,
  });

  final bool expanded;
  final bool loading;
  final List<AssignedQuizAttemptSummary> items;
  final String? error;

  _AttemptsState copyWith({
    bool? expanded,
    bool? loading,
    List<AssignedQuizAttemptSummary>? items,
    String? error,
  }) {
    return _AttemptsState(
      expanded: expanded ?? this.expanded,
      loading: loading ?? this.loading,
      items: items ?? this.items,
      error: error,
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.item,
    required this.expired,
    required this.ctaLabel,
    required this.canStart,
    required this.busy,
    required this.attempts,
    required this.onStart,
    required this.onToggleAttempts,
    required this.onResumeAttempt,
    required this.onOpenReview,
  });

  final AssignedQuizSummary item;
  final bool expired;
  final String ctaLabel;
  final bool canStart;
  final bool busy;
  final _AttemptsState? attempts;
  final VoidCallback onStart;
  final VoidCallback onToggleAttempts;
  final ValueChanged<AssignedQuizAttemptSummary> onResumeAttempt;
  final ValueChanged<AssignedQuizAttemptSummary> onOpenReview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppVisual.ivory,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppVisual.chipFill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              _Chip(
                label: AssignedQuizStaffLabels.categoryBadge(
                  item.licenseCategory,
                ),
              ),
              if (expired)
                const _Chip(
                  label: 'Scaduto',
                  foreground: AppVisual.error,
                  background: Color(0xFFFDECEC),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.publicCode,
            style: textTheme.bodySmall?.copyWith(
              color: AppVisual.logoBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${item.questionCount} domande · '
            '${AssignedQuizStaffLabels.repeatPolicy(item.repeatPolicy, item.maxAttempts)}',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (item.assignedAt != null)
                'Assegnato: ${AssignedQuizStaffLabels.formatDate(item.assignedAt)}',
              if (item.expiresAt != null)
                'Scade: ${AssignedQuizStaffLabels.formatDate(item.expiresAt)}',
            ].join(' · '),
            style: textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
          ),
          if (item.attemptsCount != null ||
              item.bestScorePercentage != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (item.attemptsCount != null)
                  'Tentativi: ${item.attemptsCount}',
                if (item.bestScorePercentage != null)
                  'Miglior punteggio: ${item.bestScorePercentage!.toStringAsFixed(0)}%',
              ].join(' · '),
              style: textTheme.bodySmall,
            ),
          ],
          if (expired) ...[
            const SizedBox(height: 8),
            Text(
              'Questo quiz è scaduto. Puoi consultare i tentativi già conclusi.',
              style: textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: canStart ? onStart : null,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(ctaLabel),
              ),
              TextButton(
                onPressed: onToggleAttempts,
                child: Text(
                  attempts?.expanded == true
                      ? 'Nascondi tentativi'
                      : 'Vedi tentativi',
                ),
              ),
            ],
          ),
          if (attempts?.expanded == true) ...[
            const SizedBox(height: 10),
            _AttemptsBlock(
              state: attempts!,
              onResume: onResumeAttempt,
              onReview: onOpenReview,
            ),
          ],
        ],
      ),
    );
  }
}

class _AttemptsBlock extends StatelessWidget {
  const _AttemptsBlock({
    required this.state,
    required this.onResume,
    required this.onReview,
  });

  final _AttemptsState state;
  final ValueChanged<AssignedQuizAttemptSummary> onResume;
  final ValueChanged<AssignedQuizAttemptSummary> onReview;

  String _statusLabel(AssignedQuizAttemptStatus status) {
    switch (status) {
      case AssignedQuizAttemptStatus.inProgress:
        return 'In corso';
      case AssignedQuizAttemptStatus.submitted:
        return 'Completato';
      case AssignedQuizAttemptStatus.abandoned:
        return 'Abbandonato';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (state.error != null) {
      return Text(
        state.error!,
        style: textTheme.bodySmall?.copyWith(color: AppVisual.error),
      );
    }
    if (state.items.isEmpty) {
      return Text('Nessun tentativo.', style: textTheme.bodySmall);
    }

    return Column(
      children: state.items
          .map((a) {
            final submitted = a.status == AssignedQuizAttemptStatus.submitted;
            final inProgress = a.status == AssignedQuizAttemptStatus.inProgress;
            final score = submitted && a.scorePercentage != null
                ? '${a.scorePercentage!.toStringAsFixed(0)}%'
                : (inProgress ? '—' : '—');
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Tentativo ${a.attemptNumber} · ${_statusLabel(a.status)}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Inizio: ${AssignedQuizStaffLabels.formatDateTime(a.startedAt)}'
                '${a.submittedAt != null ? ' · Invio: ${AssignedQuizStaffLabels.formatDateTime(a.submittedAt)}' : ''}'
                '${submitted ? ' · Corrette ${a.correctCount}, errate ${a.wrongCount}, non risposte ${a.unansweredCount}' : ''}'
                ' · Punteggio $score'
                ' · Durata ${AssignedQuizStaffLabels.formatDuration(a.durationSeconds)}',
                style: textTheme.bodySmall,
              ),
              trailing: submitted
                  ? TextButton(
                      onPressed: () => onReview(a),
                      child: const Text('Rivedi'),
                    )
                  : inProgress
                  ? TextButton(
                      onPressed: () => onResume(a),
                      child: const Text('Riprendi'),
                    )
                  : null,
            );
          })
          .toList(growable: false),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    this.foreground = AppVisual.logoBlue,
    this.background = const Color(0xFFE8F4FA),
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
