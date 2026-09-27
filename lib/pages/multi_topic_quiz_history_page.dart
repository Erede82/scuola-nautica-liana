import 'package:flutter/material.dart';

import '../data/license_catalog.dart';
import '../debug/quiz_flow_debug.dart';
import '../domain/multi_topic_quiz_attempt_exception.dart';
import '../domain/multi_topic_quiz_history_models.dart';
import '../domain/multi_topic_quiz_support.dart';
import '../domain/quiz_license_category.dart';
import '../models/license_models.dart';
import '../repositories/multi_topic_quiz_attempt_repository.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/staff_preview_app_bar_badge.dart';
import 'multi_topic_quiz_history_detail_page.dart';

/// Storico Multischeda separato dalle Schede / `quiz_results`.
class MultiTopicQuizHistoryPage extends StatefulWidget {
  const MultiTopicQuizHistoryPage({
    super.key,
    required this.categoryId,
    this.repository,
  });

  final LicenseCategoryId categoryId;
  final MultiTopicQuizAttemptRepository? repository;

  @override
  State<MultiTopicQuizHistoryPage> createState() =>
      _MultiTopicQuizHistoryPageState();
}

class _MultiTopicQuizHistoryPageState extends State<MultiTopicQuizHistoryPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;

  bool _loading = true;
  String? _error;
  List<MultiTopicQuizAttemptSummary> _attempts = const [];

  MultiTopicQuizAttemptRepository get _repo =>
      widget.repository ?? multiTopicQuizAttemptRepository;

  @override
  void initState() {
    super.initState();
    qfLog('route: MultiTopicQuizHistoryPage categoryId=${widget.categoryId}');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!isMultiTopicCategorySupported(widget.categoryId)) {
      setState(() {
        _loading = false;
        _attempts = const [];
        _error = 'Storico Multischeda non disponibile per questa categoria.';
      });
      return;
    }
    try {
      final list = await _repo.fetchCurrentUserAttempts(
        category: widget.categoryId,
      );
      if (!mounted) return;
      setState(() {
        _attempts = list;
        _loading = false;
      });
    } on MultiTopicQuizAttemptException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = multiTopicQuizAttemptErrorMessageIt(
          MultiTopicQuizAttemptErrorCode.unknown,
        );
        _loading = false;
      });
    }
  }

  static String _formatDate(DateTime utc) {
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryName = LicenseCatalog.byId(widget.categoryId).name;
    final dbLabel = dbLicenseCategoryFor(widget.categoryId) ?? '—';

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Storico Multischeda'),
        centerTitle: true,
        actions: const [StaffPreviewAppBarBadge()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? AppEmptyState(
              title: 'Errore',
              message: _error!,
              icon: Icons.error_outline_rounded,
              primaryActionLabel: 'Riprova',
              primaryActionIcon: Icons.refresh_rounded,
              onPrimaryActionPressed: _load,
            )
          : _attempts.isEmpty
          ? AppEmptyState(
              title: 'Nessun tentativo',
              message:
                  'Non hai ancora completato schede Multischeda per '
                  '$categoryName ($dbLabel).',
              icon: Icons.history_rounded,
              tagLabel: 'Multischeda argomento',
              primaryActionLabel: 'Indietro',
              primaryActionIcon: Icons.arrow_back_rounded,
              onPrimaryActionPressed: () => Navigator.maybePop(context),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: _attempts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Tentativi Multischeda conclusi ($categoryName · $dbLabel). '
                      'Questo storico è separato dalle schede lezione.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _textPrimaryColor,
                      ),
                    ),
                  );
                }
                final attempt = _attempts[index - 1];
                return _HistoryCard(
                  attempt: attempt,
                  dateLabel: _formatDate(attempt.completedAt),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MultiTopicQuizHistoryDetailPage(
                          attemptId: attempt.id,
                          repository: widget.repository,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.attempt,
    required this.dateLabel,
    required this.onTap,
  });

  final MultiTopicQuizAttemptSummary attempt;
  final String dateLabel;
  final VoidCallback onTap;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dbLabel = dbLicenseCategoryFor(attempt.licenseCategory) ?? '—';
    final topics = attempt.lessonNumbers.map((n) => 'L$n').join(', ');
    final durationMin = (attempt.durationSeconds / 60).floor();
    final durationSec = attempt.durationSeconds % 60;
    final durationLabel = durationMin > 0
        ? '${durationMin}m ${durationSec}s'
        : '${attempt.durationSeconds}s';

    return Card(
      color: _cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Multischeda argomento',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Categoria $dbLabel · $topics',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                attempt.progressLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${attempt.correctCount}/${attempt.totalQuestions} corrette · '
                '${attempt.wrongCount} errate · '
                '${attempt.unansweredCount} non risposte',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$dateLabel · durata $durationLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
