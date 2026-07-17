import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/license_catalog.dart';
import '../../domain/quiz_license_category.dart';
import '../../models/assigned_quiz_models.dart';
import '../../models/license_models.dart';
import '../../repositories/assigned_quiz_repository.dart';
import 'assigned_quiz_staff_labels.dart';
import 'backoffice_ui_tokens.dart';
import 'student_backoffice_dialogs.dart';

void _assignedQuizSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

String _newIdempotencyKey() =>
    'aqz-${DateTime.now().toUtc().microsecondsSinceEpoch}';

/// Dialog generazione quiz dagli errori (staff).
Future<AssignedQuizGenerationResult?> showAssignedQuizGenerateDialog(
  BuildContext context, {
  required String studentId,
  required String studentDisplayName,
  required LicenseCategoryId licenseCategoryId,
  required AssignedQuizRepository repository,
}) {
  final supported = dbLicenseCategoryFor(licenseCategoryId) != null;
  return showDialog<AssignedQuizGenerationResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AssignedQuizGenerateDialog(
      studentId: studentId,
      studentDisplayName: studentDisplayName,
      licenseCategoryId: licenseCategoryId,
      repository: repository,
      generationSupported: supported,
    ),
  );
}

class _AssignedQuizGenerateDialog extends StatefulWidget {
  const _AssignedQuizGenerateDialog({
    required this.studentId,
    required this.studentDisplayName,
    required this.licenseCategoryId,
    required this.repository,
    required this.generationSupported,
  });

  final String studentId;
  final String studentDisplayName;
  final LicenseCategoryId licenseCategoryId;
  final AssignedQuizRepository repository;
  final bool generationSupported;

  @override
  State<_AssignedQuizGenerateDialog> createState() =>
      _AssignedQuizGenerateDialogState();
}

