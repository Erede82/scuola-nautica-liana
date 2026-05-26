import 'package:flutter/material.dart';

import '../models/license_models.dart';

class LicenseCatalog {
  static const LicenseCategory defaultCategory = patenteMotore;

  static const LicenseCategory patenteMotore = LicenseCategory(
    id: LicenseCategoryId.motore,
    name: 'Entro le 12 miglia motore',
    isAvailable: true,
    lessons: [
      LessonItem(
        number: 1,
        title: '1. Teoria dello scafo',
        quizSheets: 24,
        icon: Icons.directions_boat_rounded,
      ),
      LessonItem(
        number: 2,
        title: '2. Motori endotermici',
        quizSheets: 24,
        icon: Icons.settings_rounded,
      ),
      LessonItem(
        number: 3,
        title: '3. Sicurezza 1: Alcool e droga - Dotazioni di sicurezza',
        quizSheets: 24,
        icon: Icons.health_and_safety_rounded,
      ),
      LessonItem(
        number: 4,
        title: '4. Manovre, ormeggio e ancoraggio',
        quizSheets: 28,
        icon: Icons.anchor_rounded,
      ),
      LessonItem(
        number: 5,
        title: '5. Sicurezza 2: Soccorso e incidenti',
        quizSheets: 20,
        icon: Icons.medical_services_rounded,
      ),
      LessonItem(
        number: 6,
        title: '6. COLRegs 1: Fanali',
        quizSheets: 20,
        icon: Icons.lightbulb_rounded,
      ),
      LessonItem(
        number: 7,
        title: '7. COLRegs 2: Segnalamenti marittimi e manovre',
        quizSheets: 36,
        icon: Icons.traffic_rounded,
      ),
      LessonItem(
        number: 8,
        title: '8. Meteorologia',
        quizSheets: 20,
        icon: Icons.cloud_rounded,
      ),
      LessonItem(
        number: 9,
        title: '9. Navigazione 1: Nozioni di base',
        quizSheets: 20,
        icon: Icons.explore_rounded,
      ),
      LessonItem(
        number: 10,
        title: '10. Navigazione 2: Carte nautiche e pubblicazioni nautiche',
        quizSheets: 16,
        icon: Icons.map_rounded,
      ),
      LessonItem(
        number: 11,
        title: '11. Navigazione 3: Strumentazione e introduzione carteggio',
        quizSheets: 28,
        icon: Icons.navigation_rounded,
      ),
      LessonItem(
        number: 12,
        title: '12. Navigazione 4: Carteggio',
        quizSheets: 16,
        icon: Icons.near_me_rounded,
      ),
      LessonItem(
        number: 13,
        title: '13. Normativa 1: Leggi e regolamenti - Patenti',
        quizSheets: 16,
        icon: Icons.gavel_rounded,
      ),
      LessonItem(
        number: 14,
        title: '14. Normativa 2: Documenti - Responsabilità',
        quizSheets: 36,
        icon: Icons.description_rounded,
      ),
    ],
  );

  /// Vela: percorso visibile in UI ma contenuti non ancora erogati (allineato prodotto).
  static const LicenseCategory patenteVela = LicenseCategory(
    id: LicenseCategoryId.vela,
    name: 'Patente a vela',
    isAvailable: false,
    comingSoonLabel: 'Contenuti vela in preparazione',
    lessons: [],
  );

  /// D1: stesso schema lezioni/schede del catalogo teoria motore entro 12 (chiavi `lesson_number` / `sheet_number` in DB).
  /// I titoli seguono il programma condiviso; distinzione operativa = `license_category` = `d1`.
  static final LicenseCategory patenteD1 = LicenseCategory(
    id: LicenseCategoryId.d1,
    name: 'Patente D1',
    isAvailable: true,
    comingSoonLabel: 'Disponibile prossimamente',
    lessons: patenteMotore.lessons,
  );

  static final List<LicenseCategory> all = [
    patenteMotore,
    patenteVela,
    patenteD1,
  ];

  static LicenseCategory byId(LicenseCategoryId id) {
    for (final category in all) {
      if (category.id == id) {
        return category;
      }
    }
    return defaultCategory;
  }
}
