import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../debug/quiz_flow_debug.dart';
import '../widgets/branded_app_bar_title.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import '../services/student_content_navigation.dart';
import 'assigned_quiz_list_page.dart';
import 'category_selection_page.dart';
import 'lesson_list_page.dart';
import 'multi_topic_quiz_setup_page.dart';
import 'quiz_exam_page.dart';
import 'quiz_statistics_review_hub_page.dart';
import '../theme/app_visual_tokens.dart';
import '../domain/multi_topic_quiz_support.dart';

class QuizDashboardPage extends StatefulWidget {
  const QuizDashboardPage({super.key});

  @override
  State<QuizDashboardPage> createState() => _QuizDashboardPageState();
}

class _QuizDashboardPageState extends State<QuizDashboardPage> {
  @override
  void initState() {
    super.initState();
    qfLog('route: QuizDashboardPage initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      qfLog('route: QuizDashboardPage first frame');
    });
  }

  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _primaryColor = AppVisual.logoBlue;

  /// Soglia (larghezza) per layout viewport-fit a 4 card (griglia 2×2).
  static const double _kDesktopNoScrollWidth = 800;

  /// Sotto questa larghezza: lista di card orizzontali (mobile).
  static const double _kHorizontalCardsWidth = 600;

  /// Altezza minima card orizzontali mobile (può crescere col testo).
  static const double _kHorizontalCardMinHeight = 96;

  /// Padding bottom lista mobile (escluso safe inset).
  static const double _kHorizontalListBottomPad = 14;

  List<Widget> _quizCardChildren({required bool horizontal}) {
    return [
      DashboardActionCard(
        dense: true,
        horizontal: horizontal,
        title: 'Lezioni e schede',
        subtitle: 'Percorso lezioni con schede quiz',
        icon: Icons.menu_book_rounded,
        useStudentBrandStyle: true,
        titleMaxLines: horizontal ? 2 : null,
        onTap: () {
          final categoryId =
              StudentContentNavigation.directLessonsCategoryForCurrentUser();
          if (categoryId != null) {
            qfLog('QuizDashboard: Lezioni dirette categoryId=$categoryId');
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => LessonListPage(categoryId: categoryId),
              ),
            );
            return;
          }
          qfLog(
            'QuizDashboard: tap "Lezioni e schede" → CategorySelection(lessons)',
          );
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CategorySelectionPage(
                destination: CategoryDestination.lessons,
              ),
            ),
          );
        },
      ),
      DashboardActionCard(
        dense: true,
        horizontal: horizontal,
        title: 'Multischede argomento',
        subtitle: 'Combina più argomenti e allenati con schede miste.',
        icon: Icons.layers_rounded,
        useStudentBrandStyle: true,
        titleMaxLines: 2,
        compactContent: !horizontal,
        onTap: () => _openMultiTopic(),
      ),
      DashboardActionCard(
        dense: true,
        horizontal: horizontal,
        title: 'Quiz esame',
        subtitle: 'Simulazioni e preparazione esame',
        icon: Icons.quiz_rounded,
        useStudentBrandStyle: true,
        titleMaxLines: horizontal ? 2 : null,
        onTap: () {
          final categoryId =
              StudentContentNavigation.directExamCategoryForCurrentUser();
          if (categoryId != null) {
            qfLog('QuizDashboard: Esame diretto categoryId=$categoryId');
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => QuizExamPage(categoryId: categoryId),
              ),
            );
            return;
          }
          qfLog(
            'QuizDashboard: tap "Quiz esame" → CategorySelection(quizExam)',
          );
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CategorySelectionPage(
                destination: CategoryDestination.quizExam,
              ),
            ),
          );
        },
      ),
      DashboardActionCard(
        dense: true,
        horizontal: horizontal,
        title: 'Statistiche e ripasso errori',
        subtitle: 'Controlla i risultati e rivedi le domande sbagliate.',
        icon: Icons.insights_outlined,
        useStudentBrandStyle: true,
        titleMaxLines: 2,
        compactContent: !horizontal,
        onTap: () {
          qfLog('QuizDashboard: tap Statistiche e ripasso errori');
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const QuizStatisticsReviewHubPage(),
            ),
          );
        },
      ),
      DashboardActionCard(
        dense: true,
        horizontal: horizontal,
        title: 'Quiz assegnati dalla scuola',
        subtitle:
            'Esercitazioni personalizzate preparate dalla scuola in base ai tuoi errori.',
        icon: Icons.assignment_turned_in_outlined,
        useStudentBrandStyle: true,
        titleMaxLines: 2,
        compactContent: !horizontal,
        onTap: () {
          qfLog('QuizDashboard: tap Quiz assegnati dalla scuola');
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const AssignedQuizListPage(),
            ),
          );
        },
      ),
    ];
  }

  void _openMultiTopic() {
    final categoryId =
        StudentContentNavigation.directLessonsCategoryForCurrentUser();
    if (categoryId != null) {
      if (!isMultiTopicCategorySupported(categoryId)) {
        qfLog('QuizDashboard: Multischeda non supportata per $categoryId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Multischeda disponibile solo per Patente Motore (A12) e D1.',
            ),
          ),
        );
        return;
      }
      qfLog('QuizDashboard: Multischeda diretta categoryId=$categoryId');
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => MultiTopicQuizSetupPage(categoryId: categoryId),
        ),
      );
      return;
    }
    qfLog('QuizDashboard: tap Multischede → CategorySelection(multiTopic)');
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const CategorySelectionPage(
          destination: CategoryDestination.multiTopic,
        ),
      ),
    );
  }

  Widget _introText(TextStyle? base, double maxWidth) {
    final wideDesktop = maxWidth >= 900;
    return Center(
      child: Text(
        'Percorso di studio, esame, quiz assegnati, statistiche e ripasso errori.',
        textAlign: TextAlign.center,
        style: base?.copyWith(
          color: _textPrimaryColor.withValues(alpha: 0.9),
          height: maxWidth >= 700 ? 1.28 : 1.35,
          fontSize: wideDesktop ? 14 : (maxWidth >= 800 ? 14.5 : null),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        toolbarHeight: 58,
        title: const SectionAppBarTitle('Quiz', logoHeight: 30),
        actions: const [StaffPreviewAppBarBadge()],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final useHorizontalCards = c.maxWidth < _kHorizontalCardsWidth;
          final cards = _quizCardChildren(horizontal: useHorizontalCards);
          final useViewportFit =
              !useHorizontalCards &&
              c.maxWidth >= _kDesktopNoScrollWidth &&
              cards.length <= 4;

          if (useHorizontalCards) {
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                _kHorizontalListBottomPad + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _introText(textTheme.bodyMedium, c.maxWidth),
                  const SizedBox(height: 12),
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _kHorizontalCardMinHeight,
                      ),
                      child: cards[i],
                    ),
                  ],
                ],
              ),
            );
          }

          if (useViewportFit) {
            const mainGap = 6.0;
            const crossGap = 8.0;
            final contentMaxW = math.min(660.0, c.maxWidth - 32);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _introText(textTheme.bodyMedium, c.maxWidth),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: contentMaxW),
                        child: LayoutBuilder(
                          builder: (context, g) {
                            final w = g.maxWidth;
                            final h = g.maxHeight;
                            final cellW = (w - crossGap) / 2.0;
                            final cellH = (h - mainGap) / 2.0;
                            final aspect = (cellW / cellH)
                                .clamp(0.5, 2.5)
                                .toDouble();
                            return GridView(
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: mainGap,
                                    crossAxisSpacing: crossGap,
                                    childAspectRatio: aspect,
                                  ),
                              children: cards,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Tablet / stretto desktop: griglia a contenuto e scroll.
          final wideDesktop = c.maxWidth >= 900;
          final laptop = c.maxWidth >= 700;
          final double aspect;
          if (wideDesktop) {
            aspect = 1.72;
          } else if (c.maxWidth >= 600) {
            aspect = 1.28;
          } else {
            aspect = 1.05;
          }
          final contentMaxW = laptop
              ? math.min(660.0, c.maxWidth - 32)
              : math.min(720.0, c.maxWidth - 32);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              laptop ? 8 : 10,
              16,
              laptop ? 10 : 14,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _introText(textTheme.bodyMedium, c.maxWidth),
                    SizedBox(height: laptop ? 8 : 12),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: laptop ? 6 : 8,
                        crossAxisSpacing: laptop ? 8 : 10,
                        childAspectRatio: aspect,
                      ),
                      children: cards,
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
