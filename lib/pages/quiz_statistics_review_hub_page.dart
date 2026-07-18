import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../debug/quiz_flow_debug.dart';
import '../services/student_content_navigation.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/branded_app_bar_title.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import 'category_selection_page.dart';
import 'error_review_page.dart';
import 'statistics_page.dart';

/// Hub intermedio tra la dashboard Quiz e le pagine Statistiche / Ripasso errori.
///
/// Non carica dati: espone soltanto le due azioni già presenti in dashboard.
class QuizStatisticsReviewHubPage extends StatelessWidget {
  const QuizStatisticsReviewHubPage({super.key});

  void _openStatistics(BuildContext context) {
    qfLog('QuizStatsReviewHub: tap Statistiche');
    final categoryId =
        StudentContentNavigation.directStatisticsCategoryForCurrentUser();
    if (categoryId != null) {
      qfLog('QuizStatsReviewHub: Statistiche dirette categoryId=$categoryId');
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => StatisticsPage(categoryId: categoryId),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const CategorySelectionPage(
          destination: CategoryDestination.statistics,
        ),
      ),
    );
  }

  void _openErrorReview(BuildContext context) {
    qfLog('QuizStatsReviewHub: tap Ripasso errori');
    final categoryId =
        StudentContentNavigation.directErrorReviewCategoryForCurrentUser();
    if (categoryId != null) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ErrorReviewPage(categoryId: categoryId),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const ErrorReviewPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppVisual.canvas,
      appBar: AppBar(
        backgroundColor: AppVisual.logoBlue,
        foregroundColor: Colors.white,
        title: const SectionAppBarTitle(
          'Statistiche e ripasso errori',
          logoHeight: 28,
        ),
        actions: const [StaffPreviewAppBarBadge()],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          final contentMaxW = wide
              ? math.min(720.0, constraints.maxWidth - 32)
              : math.min(560.0, constraints.maxWidth - 32);

          final cards = [
            DashboardActionCard(
              dense: true,
              title: 'Statistiche',
              subtitle:
                  'Visualizza risultati, andamento e argomenti da rinforzare.',
              icon: Icons.bar_chart_rounded,
              useStudentBrandStyle: true,
              titleMaxLines: 2,
              onTap: () => _openStatistics(context),
            ),
            DashboardActionCard(
              dense: true,
              title: 'Ripasso errori',
              subtitle:
                  'Rivedi le domande sbagliate e prova a rispondere nuovamente.',
              icon: Icons.fact_check_outlined,
              useStudentBrandStyle: true,
              titleMaxLines: 2,
              onTap: () => _openErrorReview(context),
            ),
          ];

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, wide ? 16 : 14, 16, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Controlla i tuoi risultati oppure rivedi le domande '
                      'in cui hai commesso errori.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppVisual.ink.withValues(alpha: 0.88),
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: wide ? 20 : 16),
                    if (wide)
                      SizedBox(
                        height: 200,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cards[0]),
                            const SizedBox(width: 12),
                            Expanded(child: cards[1]),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          SizedBox(height: 168, child: cards[0]),
                          const SizedBox(height: 12),
                          SizedBox(height: 168, child: cards[1]),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
