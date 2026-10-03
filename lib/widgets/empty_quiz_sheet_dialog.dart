import 'package:flutter/material.dart';

/// Azione scelta nel dialog "scheda non compilata" (0 risposte).
enum EmptyQuizSheetDialogAction {
  /// Chiude il dialog e resta nella scheda (nessun save).
  stay,

  /// Esce dalla scheda senza salvare.
  exit,
}

/// Dialog condiviso Schede / Multischeda quando si tenta di concludere con 0 risposte.
Future<EmptyQuizSheetDialogAction?> showEmptyQuizSheetDialog(
  BuildContext context,
) {
  return showDialog<EmptyQuizSheetDialogAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Scheda non compilata'),
      content: const Text(
        'Non hai ancora risposto a nessuna domanda. '
        'Per concludere e salvare la scheda serve almeno una risposta. '
        'Puoi tornare a rispondere oppure uscire senza salvare.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, EmptyQuizSheetDialogAction.stay),
          child: const Text('Torna alla scheda'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(ctx, EmptyQuizSheetDialogAction.exit),
          child: const Text('Esci dalla scheda'),
        ),
      ],
    ),
  );
}
