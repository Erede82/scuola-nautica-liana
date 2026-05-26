import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../models/license_models.dart';
import '../widgets/category_content_state.dart';
import '../widgets/statistics_lesson_error_chart.dart';
import '../widgets/statistics_recommended_review_section.dart';
import '../theme/app_visual_tokens.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key, this.categoryId = LicenseCategoryId.motore});

  final LicenseCategoryId categoryId;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final category = LicenseCatalog.byId(categoryId);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          categoryId == LicenseCategoryId.d1
              ? 'Statistiche · Patente D1'
              : 'Statistiche',
        ),
        centerTitle: true,
      ),
      body: !category.isAvailable
          ? CategoryContentState(
              category: category,
              availableTitle: 'Statistiche — ${category.name}',
              availableMessage:
                  'Le statistiche di ${category.name} verranno visualizzate qui.\n\n'
                  'Gli stessi andamenti alimenteranno anche Ripasso errori nella sezione Quiz '
                  'quando saranno collegati al tuo account.',
              availableIcon: Icons.bar_chart_rounded,
              unavailableTitle: null,
              unavailableMessage: null,
              unavailableIcon: Icons.insights_rounded,
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                StatisticsRecommendedReviewSection(categoryId: category.id),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _neutralColor),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: StatisticsLessonErrorChart(categoryId: categoryId),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _neutralColor),
                    ),
                    child: Column(
                      children: [
                        Text(
                          categoryId == LicenseCategoryId.d1
                              ? 'Percorso D1'
                              : 'Il tuo andamento',
                          textAlign: TextAlign.center,
                          style: textTheme.titleSmall?.copyWith(
                            color: _textPrimaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          categoryId == LicenseCategoryId.d1
                              ? 'Grafico e raccomandazioni usano le lezioni del programma teorico condiviso. '
                                  'I dati effettivi si aggiorneranno con lo storico quiz collegato al tuo account.'
                              : 'Le statistiche riflettono tutte le lezioni del catalogo attivo. '
                                  'Ripasso errori (Quiz) usa gli stessi criteri sulle aree più delicate.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: _textPrimaryColor.withOpacity(0.84),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