class _AssignedQuizGenerateDialogState
    extends State<_AssignedQuizGenerateDialog> {
  final _titleController = TextEditingController(
    text: 'Quiz personalizzato dagli errori',
  );
  final _noteController = TextEditingController();
  final _customCountController = TextEditingController();
  final _maxAttemptsController = TextEditingController(text: '1');

  late String _idempotencyKey;
  bool _submitting = false;
  String? _titleError;
  String? _lessonsError;
  String? _attemptsError;
  String? _expiryError;
  String? _countError;

  int _questionCount = 20;
  bool _useCustomCount = false;
  AssignedQuizLessonFilterMode _lessonFilter =
      AssignedQuizLessonFilterMode.allLessons;
  final Set<int> _selectedLessons = {};
  AssignedQuizSortMode _sortMode = AssignedQuizSortMode.mostWrong;
  AssignedQuizRepeatPolicy _repeatPolicy = AssignedQuizRepeatPolicy.unlimited;
  DateTime? _expiresAt;
  bool _allowPartial = false;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = _newIdempotencyKey();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _customCountController.dispose();
    _maxAttemptsController.dispose();
    super.dispose();
  }

  List<LessonItem> get _catalogLessons {
    final category = LicenseCatalog.byId(widget.licenseCategoryId);
    return category.lessons
        .where((l) => l.quizSheets > 0)
        .toList(growable: false);
  }

  int? _resolvedQuestionCount() {
    if (!_useCustomCount) return _questionCount;
    final parsed = int.tryParse(_customCountController.text.trim());
    return parsed;
  }

  AssignedQuizGenerationRequest? _buildRequest({
    required bool assignImmediately,
  }) {
    setState(() {
      _titleError = null;
      _lessonsError = null;
      _attemptsError = null;
      _expiryError = null;
      _countError = null;
    });

    final title = _titleController.text;
    final count = _resolvedQuestionCount();
    if (count == null || count < 1 || count > 50) {
      setState(() {
        _countError = 'Indica un numero di domande tra 1 e 50.';
      });
      return null;
    }

    int? maxAttempts;
    if (_repeatPolicy == AssignedQuizRepeatPolicy.limited) {
      maxAttempts = int.tryParse(_maxAttemptsController.text.trim());
      if (maxAttempts == null || maxAttempts < 1) {
        setState(() {
          _attemptsError = 'Indica almeno 1 tentativo.';
        });
        return null;
      }
    }

    final request = AssignedQuizGenerationRequest(
      studentId: widget.studentId,
      title: title,
      staffNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      questionCount: count,
      lessonFilterMode: _lessonFilter,
      lessonNumbers: _selectedLessons.toList()..sort(),
      sortMode: _sortMode,
      repeatPolicy: _repeatPolicy,
      maxAttempts: maxAttempts,
      expiresAt: _expiresAt,
      allowPartial: _allowPartial,
      assignImmediately: assignImmediately,
      idempotencyKey: _idempotencyKey,
    );

    final validation = request.validate();
    if (validation != null) {
      setState(() {
        if (validation.contains('titolo') || validation.contains('Titolo')) {
          _titleError = validation;
        } else if (validation.contains('lezione')) {
          _lessonsError = validation;
        } else if (validation.contains('tentativ')) {
          _attemptsError = validation;
        } else if (validation.contains('scadenza')) {
          _expiryError = validation;
        } else if (validation.contains('domande')) {
          _countError = validation;
        } else {
          _titleError = validation;
        }
      });
      return null;
    }
    return request;
  }

  Future<void> _submit({required bool assignImmediately}) async {
    if (_submitting || !widget.generationSupported) return;
    final request = _buildRequest(assignImmediately: assignImmediately);
    if (request == null) return;

    setState(() => _submitting = true);
    try {
      final result = await widget.repository.generateFromErrors(request);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      final mapped = assignedQuizExceptionFrom(error);
      _assignedQuizSnack(context, mapped.message);
      setState(() => _submitting = false);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final initial = _expiresAt?.toLocal() ?? now.add(const Duration(days: 14));
    final picked = await showBackofficeDatePicker(
      context,
      initialDate: initial.isBefore(now)
          ? now.add(const Duration(days: 1))
          : initial,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _expiresAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
      ).toUtc();
      _expiryError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lessons = _catalogLessons;

    return AlertDialog(
      scrollable: true,
      title: Text(
        'Genera quiz dagli errori',
        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Allievo: ${widget.studentDisplayName}',
                style: textTheme.bodyMedium?.copyWith(
                  color: BackofficeUiTokens.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Il percorso A12 o D1 viene rilevato automaticamente '
                'dall’iscrizione dell’allievo.',
                style: textTheme.bodySmall?.copyWith(
                  color: BackofficeUiTokens.textMuted,
                  height: 1.35,
                ),
              ),
              if (!widget.generationSupported) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: BackofficeUiTokens.neutral,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Funzione non disponibile per questo percorso',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: BackofficeUiTokens.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                enabled: !_submitting && widget.generationSupported,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: 'Titolo',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                enabled: !_submitting && widget.generationSupported,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nota interna (solo staff)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Text('Numero domande', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in const [10, 20, 30])
                    ChoiceChip(
                      label: Text('$n'),
                      selected: !_useCustomCount && _questionCount == n,
                      onSelected: (!_submitting && widget.generationSupported)
                          ? (_) => setState(() {
                              _useCustomCount = false;
                              _questionCount = n;
                              _countError = null;
                            })
                          : null,
                    ),
                  FilterChip(
                    label: const Text('Personalizzato'),
                    selected: _useCustomCount,
                    onSelected: (!_submitting && widget.generationSupported)
                        ? (v) => setState(() {
                            _useCustomCount = v;
                            _countError = null;
                          })
                        : null,
                  ),
                ],
              ),
              if (_useCustomCount) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customCountController,
                  enabled: !_submitting && widget.generationSupported,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Domande (1–50)',
                    errorText: _countError,
                  ),
                ),
              ] else if (_countError != null) ...[
                const SizedBox(height: 4),
                Text(
                  _countError!,
                  style: textTheme.bodySmall?.copyWith(
                    color: BackofficeUiTokens.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Lezioni', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tutte le lezioni'),
                    selected:
                        _lessonFilter ==
                        AssignedQuizLessonFilterMode.allLessons,
                    onSelected: (!_submitting && widget.generationSupported)
                        ? (_) => setState(() {
                            _lessonFilter =
                                AssignedQuizLessonFilterMode.allLessons;
                            _lessonsError = null;
                          })
                        : null,
                  ),
                  ChoiceChip(
                    label: const Text('Seleziona lezioni'),
                    selected:
                        _lessonFilter ==
                        AssignedQuizLessonFilterMode.selectedLessons,
                    onSelected: (!_submitting && widget.generationSupported)
                        ? (_) => setState(() {
                            _lessonFilter =
                                AssignedQuizLessonFilterMode.selectedLessons;
                            _lessonsError = null;
                          })
                        : null,
                  ),
                ],
              ),
              if (_lessonFilter ==
                  AssignedQuizLessonFilterMode.selectedLessons) ...[
                ...lessons.map((lesson) {
                  final selected = _selectedLessons.contains(lesson.number);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: selected,
                    title: Text(lesson.title),
                    onChanged: (!_submitting && widget.generationSupported)
                        ? (v) => setState(() {
                            if (v == true) {
                              _selectedLessons.add(lesson.number);
                            } else {
                              _selectedLessons.remove(lesson.number);
                            }
                            _lessonsError = null;
                          })
                        : null,
                  );
                }),
                if (_lessonsError != null)
                  Text(
                    _lessonsError!,
                    style: textTheme.bodySmall?.copyWith(
                      color: BackofficeUiTokens.error,
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Text('Ordinamento errori', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Più sbagliate'),
                    selected: _sortMode == AssignedQuizSortMode.mostWrong,
                    onSelected: (!_submitting && widget.generationSupported)
                        ? (_) => setState(
                            () => _sortMode = AssignedQuizSortMode.mostWrong,
                          )
                        : null,
                  ),
                  ChoiceChip(
                    label: const Text('Più recenti'),
                    selected: _sortMode == AssignedQuizSortMode.mostRecent,
                    onSelected: (!_submitting && widget.generationSupported)
                        ? (_) => setState(
                            () => _sortMode = AssignedQuizSortMode.mostRecent,
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Tentativi', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Illimitati'),
                    selected:
                        _repeatPolicy == AssignedQuizRepeatPolicy.unlimited,
                    onSelected: (!_submitting && widget.generationSupported)
                        ? (_) => setState(() {
                            _repeatPolicy = AssignedQuizRepeatPolicy.unlimited;
                            _attemptsError = null;
                          })
                        : null,
                  ),
                  ChoiceChip(
                    label: const Text('Limitati'),
                    selected: _repeatPolicy == AssignedQuizRepeatPolicy.limited,
                    onSelected: (!_submitting && widget.generationSupported)
                        ? (_) => setState(() {
                            _repeatPolicy = AssignedQuizRepeatPolicy.limited;
                            _attemptsError = null;
                          })
                        : null,
                  ),
                ],
              ),
              if (_repeatPolicy == AssignedQuizRepeatPolicy.limited)
                TextField(
                  controller: _maxAttemptsController,
                  enabled: !_submitting && widget.generationSupported,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Massimo tentativi',
                    errorText: _attemptsError,
                  ),
                ),
              const SizedBox(height: 12),
              Text('Scadenza (opzionale)', style: textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: (!_submitting && widget.generationSupported)
                        ? _pickExpiry
                        : null,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _expiresAt == null
                          ? 'Imposta scadenza'
                          : AssignedQuizStaffLabels.formatDate(_expiresAt),
                    ),
                  ),
                  if (_expiresAt != null)
                    TextButton(
                      onPressed: (!_submitting && widget.generationSupported)
                          ? () => setState(() {
                              _expiresAt = null;
                              _expiryError = null;
                            })
                          : null,
                      child: const Text('Rimuovi scadenza'),
                    ),
                ],
              ),
              if (_expiryError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expiryError!,
                    style: textTheme.bodySmall?.copyWith(
                      color: BackofficeUiTokens.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Accetta un numero inferiore di domande se gli errori '
                  'disponibili non bastano',
                ),
                value: _allowPartial,
                onChanged: (!_submitting && widget.generationSupported)
                    ? (v) => setState(() => _allowPartial = v)
                    : null,
              ),
              if (_submitting) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        OutlinedButton(
          onPressed: (_submitting || !widget.generationSupported)
              ? null
              : () => _submit(assignImmediately: false),
          child: const Text('Salva come bozza'),
        ),
        FilledButton(
          onPressed: (_submitting || !widget.generationSupported)
              ? null
              : () => _submit(assignImmediately: true),
          child: const Text('Assegna ora'),
        ),
      ],
    );
  }
}

