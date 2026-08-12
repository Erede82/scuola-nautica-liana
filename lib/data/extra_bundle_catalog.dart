import '../constants/extra_content_ids.dart';

/// Catalogo bundle videocorsi Extra — mappa `ex-bundle` → prodotti inclusi (H1.1).
abstract final class ExtraBundleCatalog {
  static const String bundleId = ExtraContentIds.extraPacchetto;

  /// Prodotti i cui video compongono il corso completo (ordine playlist).
  static const List<String> bundleIncludedProductIds = <String>[
    ExtraContentIds.extraTeoria,
    ExtraContentIds.extraCarteggio,
    ExtraContentIds.extraGuida,
  ];

  static bool isBundle(String productId) => productId == bundleId;

  /// Righe `student_extra_purchases` da creare/aggiornare quando lo staff
  /// abilita un prodotto.
  static List<String> productsToGrantOnAccess(String productId) {
    if (isBundle(productId)) {
      return <String>[bundleId, ...bundleIncludedProductIds];
    }
    return <String>[productId];
  }

  /// Righe `student_extra_purchases` da revocare quando lo staff disabilita un
  /// prodotto.
  static List<String> productsToRevokeOnAccess(String productId) {
    if (isBundle(productId)) {
      return <String>[bundleId, ...bundleIncludedProductIds];
    }
    return <String>[productId];
  }

  /// Prodotti da cui leggere i video per la playlist lato allievo/backoffice.
  static List<String> videoSourceProductIds(String productId) {
    if (isBundle(productId)) {
      return List<String>.unmodifiable(bundleIncludedProductIds);
    }
    return <String>[productId];
  }

  /// Istruzione caricamento video nel backoffice (tab Prodotti / gestione video).
  static String uploadGuidance(String productId) {
    switch (productId) {
      case ExtraContentIds.extraTeoria:
        return 'Carica qui i video delle lezioni teoriche. '
            'Questi video saranno visibili anche nel corso completo.';
      case ExtraContentIds.extraCarteggio:
        return 'Carica qui i video di carteggio. '
            'Il carteggio è un percorso separato dalle schede quiz.';
      case ExtraContentIds.extraGuida:
        return 'Carica qui i video per la preparazione alla prova pratica/guida. '
            'La guida è un percorso separato.';
      case ExtraContentIds.extraPacchetto:
        return 'Il corso completo include automaticamente Teoria, Carteggio e Guida. '
            'Non caricare qui i video già presenti nei singoli corsi.';
      default:
        return 'Gestisci i video associati a questo prodotto.';
    }
  }

  static const String videoTitleNamingHint =
      'Esempi titolo: «01 - Teoria dello scafo - Parte 1», '
      '«02 - Motori endotermici - Parte 1», '
      '«Carteggio 01 - Coordinate e punto nave», '
      '«Guida 01 - Preparazione alla prova pratica».';

  static const String bundleLegacySectionTitle =
      'Video caricati direttamente nel corso completo';

  static const String bundleLegacySectionHint =
      'Consigliato: sposta questi video in Teoria, Carteggio o Guida.';

  static String moveTargetLabel(String productId) {
    switch (productId) {
      case ExtraContentIds.extraTeoria:
        return 'Sposta in Teoria';
      case ExtraContentIds.extraCarteggio:
        return 'Sposta in Carteggio';
      case ExtraContentIds.extraGuida:
        return 'Sposta in Guida';
      default:
        return 'Sposta';
    }
  }

  static bool isValidMoveTarget(String productId) =>
      bundleIncludedProductIds.contains(productId);

  static bool allowDirectVideoUpload(String productId) => !isBundle(productId);

  /// Titolo sezione playlist aggregata del corso completo.
  static String playlistSectionTitle(String includedProductId) {
    switch (includedProductId) {
      case ExtraContentIds.extraTeoria:
        return 'Lezioni teoriche';
      case ExtraContentIds.extraCarteggio:
        return 'Carteggio';
      case ExtraContentIds.extraGuida:
        return 'Guida';
      default:
        return 'Video';
    }
  }

  static String emptyBundlePlaylistMessage() =>
      'Nessun video disponibile nei corsi inclusi. '
      'Carica video in Teoria, Carteggio o Guida dal backoffice.';

  static String grantBundleSnackMessage() =>
      'Corso completo abilitato: accesso anche a teoria, carteggio e guida.';
}
