import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../data/supabase/mappers/quiz_error_review_mapper.dart';
import '../domain/quiz_license_category.dart';
import '../models/license_models.dart';
import '../models/quiz_error_review_data.dart';
import '../models/quiz_wrong_answer_entry.dart';
import '../pages/lesson_list_page.dart';
import '../pages/statistics_page.dart';
import '../repositories/quiz_error_review_repository.dart';
import '../repositories/study_access_repository.dart';
import '../services/student_area_context.dart';
import '../widgets/quiz_error_review_filters.dart';
import '../widgets/quiz_error_review_summary.dart';
import '../widgets/quiz_wrong_answer_card.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import '../theme/app_visual_tokens.dart';

/// Ripasso errori reale: domande sbagliate su schede lezione (read-only).
class ErrorReviewPage extends StatefulWidget {
  const ErrorReviewPage({
    super.key,
    this.categoryId = LicenseCategoryId.motore,
    this.repository,
  });

  final LicenseCategoryId categoryId;
  final QuizErrorReviewRepository? repository;

  @override
  State<ErrorReviewPage> createState() => _ErrorReviewPageState();
}

class _ErrorReviewPageState extends State<ErrorReviewPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _warningColor = Color(0xFFC75D3A);

  late final QuizErrorReviewRepository _repository;
  late LicenseCategoryId _categoryId;

  QuizErrorReviewData? _data;
  bool _loading = false;
  bool _refreshing = false;
  bool _unauthenticated = false;
  Object? _loadError;
  int _loadGeneration = 0;

  int? _lessonFilter;
  QuizErrorReviewSort _sort = QuizErrorReviewSort.recent;

  LicenseCategory get _category => LicenseCatalog.byId(_categoryId);

  bool get _categorySupported =>
      _category.isAvailable && dbLicenseCategoryFor(_categoryId) != null;

  bool get _isStaffPreview => StudentAreaContext.of(context).isStaffPreview;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? quizErrorReviewRepository;
    _categoryId = widget.categoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoad());
  }

  Future<void> _maybeLoad({bool isRefresh = false}) async {
    if (!mounted || _isStaffPreview || !_categorySupported) return;
    await _load(isRefresh: isRefresh);
  }

  Future<void> _load({bool isRefresh = false}) async {
    if (!mounted || _isStaffPreview || !_categorySupported) return;

    final generation = ++_loadGeneration;

    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
        _data = null;
        _loadError = null;
        _refreshing = false;
      }
      _unauthenticated = false;
    });

    try {
      final data = await _repository.fetchCurrentUserErrors(
        categoryId: _categoryId,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _data = data;
        _loading = false;
        _refreshing = false;
        _loadError = null;
      });
    } on QuizErrorReviewUnauthenticatedException {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _unauthenticated = true;
        _data = null;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadError = error;
        if (!isRefresh) _data = null;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  void _onCategoryChanged(LicenseCategoryId? id) {
    if (id == null || id == _categoryId) return;
    setState(() {
      _categoryId = id;
      _lessonFilter = null;
      _data = null;
      _loadError = null;
      _refreshing = false;
      _unauthenticated = false;
      _loading = true;
    });
    _load();
  }

  List<QuizWrongAnswerEntry> _visibleEntries(QuizErrorReviewData data) {
    var entries = List<QuizWrongAnswerEntry>.from(data.entries);
    if (_lessonFilter != null) {
      entries = entries
          .where((e) => e.lessonNumber == _lessonFilter)
          .toList(growable: false);
    }
    return sortWrongAnswerEntries(entries, sort: _sort);
  }

  void _openLessons() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => LessonListPage(categoryId: _categoryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studyAccessListenable,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            title: const Text('Ripasso errori'),
            centerTitle: true,
            actions: [
              const StaffPreviewAppBarBadge(),
              if (!_isStaffPreview && _categorySupported)
                IconButton(
                  tooltip: 'Aggiorna',
                  onPressed: _loading || _refreshing
                      ? null
                      : () => _load(isRefresh: true),
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
          body: _buildBody(Theme.of(context).textTheme),
        );
      },
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_isStaffPreview) {
      return _staffPreviewState(textTheme);
    }

    if (!_category.isAvailable || !_categorySupported) {
      return _messageState(
        textTheme,
        title: 'Percorso non disponibile',
        message:
            'Il ripasso errori per questo percorso non è ancora disponibile.',
        icon: Icons.fact_check_outlined,
      );
    }

    if (_loading && _data == null) {
      return _loadingState(textTheme);
    }

    if (_unauthenticated) {
      return _messageState(
        textTheme,
        title: 'Sessione non disponibile',
        message: 'La sessione non è disponibile. Accedi nuovamente.',
        icon: Icons.lock_outline_rounded,
      );
    }

    if (_loadError != null && _data == null) {
      return _messageState(
        textTheme,
        title: 'Errore di caricamento',
        message: 'Non è stato possibile caricare il ripasso errori.',
        icon: Icons.cloud_off_rounded,
        primaryLabel: 'Riprova',
        onPrimary: () => _load(),
        secondaryLabel: 'Indietro',
        onSecondary: () => Navigator.maybePop(context),
      );
    }

    final data = _data;
    if (data == null) return _loadingState(textTheme);

    if (!data.hasData && data.ignoredMalformedRows > 0) {
      return _messageState(
        textTheme,
        title: 'Errori non mostrabili',
        message: 'Alcuni errori non possono essere mostrati.',
        icon: Icons.warning_amber_rounded,
        primaryLabel: 'Riprova',
        onPrimary: () => _load(isRefresh: true),
      );
    }

    if (!data.hasData) {
      return _messageState(
        textTheme,
        title: 'Nessun errore da ripassare',
        message: 'Le risposte errate delle schede completate compariranno qui.',
        icon: Icons.check_circle_outline_rounded,
        primaryLabel: 'Vai alle schede',
        onPrimary: _openLessons,
      );
    }

    final visible = _visibleEntries(data);

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: () => _load(isRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _CategorySelectorBar(
            value: _categoryId,
            onChanged: _onCategoryChanged,
          ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _inlineErrorBanner(textTheme),
            ),
          QuizErrorReviewSummary(data: data),
          if (data.ignoredMalformedRows > 0)
            _ignoredNote(textTheme, data.ignoredMalformedRows),
          QuizErrorReviewFilters(
            data: data,
            selectedLesson: _lessonFilter,
            sort: _sort,
            onLessonChanged: (lesson) => setState(() => _lessonFilter = lesson),
            onSortChanged: (sort) => setState(() => _sort = sort),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => StatisticsPage(categoryId: _categoryId),
                    ),
                  );
                },
                icon: const Icon(Icons.insights_rounded, size: 20),
                label: const Text('Apri statistiche per questa categoria'),
              ),
            ),
          ),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: _filterEmptyState(textTheme),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: visible
                    .map(
                      (entry) => QuizWrongAnswerCard(
                        entry: entry,
                        categoryId: _categoryId,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _loadingState(TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            Text(
              'Caricamento errori da ripassare…',
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

  Widget _staffPreviewState(TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _messageState(
          textTheme,
          title: 'Ripasso errori allievo',
          message:
              'Gli errori reali saranno disponibili quando l’anteprima verrà '
              'aperta per uno specifico allievo.',
          icon: Icons.fact_check_outlined,
        ),
      ],
    );
  }

  Widget _filterEmptyState(TextTheme textTheme) {
    return Column(
      children: [
        Text(
          'Nessun errore per questa lezione.',
          textAlign: TextAlign.center,
          style: textTheme.titleSmall?.copyWith(
            color: _textPrimaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(() => _lessonFilter = null),
          style: FilledButton.styleFrom(backgroundColor: _primaryColor),
          child: const Text('Mostra tutte'),
        ),
      ],
    );
  }

  Widget _ignoredNote(TextTheme textTheme, int count) {
    final label = count == 1
        ? '1 risposta non inclusa.'
        : '$count risposte non incluse.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _warningColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _warningColor.withValues(alpha: 0.25)),
        ),
        child: Text(
          'Alcune risposte non sono state incluse. $label',
          style: textTheme.bodySmall?.copyWith(
            color: _textPrimaryColor.withValues(alpha: 0.88),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _inlineErrorBanner(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _warningColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aggiornamento non riuscito. I dati mostrati potrebbero non '
              'essere aggiornati.',
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.9),
              ),
            ),
          ),
          TextButton(
            onPressed: () => _load(isRefresh: true),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
  }

  Widget _messageState(
    TextTheme textTheme, {
    required String title,
    required String message,
    required IconData icon,
    String? primaryLabel,
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
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
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 8),
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySelectorBar extends StatelessWidget {
  const _CategorySelectorBar({required this.value, required this.onChanged});

  final LicenseCategoryId value;
  final void Function(LicenseCategoryId?) onChanged;

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
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
      ),
    );
  }
}
