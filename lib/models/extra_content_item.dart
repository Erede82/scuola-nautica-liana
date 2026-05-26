import 'package:flutter/material.dart';

import '../constants/extra_content_ids.dart';

/// Tipologia contenuto area Extra (pagamenti / unlock da collegare in seguito).
enum ExtraContentType {
  videoCourse,
  premiumSupport,
  advancedPack,
  comingSoon,
  /// Contenuto incluso senza acquisto Extra (legacy / generico).
  includedStudy,
  /// Video didattici carteggio inclusi nel percorso ([ExtraContentIds.carteggioInclusa]).
  chartworkIncluded,
  teoriaTheoreticalVideos,
  guidaPracticalVideos,
  carteggioCourseVideos,
  pacchettoFull,
}

extension ExtraContentTypeX on ExtraContentType {
  String get label {
    switch (this) {
      case ExtraContentType.videoCourse:
        return 'Corso video';
      case ExtraContentType.premiumSupport:
        return 'Supporto premium';
      case ExtraContentType.advancedPack:
        return 'Pacchetto avanzato';
      case ExtraContentType.comingSoon:
        return 'In arrivo';
      case ExtraContentType.includedStudy:
        return 'Supporto incluso';
      case ExtraContentType.chartworkIncluded:
        return 'Contenuti inclusi';
      case ExtraContentType.teoriaTheoreticalVideos:
        return 'Teoria';
      case ExtraContentType.guidaPracticalVideos:
        return 'Guida';
      case ExtraContentType.carteggioCourseVideos:
        return 'Carteggio';
      case ExtraContentType.pacchettoFull:
        return 'Pacchetto completo';
    }
  }
}

/// Elemento catalogo Extra (DTO locale — sostituibile con API).
class ExtraContentItem {
  const ExtraContentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.fullDescription,
    required this.type,
    required this.isPremium,
    required this.isUnlocked,
    required this.isComingSoon,
    required this.icon,
    this.lessonCount,
    this.durationLabel,
    this.badgeLabel,
    this.priceLabel,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Anteprima breve (lista catalogo).
  final String description;

  /// Testo completo (scheda dettaglio).
  final String fullDescription;

  final ExtraContentType type;
  final bool isPremium;
  final bool isUnlocked;
  final bool isComingSoon;

  /// Icona placeholder finché non ci sono cover image da server.
  final IconData icon;

  final int? lessonCount;
  final String? durationLabel;

  /// Etichetta pill opzionale (es. "Premium", "Incluso").
  final String? badgeLabel;

  /// Prezzo mostrato in catalogo (es. "€ 49,00") — testo statico.
  final String? priceLabel;

  bool get isPremiumLocked =>
      isPremium && !isUnlocked && !isComingSoon;

  bool get canAccessContent =>
      !isComingSoon && isUnlocked && !isPremiumLocked;

  /// Beneficio incluso nell’esperienza standard (nessun acquisto Extra).
  bool get isIncludedAppBenefit =>
      !isPremium && !isComingSoon && isUnlocked;

  /// Legacy: il ripasso errori è ora nella sezione Quiz; nessuna scheda Extra usa più questo flag.
  bool get opensErrorReviewExperience =>
      id == ExtraContentIds.ripassoErrori && isIncludedAppBenefit;

  /// Stato UI per card e dettaglio.
  ExtraCatalogUiState get uiState {
    if (isComingSoon) return ExtraCatalogUiState.comingSoon;
    if (isPremiumLocked) return ExtraCatalogUiState.premiumLocked;
    return ExtraCatalogUiState.unlocked;
  }

  /// Etichetta piano per scheda dettaglio.
  String get planStatusLabel {
    if (isComingSoon) return 'In arrivo';
    if (isPremium) return 'A pagamento';
    if (type == ExtraContentType.chartworkIncluded) {
      return 'Inclusa nel percorso';
    }
    return 'Incluso nell’app';
  }

  bool get isCarteggioIncluded =>
      id == ExtraContentIds.carteggioInclusa ||
      type == ExtraContentType.chartworkIncluded;
}

enum ExtraCatalogUiState {
  unlocked,
  premiumLocked,
  comingSoon,
}
