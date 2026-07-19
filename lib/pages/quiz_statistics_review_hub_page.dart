import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../debug/quiz_flow_debug.dart';
import '../services/student_content_navigation.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/branded_app_bar_title.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import 'category_selection_page.dart';
import 'error_review_page.dart';
import 'statistics_page.dart';

/// Chiave del contenitore unico (macro-card) nella pagina hub.
@visibleForTesting
const Key quizStatisticsReviewHubMacroCardKey = Key(
  'quiz_statistics_review_hub_macro_card',
);

/// Hub intermedio tra la dashboard Quiz e le pagine Statistiche / Ripasso errori.
///
/// Non carica dati: espone soltanto le due azioni in una macro-card ampia.
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
              ? math.min(760.0, constraints.maxWidth - 32)
              : math.min(560.0, constraints.maxWidth - 32);

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, wide ? 20 : 16, 16, 28),
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
                    SizedBox(height: wide ? 24 : 18),
                    _StatsReviewMacroCard(
                      wide: wide,
                      onStatistics: () => _openStatistics(context),
                      onErrorReview: () => _openErrorReview(context),
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

class _StatsReviewMacroCard extends StatelessWidget {
  const _StatsReviewMacroCard({
    required this.wide,
    required this.onStatistics,
    required this.onErrorReview,
  });

  final bool wide;
  final VoidCallback onStatistics;
  final VoidCallback onErrorReview;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: quizStatisticsReviewHubMacroCardKey,
      decoration: BoxDecoration(
        color: AppVisual.ivory,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppVisual.logoBlue.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppVisual.ink.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: wide
              ? SizedBox(
                  height: 256,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _HubActionPane(
                          semanticsLabel: 'Statistiche',
                          icon: Icons.bar_chart_rounded,
                          title: 'Statistiche',
                          subtitle:
                              'Visualizza risultati, andamento e argomenti '
                              'da rinforzare.',
                          onTap: onStatistics,
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: AppVisual.logoBlue.withValues(alpha: 0.16),
                      ),
                      Expanded(
                        child: _HubActionPane(
                          semanticsLabel: 'Ripasso errori',
                          icon: Icons.fact_check_outlined,
                          title: 'Ripasso errori',
                          subtitle:
                              'Rivedi le domande sbagliate e prova a '
                              'rispondere nuovamente.',
                          onTap: onErrorReview,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _HubActionPane(
                      semanticsLabel: 'Statistiche',
                      icon: Icons.bar_chart_rounded,
                      title: 'Statistiche',
                      subtitle:
                          'Visualizza risultati, andamento e argomenti '
                          'da rinforzare.',
                      onTap: onStatistics,
                      minHeight: 148,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppVisual.logoBlue.withValues(alpha: 0.16),
                    ),
                    _HubActionPane(
                      semanticsLabel: 'Ripasso errori',
                      icon: Icons.fact_check_outlined,
                      title: 'Ripasso errori',
                      subtitle:
                          'Rivedi le domande sbagliate e prova a '
                          'rispondere nuovamente.',
                      onTap: onErrorReview,
                      minHeight: 148,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HubActionPane extends StatefulWidget {
  const _HubActionPane({
    required this.semanticsLabel,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.minHeight,
  });

  final String semanticsLabel;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double? minHeight;

  @override
  State<_HubActionPane> createState() => _HubActionPaneState();
}

class _HubActionPaneState extends State<_HubActionPane> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final highlight = _hovered || _focused;

    return Semantics(
      button: true,
      label: widget.semanticsLabel,
      child: FocusableActionDetector(
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: Material(
          color: highlight
              ? AppVisual.logoBlue.withValues(alpha: 0.06)
              : Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return AppVisual.logoBlue.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return AppVisual.logoBlue.withValues(alpha: 0.07);
              }
              return null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              constraints: BoxConstraints(minHeight: widget.minHeight ?? 0),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
              decoration: BoxDecoration(
                border: _focused
                    ? Border.all(
                        color: AppVisual.logoBlue.withValues(alpha: 0.55),
                        width: 2,
                      )
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppVisual.logoBlue,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppVisual.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppVisual.ink.withValues(alpha: 0.82),
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
