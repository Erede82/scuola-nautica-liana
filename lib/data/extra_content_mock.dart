import 'package:flutter/material.dart';

import '../constants/extra_content_ids.dart';
import '../models/extra_content_item.dart';

/// Catalogo Extra locale — sostituire con fetch backend / acquisti.
abstract final class ExtraContentMock {
  static List<ExtraContentItem> get items =>
      List<ExtraContentItem>.unmodifiable(_items);

  static final List<ExtraContentItem> _items = [
    teoriaLezioni,
    guidaEsame,
    carteggio,
    pacchettoCompleto,
  ];

  static final ExtraContentItem teoriaLezioni = ExtraContentItem(
    id: ExtraContentIds.extraTeoria,
    title: 'Video corso lezioni teoriche',
    subtitle: 'Corso video dedicato alla preparazione teorica nautica.',
    description: 'Lezioni teoriche in video per affiancare corso in aula e ripasso.',
    fullDescription:
        'Percorso video dedicato alla preparazione teorica, utile per seguire le lezioni e '
        'ripassare gli argomenti principali del corso nautico.',
    type: ExtraContentType.teoriaTheoreticalVideos,
    isPremium: true,
    isUnlocked: false,
    isComingSoon: false,
    icon: Icons.school_outlined,
    lessonCount: null,
    durationLabel: null,
    priceLabel: '€ 49,00',
  );

  static final ExtraContentItem guidaEsame = ExtraContentItem(
    id: ExtraContentIds.extraGuida,
    title: 'Video preparazione esame di guida',
    subtitle: 'Contenuti video dedicati alla preparazione della prova pratica/guida.',
    description: 'Esercitazione e approccio all’esame pratico e alla guida in mare.',
    fullDescription:
        'Percorso video dedicato alla preparazione dell’esame di guida e delle prove pratiche, '
        'con spiegazioni orientate all’apprendimento operativo.',
    type: ExtraContentType.guidaPracticalVideos,
    isPremium: true,
    isUnlocked: false,
    isComingSoon: false,
    icon: Icons.sailing_outlined,
    lessonCount: null,
    durationLabel: null,
    priceLabel: '€ 39,00',
  );

  static final ExtraContentItem carteggio = ExtraContentItem(
    id: ExtraContentIds.extraCarteggio,
    title: 'Video corso carteggio',
    subtitle: 'Percorso video dedicato al carteggio nautico e agli esercizi pratici.',
    description: 'Carteggio: strumenti, tracciamento, lettura carta (contenuto a pagamento).',
    fullDescription:
        'Percorso video dedicato al carteggio nautico, con spiegazioni pratiche su tracciamento, '
        'lettura carta e impostazione degli esercizi.',
    type: ExtraContentType.carteggioCourseVideos,
    isPremium: true,
    isUnlocked: false,
    isComingSoon: false,
    icon: Icons.map_outlined,
    lessonCount: null,
    durationLabel: null,
    priceLabel: '€ 35,00',
  );

  static final ExtraContentItem pacchettoCompleto = ExtraContentItem(
    id: ExtraContentIds.extraPacchetto,
    title: 'Pacchetto completo',
    subtitle: 'Comprende teoria, guida e carteggio.',
    description: 'Accesso a tutti i percorsi video: teoria, guida, carteggio in un’unica offerta.',
    fullDescription:
        'Soluzione completa che include teoria, guida e carteggio in un unico percorso.',
    type: ExtraContentType.pacchettoFull,
    isPremium: true,
    isUnlocked: false,
    isComingSoon: false,
    icon: Icons.workspace_premium_outlined,
    lessonCount: null,
    durationLabel: null,
    priceLabel: '€ 99,00',
  );
}
