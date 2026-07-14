import 'package:flutter/material.dart';

import '../models/quiz_error_review_data.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/guida_datetime_format.dart';

/// Riepilogo compatto Ripasso errori (domande uniche, occorrenze, lezioni).
class QuizErrorReviewSummary extends StatelessWidget {
  const QuizErrorReviewSummary({super.key, required this.data});

  final QuizErrorReviewData data;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 720 ? 4 : 2;

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
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: width >= 720 ? 1.8 : 1.6,
        children: [
          _tile(
            textTheme,
            label: 'Domande da ripassare',
            value: '${data.totalUniqueQuestions}',
            icon: Icons.help_outline_rounded,
            accent: _primaryColor,
          ),
          _tile(
            textTheme,
            label: 'Errori registrati',
            value: '${data.totalWrongOccurrences}',
            icon: Icons.close_rounded,
            accent: const Color(0xFFC75D3A),
          ),
          _tile(
            textTheme,
            label: 'Lezioni coinvolte',
            value: '${data.availableLessons.length}',
            icon: Icons.menu_book_outlined,
            accent: _accentColor,
          ),
          _tile(
            textTheme,
            label: 'Ultimo errore',
            value: _formatLastWrong(data.lastWrongAt),
            icon: Icons.schedule_rounded,
            accent: _primaryColor,
            compact: true,
          ),
        ],
      ),
    );
  }

  String _formatLastWrong(DateTime? at) {
    if (at == null) return '—';
    return '${GuidaDateTimeFormat.formatDate(at)} · '
        '${GuidaDateTimeFormat.formatTime(at)}';
  }

  Widget _tile(
    TextTheme textTheme, {
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    bool compact = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _neutralColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: compact ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: (compact ? textTheme.titleSmall : textTheme.titleLarge)
                ?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}
