import 'package:flutter/material.dart';

import '../domain/student_stats_source.dart';
import '../theme/app_visual_tokens.dart';

/// Chip filter: Tutto / Studio / Esame.
class StudentStatsSourceFilterBar extends StatelessWidget {
  const StudentStatsSourceFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.keyPrefix = 'student-stats-filter',
  });

  final StudentStatsSource value;
  final ValueChanged<StudentStatsSource> onChanged;
  final String keyPrefix;

  static const Color _primary = AppVisual.logoBlue;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final source in StudentStatsSource.values)
          ChoiceChip(
            key: ValueKey('$keyPrefix-${source.name}'),
            label: Text(source.labelIt),
            selected: value == source,
            onSelected: (_) => onChanged(source),
            selectedColor: _primary.withValues(alpha: 0.14),
            labelStyle: TextStyle(
              color: value == source ? _primary : AppVisual.ink,
              fontWeight: value == source ? FontWeight.w700 : FontWeight.w600,
            ),
            side: BorderSide(
              color: value == source
                  ? _primary.withValues(alpha: 0.45)
                  : AppVisual.chipFill,
            ),
          ),
      ],
    );
  }
}
