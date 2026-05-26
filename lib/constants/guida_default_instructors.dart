/// Docenti predefiniti per **Guida** / appuntamenti creati dallo staff (backoffice).
///
/// Usare [selectableInstructorNames] nei form di creazione (e in futuro modifica): elenco
/// estendibile senza cambiare la logica di salvataggio (resta un `String` libero sul dominio).
abstract final class GuidaDefaultInstructors {
  /// Nomi proposti come scelta rapida; l’utente staff può sempre digitare altro.
  static const List<String> selectableInstructorNames = [
    'Scibile Vincenzo',
    'Luigi Visalli',
    'Vincenzo Lomiento',
  ];
}
