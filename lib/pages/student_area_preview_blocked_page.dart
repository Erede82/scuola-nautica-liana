import 'package:flutter/material.dart';

import '../theme/app_visual_tokens.dart';
import '../widgets/app_empty_state.dart';

/// Sezione non disponibile in anteprima staff read-only.
class StudentAreaPreviewBlockedPage extends StatelessWidget {
  const StudentAreaPreviewBlockedPage({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: AppEmptyState(
        title: title,
        message: message,
        icon: Icons.visibility_outlined,
        tagLabel: 'Anteprima staff',
        primaryActionLabel: 'Indietro',
        primaryActionIcon: Icons.arrow_back_rounded,
        onPrimaryActionPressed: () => Navigator.maybePop(context),
      ),
    );
  }
}
