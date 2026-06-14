import 'package:flutter/material.dart';

import '../constants/extra_content_ids.dart';
import '../domain/backoffice/backoffice.dart';
import '../models/extra_content_item.dart';

enum ExtraCardAccent { teoria, guida, carteggio, pacchetto }

/// Mappa prodotti Extra da DB/domain verso il DTO UI catalogo allievo.
abstract final class ExtraContentMapper {
  static ExtraContentItem fromProduct(ExtraProduct product) {
    return ExtraContentItem(
      id: product.id,
      title: product.title,
      subtitle: product.subtitle ?? '',
      description: product.description ?? product.subtitle ?? product.title,
      fullDescription: product.description ?? product.subtitle ?? product.title,
      type: _typeForProductId(product.id),
      isPremium: true,
      isUnlocked: false,
      isComingSoon: !product.active,
      icon: _iconForProductId(product.id),
      priceLabel: product.priceCents != null
          ? _formatPriceEur(product.priceCents!)
          : null,
    );
  }

  static ExtraCardAccent accentForProductId(String id) {
    switch (id) {
      case ExtraContentIds.extraTeoria:
        return ExtraCardAccent.teoria;
      case ExtraContentIds.extraGuida:
        return ExtraCardAccent.guida;
      case ExtraContentIds.extraCarteggio:
        return ExtraCardAccent.carteggio;
      case ExtraContentIds.extraPacchetto:
        return ExtraCardAccent.pacchetto;
      default:
        return ExtraCardAccent.teoria;
    }
  }

  static String _formatPriceEur(int cents) {
    final euros = (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
    return '€ $euros';
  }

  static ExtraContentType _typeForProductId(String id) {
    switch (id) {
      case ExtraContentIds.extraTeoria:
        return ExtraContentType.teoriaTheoreticalVideos;
      case ExtraContentIds.extraGuida:
        return ExtraContentType.guidaPracticalVideos;
      case ExtraContentIds.extraCarteggio:
        return ExtraContentType.carteggioCourseVideos;
      case ExtraContentIds.extraPacchetto:
        return ExtraContentType.pacchettoFull;
      default:
        return ExtraContentType.videoCourse;
    }
  }

  static IconData _iconForProductId(String id) {
    switch (id) {
      case ExtraContentIds.extraTeoria:
        return Icons.school_outlined;
      case ExtraContentIds.extraGuida:
        return Icons.sailing_outlined;
      case ExtraContentIds.extraCarteggio:
        return Icons.map_outlined;
      case ExtraContentIds.extraPacchetto:
        return Icons.collections_bookmark_outlined;
      default:
        return Icons.play_circle_outline_rounded;
    }
  }
}

ExtraCardAccent extraCardAccentForProductId(String id) =>
    ExtraContentMapper.accentForProductId(id);
