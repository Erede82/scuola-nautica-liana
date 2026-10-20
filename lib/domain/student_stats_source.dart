/// Filtro aggregazione statistiche allievo (Studio / Esame / Tutto).
enum StudentStatsSource {
  /// Schede normali + Multischeda.
  study,

  /// Solo simulazioni d'esame.
  exam,

  /// Unione Studio + Esame.
  all,
}

extension StudentStatsSourceUi on StudentStatsSource {
  String get labelIt {
    switch (this) {
      case StudentStatsSource.all:
        return 'Tutto';
      case StudentStatsSource.study:
        return 'Studio';
      case StudentStatsSource.exam:
        return 'Esame';
    }
  }
}
