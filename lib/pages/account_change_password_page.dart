import 'package:flutter/material.dart';

import '../widgets/app_empty_state.dart';
import '../theme/app_visual_tokens.dart';

/// Placeholder premium per il flusso cambio password (backend futuro).
class AccountChangePasswordPage extends StatelessWidget {
  const AccountChangePasswordPage({super.key});

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Cambio password'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: _primaryColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Sicurezza account',
                        style: textTheme.titleMedium?.copyWith(
                          color: _textPrimaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Quando l’accesso con credenziali sarà attivo, potrai aggiornare la password in autonomia con verifica sicura.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.88),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppEmptyState(
            title: 'Funzionalità in preparazione',
            message:
                'Stiamo definendo il flusso con la segreteria: password robusta, conferma via email o SMS e blocco tentativi falliti.',
            icon: Icons.lock_reset_rounded,
            tagLabel: 'In arrivo',
            primaryActionLabel: 'Ho capito',
            primaryActionIcon: Icons.check_rounded,
            onPrimaryActionPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }
}
