import 'package:flutter/material.dart';
import '../theme/app_visual_tokens.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tagLabel,
    this.onPrimaryActionPressed,
    this.primaryActionLabel,
    this.primaryActionIcon = Icons.arrow_forward_rounded,
  });

  final String title;
  final String message;
  final IconData icon;

  // Optional small pill/tag (e.g. "Coming soon").
  final String? tagLabel;

  final VoidCallback? onPrimaryActionPressed;
  final String? primaryActionLabel;
  final IconData primaryActionIcon;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showAction = onPrimaryActionPressed != null && primaryActionLabel != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _neutralColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tagLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _neutralColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tagLabel!,
                    style: textTheme.labelSmall?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: _primaryColor, size: 30),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: _textPrimaryColor,
                ),
              ),
              if (showAction) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onPrimaryActionPressed,
                  icon: Icon(primaryActionIcon),
                  label: Text(primaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

