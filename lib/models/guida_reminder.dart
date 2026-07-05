/// Stato dell’avviso guidato dalla segreteria / istruttore.
enum GuidaReminderStatus { daLeggere, confermato, completato }

extension GuidaReminderStatusX on GuidaReminderStatus {
  String get label {
    switch (this) {
      case GuidaReminderStatus.daLeggere:
        return 'Da leggere';
      case GuidaReminderStatus.confermato:
        return 'Confermato';
      case GuidaReminderStatus.completato:
        return 'Completato';
    }
  }
}

/// Categoria opzionale (filtri / iconografia future).
enum GuidaReminderCategory { lezionePratica, teoria, documenti, generale }

extension GuidaReminderCategoryX on GuidaReminderCategory {
  String get label {
    switch (this) {
      case GuidaReminderCategory.lezionePratica:
        return 'Lezione pratica';
      case GuidaReminderCategory.teoria:
        return 'Teoria';
      case GuidaReminderCategory.documenti:
        return 'Documenti';
      case GuidaReminderCategory.generale:
        return 'Generale';
    }
  }
}

/// Promemoria / comunicazione area Guida (sostituibile con DTO da API).
class GuidaReminder {
  const GuidaReminder({
    required this.id,
    required this.title,
    required this.instructorName,
    required this.scheduledAt,
    required this.status,
    required this.shortMessage,
    this.longMessage,
    required this.isUnread,
    this.requiresReading = false,
    this.category,
    this.timeDisplayOverride,
  });

  final String id;
  final String title;
  final String instructorName;

  /// Data e ora previste per l’impegno (ordinamento e formattazione).
  final DateTime scheduledAt;

  final GuidaReminderStatus status;
  final String shortMessage;
  final String? longMessage;

  /// Evidenziazione “non letto” (push / badge futuri).
  final bool isUnread;

  /// Richiede conferma di lettura da parte dello studente.
  final bool requiresReading;

  final GuidaReminderCategory? category;

  /// Se valorizzato, sostituisce l’ora formattata da [scheduledAt] (es. «Da concordare»).
  final String? timeDisplayOverride;

  bool get shouldHighlight =>
      isUnread || status == GuidaReminderStatus.daLeggere || requiresReading;

  /// Conteggio per badge dashboard (esclude completati).
  bool get appearsUnreadForBadge {
    if (status == GuidaReminderStatus.completato) return false;
    return isUnread ||
        requiresReading ||
        status == GuidaReminderStatus.daLeggere;
  }

  /// Filtro “Da leggere” (non include completati).
  bool get matchesDaLeggereFilter => appearsUnreadForBadge;

  String get bodyForDetail {
    final long = longMessage?.trim();
    if (long != null && long.isNotEmpty) return long;
    return shortMessage;
  }

  GuidaReminder copyWith({
    String? id,
    String? title,
    String? instructorName,
    DateTime? scheduledAt,
    GuidaReminderStatus? status,
    String? shortMessage,
    String? longMessage,
    bool? isUnread,
    bool? requiresReading,
    GuidaReminderCategory? category,
    String? timeDisplayOverride,
  }) {
    return GuidaReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      instructorName: instructorName ?? this.instructorName,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      shortMessage: shortMessage ?? this.shortMessage,
      longMessage: longMessage ?? this.longMessage,
      isUnread: isUnread ?? this.isUnread,
      requiresReading: requiresReading ?? this.requiresReading,
      category: category ?? this.category,
      timeDisplayOverride: timeDisplayOverride ?? this.timeDisplayOverride,
    );
  }
}

extension GuidaReminderActions on GuidaReminder {
  /// Aggiorna stato dopo conferma lettura (logica locale finché non c’è backend).
  GuidaReminder markedAsRead() {
    final newStatus = status == GuidaReminderStatus.daLeggere
        ? GuidaReminderStatus.confermato
        : status;
    return copyWith(isUnread: false, requiresReading: false, status: newStatus);
  }

  bool get canMarkAsRead {
    if (status == GuidaReminderStatus.completato) return false;
    return isUnread ||
        requiresReading ||
        status == GuidaReminderStatus.daLeggere;
  }
}

extension GuidaReminderListX on List<GuidaReminder> {
  /// Prossimi impegni prima; stessa data → ordine per ora.
  List<GuidaReminder> sortedUpcomingFirst() {
    final copy = List<GuidaReminder>.from(this);
    copy.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return copy;
  }
}
