import 'package:flutter/material.dart';

import '../models/guida_list_filter.dart';
import '../theme/app_visual_tokens.dart';

/// Barra filtri compatta stile segment / chip premium.
class GuidaFilterBar extends StatelessWidget {
  const GuidaFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final GuidaListFilter selected;
  final ValueChanged<GuidaListFilter> onChanged;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  static const List<GuidaListFilter> _filters = GuidaListFilter.values;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in _filters) ...[
            if (f != _filters.first) const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(f),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == f ? _primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected == f
                          ? _primaryColor
                          : _neutralColor,
                      width: 1,
                    ),
                    boxShadow: selected == f
                        ? [
                            BoxShadow(
                              color: _accentColor.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    f.label,
                    style: textTheme.labelMedium?.copyWith(
                      color: selected == f
                          ? Colors.white
                          : _textPrimaryColor.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
