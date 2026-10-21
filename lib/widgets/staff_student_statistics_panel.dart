import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../domain/quiz_license_category.dart';
import '../domain/student_quiz_statistics_models.dart';
import '../domain/student_stats_source.dart';
import '../models/license_models.dart';
import '../repositories/staff_student_quiz_statistics_repository.dart';
import '../theme/app_visual_tokens.dart';
import 'student_quiz_statistics_dashboard.dart';

/// Pannello READ-ONLY Statistiche allievo (Accessi studio / riusabile).
class StaffStudentStatisticsPanel extends StatefulWidget {
  const StaffStudentStatisticsPanel({
    super.key,
    required this.studentId,
    required this.categoryId,
    this.repository,
    this.active = true,
  });

  /// `public.students.id`
  final String studentId;
  final LicenseCategoryId categoryId;
  final StaffStudentQuizStatisticsRepository? repository;

  /// Se false, non carica (lazy tab).
  final bool active;

  @override
  State<StaffStudentStatisticsPanel> createState() =>
      _StaffStudentStatisticsPanelState();
}

class _StaffStudentStatisticsPanelState
    extends State<StaffStudentStatisticsPanel> {
  static const Color _primary = AppVisual.logoBlue;
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _border = AppVisual.chipFill;
  static const Color _ink = AppVisual.ink;

  late final StaffStudentQuizStatisticsRepository _repository;
  int _loadGen = 0;
  bool _loading = false;
  bool _refreshing = false;
  StaffStudentQuizStatisticsResult? _result;
  StudentStatsSource _reviewSource = StudentStatsSource.all;
  StudentStatsSource _topicSource = StudentStatsSource.all;

  String? _loadedStudentId;
  LicenseCategoryId? _loadedCategoryId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? staffStudentQuizStatisticsRepository;
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
    }
  }

  @override
  void didUpdateWidget(covariant StaffStudentStatisticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final identityChanged =
        oldWidget.studentId != widget.studentId ||
        oldWidget.categoryId != widget.categoryId;
    if (identityChanged) {
      _loadedStudentId = null;
      _loadedCategoryId = null;
      _result = null;
    }
    if (widget.active &&
        (identityChanged ||
            !oldWidget.active ||
            _loadedStudentId != widget.studentId ||
            _loadedCategoryId != widget.categoryId)) {
      _ensureLoaded();
    }
  }

  Future<void> _ensureLoaded({bool isRefresh = false}) async {
    if (!mounted || !widget.active) return;
    if (!isRefresh &&
        _loadedStudentId == widget.studentId &&
        _loadedCategoryId == widget.categoryId &&
        _result != null &&
        !_loading) {
      return;
    }
    await _load(isRefresh: isRefresh);
  }

  Future<void> _load({bool isRefresh = false}) async {
    if (!mounted) return;
    final gen = ++_loadGen;
    final studentId = widget.studentId;
    final categoryId = widget.categoryId;

    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
    });

    final result = await _repository.fetchStudentCategoryStatistics(
      studentId: studentId,
      categoryId: categoryId,
    );

    if (!mounted || gen != _loadGen) return;
    if (studentId != widget.studentId || categoryId != widget.categoryId) {
      return;
    }

    setState(() {
      _result = result;
      _loadedStudentId = studentId;
      _loadedCategoryId = categoryId;
      _loading = false;
      _refreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final category = LicenseCatalog.byId(widget.categoryId);
    final dbCat = dbLicenseCategoryFor(widget.categoryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dbCat == null
                      ? 'Statistiche quiz'
                      : 'Statistiche quiz · $dbCat',
                  style: textTheme.titleSmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Aggiorna',
                onPressed: !widget.active || _loading || _refreshing
                    ? null
                    : () => _ensureLoaded(isRefresh: true),
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody(textTheme, category)),
      ],
    );
  }

  Widget _buildBody(TextTheme textTheme, LicenseCategory category) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }

    if (_loading && _result == null) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    final result = _result;
    if (result == null) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    return switch (result) {
      StaffStudentQuizStatisticsUnsupportedCategory() => _message(
        textTheme,
        title: 'Statistiche non disponibili',
        message: 'Statistiche quiz non disponibili per questa categoria.',
        icon: Icons.insights_rounded,
      ),
      StaffStudentQuizStatisticsUnlinked() => _message(
        textTheme,
        title: 'Nessuna attività quiz',
        message: 'Nessuna attività quiz collegata a questo allievo.',
        icon: Icons.link_off_rounded,
      ),
      StaffStudentQuizStatisticsNotAuthorized() => _message(
        textTheme,
        title: 'Permesso insufficiente',
        message: 'Non sei autorizzato a visualizzare queste statistiche.',
        icon: Icons.lock_outline_rounded,
      ),
      StaffStudentQuizStatisticsStudentNotFound() => _message(
        textTheme,
        title: 'Allievo non disponibile',
        message: 'Allievo non più disponibile.',
        icon: Icons.person_off_outlined,
      ),
      StaffStudentQuizStatisticsFailure() => _message(
        textTheme,
        title: 'Errore di caricamento',
        message: 'Non è stato possibile caricare le statistiche.',
        icon: Icons.cloud_off_rounded,
        actionLabel: 'Riprova',
        onAction: () => _ensureLoaded(isRefresh: true),
      ),
      StaffStudentQuizStatisticsLoaded(:final statistics) =>
        _buildLoaded(textTheme, statistics),
    };
  }

  Widget _buildLoaded(TextTheme textTheme, StudentQuizStatistics stats) {
    final ignored =
        stats.ignoredIncompleteLessonAttempts +
        stats.ignoredIncompleteMultiAttempts +
        stats.ignoredIncompleteExamAttempts;

    if (!stats.hasAnyActivity && ignored > 0 && !stats.hasCatalog) {
      return _message(
        textTheme,
        title: 'Tentativi non inclusi',
        message:
            'Alcuni tentativi non possono essere inclusi nelle statistiche.',
        icon: Icons.warning_amber_rounded,
        actionLabel: 'Riprova',
        onAction: () => _ensureLoaded(isRefresh: true),
      );
    }

    if (!stats.showDashboard) {
      return _message(
        textTheme,
        title: 'Nessuna attività',
        message:
            'Questo allievo non ha ancora completato schede o simulazioni '
            'per questo percorso.',
        icon: Icons.query_stats_rounded,
      );
    }

    return StudentQuizStatisticsDashboard(
      statistics: stats,
      reviewSource: _reviewSource,
      topicSource: _topicSource,
      onReviewSourceChanged: (v) => setState(() => _reviewSource = v),
      onTopicSourceChanged: (v) => setState(() => _topicSource = v),
      onRefresh: () => _ensureLoaded(isRefresh: true),
    );
  }

  Widget _message(
    TextTheme textTheme, {
    required String title,
    required String message,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: _primary.withValues(alpha: 0.85)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: _ink.withValues(alpha: 0.84),
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  child: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
