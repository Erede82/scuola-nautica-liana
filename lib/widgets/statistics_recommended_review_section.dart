import 'package:flutter/material.dart';

import '../models/error_review_recommendation.dart';
import '../models/license_models.dart';
import '../pages/error_review_page.dart';
import '../repositories/study_access_repository.dart';
import '../services/error_review_provider.dart';
import '../widgets/app_empty_state.dart';
import '../theme/app_visual_tokens.dart';

/// Blocco compatto “Argomenti da ripassare” nella pagina Statistiche.
class StatisticsRecommendedReviewSection extends StatelessWidget {
  const StatisticsRecommendedReviewSection({
    super.key,
    required this.categoryId,
  });

  final LicenseCategoryId categoryId;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _successColor = Color(0xFF2E9E5B);
  static const Color _errorTint = Color(0xFFD64545);

  static const int _maxItems = 3;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: studyAccessListenable,
      builder: (context, _) {
        final textTheme = Theme.of(context).textTheme;
        final view = ErrorReviewProvider.buildViewData(categoryId);

        return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_fix_high_rounded,
                color: _primaryColor.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Argomenti da ripassare',
                  style: textTheme.titleMedium?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Suggerimenti di anteprima (fase successiva: statistiche reali dell’allievo). '
            'Il materiale resta soggetto all’abilitazione della scuola.',
            style: textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.78),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _buildBody(context, textTheme, view),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ErrorReviewPage(initialCategoryId: categoryId),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apri Ripasso errori',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    TextTheme textTheme,
    ErrorReviewViewData view,
  ) {
    if (view.emptyKind == ErrorReviewEmptyKind.noQuizData) {
      return AppEmptyState(
        title: 'Nessun dato disponibile',
        message:
            'Completa alcuni quiz per ricevere suggerimenti di ripasso collegati alle statistiche.',
        icon: Icons.query_stats_rounded,
        tagLabel: 'Suggerimenti',
        primaryActionLabel: 'Vai a Ripasso errori',
        primaryActionIcon: Icons.fact_check_rounded,
        onPrimaryActionPressed: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ErrorReviewPage(initialCategoryId: categoryId),
            ),
          );
        },
      );
    }

    if (view.emptyKind == ErrorReviewEmptyKind.allClear) {
      return AppEmptyState(
        title: 'Ottimo lavoro',
        message:
            'Al momento non rileviamo aree critiche da ripassare per questa categoria.',
        icon: Icons.check_circle_outline_rounded,
        tagLabel: 'Statistiche',
      );
    }

    final top = view.recommendations.take(_maxItems).toList(growable: false);

    if (view.allRecommendedTopicsLocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _neutralColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, color: _primaryColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ci sono argomenti consigliati, ma tutti sono ancora in attesa '
                    'di abilitazione da parte della scuola. Apri Ripasso errori per i dettagli.',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor.withValues(alpha: 0.88),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...top.map((r) => _compactRecommendationRow(textTheme, r)),
        ],
      );
    }

    return Column(
      children: top.map((r) => _compactRecommendationRow(textTheme, r)).toList(),
    );
  }

  Widget _compactRecommendationRow(
    TextTheme textTheme,
    ErrorReviewRecommendation r,
  ) {
    final pct = r.averageErrorPercentage.round();
    final locked = !r.isSchoolUnlocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _cardColor,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _neutralColor),
            color: locked
                ? _neutralColor.withValues(alpha: 0.35)
                : _accentColor.withValues(alpha: 0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      r.lessonTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '~$pct% err.',
                    style: textTheme.labelLarge?.copyWith(
                      color: _primaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _miniChip(
                    textTheme,
                    'Argomento consigliato',
                    _primaryColor.withValues(alpha: 0.1),
                    _primaryColor,
                  ),
                  if (locked)
                    _miniChip(
                      textTheme,
                      'Disponibile su assegnazione della scuola',
                      _errorTint.withValues(alpha: 0.1),
                      _errorTint,
                    )
                  else
                    _miniChip(
                      textTheme,
                      'Sbloccato dalla scuola',
                      _successColor.withValues(alpha: 0.14),
                      _successColor,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniChip(
    TextTheme textTheme,
    String label,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
