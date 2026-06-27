import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import '../domain/staff/staff_school_role.dart';
import '../models/app_auth_summary.dart';
import '../services/auth_identity.dart';
import '../services/demo_student_enrollment.dart';
import '../services/staff_access_service.dart';
import '../widgets/branded_app_bar_title.dart';
import '../widgets/account_option_tile.dart';
import '../widgets/dev_backend_env_badge.dart';
import 'account_change_password_page.dart';
import 'account_contacts_page.dart';
import 'account_profile_page.dart';
import 'extra_my_purchases_page.dart';
import 'login_page.dart';
import 'student_registration_page.dart';
import '../theme/app_visual_tokens.dart';

/// Hub account / supporto con sezioni raggruppate (contenuti diversi per ospite vs utente autenticato).
class AccountHubPage extends StatelessWidget {
  const AccountHubPage({super.key});

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const SectionAppBarTitle('Account e assistenza', logoHeight: 30),
        shape: const RoundedRectangleBorder(),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([studentSession, staffAccessNotifier]),
        builder: (context, _) {
          final summary = AppAuthSummary.fromSources(
            student: studentSession.value,
            staffSnap: staffAccessNotifier.value,
          );
          final isGuest = summary.kind == AppUserKind.guest;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              const DevBackendEnvBadge(),
              const SizedBox(height: 12),
              _ProfileHeaderCard(textTheme: textTheme),
              if (isGuest) ...[
                const SizedBox(height: 18),
                _SectionLabel(text: 'PRIMO ACCESSO'),
                const SizedBox(height: 8),
                _RoundedGroup(
                  child: Column(
                    children: [
                      AccountOptionTile(
                        icon: Icons.person_add_alt_1_rounded,
                        title: 'Registrati',
                        subtitle:
                            'Crea account e scegli il percorso di iscrizione',
                        onTap: () async {
                          final ok = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute<bool>(
                              builder: (_) => const StudentRegistrationPage(),
                            ),
                          );
                          if (!context.mounted) return;
                          if (ok == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Registrazione completata con successo. Puoi iniziare a usare l’area corsi.',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppVisual.logoBlue,
                                duration: const Duration(milliseconds: 1800),
                              ),
                            );
                          }
                        },
                      ),
                      const _TileDivider(),
                      AccountOptionTile(
                        icon: Icons.login_rounded,
                        title: 'Accedi',
                        subtitle: 'Entra con email e password',
                        onTap: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              _SectionLabel(text: 'IL TUO ACCOUNT'),
              const SizedBox(height: 8),
              _RoundedGroup(
                child: Column(
                  children: [
                    AccountOptionTile(
                      icon: Icons.person_rounded,
                      title: 'Profilo',
                      subtitle: 'Dati personali e percorso di iscrizione',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountProfilePage(),
                        ),
                      ),
                    ),
                    const _TileDivider(),
                    AccountOptionTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Cambio password',
                      subtitle: 'Sicurezza dell’account',
                      onTap: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountChangePasswordPage(),
                        ),
                      ),
                    ),
                    if (!isGuest &&
                        studentSession.value?.studentId != null) ...[
                      const _TileDivider(),
                      AccountOptionTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'I miei acquisti Extra',
                        subtitle: 'Videocorsi premium acquistati online',
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const ExtraMyPurchasesPage(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel(text: 'SCUOLA'),
              const SizedBox(height: 8),
              _RoundedGroup(
                child: AccountOptionTile(
                  icon: Icons.apartment_rounded,
                  title: 'Informazioni e contatti',
                  subtitle:
                      'Orari, Google Maps, WhatsApp, Instagram e recensioni',
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const AccountContactsPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  AppBranding.schoolName,
                  style: textTheme.labelSmall?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.textTheme});

  final TextTheme textTheme;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([studentSession, staffAccessNotifier]),
      builder: (context, _) {
        final summary = AppAuthSummary.fromSources(
          student: studentSession.value,
          staffSnap: staffAccessNotifier.value,
        );
        final title = summary.hasStudentProfile
            ? summary.studentSession!.displayName
            : summary.hasStaffAccess
            ? 'Account staff'
            : 'Il tuo profilo';
        final subtitle = _headerSubtitle(summary);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_cardColor, _accentColor.withValues(alpha: 0.08)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _neutralColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: _primaryColor.withValues(alpha: 0.15),
                child: Icon(
                  Icons.person_rounded,
                  size: 40,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: _textPrimaryColor.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppBranding.schoolName,
                      style: textTheme.labelMedium?.copyWith(
                        color: _primaryColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.15,
                      ),
                    ),
                    if (summary.hasStaffAccess) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Funzioni staff: ${summary.staffRole!.labelIt}',
                        style: textTheme.labelSmall?.copyWith(
                          color: _primaryColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (!summary.hasStudentProfile &&
                        summary.hasStaffAccess) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Profilo studente non disponibile per questo account.',
                        style: textTheme.bodySmall?.copyWith(
                          color: _textPrimaryColor.withValues(alpha: 0.72),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _headerSubtitle(AppAuthSummary summary) {
    if (summary.kind == AppUserKind.guest) {
      return 'Anteprima app · registrati o accedi per salvare i progressi';
    }
    final email = AuthIdentity.resolvedAccountEmail();
    if (email != null && email.isNotEmpty) return email;
    if (summary.authEmail != null && summary.authEmail!.isNotEmpty) {
      return summary.authEmail!;
    }
    return 'Account attivo';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: textTheme.labelSmall?.copyWith(
          color: _textPrimaryColor.withValues(alpha: 0.55),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _RoundedGroup extends StatelessWidget {
  const _RoundedGroup({required this.child});

  final Widget child;

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _cardColor,
          border: Border.all(color: _neutralColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  static const Color _neutralColor = AppVisual.chipFill;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: _neutralColor.withValues(alpha: 0.85),
    );
  }
}
