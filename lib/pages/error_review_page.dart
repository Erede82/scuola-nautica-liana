import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../models/error_review_recommendation.dart';
import '../models/license_models.dart';
import '../repositories/study_access_repository.dart';
import '../services/error_review_provider.dart';
import '../widgets/app_empty_state.dart';
import 'lesson_quiz_list_page.dart';
import 'quiz_dashboard_page.dart';
import 'statistics_page.dart';
import '../theme/app_visual_tokens.dart';

/// Ripasso errori: suggerimenti derivati dalle performance quiz (mock locale → pronto per backend).
class ErrorReviewPage extends StatefulWidget {
  const ErrorReviewPage({
    super.key,
    this.initialCategoryId = LicenseCategoryId.motore,
  });

  final LicenseCategoryId initialCategoryId;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  State<ErrorReviewPage> createState() => _ErrorReviewPageState();
}

class _ErrorReviewPageState extends State<ErrorReviewPage> {
  late LicenseCategoryId _categoryId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCategoryId;
    _categoryId = LicenseCatalog.byId(initial).isAvailable
        ? initial
        : LicenseCategoryId.motore;
  }

  void _onCategoryChanged(LicenseCategoryId? id) {
    if (id == null) return;
    setState(() => _categoryId = id);
  }

  void _handleCta(BuildContext context, ErrorReviewRecommendation r) {
    if (!r.isSchoolUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r.schoolLockMessage.isNotEmpty
                ? r.schoolLockMessage
                : 'La scuola ti abiliterà questo ripasso quando opportuno.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    switch (r.ctaKind) {
      case ErrorReviewCtaKind.openLessonSheets:
      case ErrorReviewCtaKind.reviewTopic:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => LessonQuizListPage(
              lessonNumber: r.lessonNumber,
              categoryId: r.linkedCategory,
            ),
          ),
        );
        break;
      case ErrorReviewCtaKind.openQuizHome:
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const QuizDashboardPage(),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studyAccessListenable,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        final category = LicenseCatalog.byId(_categoryId);
        final viewData = ErrorReviewProvider.buildViewData(_categoryId);
        final headerSubtitle = _categoryId == LicenseCategoryId.d1
            ? 'Ripasso D1 — rafforza la preparazione sui temi da migliorare'
            : 'Rafforza la preparazione sui temi da migliorare';

        return Scaffold(
      backgroundColor: ErrorReviewPage._backgroundColor,
      appBar: AppBar(
        backgroundColor: ErrorReviewPage._primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Ripasso errori'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _HeaderSummaryCard(
                textTheme: textTheme,
                subtitle: headerSubtitle,
                categoryName: category.name,
                totalAttempts: viewData.totalAttemptsAcrossLessons,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _CategorySelectorBar(
                value: _categoryId,
                onChanged: _onCategoryChanged,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'I suggerimenti si basano su percentuali di errore simili a quelle '
                'che vedrai in Statistiche quando saranno collegate al tuo storico quiz.',
                style: textTheme.bodySmall?.copyWith(
                  color: ErrorReviewPage._textPrimaryColor.withValues(alpha: 0.78),
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (viewData.hasRecommendations)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: _SchoolGateInfoCard(
                  textTheme: textTheme,
                  allTopicsLocked: viewData.allRecommendedTopicsLocked,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            StatisticsPage(categoryId: _categoryId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.insights_rounded, size: 20),
                  label: const Text('Apri statistiche per questa categoria'),
                ),
              ),
            ),
          ),
          if (viewData.hasRecommendations) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Aree consigliate',
                  style: textTheme.titleMedium?.copyWith(
                    color: ErrorReviewPage._textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final r = viewData.recommendations[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecommendationCard(
                        recommendation: r,
                        onCta: () => _handleCta(context, r),
                      ),
                    );
                  },
                  childCount: viewData.recommendations.length,
                ),
              ),
            ),
          ] else ...[
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: _EmptyBody(
                  kind: viewData.emptyKind!,
                  categoryName: category.name,
                  categoryId: _categoryId,
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: _FooterNote(textTheme: textTheme),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _HeaderSummaryCard extends StatelessWidget {
  const _HeaderSummaryCard({
    required this.textTheme,
    required this.subtitle,
    required this.categoryName,
    required this.totalAttempts,
  });

  final TextTheme textTheme;
  final String subtitle;
  final String categoryName;
  final int totalAttempts;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor,
            _primaryColor.withValues(alpha: 0.92),
            _accentColor.withValues(alpha: 0.72),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.fact_check_rounded,
                  color: Colors.white.withValues(alpha: 0.96),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      style: textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      categoryName,
                      style: textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            totalAttempts > 0
                ? 'Dati sintetici da $totalAttempts tentativi sulle schede quiz '
                    '(esempio locale, allineato al catalogo lezioni).'
                : 'Non risultano ancora tentativi per questa categoria: svolgi qualche '
                    'scheda quiz per generare suggerimenti mirati.',
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'L’accesso ai contenuti di ripasso è abilitato dalla scuola: '
            'vedrai “Sbloccato dalla scuola” sugli argomenti già assegnati.',
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolGateInfoCard extends StatelessWidget {
  const _SchoolGateInfoCard({
    required this.textTheme,
    required this.allTopicsLocked,
  });

  final TextTheme textTheme;
  final bool allTopicsLocked;

  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _warnColor = Color(0xFFC27C1C);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _neutralColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            color: allTopicsLocked ? _warnColor : _textPrimaryColor.withValues(alpha: 0.75),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              allTopicsLocked
                  ? 'Tutti gli argomenti sotto sono consigliati dalle statistiche, '
                      'ma sono ancora in attesa di abilitazione da parte della scuola.'
                  : 'Alcuni argomenti possono essere ancora bloccati: il suggerimento '
                      'indica cosa ripassare, mentre la scuola decide quando sbloccare il materiale.',
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.88),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySelectorBar extends StatelessWidget {
  const _CategorySelectorBar({
    required this.value,
    required this.onChanged,
  });

  final LicenseCategoryId value;
  final void Function(LicenseCategoryId?) onChanged;

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _neutralColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LicenseCategoryId>(
          isExpanded: true,
          value: value,
          borderRadius: BorderRadius.circular(12),
          hint: const Text('Categoria patente'),
          items: LicenseCatalog.all
              .where((c) => c.isAvailable)
              .map(
                (c) => DropdownMenuItem<LicenseCategoryId>(
                  value: c.id,
                  child: Text(
                    c.name,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.recommendation,
    required this.onCta,
  });

  final ErrorReviewRecommendation recommendation;
  final VoidCallback onCta;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _successColor = Color(0xFF2E9E5B);
  static const Color _errorTint = Color(0xFFD64545);
  static const Color _warnColor = Color(0xFFC27C1C);

  Color _badgeColor(ErrorReviewPriority p) {
    switch (p) {
      case ErrorReviewPriority.high:
        return _errorTint.withValues(alpha: 0.12);
      case ErrorReviewPriority.medium:
        return _warnColor.withValues(alpha: 0.15);
      case ErrorReviewPriority.low:
        return _successColor.withValues(alpha: 0.14);
    }
  }

  Color _badgeFg(ErrorReviewPriority p) {
    switch (p) {
      case ErrorReviewPriority.high:
        return _errorTint;
      case ErrorReviewPriority.medium:
        return _warnColor;
      case ErrorReviewPriority.low:
        return _successColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final r = recommendation;
    final pct = r.averageErrorPercentage;
    final pctLabel =
        pct >= 10 ? '${pct.round()}%' : '${pct.toStringAsFixed(1)}%';

    return Material(
      color: _cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _neutralColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Expanded(
                  child: Text(
                    r.recommendationTitle,
                    style: textTheme.titleSmall?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _badgeColor(r.priority),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    r.priority.badgeLabel,
                    style: textTheme.labelSmall?.copyWith(
                      color: _badgeFg(r.priority),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _neutralColor),
                  ),
                  child: Text(
                    'Argomento consigliato',
                    style: textTheme.labelSmall?.copyWith(
                      color: _primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: r.isSchoolUnlocked
                        ? _successColor.withValues(alpha: 0.16)
                        : _warnColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: r.isSchoolUnlocked
                          ? _successColor.withValues(alpha: 0.35)
                          : _warnColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    r.isSchoolUnlocked
                        ? 'Sbloccato dalla scuola'
                        : 'Disponibile su assegnazione della scuola',
                    style: textTheme.labelSmall?.copyWith(
                      color: r.isSchoolUnlocked ? _successColor : _warnColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              r.lessonTitle,
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.trending_down_rounded,
                  size: 20,
                  color: _primaryColor.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  'Errori medi: $pctLabel',
                  style: textTheme.titleSmall?.copyWith(
                    color: _primaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              r.recommendationMessage,
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.88),
                height: 1.45,
              ),
            ),
            if (!r.isSchoolUnlocked) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _warnColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _warnColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  r.schoolLockMessage,
                  style: textTheme.bodySmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.9),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onCta,
                style: FilledButton.styleFrom(
                  foregroundColor:
                      r.isSchoolUnlocked ? _primaryColor : _warnColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  r.isSchoolUnlocked ? r.ctaLabel : 'Disponibile su assegnazione della scuola',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    required this.kind,
    required this.categoryName,
    required this.categoryId,
  });

  final ErrorReviewEmptyKind kind;
  final String categoryName;
  final LicenseCategoryId categoryId;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case ErrorReviewEmptyKind.noQuizData:
        return AppEmptyState(
          title: 'Nessun dato disponibile',
          message:
              'Completa alcuni quiz per ricevere suggerimenti di ripasso '
              'basati sulle tue risposte.',
          icon: Icons.query_stats_rounded,
          tagLabel: 'Statistiche',
          primaryActionLabel: 'Vai ai quiz',
          primaryActionIcon: Icons.quiz_rounded,
          onPrimaryActionPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const QuizDashboardPage(),
              ),
            );
          },
        );
      case ErrorReviewEmptyKind.allClear:
        return AppEmptyState(
          title: 'Ottimo lavoro',
          message:
              'Al momento non ci sono aree critiche da ripassare per $categoryName '
              'in base ai dati disponibili.',
          icon: Icons.sentiment_satisfied_rounded,
          tagLabel: 'Tutto in ordine',
          primaryActionLabel: 'Vedi statistiche',
          primaryActionIcon: Icons.bar_chart_rounded,
          onPrimaryActionPressed: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => StatisticsPage(categoryId: categoryId),
              ),
            );
          },
        );
    }
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote({required this.textTheme});

  final TextTheme textTheme;

  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _successColor = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _neutralColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_outlined,
            color: _successColor.withValues(alpha: 0.95),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ripasso errori · incluso nel percorso Quiz',
                  style: textTheme.labelMedium?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Quando le statistiche saranno online, questo elenco si aggiornerà '
                  'dal tuo profilo; gli accessi al materiale restano assegnati dalla scuola, '
                  'come per le schede quiz e il quiz esame.',
                  style: textTheme.bodySmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.85),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
