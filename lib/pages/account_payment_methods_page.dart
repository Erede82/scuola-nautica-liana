import 'package:flutter/material.dart';

import '../widgets/app_empty_state.dart';
import '../theme/app_visual_tokens.dart';

/// Pagamenti legati ai contenuti Extra (videolezioni premium), non al rapporto generico con la segreteria.
class AccountPaymentMethodsPage extends StatelessWidget {
  const AccountPaymentMethodsPage({super.key});

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _successColor = Color(0xFF2E9E5B);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Pagamenti Extra'),
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
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.workspace_premium_outlined,
                  color: _successColor.withOpacity(0.9),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Questa area riguarda solo gli acquisti delle videolezioni premium '
                    'in sezione Extra. Rate, iscrizioni ai corsi e pratiche di segreteria '
                    'non passano da qui.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: _textPrimaryColor.withOpacity(0.88),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _neutralColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: _successColor.withOpacity(0.9),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I pagamenti saranno gestiti con fornitori certificati. In app vedrai solo l’esito e le ricevute, '
                    'mai i dati completi della carta.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: _textPrimaryColor.withOpacity(0.88),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AppEmptyState(
            title: 'Nessun metodo collegato',
            message:
                'Quando gli acquisti Extra saranno attivi, potrai vedere qui metodi di pagamento e '
                'storico legato alle videolezioni premium.',
            icon: Icons.credit_card_rounded,
            tagLabel: 'Prossimamente',
            primaryActionLabel: 'Torna a Extra',
            primaryActionIcon: Icons.arrow_back_rounded,
            onPrimaryActionPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }
}
