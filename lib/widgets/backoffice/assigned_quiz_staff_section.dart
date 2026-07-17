import 'package:flutter/material.dart';

import '../../domain/quiz_license_category.dart';
import '../../models/assigned_quiz_models.dart';
import '../../models/license_models.dart';
import '../../repositories/assigned_quiz_repository.dart';
import '../../theme/app_visual_tokens.dart';
import 'assigned_quiz_staff_dialogs.dart';
import 'assigned_quiz_staff_labels.dart';
import 'backoffice_ui_tokens.dart';

/// Sezione Studio — Quiz assegnati dalla scuola (staff Scheda 360).
class AssignedQuizStaffSection extends StatefulWidget {
  const AssignedQuizStaffSection({
    super.key,
    required this.studentId,
    required this.studentDisplayName,
    required this.licenseCategoryId,
    this.repository,
    this.isStaffPreview = false,
  });

  final String studentId;
  final String studentDisplayName;
  final LicenseCategoryId licenseCategoryId;

  /// Se null usa [assignedQuizRepository].
  final AssignedQuizRepository? repository;

  /// Preview dimostrativa: nessun fetch né mutazioni reali.
  final bool isStaffPreview;

  @override
  State<AssignedQuizStaffSection> createState() =>
      AssignedQuizStaffSectionState();
}

@visibleForTesting
class AssignedQuizStaffSectionState extends State<AssignedQuizStaffSection> {
  late AssignedQuizRepository _repository;

  bool _loading = true;
  String? _error;
  List<AssignedQuizSummary> _items = const [];
  final Set<String> _busyAssignmentIds = {};
  final Map<String, _AttemptsPanelState> _attemptsByAssignment = {};
  int _loadGeneration = 0;

  bool get generationSupported =>
      dbLicenseCategoryFor(widget.licenseCategoryId) != null;

  AssignedQuizRepository _resolveRepository() {
    if (widget.isStaffPreview) {
      return widget.repository ?? const AssignedQuizRepositoryEmpty();
    }
    return widget.repository ?? assignedQuizRepository;
  }

  void _enterPreviewState() {
    _loadGeneration += 1;
    _attemptsByAssignment.clear();
    _busyAssignmentIds.clear();
    _loading = false;
    _error = null;
    _items = _previewDemoItems(widget.studentId);
  }

  @override
  void initState() {
    super.initState();
    _repository = _resolveRepository();
    if (widget.isStaffPreview) {
      _enterPreviewState();
    } else {
      _reload();
    }
  }

  @override
  void didUpdateWidget(covariant AssignedQuizStaffSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _repository = _resolveRepository();
    final modeChanged = oldWidget.isStaffPreview != widget.isStaffPreview;
    final studentChanged = oldWidget.studentId != widget.studentId;
    if (!modeChanged && !studentChanged) return;

    if (widget.isStaffPreview) {
      setState(_enterPreviewState);
      return;
    }

    // Reale: invalida fetch precedenti e ricarica per il studentId corrente.
    _attemptsByAssignment.clear();
    _busyAssignmentIds.clear();
    _reload();
  }