/// Dialog modifica metadata (title / staffNote / expiresAt).
Future<bool> showAssignedQuizEditMetadataDialog(
  BuildContext context, {
  required AssignedQuizSummary assignment,
  required AssignedQuizRepository repository,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AssignedQuizEditMetadataDialog(
      assignment: assignment,
      repository: repository,
    ),
  );
  return result ?? false;
}

class _AssignedQuizEditMetadataDialog extends StatefulWidget {
  const _AssignedQuizEditMetadataDialog({
    required this.assignment,
    required this.repository,
  });

  final AssignedQuizSummary assignment;
  final AssignedQuizRepository repository;

  @override
  State<_AssignedQuizEditMetadataDialog> createState() =>
      _AssignedQuizEditMetadataDialogState();
}

class _AssignedQuizEditMetadataDialogState
    extends State<_AssignedQuizEditMetadataDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  DateTime? _expiresAt;
  bool _clearExpiresAt = false;
  bool _submitting = false;
  String? _titleError;
  String? _expiryError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.assignment.title);
    _noteController = TextEditingController(
      text: widget.assignment.staffNote ?? '',
    );
    _expiresAt = widget.assignment.expiresAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final initial = _expiresAt?.toLocal() ?? now.add(const Duration(days: 14));
    final picked = await showBackofficeDatePicker(
      context,
      initialDate: initial.isBefore(now)
          ? now.add(const Duration(days: 1))
          : initial,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _expiresAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
      ).toUtc();
      _clearExpiresAt = false;
      _expiryError = null;
    });
  }

  Future<void> _save() async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Il titolo è obbligatorio.');
      return;
    }

    final original = widget.assignment;
    final noteText = _noteController.text.trim();
    final originalNote = original.staffNote?.trim() ?? '';

    final titlePatch = title == original.title
        ? const AssignedQuizFieldPatch<String>.omit()
        : AssignedQuizFieldPatch<String>.set(title);

    final AssignedQuizFieldPatch<String> notePatch;
    if (noteText == originalNote) {
      notePatch = const AssignedQuizFieldPatch<String>.omit();
    } else if (noteText.isEmpty) {
      notePatch = const AssignedQuizFieldPatch<String>.clear();
    } else {
      notePatch = AssignedQuizFieldPatch<String>.set(noteText);
    }

    final AssignedQuizFieldPatch<DateTime> expiryPatch;
    if (_clearExpiresAt) {
      expiryPatch = const AssignedQuizFieldPatch<DateTime>.clear();
    } else if (_expiresAt == null && original.expiresAt == null) {
      expiryPatch = const AssignedQuizFieldPatch<DateTime>.omit();
    } else if (_expiresAt != null &&
        original.expiresAt != null &&
        _expiresAt!.toUtc().isAtSameMomentAs(original.expiresAt!.toUtc())) {
      expiryPatch = const AssignedQuizFieldPatch<DateTime>.omit();
    } else if (_expiresAt != null) {
      expiryPatch = AssignedQuizFieldPatch<DateTime>.set(_expiresAt!);
    } else {
      expiryPatch = const AssignedQuizFieldPatch<DateTime>.omit();
    }

    final patch = AssignedQuizMetadataPatch(
      title: titlePatch,
      staffNote: notePatch,
      expiresAt: expiryPatch,
    );

    if (!patch.hasChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _submitting = true;
      _titleError = null;
      _expiryError = null;
    });

    try {
      await widget.repository.updateAssignmentMetadata(original.id, patch);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final mapped = assignedQuizExceptionFrom(error);
      if (mapped.code == AssignedQuizErrorCode.validationFailed ||
          mapped.code == AssignedQuizErrorCode.titleRequired) {
        setState(() {
          _titleError = mapped.message;
          _submitting = false;
        });
      } else {
        _assignedQuizSnack(context, mapped.message);
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifica assegnazione'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                enabled: !_submitting,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: 'Titolo',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                enabled: !_submitting,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Nota interna',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Text('Scadenza', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickExpiry,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _clearExpiresAt || _expiresAt == null
                          ? 'Nessuna scadenza'
                          : AssignedQuizStaffLabels.formatDate(_expiresAt),
                    ),
                  ),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                            _expiresAt = null;
                            _clearExpiresAt = true;
                            _expiryError = null;
                          }),
                    child: const Text('Cancella scadenza'),
                  ),
                ],
              ),
              if (_expiryError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _expiryError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BackofficeUiTokens.error,
                    ),
                  ),
                ),
              if (_submitting) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _save,
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

Future<bool> confirmAssignedQuizPublish(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Assegna quiz'),
      content: const Text(
        'Il quiz diventerà visibile all’allievo e non potrà più tornare '
        'in bozza.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Assegna'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmAssignedQuizArchive(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Archivia quiz'),
      content: const Text(
        'L’assegnazione verrà archiviata e non sarà più disponibile '
        'per nuovi tentativi dell’allievo.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Archivia'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmAssignedQuizDeleteDraft(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Elimina bozza'),
      content: const Text(
        'La bozza e le sue domande verranno eliminate definitivamente.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BackofficeUiTokens.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Elimina'),
        ),
      ],
    ),
  );
  return result ?? false;
}
