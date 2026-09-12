import 'package:flutter/material.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_repository.dart';

/// Controller unico per assegnazione/retry numero registro (PRATICHE.8D).
///
/// Usa esclusivamente [BackofficeRepository.assignPracticeRegistryNumber]
/// (stesso percorso della create). Protegge da doppia chiamata in-flight.
class PracticeRegistryAssignController {
  PracticeRegistryAssignController({required this.repository});

  final BackofficeRepository repository;

  bool _busy = false;
  bool get isBusy => _busy;

  /// Una sola chiamata per volta. Rilancia errori del repository (nessun fake locale).
  Future<PracticeRegistryAssignment> assign({
    required PracticeDossierId practiceDossierId,
    required DateTime registrationDate,
  }) async {
    if (_busy) {
      throw StateError('Assegnazione registro già in corso.');
    }
    _busy = true;
    try {
      return await repository.assignPracticeRegistryNumber(
        practiceDossierId: practiceDossierId,
        registrationDate: registrationDate,
      );
    } finally {
      _busy = false;
    }
  }
}

/// Dialog conferma + loading + chiamata controller.
///
/// Ritorna l'assegnazione su successo, `null` se annullato.
/// Su errore mostra snackbar e lascia `null` (retry possibile).
Future<PracticeRegistryAssignment?> showAssignPracticeRegistryNumberDialog({
  required BuildContext context,
  required BackofficeRepository repository,
  required PracticeDossierId practiceDossierId,
  required DateTime registrationDate,
  String? studentFullName,
  PracticeRegistryAssignController? controller,
}) async {
  final ctrl =
      controller ?? PracticeRegistryAssignController(repository: repository);
  final year = practiceRegistryYearFromRegistrationDate(registrationDate);

  return showDialog<PracticeRegistryAssignment>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return _AssignPracticeRegistryConfirmDialog(
        controller: ctrl,
        practiceDossierId: practiceDossierId,
        registrationDate: registrationDate,
        studentFullName: studentFullName,
        registryYear: year,
      );
    },
  );
}

class _AssignPracticeRegistryConfirmDialog extends StatefulWidget {
  const _AssignPracticeRegistryConfirmDialog({
    required this.controller,
    required this.practiceDossierId,
    required this.registrationDate,
    required this.registryYear,
    this.studentFullName,
  });

  final PracticeRegistryAssignController controller;
  final PracticeDossierId practiceDossierId;
  final DateTime registrationDate;
  final int? registryYear;
  final String? studentFullName;

  @override
  State<_AssignPracticeRegistryConfirmDialog> createState() =>
      _AssignPracticeRegistryConfirmDialogState();
}

class _AssignPracticeRegistryConfirmDialogState
    extends State<_AssignPracticeRegistryConfirmDialog> {
  bool _submitting = false;

  Future<void> _onAssign() async {
    if (_submitting || widget.controller.isBusy) return;
    setState(() => _submitting = true);
    try {
      final assignment = await widget.controller.assign(
        practiceDossierId: widget.practiceDossierId,
        registrationDate: widget.registrationDate,
      );
      if (!mounted) return;
      Navigator.of(context).pop(assignment);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg = e is StateError ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossibile assegnare il numero di registro.\n$msg',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.studentFullName?.trim();
    return AlertDialog(
      title: const Text('Assegna n. registro'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assegnare il numero di registro a questa pratica?'),
          if (name != null && name.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Allievo: $name'),
          ],
          if (widget.registryYear != null) ...[
            const SizedBox(height: 6),
            Text('Anno registro previsto: ${widget.registryYear}'),
          ],
          if (_submitting) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _onAssign,
          child: const Text('Assegna'),
        ),
      ],
    );
  }
}
