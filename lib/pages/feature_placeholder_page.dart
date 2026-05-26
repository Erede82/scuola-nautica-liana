import 'package:flutter/material.dart';

import '../widgets/app_empty_state.dart';
import '../theme/app_visual_tokens.dart';

class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.tagLabel,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? tagLabel;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: AppEmptyState(
        title: title,
        message: message,
        icon: icon,
        tagLabel: tagLabel,
        primaryActionLabel: 'Torna alla dashboard',
        primaryActionIcon: Icons.arrow_back_rounded,
        onPrimaryActionPressed: () => Navigator.maybePop(context),
      ),
    );
  }
}
