import 'package:flutter/material.dart';

import '../../services/app_update/app_update_coordinator.dart';
import '../../theme/app_visual_tokens.dart';

/// Banner discreto quando update è disponibile ma l'app non è safe.
class UpdateAvailableBanner extends StatelessWidget {
  const UpdateAvailableBanner({
    super.key,
    required this.coordinator,
  });

  final AppUpdateCoordinator coordinator;

  static const String message =
      'È disponibile una nuova versione dell\u2019app.';
  static const String updateNowLabel = 'Aggiorna ora';
  static const String laterLabel = 'Più tardi';
  static const String unsafeHint = 'Salva prima le modifiche in corso.';

  @override
  Widget build(BuildContext context) {
    if (!coordinator.bannerVisible) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final canReload = coordinator.canReloadSafely;
    final topInset = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topInset + 8,
      left: 12,
      right: 12,
      child: Material(
        elevation: 2,
        color: AppVisual.canvas,
        surfaceTintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppVisual.border.withValues(alpha: 0.85),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppVisual.ink,
                  ),
                ),
                if (!canReload) ...[
                  const SizedBox(height: 6),
                  Text(
                    unsafeHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppVisual.ink.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: coordinator.deferUpdate,
                      child: const Text(laterLabel),
                    ),
                    FilledButton(
                      onPressed: canReload ? coordinator.updateNow : null,
                      child: const Text(updateNowLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
