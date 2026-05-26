import 'package:flutter/material.dart';

import '../../domain/staff/staff_school_role.dart';
import '../../pages/account_hub_page.dart';
import '../../services/staff_access_service.dart';
import '../../theme/app_visual_tokens.dart';

/// Mostra [child] solo se l’utente ha sessione e ruolo staff; altrimenti stati UX dedicati (italiano).
class StaffAccessGate extends StatefulWidget {
  const StaffAccessGate({
    super.key,
    required this.child,
    this.showStaffWelcomeSnack = false,
    this.gateTitle = 'Area staff',
  });

  final Widget child;

  /// Mostra un SnackBar alla prima apertura autorizzata (es. backoffice).
  final bool showStaffWelcomeSnack;

  final String gateTitle;

  @override
  State<StaffAccessGate> createState() => _StaffAccessGateState();
}

class _StaffAccessGateState extends State<StaffAccessGate> {
  bool _shownStaffSnack = false;

  @override
  void initState() {
    super.initState();
    staffAccessNotifier.addListener(_onStaffAccessChanged);
  }

  @override
  void dispose() {
    staffAccessNotifier.removeListener(_onStaffAccessChanged);
    super.dispose();
  }

  void _onStaffAccessChanged() {
    final s = staffAccessNotifier.value;
    if (widget.showStaffWelcomeSnack &&
        !s.isLoading &&
        s.canAccessBackoffice &&
        s.lastError == null &&
        mounted &&
        !_shownStaffSnack) {
      _shownStaffSnack = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Accesso effettuato come staff · ${s.staffRole!.labelIt}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StaffAccessSnapshot>(
      valueListenable: staffAccessNotifier,
      builder: (context, snap, _) {
        if (snap.isLoading && snap.lastError == null) {
          return _GateLoading(message: 'Verifica permessi in corso…');
        }

        if (snap.lastError != null) {
          return _GateMessagePage(
            gateTitle: widget.gateTitle,
            icon: Icons.cloud_off_rounded,
            title: 'Impossibile verificare i permessi',
            body:
                'Controlla la connessione e riprova. Se il problema persiste, contatta il supporto IT.',
            detail: snap.lastError.toString(),
            primaryLabel: 'Riprova',
            onPrimary: () => refreshStaffAccess(),
            secondaryLabel: 'Indietro',
            onSecondary: () => Navigator.of(context).pop(),
          );
        }

        if (!snap.hasAuthSession) {
          return _GateMessagePage(
            gateTitle: widget.gateTitle,
            icon: Icons.lock_outline_rounded,
            title: 'Accesso staff richiesto',
            body:
                'Accedi con un account autorizzato dalla scuola per usare questa area.',
            primaryLabel: 'Vai ad accedi / account',
            onPrimary: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const AccountHubPage(),
                ),
              );
            },
            secondaryLabel: 'Indietro',
            onSecondary: () => Navigator.of(context).pop(),
          );
        }

        if (!snap.canAccessBackoffice) {
          return _GateMessagePage(
            gateTitle: widget.gateTitle,
            icon: Icons.gpp_bad_outlined,
            title: 'Accesso non autorizzato',
            body: 'Non sei autorizzato ad accedere a questa area.',
            detail:
                'Serve un ruolo scuola (amministratore, staff o istruttore) su questo account.',
            primaryLabel: 'Indietro',
            onPrimary: () => Navigator.of(context).pop(),
          );
        }

        return widget.child;
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading({required this.message});

  final String message;

  static const Color _bg = AppVisual.canvas;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GateMessagePage extends StatelessWidget {
  const _GateMessagePage({
    required this.gateTitle,
    required this.icon,
    required this.title,
    required this.body,
    this.detail,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String gateTitle;
  final IconData icon;
  final String title;
  final String body;
  final String? detail;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  static const Color _primary = AppVisual.logoBlue;
  static const Color _bg = AppVisual.canvas;
  static const Color _text = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text(gateTitle),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Icon(icon, size: 56, color: _text.withValues(alpha: 0.45)),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      color: _text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _text.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      detail!,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: _text.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel),
                  ),
                  if (secondaryLabel != null && onSecondary != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
