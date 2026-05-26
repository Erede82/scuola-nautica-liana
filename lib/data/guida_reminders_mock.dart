import '../models/guida_reminder.dart';

/// Dati statici locali — sostituire con fetch Supabase / notifiche.
abstract final class GuidaRemindersMock {
  static List<GuidaReminder> get seeded => List<GuidaReminder>.unmodifiable(_seeded);

  static final List<GuidaReminder> _seeded = [
    GuidaReminder(
      id: 'gr-001',
      title: 'Lezione pratica in bacino',
      instructorName: 'Istr. Marco Bianchi',
      scheduledAt: DateTime(2026, 3, 24, 9, 0),
      status: GuidaReminderStatus.daLeggere,
      shortMessage:
          'Portare giacca a vento e documento. Leggere il capitolo 4 prima dell’uscita.',
      longMessage:
          'Portare giacca a vento, scarpe chiuse e documento d’identità.\n\n'
          'È richiesta la lettura del capitolo 4 del manuale prima dell’uscita in acqua. '
          'In caso di maltempo la lezione potrà essere posticipata: riceverai aggiornamento su questa scheda.',
      isUnread: true,
      requiresReading: true,
      category: GuidaReminderCategory.lezionePratica,
    ),
    GuidaReminder(
      id: 'gr-002',
      title: 'Ripasso teoria — COLREG',
      instructorName: 'Istr. Laura Verdi',
      scheduledAt: DateTime(2026, 3, 26, 18, 30),
      status: GuidaReminderStatus.confermato,
      shortMessage:
          'Incontro in aula. Portare appunti e materiali dalla sezione Quiz.',
      longMessage:
          'Sessione in aula dedicata al regolamento di traffico (COLREG). '
          'Porta gli appunti delle lezioni precedenti. Trovi schede di ripasso nella sezione Quiz.',
      isUnread: true,
      requiresReading: false,
      category: GuidaReminderCategory.teoria,
    ),
    GuidaReminder(
      id: 'gr-003',
      title: 'Promemoria documenti esame',
      instructorName: 'Segreteria',
      scheduledAt: DateTime(2026, 3, 28, 10, 0),
      status: GuidaReminderStatus.daLeggere,
      shortMessage:
          'Verificare scadenza certificato medico e modulo iscrizione esame.',
      longMessage:
          'Controlla entro la data indicata:\n\n'
          '• certificato medico in corso di validità\n'
          '• modulo di iscrizione esame firmato\n'
          '• eventuali versamenti in regola\n\n'
          'Per dubbi contatta la segreteria dall’area Account.',
      isUnread: false,
      requiresReading: true,
      category: GuidaReminderCategory.documenti,
      timeDisplayOverride: 'Entro il giorno',
    ),
    GuidaReminder(
      id: 'gr-004',
      title: 'Uscita guidata — ormeggio',
      instructorName: 'Istr. Marco Bianchi',
      scheduledAt: DateTime(2026, 4, 2, 15, 0),
      status: GuidaReminderStatus.completato,
      shortMessage: 'Lezione completata. Feedback disponibile in segreteria.',
      isUnread: false,
      requiresReading: false,
      category: GuidaReminderCategory.lezionePratica,
    ),
  ];

  /// Prossimi impegni prima; stessa data → ordine per ora.
  static List<GuidaReminder> sortedUpcomingFirst(List<GuidaReminder> items) {
    final copy = List<GuidaReminder>.from(items);
    copy.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return copy;
  }
}
