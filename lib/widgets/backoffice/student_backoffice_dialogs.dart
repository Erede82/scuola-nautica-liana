import 'package:flutter/material.dart';
import 'package:postgrest/postgrest.dart';

import '../../constants/backoffice_payment_methods.dart';
import '../../constants/guida_default_instructors.dart';
import '../../utils/guidance_appointment_validation.dart';
import '../../data/license_catalog.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../models/license_models.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import 'backoffice_formatters.dart';
import 'backoffice_ui_tokens.dart';

typedef _PaymentResult = ({
  int amountCents,
  PaymentMethod method,
  DateTime receivedAt,
  String? notes,
  String? receiptReference,
  String idempotencyKey,
});

typedef _GuidanceResult = ({
  DateTime lessonDate,
  DateTime start,
  DateTime end,
  String instructor,
  String? notes,
});

int? parseEuroInputToCents(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v <= 0) return null;
  return (v * 100).round();
}

String _formatWriteError(Object e) {
  if (e is PostgrestException) return e.message;
  return e.toString();
}

const _backofficePickerLocale = Locale('it', 'IT');

Future<DateTime?> showBackofficeDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  return showDatePicker(
    context: context,
    locale: _backofficePickerLocale,
    initialDate: initialDate,
    firstDate: firstDate ?? DateTime(2020),
    lastDate: lastDate ?? DateTime(2100),
    helpText: 'Seleziona data',
    cancelText: 'Annulla',
    confirmText: 'Conferma',
  );
}

Future<TimeOfDay?> showBackofficeTimePicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    helpText: 'Seleziona orario',
    cancelText: 'Annulla',
    confirmText: 'Conferma',
  );
}

/// `true` se tra le righe `sheetUnlocks` ci sono sia schede con `unlocked` true sia false.
bool _lessonUnlockRowsMixedInAggregate(
  StudentAdmin360View agg,
  LicenseCategoryId categoryId,
  int lessonNumber,
  int quizSheets,
) {
  var anyTrue = false;
  var anyFalse = false;
  for (var s = 1; s <= quizSheets; s++) {
    LessonQuizSheetUnlock? row;
    for (final e in agg.studyProgress.sheetUnlocks) {
      if (e.categoryId == categoryId &&
          e.lessonNumber == lessonNumber &&
          e.sheetNumber == s) {
        row = e;
        break;
      }
    }
    final on = row?.unlocked ?? false;
    if (on) {
      anyTrue = true;
    } else {
      anyFalse = true;
    }
  }
  return anyTrue && anyFalse;
}

bool _lessonHasAnySheetUnlockedInAggregate(
  StudentAdmin360View agg,
  LicenseCategoryId categoryId,
  int lessonNumber,
  int quizSheets,
) {
  for (var s = 1; s <= quizSheets; s++) {
    LessonQuizSheetUnlock? row;
    for (final e in agg.studyProgress.sheetUnlocks) {
      if (e.categoryId == categoryId &&
          e.lessonNumber == lessonNumber &&
          e.sheetNumber == s) {
        row = e;
        break;
      }
    }
    if (row?.unlocked ?? false) return true;
  }
  return false;
}

void _backofficeSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

