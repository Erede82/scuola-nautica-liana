/// Filtri elenco promemoria Guida (UI segment / chip).
enum GuidaListFilter {
  tutte,
  daLeggere,
  confermate,
  completate,
}

extension GuidaListFilterX on GuidaListFilter {
  String get label {
    switch (this) {
      case GuidaListFilter.tutte:
        return 'Tutte';
      case GuidaListFilter.daLeggere:
        return 'Da leggere';
      case GuidaListFilter.confermate:
        return 'Confermate';
      case GuidaListFilter.completate:
        return 'Completate';
    }
  }
}
