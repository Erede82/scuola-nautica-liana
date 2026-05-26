import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import 'backoffice_formatters.dart';
import 'backoffice_ui_tokens.dart';

String _formatWriteError(Object e) {
  if (e is PostgrestException) return e.message;
  return e.toString();
}

void _recordSnack(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<void> showAddStaffNoteDialog(
  BuildContext context, {
  required StudentAdmin360View view,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
}) async {
  final bodyCtrl = TextEditingController();
  final authorCtrl = TextEditingController();
  var category = StaffNoteCategory.general;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setLocal) {
        return AlertDialog(
          title: const Text('Aggiungi nota'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: bodyCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Testo nota',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Autore (opz.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StaffNoteCategory>(
                        isExpanded: true,
                        value: category,
                        items: StaffNoteCategory.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(
                                  BackofficeFormatters.staffNoteCategory(c),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => category = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (bodyCtrl.text.trim().isEmpty) {
                  _recordSnack(context, 'Inserire il testo della nota.');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Salva'),
            ),
          ],
        );
      },
    ),
  );

  if (saved == true) {
    try {
      await repository.addInternalNote(
        studentId: view.profile.id,
        body: bodyCtrl.text,
        authorStaffName: authorCtrl.text,
        category: category,
      );
      final fresh = await repository.getStudentAdmin360(view.profile.id);
      if (fresh != null) await onRefreshDetail(fresh);
      if (context.mounted) {
        _recordSnack(context, 'Nota interna salvata.');
      }
    } catch (e) {
      if (context.mounted) {
        _recordSnack(context, 'Errore: ${_formatWriteError(e)}');
      }
    }
  }
  bodyCtrl.dispose();
  authorCtrl.dispose();
}

Future<void> showEditProfileInternalNotesDialog(
  BuildContext context, {
  required StudentAdmin360View view,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
}) async {
  final ctrl = TextEditingController(text: view.profile.internalNotes ?? '');

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Modifica note anagrafiche'),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText:
                'Sintesi per scheda anagrafica (campo legacy interno staff)…',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Salva'),
        ),
      ],
    ),
  );

  if (saved == true) {
    try {
      await repository.updateProfileLegacyInternalNote(
        studentId: view.profile.id,
        internalNotes: ctrl.text,
      );
      final fresh = await repository.getStudentAdmin360(view.profile.id);
      if (fresh != null) await onRefreshDetail(fresh);
      if (context.mounted) {
        _recordSnack(context, 'Note anagrafiche aggiornate.');
      }
    } catch (e) {
      if (context.mounted) {
        _recordSnack(context, 'Errore: ${_formatWriteError(e)}');
      }
    }
  }
  ctrl.dispose();
}

Future<void> showRegisterExamOutcomeDialog(
  BuildContext context, {
  required StudentAdmin360View view,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
  required ExamAttemptType examType,
}) async {
  final noteCtrl = TextEditingController();
  final scoreCtrl = TextEditingController();
  var result = ExamAttemptResult.passed;
  var examDate = DateTime.now();

  final title = examType == ExamAttemptType.theory
      ? 'Registra esito teoria'
      : 'Registra esito pratica';

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setLocal) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Data · ${BackofficeFormatters.dateUi(examDate)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: examDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) {
                          setLocal(
                            () => examDate = DateTime(
                              d.year,
                              d.month,
                              d.day,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Esito',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ExamAttemptResult>(
                        isExpanded: true,
                        value: result,
                        items: [
                          ExamAttemptResult.passed,
                          ExamAttemptResult.failed,
                          ExamAttemptResult.pending,
                          ExamAttemptResult.scheduled,
                          ExamAttemptResult.noShow,
                        ]
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(BackofficeFormatters.examResult(r)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => result = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: scoreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Voto / etichetta (opz.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opz.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    ),
  );

  if (saved == true) {
    try {
      await repository.addExamAttemptRecord(
        studentId: view.profile.id,
        examType: examType,
        result: result,
        examDate: examDate,
        scoreOrLabel: scoreCtrl.text,
        notes: noteCtrl.text,
      );
      final fresh = await repository.getStudentAdmin360(view.profile.id);
      if (fresh != null) await onRefreshDetail(fresh);
      if (context.mounted) {
        _recordSnack(context, 'Esito esame registrato.');
      }
    } catch (e) {
      if (context.mounted) {
        _recordSnack(context, 'Errore: ${_formatWriteError(e)}');
      }
    }
  }
  noteCtrl.dispose();
  scoreCtrl.dispose();
}

Future<void> showUpdatePracticeDossierDialog(
  BuildContext context, {
  required StudentAdmin360View view,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
}) async {
  final d = view.practiceDossier;
  final practiceCtrl = TextEditingController(text: d?.practiceNumber ?? '');
  final licenseCtrl = TextEditingController(text: d?.licenseNumber ?? '');
  final notesCtrl = TextEditingController(text: d?.authorityNotes ?? '');
  var docStatus = d?.documentStatus ?? LicenseDocumentStatus.notStarted;
  var prStatus = d?.practiceStatus ?? PracticeFileStatus.notOpen;
  var issue = d?.issueDate;
  var expiry = d?.expirationDate;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setLocal) {
        return AlertDialog(
          title: const Text('Aggiorna pratica e documenti'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: practiceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Numero pratica',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: licenseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Numero patente / titolo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Data rilascio · ${BackofficeFormatters.dateUi(issue)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: () async {
                        final x = await showDatePicker(
                          context: context,
                          initialDate: issue ?? DateTime.now(),
                          firstDate: DateTime(1990),
                          lastDate: DateTime(2100),
                        );
                        if (x != null) {
                          setLocal(() => issue = x);
                        }
                      },
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Scadenza · ${BackofficeFormatters.dateUi(expiry)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.event_outlined),
                      onPressed: () async {
                        final x = await showDatePicker(
                          context: context,
                          initialDate: expiry ?? DateTime.now(),
                          firstDate: DateTime(1990),
                          lastDate: DateTime(2100),
                        );
                        if (x != null) {
                          setLocal(() => expiry = x);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Stato documenti',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<LicenseDocumentStatus>(
                        isExpanded: true,
                        value: docStatus,
                        items: LicenseDocumentStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  BackofficeFormatters.documentStatus(s),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => docStatus = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Stato pratica',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PracticeFileStatus>(
                        isExpanded: true,
                        value: prStatus,
                        items: PracticeFileStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  BackofficeFormatters.practiceStatus(s),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => prStatus = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BackofficeUiTokens.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salva'),
            ),
          ],
        );
      },
    ),
  );

  if (saved == true) {
    try {
      await repository.updatePracticeDossier(
        studentId: view.profile.id,
        practiceNumber: practiceCtrl.text,
        licenseNumber: licenseCtrl.text,
        issueDate: issue,
        expirationDate: expiry,
        documentStatus: docStatus,
        practiceStatus: prStatus,
        authorityNotes: notesCtrl.text,
      );
      final fresh = await repository.getStudentAdmin360(view.profile.id);
      if (fresh != null) await onRefreshDetail(fresh);
      if (context.mounted) {
        _recordSnack(context, 'Dati pratica aggiornati.');
      }
    } catch (e) {
      if (context.mounted) {
        _recordSnack(context, 'Errore: ${_formatWriteError(e)}');
      }
    }
  }
  practiceCtrl.dispose();
  licenseCtrl.dispose();
  notesCtrl.dispose();
}