Future<void> showManageLessonSheetsDialog(
  BuildContext context, {
  required StudentAdmin360View initialView,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
}) async {
  final holder = ValueNotifier<StudentAdmin360View>(initialView);
  var busy =
      false; // ignore: prefer_final_locals (mutated across async closures)
  try {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return ValueListenableBuilder<StudentAdmin360View>(
              valueListenable: holder,
              builder: (context, currentView, _) {
                final agg = currentView;
                final categoryId = currentView.profile.enrolledLicenseCategory;
                final category = LicenseCatalog.byId(categoryId);

                return AlertDialog(
                  title: const Text('Gestisci schede'),
                  content: SizedBox(
                    width: 520,
                    height: 460,
                    child: !category.isAvailable || category.lessons.isEmpty
                        ? Text(
                            category.id == LicenseCategoryId.vela
                                ? 'Contenuti vela in preparazione. Le lezioni e le schede quiz '
                                      'non sono ancora nel catalogo operativo: disponibile prossimamente.'
                                : 'Nessuna lezione nel catalogo per questa categoria.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gestione per lezione: sbloccando l’intera lezione abiliti tutte '
                                'le sue schede; bloccando, l’allievo non vede più i quiz di quella lezione.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView(
                                  children: category.lessons.map((lesson) {
                                    if (lesson.quizSheets == 0) {
                                      return const SizedBox.shrink();
                                    }
                                    final storedMixed =
                                        _lessonUnlockRowsMixedInAggregate(
                                      agg,
                                      categoryId,
                                      lesson.number,
                                      lesson.quizSheets,
                                    );
                                    final studentGetsLesson =
                                        _lessonHasAnySheetUnlockedInAggregate(
                                      agg,
                                      categoryId,
                                      lesson.number,
                                      lesson.quizSheets,
                                    );

                                    String statusLine;
                                    if (storedMixed) {
                                      statusLine =
                                          'Anagrafica non uniforme tra le schede — usa i pulsanti per allineare.';
                                    } else if (studentGetsLesson) {
                                      statusLine =
                                          'Per l’allievo: lezione accessibile (tutte le schede).';
                                    } else {
                                      statusLine =
                                          'Per l’allievo: lezione non accessibile.';
                                    }

                                    Future<void> applyWholeLesson(
                                      bool unlocked,
                                    ) async {
                                      busy = true;
                                      setLocal(() {});
                                      final messenger =
                                          ScaffoldMessenger.maybeOf(context);
                                      try {
                                        for (var s = 1;
                                            s <= lesson.quizSheets;
                                            s++) {
                                          await repository
                                              .setLessonSheetUnlocked(
                                            studentId:
                                                currentView.profile.id,
                                            categoryId: categoryId,
                                            lessonNumber: lesson.number,
                                            sheetNumber: s,
                                            unlocked: unlocked,
                                          );
                                        }
                                        final fresh = await repository
                                            .getStudentAdmin360(
                                          currentView.profile.id,
                                        );
                                        if (fresh != null) {
                                          holder.value = fresh;
                                          await onRefreshDetail(fresh);
                                        }
                                        if (context.mounted) {
                                          messenger?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                unlocked
                                                    ? 'Intera lezione sbloccata.'
                                                    : 'Intera lezione bloccata.',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          messenger?.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Errore: '
                                                '${_formatWriteError(e)}',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } finally {
                                        busy = false;
                                        if (context.mounted) {
                                          setLocal(() {});
                                        }
                                      }
                                    }

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          12,
                                          12,
                                          14,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              lesson.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${lesson.quizSheets} schede',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              statusLine,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                color: storedMixed
                                                    ? const Color(0xFFC27C1C)
                                                    : Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color,
                                                fontWeight: storedMixed
                                                    ? FontWeight.w800
                                                    : FontWeight.w500,
                                                height: 1.35,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                FilledButton.icon(
                                                  onPressed: busy
                                                      ? null
                                                      : () =>
                                                          applyWholeLesson(true),
                                                  icon: const Icon(
                                                    Icons.lock_open_rounded,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    'Sblocca tutta la lezione',
                                                  ),
                                                ),
                                                OutlinedButton.icon(
                                                  onPressed: busy
                                                      ? null
                                                      : () =>
                                                          applyWholeLesson(
                                                    false,
                                                  ),
                                                  icon: const Icon(
                                                    Icons.lock_rounded,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    'Blocca tutta la lezione',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Chiudi'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  } finally {
    holder.dispose();
  }
}

Future<void> showExamAccessManageDialog(
  BuildContext context, {
  required StudentAdmin360View initialView,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
}) async {
  final holder = ValueNotifier<StudentAdmin360View>(initialView);
  var busy = false;
  try {
    final categoryId = initialView.profile.enrolledLicenseCategory;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return ValueListenableBuilder<StudentAdmin360View>(
              valueListenable: holder,
              builder: (context, currentView, _) {
                if (categoryId == LicenseCategoryId.vela) {
                  return AlertDialog(
                    title: const Text('Abilita quiz esame'),
                    content: SizedBox(
                      width: 400,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            BackofficeFormatters.categoryName(categoryId),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: BackofficeUiTokens.primary,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Contenuti vela in preparazione. Il quiz esame non può essere '
                            'abilitato finché i contenuti didattici non sono pubblicati '
                            '(disponibile prossimamente).',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: BackofficeUiTokens.text.withValues(
                                    alpha: 0.88,
                                  ),
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Chiudi'),
                      ),
                    ],
                  );
                }

                final list = List<ExamQuizAccess>.from(
                  currentView.studyProgress.examAccessByCategory,
                );
                final ix = list.indexWhere((e) => e.categoryId == categoryId);
                final unlocked = ix >= 0 ? list[ix].examUnlocked : false;

                return AlertDialog(
                  title: const Text('Abilita quiz esame'),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          BackofficeFormatters.categoryName(categoryId),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: BackofficeUiTokens.primary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'La simulazione esame resta disattivata finché la scuola non abilita l’accesso.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: BackofficeUiTokens.text.withValues(
                                  alpha: 0.75,
                                ),
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Quiz esame abilitato'),
                          subtitle: Text(
                            unlocked
                                ? 'Studente può accedere al quiz esame.'
                                : 'Accesso disattivato.',
                          ),
                          value: unlocked,
                          activeTrackColor: BackofficeUiTokens.success
                              .withValues(alpha: 0.55),
                          onChanged: busy
                              ? null
                              : (v) async {
                                  busy = true;
                                  setLocal(() {});
                                  final messenger = ScaffoldMessenger.maybeOf(
                                    context,
                                  );
                                  try {
                                    await repository
                                        .setExamQuizAccessForCategory(
                                          studentId: currentView.profile.id,
                                          categoryId: categoryId,
                                          examUnlocked: v,
                                        );
                                    final fresh = await repository
                                        .getStudentAdmin360(
                                          currentView.profile.id,
                                        );
                                    if (fresh != null) {
                                      holder.value = fresh;
                                      await onRefreshDetail(fresh);
                                    }
                                    if (context.mounted) {
                                      messenger?.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Accesso quiz esame aggiornato.',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      messenger?.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Errore: ${_formatWriteError(e)}',
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } finally {
                                    busy = false;
                                    if (context.mounted) setLocal(() {});
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Chiudi'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  } finally {
    holder.dispose();
  }
}

Future<void> showErrorReviewAssignDialog(
  BuildContext context, {
  required StudentAdmin360View initialView,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
}) async {
  final holder = ValueNotifier<StudentAdmin360View>(initialView);
  var busy = false;
  try {
    final categoryId = initialView.profile.enrolledLicenseCategory;
    final category = LicenseCatalog.byId(categoryId);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return ValueListenableBuilder<StudentAdmin360View>(
              valueListenable: holder,
              builder: (context, currentView, _) {
                final agg = currentView;

                return AlertDialog(
                  title: const Text('Assegna ripasso'),
                  content: SizedBox(
                    width: 440,
                    height: 400,
                    child: !category.isAvailable || category.lessons.isEmpty
                        ? Text(
                            category.id == LicenseCategoryId.vela
                                ? 'Contenuti vela in preparazione. Il ripasso per argomento '
                                      'sarà disponibile con i contenuti didattici (disponibile prossimamente).'
                                : 'Nessuna lezione disponibile nel catalogo per questa categoria.',
                          )
                        : ListView(
                            children: category.lessons.map((lesson) {
                              ErrorReviewTopicAssignment? row;
                              for (final e
                                  in agg.studyProgress.errorReviewAssignments) {
                                if (e.categoryId == categoryId &&
                                    e.lessonNumber == lesson.number) {
                                  row = e;
                                  break;
                                }
                              }
                              final open = row?.topicUnlocked ?? false;
                              return SwitchListTile.adaptive(
                                title: Text('Lezione ${lesson.number}'),
                                subtitle: Text(
                                  lesson.title,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                value: open,
                                activeTrackColor: BackofficeUiTokens.success
                                    .withValues(alpha: 0.55),
                                onChanged: busy
                                    ? null
                                    : (v) async {
                                        busy = true;
                                        setLocal(() {});
                                        final messenger =
                                            ScaffoldMessenger.maybeOf(context);
                                        try {
                                          await repository
                                              .setErrorReviewTopicAssignment(
                                                studentId:
                                                    currentView.profile.id,
                                                categoryId: categoryId,
                                                lessonNumber: lesson.number,
                                                topicUnlocked: v,
                                                didacticNote: row?.didacticNote,
                                              );
                                          final fresh = await repository
                                              .getStudentAdmin360(
                                                currentView.profile.id,
                                              );
                                          if (fresh != null) {
                                            holder.value = fresh;
                                            await onRefreshDetail(fresh);
                                          }
                                          if (context.mounted) {
                                            messenger?.showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Ripasso errori aggiornato.',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            messenger?.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Errore: '
                                                  '${_formatWriteError(e)}',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        } finally {
                                          busy = false;
                                          if (context.mounted) {
                                            setLocal(() {});
                                          }
                                        }
                                      },
                              );
                            }).toList(),
                          ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Chiudi'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  } finally {
    holder.dispose();
  }
}

class _AddPaymentDialogBody extends StatefulWidget {
  const _AddPaymentDialogBody();

  @override
  State<_AddPaymentDialogBody> createState() => _AddPaymentDialogBodyState();
}

class _AddPaymentDialogBodyState extends State<_AddPaymentDialogBody> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _receiptCtrl = TextEditingController();

  PaymentMethod _method = BackofficePaymentMethods.selectableForNewPayment.first;
  DateTime _received = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _receiptCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cents = parseEuroInputToCents(_amountCtrl.text);
    if (cents == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Importo non valido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c2) => AlertDialog(
        title: const Text('Conferma registrazione'),
        content: Text(
          'Registrare ${BackofficeFormatters.moneyEur(cents)} '
          '(${BackofficeFormatters.paymentMethod(_method)})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c2, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c2, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final r = (
      amountCents: cents,
      method: _method,
      receivedAt: _received,
      notes: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      receiptReference: _receiptCtrl.text.trim().isEmpty
          ? null
          : _receiptCtrl.text.trim(),
      idempotencyKey: 'payment-${DateTime.now().microsecondsSinceEpoch}',
    );
    Navigator.of(context).pop<_PaymentResult>(r);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aggiungi pagamento'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Registra solo incassi verificati. Importo in euro (es. 250,50).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BackofficeUiTokens.text.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Importo (€)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Metodo',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PaymentMethod>(
                    isExpanded: true,
                    value: _method,
                    items: BackofficePaymentMethods.selectableForNewPayment
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(BackofficeFormatters.paymentMethod(m)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _method = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Data incasso · ${BackofficeFormatters.dateUi(_received)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined),
                  onPressed: () async {
                    final d = await showBackofficeDatePicker(
                      context,
                      initialDate: _received,
                    );
                    if (d != null && mounted) {
                      setState(() {
                        _received = DateTime(d.year, d.month, d.day, 12, 0);
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _receiptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Riferimento ricevuta (opz.)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salva')),
      ],
    );
  }
}

Future<void> showAddPaymentDialog(
  BuildContext context, {
  required StudentAdmin360View view,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
}) async {
  final studentId = view.profile.id;

  final result = await showDialog<_PaymentResult>(
    context: context,
    builder: (ctx) => const _AddPaymentDialogBody(),
  );

  if (result == null || !context.mounted) return;

  try {
    await repository.addPayment(
      studentId: studentId,
      amountCents: result.amountCents,
      method: result.method,
      receivedAt: result.receivedAt,
      notes: result.notes,
      receiptReference: result.receiptReference,
      idempotencyKey: result.idempotencyKey,
    );
    final fresh = await repository.getStudentAdmin360(studentId);
    if (fresh != null) await onRefreshDetail(fresh);
    if (context.mounted) {
      _backofficeSnack(context, 'Pagamento registrato.');
    }
  } catch (e) {
    if (context.mounted) {
      _backofficeSnack(context, 'Errore: ${_formatWriteError(e)}');
    }
  }
}

class _AddGuidanceDialogBody extends StatefulWidget {
  const _AddGuidanceDialogBody({required this.initialDay});

  final DateTime initialDay;

  @override
  State<_AddGuidanceDialogBody> createState() => _AddGuidanceDialogBodyState();
}

class _AddGuidanceDialogBodyState extends State<_AddGuidanceDialogBody> {
  late DateTime _day;
  TimeOfDay _startT = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endT = const TimeOfDay(hour: 10, minute: 0);
  String? _instructorName;
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = DateTime(
      widget.initialDay.year,
      widget.initialDay.month,
      widget.initialDay.day,
    );
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime day, TimeOfDay t) {
    return DateTime(day.year, day.month, day.day, t.hour, t.minute);
  }

  void _submit() {
    final inst = _instructorName?.trim();
    if (inst == null || inst.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona l’istruttore.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final start = _combine(_day, _startT);
    final end = _combine(_day, _endT);
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’ora fine deve essere dopo l’ora inizio.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop((
      lessonDate: _day,
      start: start,
      end: end,
      instructor: inst,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registra guida — pratica in mare'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pratica in mare: l’istruttore è assegnato dalla scuola. '
                'L’appuntamento compare in Agenda e in questa scheda.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BackofficeUiTokens.text.withValues(alpha: 0.72),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Data · ${BackofficeFormatters.dateUi(_day)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () async {
                    final d = await showBackofficeDatePicker(
                      context,
                      initialDate: _day,
                    );
                    if (d != null) setState(() => _day = d);
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Inizio · ${_startT.format(context)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: () async {
                    final t = await showBackofficeTimePicker(
                      context,
                      initialTime: _startT,
                    );
                    if (t != null) setState(() => _startT = t);
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Fine · ${_endT.format(context)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.schedule_outlined),
                  onPressed: () async {
                    final t = await showBackofficeTimePicker(
                      context,
                      initialTime: _endT,
                    );
                    if (t != null) setState(() => _endT = t);
                  },
                ),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_instructorName ?? '__none__'),
                initialValue: _instructorName,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Istruttore assegnato',
                  hintText: 'Scegli dalla lista',
                  border: OutlineInputBorder(),
                ),
                items: GuidaDefaultInstructors.selectableInstructorNames
                    .map(
                      (name) => DropdownMenuItem(
                        value: name,
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (v) => setState(() => _instructorName = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (opz.)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salva')),
      ],
    );
  }
}

Future<void> showAddGuidanceAppointmentDialog(
  BuildContext context, {
  required StudentAdmin360View view,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
}) async {
  final studentId = view.profile.id;
  final now = DateTime.now();

  final result = await showDialog<_GuidanceResult>(
    context: context,
    builder: (ctx) => _AddGuidanceDialogBody(initialDay: now),
  );

  if (result == null || !context.mounted) return;

  try {
    final existing = await repository.listGuidanceAppointments();
    final conflict = validateGuidanceSlotConflict(
      existing: existing,
      studentId: studentId,
      instructorName: result.instructor,
      start: result.start,
      end: result.end,
    );
    if (conflict != null) {
      if (context.mounted) {
        _backofficeSnack(context, conflict);
      }
      return;
    }
    await repository.addGuidanceAppointment(
      studentId: studentId,
      lessonDate: result.lessonDate,
      startTime: result.start,
      endTime: result.end,
      instructorName: result.instructor,
      lessonType: GuidanceLessonType.practiceSea,
      notes: result.notes,
    );
    final fresh = await repository.getStudentAdmin360(studentId);
    if (fresh != null) await onRefreshDetail(fresh);
    if (context.mounted) {
      _backofficeSnack(context, 'Guida registrata.');
    }
  } catch (e) {
    if (context.mounted) {
      _backofficeSnack(context, 'Errore: ${_formatWriteError(e)}');
    }
  }
}

/// Pratica in mare da modulo Guide / Agenda — tipo lezione sempre [GuidanceLessonType.practiceSea].
Future<void> showAgendaSeaPracticeDialog(
  BuildContext context, {
  required BackofficeRepository repository,
  required List<StudentProfile> students,
  required Future<void> Function() onSaved,
}) async {
  if (students.isEmpty) {
    if (context.mounted) {
      _backofficeSnack(context, 'Nessun allievo disponibile.');
    }
    return;
  }
  final sorted = List<StudentProfile>.from(students)
    ..sort((a, b) {
      final c = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
      if (c != 0) return c;
      return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
    });

  final result = await showDialog<_AgendaSeaResult>(
    context: context,
    builder: (ctx) => _AgendaSeaPracticeDialogBody(students: sorted),
  );

  if (result == null || !context.mounted) return;

  try {
    final existing = await repository.listGuidanceAppointments();
    final conflict = validateGuidanceSlotConflict(
      existing: existing,
      studentId: result.studentId,
      instructorName: result.instructor,
      start: result.start,
      end: result.end,
    );
    if (conflict != null) {
      if (context.mounted) {
        _backofficeSnack(context, conflict);
      }
      return;
    }
    await repository.addGuidanceAppointment(
      studentId: result.studentId,
      lessonDate: result.lessonDate,
      startTime: result.start,
      endTime: result.end,
      instructorName: result.instructor,
      lessonType: GuidanceLessonType.practiceSea,
      notes: result.notes,
    );
    if (context.mounted) {
      _backofficeSnack(context, 'Guida pratica in mare registrata.');
    }
    await onSaved();
  } catch (e) {
    if (context.mounted) {
      _backofficeSnack(context, 'Errore: ${_formatWriteError(e)}');
    }
  }
}

/// Azioni disponibili dal blocco guida in Agenda.
enum AgendaGuidanceBlockAction { open360, edit, delete }

Future<AgendaGuidanceBlockAction?> showAgendaGuidanceBlockActions(
  BuildContext context, {
  required GuidanceListItem item,
}) {
  final textTheme = Theme.of(context).textTheme;
  return showModalBottomSheet<AgendaGuidanceBlockAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              item.studentFullName,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_search_outlined),
            title: const Text('Apri Scheda 360'),
            onTap: () =>
                Navigator.pop(ctx, AgendaGuidanceBlockAction.open360),
          ),
          ListTile(
            leading: const Icon(Icons.edit_calendar_outlined),
            title: const Text('Sposta / Modifica guida'),
            onTap: () => Navigator.pop(ctx, AgendaGuidanceBlockAction.edit),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
            title: Text(
              'Cancella guida',
              style: TextStyle(color: Colors.red.shade700),
            ),
            onTap: () => Navigator.pop(ctx, AgendaGuidanceBlockAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> showEditAgendaSeaPracticeDialog(
  BuildContext context, {
  required GuidanceListItem item,
  required List<StudentProfile> students,
  required BackofficeRepository repository,
  required Future<void> Function() onSaved,
}) async {
  if (students.isEmpty) {
    if (context.mounted) {
      _backofficeSnack(context, 'Nessun allievo disponibile.');
    }
    return;
  }
  final sorted = List<StudentProfile>.from(students)
    ..sort((a, b) {
      final c = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
      if (c != 0) return c;
      return a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
    });

  final result = await showDialog<_AgendaSeaResult>(
    context: context,
    builder: (ctx) => _AgendaSeaPracticeDialogBody(
      students: sorted,
      editItem: item,
    ),
  );

  if (result == null || !context.mounted) return;

  try {
    final existing = await repository.listGuidanceAppointments();
    final conflict = validateGuidanceSlotConflict(
      existing: existing,
      studentId: result.studentId,
      instructorName: result.instructor,
      start: result.start,
      end: result.end,
      excludeAppointmentId: item.appointmentId,
    );
    if (conflict != null) {
      if (context.mounted) {
        _backofficeSnack(context, conflict);
      }
      return;
    }
    await repository.updateGuidanceAppointment(
      appointmentId: item.appointmentId,
      studentId: result.studentId,
      lessonDate: result.lessonDate,
      startTime: result.start,
      endTime: result.end,
      instructorName: result.instructor,
      notes: result.notes,
    );
    if (context.mounted) {
      _backofficeSnack(context, 'Guida aggiornata.');
    }
    await onSaved();
  } catch (e) {
    if (context.mounted) {
      _backofficeSnack(context, 'Errore: ${_formatWriteError(e)}');
    }
  }
}

Future<void> showDeleteGuidanceAppointmentDialog(
  BuildContext context, {
  required GuidanceListItem item,
  required BackofficeRepository repository,
  required Future<void> Function() onSaved,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancella guida'),
      content: const Text('Vuoi cancellare questa guida dall’agenda?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cancella guida'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await repository.deleteGuidanceAppointment(
      appointmentId: item.appointmentId,
    );
    if (context.mounted) {
      _backofficeSnack(context, 'Guida cancellata dall’agenda.');
    }
    await onSaved();
  } catch (e) {
    if (context.mounted) {
      _backofficeSnack(context, 'Errore: ${_formatWriteError(e)}');
    }
  }
}

typedef _AgendaSeaResult = ({
  StudentId studentId,
  DateTime lessonDate,
  DateTime start,
  DateTime end,
  String instructor,
  String? notes,
});

class _AgendaSeaPracticeDialogBody extends StatefulWidget {
  const _AgendaSeaPracticeDialogBody({
    required this.students,
    this.editItem,
  });

  final List<StudentProfile> students;
  final GuidanceListItem? editItem;

  @override
  State<_AgendaSeaPracticeDialogBody> createState() =>
      _AgendaSeaPracticeDialogBodyState();
}

class _AgendaSeaPracticeDialogBodyState
    extends State<_AgendaSeaPracticeDialogBody> {
  late StudentId _studentId;
  late DateTime _day;
  TimeOfDay _startT = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endT = const TimeOfDay(hour: 10, minute: 0);
  bool _endTimeManuallySet = false;
  String? _instructorName;
  final TextEditingController _notesCtrl = TextEditingController();

  bool get _isEdit => widget.editItem != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.editItem;
    if (edit != null) {
      _studentId = edit.studentId;
      _day = DateTime(
        edit.lessonDate.year,
        edit.lessonDate.month,
        edit.lessonDate.day,
      );
      if (edit.startTime != null) {
        final s = edit.startTime!.toLocal();
        _startT = TimeOfDay(hour: s.hour, minute: s.minute);
      }
      if (edit.endTime != null) {
        final e = edit.endTime!.toLocal();
        _endT = TimeOfDay(hour: e.hour, minute: e.minute);
        _endTimeManuallySet = true;
      }
      _instructorName = edit.instructorName;
      if (edit.notes != null && edit.notes!.trim().isNotEmpty) {
        _notesCtrl.text = edit.notes!.trim();
      }
    } else {
      _studentId = widget.students.first.id;
      final now = DateTime.now();
      _day = DateTime(now.year, now.month, now.day);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime day, TimeOfDay t) {
    return DateTime(day.year, day.month, day.day, t.hour, t.minute);
  }

  void _submit() {
    final inst = _instructorName?.trim();
    if (inst == null || inst.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona l’istruttore.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final start = _combine(_day, _startT);
    final end = _combine(_day, _endT);
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L’ora fine deve essere dopo l’ora inizio.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.of(context).pop((
      studentId: _studentId,
      lessonDate: _day,
      start: start,
      end: end,
      instructor: inst,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit
            ? 'Modifica guida — pratica in mare'
            : 'Nuova guida — pratica in mare',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<StudentId>(
                key: ValueKey(_studentId),
                initialValue: _studentId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Allievo',
                  border: OutlineInputBorder(),
                ),
                items: widget.students
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.firstName} ${p.lastName}'.trim(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (v) {
                  if (v != null) setState(() => _studentId = v);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Data · ${BackofficeFormatters.dateUi(_day)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () async {
                    final d = await showBackofficeDatePicker(
                      context,
                      initialDate: _day,
                    );
                    if (d != null) setState(() => _day = d);
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Inizio · ${_startT.format(context)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.schedule),
                  onPressed: () async {
                    final t = await showBackofficeTimePicker(
                      context,
                      initialTime: _startT,
                    );
                    if (t != null) {
                      setState(() {
                        _startT = t;
                        if (!_endTimeManuallySet) {
                          _endT = guidanceAddOneHour(t);
                        }
                      });
                    }
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Fine · ${_endT.format(context)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.schedule_outlined),
                  onPressed: () async {
                    final t = await showBackofficeTimePicker(
                      context,
                      initialTime: _endT,
                    );
                    if (t != null) {
                      setState(() {
                        _endT = t;
                        _endTimeManuallySet = true;
                      });
                    }
                  },
                ),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_instructorName ?? '__none__'),
                initialValue: _instructorName,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Istruttore assegnato',
                  hintText: 'Scegli dalla lista',
                  border: OutlineInputBorder(),
                ),
                items: GuidaDefaultInstructors.selectableInstructorNames
                    .map(
                      (name) => DropdownMenuItem(
                        value: name,
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (v) => setState(() => _instructorName = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (opz.)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Salva')),
      ],
    );
  }
}

/// Imposta la quota pratica attesa (ricalcolo saldo residuo).
Future<void> showOnboardingRegistrationFeeDialog(
  BuildContext context, {
  required StudentAdmin360View view,
  required BackofficeRepository repository,
  required BackofficeDetailRefresh onRefreshDetail,
}) async {
  final ctrl = TextEditingController(
    text: (view.financialSummary.registrationFeeCents / 100).toStringAsFixed(2),
  );

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Quota pratica'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Costo pratica atteso (€)',
            hintText: 'es. 250,00',
            border: OutlineInputBorder(),
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

  if (saved != true || !context.mounted) return;

  final cents = parseEuroInputToCents(ctrl.text);
  if (cents == null) {
    _backofficeSnack(context, 'Importo non valido.');
    return;
  }

  try {
    await repository.setStudentRegistrationFeeCents(
      studentId: view.profile.id,
      registrationFeeCents: cents,
    );
    final fresh = await repository.getStudentAdmin360(view.profile.id);
    if (fresh != null) await onRefreshDetail(fresh);
    if (context.mounted) {
      _backofficeSnack(context, 'Quota pratica aggiornata.');
    }
  } catch (e) {
    if (context.mounted) {
      _backofficeSnack(context, 'Errore: ${_formatWriteError(e)}');
    }
  }
}
