import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/supabase_config.dart';

/// Indicatore **solo in debug** (`kDebugMode`): backend reale vs mock.
///
/// In release/profile è un [SizedBox.shrink] (nessun costo UI).
class DevBackendEnvBadge extends StatelessWidget {
  const DevBackendEnvBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final live = SupabaseConfig.isConfigured;
    final label = live ? 'LIVE SUPABASE' : 'MOCK MODE';
    final bg = live ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final fg = live ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);
    final border = live ? const Color(0xFF43A047) : const Color(0xFFFF6F00);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
                color: fg,
                height: 1.05,
              ),
            ),
            Text(
              'DEBUG',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: fg.withValues(alpha: 0.75),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
