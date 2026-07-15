import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../domain/quiz_license_category.dart';
import '../models/license_models.dart';
import '../models/quiz_category_statistics.dart';
import '../pages/lesson_list_page.dart';
import '../repositories/quiz_statistics_repository.dart';
import '../services/error_review_provider.dart';
import '../services/student_area_context.dart';
import '../widgets/category_content_state.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import '../widgets/statistics_lesson_error_chart.dart';
import '../widgets/statistics_recent_attempts_section.dart';
import '../widgets/statistics_recommended_review_section.dart';
import '../widgets/statistics_summary_section.dart';
import '../widgets/statistics_topic_progress_section.dart';
import '../theme/app_visual_tokens.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.categoryId, this.repository});

  final LicenseCategoryId categoryId;
  final QuizStatisticsRepository? repository;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _warningColor = Color(0xFFC75D3A);

  late final QuizStatisticsRepository _repository;
  QuizCategoryStatistics? _statistics;
  bool _loading = false;
  bool _refreshing = false;
  bool _unauthenticated = false;
  Object? _loadError;
  int _loadGeneration = 0;

  LicenseCategory get _category => LicenseCatalog.byId(widget.categoryId);

  bool get _categorySupportsStatistics =>
      _category.isAvailable && dbLicenseCategoryFor(widget.categoryId) != null;

  bool get _isStaffPreview => StudentAreaContext.of(context).isStaffPreview;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? quizStatisticsRepository;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadStatistics());
  }

  Future<void> _maybeLoadStatistics({bool isRefresh = false}) async {
    if (!mounted || _isStaffPreview || !_categorySupportsStatistics) return;
    await _loadStatistics(isRefresh: isRefresh);
  }

  Future<void> _loadStatistics({bool isRefresh = false}) async {
    if (!mounted || _isStaffPreview || !_categorySupportsStatistics) return;

    final generation = ++_loadGeneration;

    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _loadError = null;
      _unauthenticated = false;
    });

    try {
      final stats = await _repository.fetchCategoryStatistics(
        categoryId: widget.categoryId,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _statistics = stats;
        _loading = false;
        _refreshing = false;
      });
    } on QuizStatisticsUnauthenticatedException {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _unauthenticated = true;
        _statistics = null;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadError = error;
        _statistics = null;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _openLessons() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LessonListPage(categoryId: widget.categoryId),
      ),
    );
  }

  String get _appBarTitle {
    return widget.categoryId == LicenseCategoryId.d1
        ? 'Statistiche · Patente D1'
        : 'Statistiche';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(_appBarTitle),
        centerTitle: true,
        actions: [
          const StaffPreviewAppBarBadge(),
          if (!_isStaffPreview && _categorySupportsStatistics)
            IconButton(
              tooltip: 'Aggiorna',
              onPressed: _loading || _refreshing
                  ? null
                  : () => _loadStatistics(isRefresh: true),
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: _buildBody(textTheme),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_isStaffPreview) {
      return _buildStaffPreviewState(textTheme);
    }

    if (!_category.isAvailable) {
      return CategoryContentState(
        category: _category,
        availableTitle: 'Statistiche — ${_category.name}',
        availableMessage:
            'Le statistiche di ${_category.name} verranno visualizzate qui.\n\n'
            'Gli stessi andamenti alimenteranno anche Ripasso errori nella sezione Quiz '
            'quando saranno collegati al tuo account.',
        unavailableTitle: null,
        unavailableMessage: widget.categoryId == LicenseCategoryId.vela
            ? 'Le statistiche per questo percorso non sono ancora disponibili.'
            : null,
        unavailableIcon: Icons.insights_rounded,
      );
    }

    if (!_categorySupportsStatistics) {
      return _messageCard(
        textTheme,
        title: 'Statistiche non disponibili',
        message:
            'Le statistiche per questo percorso non sono ancora disponibili.',
        icon: Icons.insights_rounded,
      );
    }

    if (_loading && _statistics == null) {
      return _buildLoadingState(textTheme);
    }

    if (_unauthenticated) {
      return _messageCard(
        textTheme,
        title: 'Sessione non disponibile',
        message: 'La sessione non è disponibile. Accedi nuovamente.',
        icon: Icons.lock_outline_rounded,
      );
    }

    if (_loadError != null) {
      return _messageCard(
        textTheme,
        title: 'Errore di caricamento',
        message: 'Non è stato possibile caricare le statistiche.',
        icon: Icons.cloud_off_rounded,
        primaryActionLabel: 'Riprova',
        onPrimaryAction: () => _loadStatistics(),
        secondaryActionLabel: 'Indietro',
        onSecondaryAction: () => Navigator.maybePop(context),
      );
    }

    final stats = _statistics;
    if (stats == null) {
      return _buildLoadingState(textTheme);
    }

    if (!stats.hasData && stats.hasIgnoredAttempts) {
      return _messageCard(
        textTheme,
        title: 'Tentativi non inclusi',
        message:
            'Alcuni tentativi non possono essere inclusi nelle statistiche.',
        icon: Icons.warning_amber_rounded,
        primaryActionLabel: 'Riprova',
        onPrimaryAction: () => _loadStatistics(isRefresh: true),
      );
    }

    if (!stats.showDashboard) {
      return _messageCard(
        textTheme,
        title: 'Nessuna scheda completata',
        message: 'Non hai ancora completato schede per questo percorso.',
        icon: Icons.query_stats_rounded,
        primaryActionLabel: 'Vai alle schede',
        onPrimaryAction: _openLessons,
      );
    }

    final reviewData = ErrorReviewProvider.buildViewDataFromSnapshots(
      categoryId: widget.categoryId,
      snapshots: stats.lessonSnapshots,
    );

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: () => _loadStatistics(isRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          StatisticsSummarySection(
            summary: stats.summary,
            progress: stats.progress,
            recentAttempts: stats.recentAttempts,
          ),
          if (stats.progress.lessonProgress.isNotEmpty)
            StatisticsTopicProgressSection(
              lessonProgress: stats.progress.lessonProgress,
            ),
          if (stats.summary.ignoredIncompleteAttempts > 0)
            _ignoredAttemptsNote(
              textTheme,
              stats.summary.ignoredIncompleteAttempts,
            ),
          if (stats.hasData)
            StatisticsRecommendedReviewSection(
              categoryId: widget.categoryId,
              viewData: reviewData,
            ),
          if (stats.hasData)
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
                child: StatisticsLessonErrorChart(
                  lessonSnapshots: stats.lessonSnapshots,
                  showLocalEmptyMessage: stats.lessonSnapshots.isEmpty,
                ),
              ),
            ),
          if (stats.hasData)
            StatisticsRecentAttemptsSection(attempts: stats.recentAttempts),
        ],
      ),
    );
  }

  Widget _buildLoadingState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            Text(
              'Caricamento statistiche…',
              textAlign: TextAlign.center,
              style: textTheme.titleSmall?.copyWith(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffPreviewState(TextTheme textTheme) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        _messageCard(
          textTheme,
          title: 'Statistiche allievo',
          message:
              'Le statistiche reali saranno disponibili quando l’anteprima verrà '
              'aperta per uno specifico allievo.',
          icon: Icons.bar_chart_rounded,
        ),
      ],
    );
  }

  Widget _ignoredAttemptsNote(TextTheme textTheme, int ignoredCount) {
    final label = ignoredCount == 1
        ? '1 tentativo incompleto non incluso.'
        : '$ignoredCount tentativi incompleti non inclusi.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _warningColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _warningColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: _warningColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Alcuni tentativi incompleti non sono stati inclusi. $label',
                style: textTheme.bodySmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.88),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageCard(
    TextTheme textTheme, {
    required String title,
    required String message,
    required IconData icon,
    String? primaryActionLabel,
    VoidCallback? onPrimaryAction,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _neutralColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 36,
                color: _primaryColor.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.84),
                  height: 1.45,
                ),
              ),
              if (primaryActionLabel != null && onPrimaryAction != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPrimaryAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      primaryActionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
