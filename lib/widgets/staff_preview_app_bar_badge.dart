import 'package:flutter/material.dart';

import '../services/student_area_context.dart';

/// Indicatore compatto «Anteprima staff» nelle AppBar delle route figlie.
class StaffPreviewAppBarBadge extends StatelessWidget {
  const StaffPreviewAppBarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!StudentAreaContext.of(context).isStaffPreview) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              'Anteprima staff',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