  Future<void> _reload() async {
    if (widget.isStaffPreview) return;
    final generation = ++_loadGeneration;
    final studentId = widget.studentId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.loadForStudent(studentId);
      if (!mounted ||
          generation != _loadGeneration ||
          widget.isStaffPreview ||
          widget.studentId != studentId) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _loadGeneration ||
          widget.isStaffPreview ||
          widget.studentId != studentId) {
        return;
      }
      final mapped = assignedQuizExceptionFrom(error);
      setState(() {
        _error = mapped.message;
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openGenerate() async {
    if (widget.isStaffPreview) return;
    final result = await showAssignedQuizGenerateDialog(
      context,
      studentId: widget.studentId,
      studentDisplayName: widget.studentDisplayName,
      licenseCategoryId: widget.licenseCategoryId,
      repository: _repository,
    );
    if (result == null || !mounted) return;
    _snack(AssignedQuizStaffLabels.generationSuccessSnack(result));
    await _reload();
  }

  Future<void> _edit(AssignedQuizSummary item) async {
    if (widget.isStaffPreview) return;
    final ok = await showAssignedQuizEditMetadataDialog(
      context,
      assignment: item,
      repository: _repository,
    );
    if (ok && mounted) await _reload();
  }

  Future<void> _publishDraft(AssignedQuizSummary item) async {
    if (widget.isStaffPreview) return;
    final confirmed = await confirmAssignedQuizPublish(context);
    if (!confirmed || !mounted) return;
    setState(() => _busyAssignmentIds.add(item.id));
    try {
      await _repository.publishDraft(item.id);
      if (!mounted) return;
      _snack('Quiz assegnato all’allievo.');
      await _reload();
    } catch (error) {
      if (!mounted) return;
      _snack(assignedQuizExceptionFrom(error).message);
    } finally {
      if (mounted) {
        setState(() => _busyAssignmentIds.remove(item.id));
      }
    }
  }

  Future<void> _archive(AssignedQuizSummary item) async {
    if (widget.isStaffPreview) return;
    final confirmed = await confirmAssignedQuizArchive(context);
    if (!confirmed || !mounted) return;
    setState(() => _busyAssignmentIds.add(item.id));
    try {
      await _repository.archiveAssignment(item.id);
      if (!mounted) return;
      _snack('Quiz archiviato.');
      await _reload();
    } catch (error) {
      if (!mounted) return;
      _snack(assignedQuizExceptionFrom(error).message);
    } finally {
      if (mounted) {
        setState(() => _busyAssignmentIds.remove(item.id));
      }
    }
  }

  Future<void> _deleteDraft(AssignedQuizSummary item) async {
    if (widget.isStaffPreview) return;
    final confirmed = await confirmAssignedQuizDeleteDraft(context);
    if (!confirmed || !mounted) return;
    setState(() => _busyAssignmentIds.add(item.id));
    try {
      await _repository.deleteDraft(item.id);
      if (!mounted) return;
      _snack('Bozza eliminata.');
      await _reload();
    } catch (error) {
      if (!mounted) return;
      _snack(assignedQuizExceptionFrom(error).message);
    } finally {
      if (mounted) {
        setState(() => _busyAssignmentIds.remove(item.id));
      }
    }
  }

  Future<void> _toggleAttempts(AssignedQuizSummary item) async {
    if (widget.isStaffPreview) return;

    final current = _attemptsByAssignment[item.id];
    if (current != null && current.expanded) {
      setState(() {
        _attemptsByAssignment[item.id] = current.copyWith(expanded: false);
      });
      return;
    }

    setState(() {
      _attemptsByAssignment[item.id] = const _AttemptsPanelState(
        expanded: true,
        loading: true,
      );
    });

    try {
      final attempts = await _repository.loadAttempts(item.id);
      if (!mounted) return;
      setState(() {
        _attemptsByAssignment[item.id] = _AttemptsPanelState(
          expanded: true,
          loading: false,
          items: attempts,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _attemptsByAssignment[item.id] = _AttemptsPanelState(
          expanded: true,
          loading: false,
          error: assignedQuizExceptionFrom(error).message,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).width < 720;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppVisual.ivory,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: AppVisual.chipFill),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiz assegnati dalla scuola',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppVisual.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: compact ? 15 : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crea esercitazioni personalizzate utilizzando le domande '
                      'sbagliate più frequentemente dall’allievo.',
                      style: textTheme.bodySmall?.copyWith(
                        color: BackofficeUiTokens.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isStaffPreview)
                IconButton(
                  tooltip: 'Aggiorna lista',
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  foregroundColor: BackofficeUiTokens.primary,
                ),
                onPressed: (_loading || widget.isStaffPreview)
                    ? null
                    : _openGenerate,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Genera quiz dagli errori'),
              ),
              if (!generationSupported && !widget.isStaffPreview)
                Text(
                  'Funzione non disponibile per questo percorso',
                  style: textTheme.bodySmall?.copyWith(
                    color: BackofficeUiTokens.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (widget.isStaffPreview) ...[
            const SizedBox(height: 12),
            Text(
              'Anteprima dimostrativa Backoffice: nessun dato reale, '
              'nessuna operazione disponibile.',
              style: textTheme.bodySmall?.copyWith(
                color: BackofficeUiTokens.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: BackofficeUiTokens.error,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            )
          else if (_items.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nessun quiz personalizzato assegnato.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: (!widget.isStaffPreview && generationSupported)
                      ? _openGenerate
                      : null,
                  child: const Text('Genera il primo quiz'),
                ),
              ],
            )
          else
            Column(
              children: [
                for (final item in _items) ...[
                  _AssignedQuizCard(
                    item: item,
                    busy: _busyAssignmentIds.contains(item.id),
                    attempts: _attemptsByAssignment[item.id],
                    readOnly: widget.isStaffPreview,
                    onEdit: () => _edit(item),
                    onPublish: () => _publishDraft(item),
                    onArchive: () => _archive(item),
                    onDeleteDraft: () => _deleteDraft(item),
                    onToggleAttempts: () => _toggleAttempts(item),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AttemptsPanelState {
  const _AttemptsPanelState({
    required this.expanded,
    this.loading = false,
    this.items = const [],
    this.error,
  });

  final bool expanded;
  final bool loading;
  final List<AssignedQuizAttemptSummary> items;
  final String? error;

  _AttemptsPanelState copyWith({
    bool? expanded,
    bool? loading,
    List<AssignedQuizAttemptSummary>? items,
    String? error,
  }) {
    return _AttemptsPanelState(
      expanded: expanded ?? this.expanded,
      loading: loading ?? this.loading,
      items: items ?? this.items,
      error: error,
    );
  }
}

class _AssignedQuizCard extends StatelessWidget {
  const _AssignedQuizCard({
    required this.item,
    required this.busy,
    required this.attempts,
    required this.readOnly,
    required this.onEdit,
    required this.onPublish,
    required this.onArchive,
    required this.onDeleteDraft,
    required this.onToggleAttempts,
  });

  final AssignedQuizSummary item;
  final bool busy;
  final _AttemptsPanelState? attempts;
  final bool readOnly;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onArchive;
  final VoidCallback onDeleteDraft;
  final VoidCallback onToggleAttempts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final expired = AssignedQuizStaffLabels.isExpired(item.expiresAt);
    final canArchive =
        item.status == AssignedQuizStatus.draft ||
        item.status == AssignedQuizStatus.assigned;
    final canDelete = item.status == AssignedQuizStatus.draft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppVisual.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppVisual.border),
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
              _Badge(
                label: AssignedQuizStaffLabels.status(item.status),
                tone: switch (item.status) {
                  AssignedQuizStatus.draft => BackofficeUiTokens.neutral,
                  AssignedQuizStatus.assigned => BackofficeUiTokens.accentLight,
                  AssignedQuizStatus.archived => BackofficeUiTokens.neutral,
                },
              ),
              _Badge(
                label: AssignedQuizStaffLabels.categoryBadge(
                  item.licenseCategory,
                ),
                tone: BackofficeUiTokens.primary.withValues(alpha: 0.12),
                foreground: BackofficeUiTokens.primary,
              ),
              if (expired)
                _Badge(
                  label: 'Scaduto',
                  tone: BackofficeUiTokens.error.withValues(alpha: 0.12),
                  foreground: BackofficeUiTokens.error,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.publicCode,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: BackofficeUiTokens.primary,
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
            'Creato: ${AssignedQuizStaffLabels.formatDate(item.createdAt)}'
            '${item.assignedAt != null ? ' · Assegnato: ${AssignedQuizStaffLabels.formatDate(item.assignedAt)}' : ''}'
            '${item.expiresAt != null ? ' · Scade: ${AssignedQuizStaffLabels.formatDate(item.expiresAt)}' : ''}',
            style: textTheme.bodySmall?.copyWith(
              color: BackofficeUiTokens.textMuted,
            ),
          ),
          if (item.staffNote != null && item.staffNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Nota: ${item.staffNote}',
              style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (item.attemptsCount != null ||
              item.bestScorePercentage != null ||
              item.averageScorePercentage != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (item.attemptsCount != null)
                  'Tentativi: ${item.attemptsCount}',
                if (item.bestScorePercentage != null)
                  'Miglior punteggio: ${item.bestScorePercentage!.toStringAsFixed(0)}%',
                if (item.averageScorePercentage != null)
                  'Media: ${item.averageScorePercentage!.toStringAsFixed(0)}%',
              ].join(' · '),
              style: textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (!readOnly)
                TextButton.icon(
                  onPressed: busy ? null : onToggleAttempts,
                  icon: Icon(
                    attempts?.expanded == true
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(
                    attempts?.expanded == true
                        ? 'Nascondi tentativi'
                        : 'Vedi tentativi',
                  ),
                ),
              if (!readOnly && item.status != AssignedQuizStatus.archived)
                TextButton(
                  onPressed: busy ? null : onEdit,
                  child: const Text('Modifica'),
                ),
              if (!readOnly && item.status == AssignedQuizStatus.draft)
                FilledButton(
                  onPressed: busy ? null : onPublish,
                  child: const Text('Assegna'),
                ),
              if (!readOnly && canArchive)
                TextButton(
                  onPressed: busy ? null : onArchive,
                  child: const Text('Archivia'),
                ),
              if (!readOnly && canDelete)
                TextButton(
                  onPressed: busy ? null : onDeleteDraft,
                  style: TextButton.styleFrom(
                    foregroundColor: BackofficeUiTokens.error,
                  ),
                  child: const Text('Elimina bozza'),
                ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (attempts?.expanded == true) ...[
            const SizedBox(height: 8),
            _AttemptsPanel(state: attempts!),
          ],
        ],
      ),
    );
  }
}

class _AttemptsPanel extends StatelessWidget {
  const _AttemptsPanel({required this.state});

  final _AttemptsPanelState state;

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
        style: textTheme.bodySmall?.copyWith(color: BackofficeUiTokens.error),
      );
    }
    if (state.items.isEmpty) {
      return Text('Nessun tentativo.', style: textTheme.bodySmall);
    }

    return Column(
      children: state.items
          .map((a) {
            final inProgress = a.status == AssignedQuizAttemptStatus.inProgress;
            final scoreLabel = inProgress
                ? '—'
                : (a.scorePercentage == null
                      ? '—'
                      : '${a.scorePercentage!.toStringAsFixed(0)}%');
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Tentativo ${a.attemptNumber} · '
                '${AssignedQuizStaffLabels.attemptStatus(a.status)}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Inizio: ${AssignedQuizStaffLabels.formatDateTime(a.startedAt)}'
                '${a.submittedAt != null ? ' · Invio: ${AssignedQuizStaffLabels.formatDateTime(a.submittedAt)}' : ''}'
                '${inProgress ? '' : ' · Corrette ${a.correctCount}, errate ${a.wrongCount}, non risposte ${a.unansweredCount}'}'
                ' · Punteggio $scoreLabel'
                ' · Durata ${AssignedQuizStaffLabels.formatDuration(a.durationSeconds)}',
                style: textTheme.bodySmall,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone, this.foreground});

  final String label;
  final Color tone;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground ?? AppVisual.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

List<AssignedQuizSummary> _previewDemoItems(String studentId) {
  final now = DateTime.now().toUtc();
  return [
    AssignedQuizSummary(
      id: 'preview-demo-only',
      publicCode: 'DEMO-NON-REALE',
      studentId: studentId,
      studentUserId: 'preview-user',
      licenseCategory: 'A12',
      title: 'Esempio dimostrativo (non reale)',
      staffNote: 'Contenuto di anteprima Backoffice',
      status: AssignedQuizStatus.assigned,
      questionCount: 20,
      repeatPolicy: AssignedQuizRepeatPolicy.unlimited,
      createdAt: now.subtract(const Duration(days: 2)),
      assignedAt: now.subtract(const Duration(days: 2)),
    ),
  ];
}
