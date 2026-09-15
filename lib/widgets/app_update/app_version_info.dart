import 'package:flutter/material.dart';

import '../../services/app_update/app_build_info.dart';
import '../../theme/app_visual_tokens.dart';

/// Versione/build leggibile (Impostazioni backoffice).
class AppVersionInfo extends StatelessWidget {
  const AppVersionInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final version = AppBuildInfo.displayVersion;
    final commit = AppBuildInfo.displayCommit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Versione $version\nBuild $commit',
        textAlign: TextAlign.center,
        style: textTheme.bodySmall?.copyWith(
          color: AppVisual.ink.withValues(alpha: 0.55),
          height: 1.35,
        ),
      ),
    );
  }
}
