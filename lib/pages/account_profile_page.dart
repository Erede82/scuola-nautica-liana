import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import '../domain/staff/staff_school_role.dart';
import '../domain/course_taxonomy.dart';
import '../domain/enrollment_content_mapping.dart';
import '../models/app_auth_summary.dart';
import '../services/auth_identity.dart';
import '../services/auth_logout_navigation.dart';
import '../services/demo_student_enrollment.dart';
import '../services/staff_access_service.dart';
import '../services/student_area_context.dart';
import '../theme/app_visual_tokens.dart';
import '../widgets/staff_preview_app_bar_badge.dart';

/// Scheda profilo: supporta allievo, account solo staff e anteprima ospite.
class AccountProfilePage extends StatelessWidget {
  const AccountProfilePage({super.key});

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  void _showEditPlaceholderSheet(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _neutralColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Modifica profilo',
                style: textTheme.titleMedium?.copyWith(
                  color: _textPrimaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Potrai aggiornare foto, nome e recapiti quando l’area riservata sarà collegata al gestionale della scuola. Le modifiche saranno sempre verificabili dalla segreteria.',
                style: textTheme.bodyMedium?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.88),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Chiudi'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uscire dall’account?'),
        content: const Text(
          'Tornerai alla modalità ospite. Potrai accedere di nuovo con le tue credenziali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Esci'),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await signOutAndReturnToWelcome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isPreview = StudentAreaContext.blocksWrites(context);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Profilo'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: const [StaffPreviewAppBarBadge()],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          studentSession,
          staffAccessNotifier,
          demoStudentEnrollmentPath,
        ]),
        builder: (context, _) {
          final summary = AppAuthSummary.fromSources(
            student: studentSession.value,
            staffSnap: staffAccessNotifier.value,
          );
          final session = studentSession.value;
          final path =
              session?.enrolledCoursePath ?? demoStudentEnrollmentPath.value;

          final guestPreview = summary.kind == AppUserKind.guest;
          final hasStudent = summary.hasStudentProfile;

          final displayName = isPreview
              ? StudentAreaPreviewCopy.previewAccountName
              : guestPreview
              ? 'Studente demo'
              : hasStudent
              ? session!.displayName
              : summary.hasStaffAccess
              ? 'Account staff'
              : summary.displayNameOrPlaceholder;

          final email = isPreview
              ? StudentAreaPreviewCopy.previewAccountEmail
              : guestPreview
              ? 'studente@esempio.it'
              : (AuthIdentity.resolvedAccountEmail() ?? '—');

          final phone = isPreview
              ? '—'
              : hasStudent
              ? (session!.phone ?? '+39 — —— —— ——')
              : (summary.hasStaffAccess ? '—' : '+39 — —— —— ——');

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              if (summary.kind == AppUserKind.authenticatedLimited) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Account attivo, ma non risulta associato a un profilo studente '
                    'né a un accesso staff. Contatta la segreteria.',
                    style: textTheme.bodySmall?.copyWith(
                      color: _textPrimaryColor,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_cardColor, _accentColor.withValues(alpha: 0.06)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _neutralColor),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10000000),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: _primaryColor.withValues(alpha: 0.12),
                      child: Icon(
                        summary.hasStaffAccess && !hasStudent
                            ? Icons.badge_outlined
                            : Icons.person_rounded,
                        size: 48,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      style: textTheme.titleLarge?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: textTheme.bodyMedium?.copyWith(
                        color: _textPrimaryColor.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppBranding.schoolName,
                      style: textTheme.labelLarge?.copyWith(
                        color: _primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!isPreview && summary.hasStaffAccess) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Funzioni staff: ${summary.staffRole!.labelIt}',
                        textAlign: TextAlign.center,
                        style: textTheme.labelMedium?.copyWith(
                          color: _primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (hasStudent) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Stato iscrizione: in attesa di conferma segreteria',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: _textPrimaryColor.withValues(alpha: 0.75),
                          height: 1.35,
                        ),
                      ),
                    ] else if (!isPreview &&
                        summary.hasStaffAccess &&
                        !hasStudent) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Profilo studente non disponibile per questo account.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: _textPrimaryColor.withValues(alpha: 0.75),
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: isPreview
                          ? null
                          : () => _showEditPlaceholderSheet(context),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: Text(
                        isPreview
                            ? 'Modifica profilo (non disponibile in anteprima)'
                            : 'Modifica profilo',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primaryColor,
                        side: const BorderSide(color: _neutralColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Dettagli',
                style: textTheme.titleSmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.25,
                ),
              ),
              const SizedBox(height: 10),
              Container(
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
                  children: [
                    if (isPreview)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Percorso dimostrativo',
                              style: textTheme.labelMedium?.copyWith(
                                color: _textPrimaryColor.withValues(
                                  alpha: 0.65,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              path.labelIt,
                              style: textTheme.titleSmall?.copyWith(
                                color: _textPrimaryColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              StudentAreaPreviewCopy.previewAccountPathNote,
                              style: textTheme.bodySmall?.copyWith(
                                color: _textPrimaryColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (guestPreview)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Anteprima percorso (demo)',
                              style: textTheme.labelMedium?.copyWith(
                                color: _textPrimaryColor.withValues(
                                  alpha: 0.65,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<EnrollmentCoursePath>(
                              key: ValueKey(path),
                              initialValue: path,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: _primaryColor.withValues(
                                  alpha: 0.06,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _neutralColor,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: EnrollmentCoursePath.values
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p.labelIt),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  demoStudentEnrollmentPath.value = v;
                                }
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Senza account puoi provare i filtri contenuto. '
                              'Con registrazione il percorso resta quello scelto in iscrizione.',
                              style: textTheme.bodySmall?.copyWith(
                                color: _textPrimaryColor.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (hasStudent)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Percorso di iscrizione',
                              style: textTheme.labelMedium?.copyWith(
                                color: _textPrimaryColor.withValues(
                                  alpha: 0.65,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              path.labelIt,
                              style: textTheme.titleSmall?.copyWith(
                                color: _textPrimaryColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Il percorso scelto in iscrizione non è modificabile dall’app. '
                              'Per variazioni rivolgiti alla segreteria.',
                              style: textTheme.bodySmall?.copyWith(
                                color: _textPrimaryColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (!isPreview && summary.hasStaffAccess)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Percorso allievo',
                              style: textTheme.labelMedium?.copyWith(
                                color: _textPrimaryColor.withValues(
                                  alpha: 0.65,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Account non associato a un profilo studente.',
                              style: textTheme.bodySmall?.copyWith(
                                color: _textPrimaryColor.withValues(
                                  alpha: 0.78,
                                ),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 1, indent: 56),
                    _ProfileRow(
                      icon: Icons.badge_outlined,
                      label: 'Nome e cognome',
                      value: displayName,
                    ),
                    const Divider(height: 1, indent: 56),
                    _ProfileRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: email,
                    ),
                    const Divider(height: 1, indent: 56),
                    _ProfileRow(
                      icon: Icons.phone_iphone_rounded,
                      label: 'Cellulare',
                      value: phone,
                    ),
                    if (!isPreview && summary.hasStaffAccess) ...[
                      const Divider(height: 1, indent: 56),
                      _ProfileRow(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Ruolo',
                        value: summary.staffRole!.labelIt,
                      ),
                    ],
                    if (hasStudent || guestPreview || isPreview) ...[
                      const Divider(height: 1, indent: 56),
                      _ProfileRow(
                        icon: Icons.menu_book_outlined,
                        label: 'Moduli contenuto',
                        value: EnrollmentContentMapping.contentModulesJoinedIt(
                          path,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isPreview && summary.canSignOut) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Esci dall’account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: const BorderSide(color: _neutralColor),
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: _primaryColor.withValues(alpha: 0.85)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: _textPrimaryColor.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
