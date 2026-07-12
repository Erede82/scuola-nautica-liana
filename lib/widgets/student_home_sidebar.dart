import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constants/app_branding.dart';
import '../models/student_session.dart';
import '../pages/account_change_password_page.dart';
import '../pages/account_contacts_page.dart';
import '../pages/account_profile_page.dart';
import '../pages/backoffice/backoffice_entry_page.dart';
import '../services/auth_identity.dart';
import '../services/student_area_context.dart';
import '../services/auth_logout_navigation.dart';
import '../services/demo_student_enrollment.dart';
import '../services/staff_access_service.dart';
import '../utils/school_contact_launcher.dart';
import '../utils/staff_area_navigation.dart';
import 'staff/staff_access_gate.dart';
import '../pages/study_access_admin_page.dart';
import '../theme/app_visual_tokens.dart';

/// Menu laterale area allievo: account, scuola, staff (se applicabile), esci.
///
/// [closeDrawerOnNavigate]: `true` quando è dentro un [Drawer] (chiude prima della push).
class StudentHomeSidebar extends StatelessWidget {
  const StudentHomeSidebar({
    super.key,
    required this.closeDrawerOnNavigate,
    required this.onOpenPlaceholder,
  });

  final bool closeDrawerOnNavigate;
  final void Function(String title, String message, IconData icon)
  onOpenPlaceholder;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;

  void _maybePopDrawer(BuildContext context) {
    if (closeDrawerOnNavigate && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _push(BuildContext context, Widget page) {
    _maybePopDrawer(context);
    Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _phoneWhatsAppSheet(BuildContext context) {
    _afterDrawerClose(context, () {
      if (!context.mounted) return;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone_rounded, color: _primaryColor),
                title: const Text('Chiama la segreteria'),
                subtitle: Text(AppBranding.supportPhoneDisplay),
                onTap: () {
                  Navigator.pop(ctx);
                  SchoolContactLauncher.dialSupportPhone(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded, color: _primaryColor),
                title: const Text('WhatsApp'),
                onTap: () {
                  Navigator.pop(ctx);
                  SchoolContactLauncher.openWhatsApp(context);
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  void _afterDrawerClose(BuildContext context, VoidCallback fn) {
    _maybePopDrawer(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) fn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final areaContext = StudentAreaContext.of(context);
    final isPreview = areaContext.isStaffPreview;

    return ColoredBox(
      color: _backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: _primaryColor,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: isPreview ? 145 : 110,
                child: isPreview
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white24,
                              child: Icon(
                                Icons.visibility_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              StudentAreaPreviewCopy.headerTitle,
                              textAlign: TextAlign.center,
                              style: textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              StudentAreaPreviewCopy.headerSubtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ValueListenableBuilder<StudentSession?>(
                        valueListenable: studentSession,
                        builder: (context, sess, _) {
                          final email =
                              AuthIdentity.resolvedAccountEmail() ??
                              sess?.email ??
                              '';
                          final name =
                              sess != null && sess.displayName.trim().isNotEmpty
                              ? sess.displayName.trim()
                              : (email.isNotEmpty
                                    ? email.split('@').first
                                    : 'Allievo');
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white24,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Area personale',
                                  textAlign: TextAlign.center,
                                  style: textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              children: [
                if (!isPreview) ...[
                  _sectionLabel('IL TUO ACCOUNT'),
                  _navTile(
                    context,
                    icon: Icons.person_rounded,
                    label: 'Profilo',
                    onTap: () => _push(context, const AccountProfilePage()),
                  ),
                  _navTile(
                    context,
                    icon: Icons.lock_outline_rounded,
                    label: 'Cambio password',
                    onTap: () =>
                        _push(context, const AccountChangePasswordPage()),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  _sectionLabel('IL TUO ACCOUNT'),
                  _navTile(
                    context,
                    icon: Icons.person_rounded,
                    label: 'Profilo',
                    onTap: () => _push(context, const AccountProfilePage()),
                  ),
                  const SizedBox(height: 14),
                ],
                _sectionLabel('SCUOLA'),
                _navTile(
                  context,
                  icon: Icons.schedule_rounded,
                  label: 'Orari',
                  onTap: () => _push(context, const AccountContactsPage()),
                ),
                _navTile(
                  context,
                  icon: Icons.map_rounded,
                  label: 'Google Maps',
                  onTap: () => _afterDrawerClose(
                    context,
                    () => SchoolContactLauncher.openMap(context),
                  ),
                ),
                _navTile(
                  context,
                  icon: Icons.phone_in_talk_rounded,
                  label: 'Telefono / WhatsApp',
                  onTap: () => _phoneWhatsAppSheet(context),
                ),
                _navTile(
                  context,
                  label: 'Instagram',
                  leading: FaIcon(
                    FontAwesomeIcons.instagram,
                    size: 24,
                    color: _primaryColor.withValues(alpha: 0.92),
                  ),
                  onTap: () => _afterDrawerClose(
                    context,
                    () => SchoolContactLauncher.openInstagram(context),
                  ),
                ),
                _navTile(
                  context,
                  icon: Icons.star_rounded,
                  label: 'Recensioni',
                  onTap: () => _afterDrawerClose(
                    context,
                    () => SchoolContactLauncher.openReviews(context),
                  ),
                ),
                ValueListenableBuilder<StaffAccessSnapshot>(
                  valueListenable: staffAccessNotifier,
                  builder: (context, snap, _) {
                    final showStaff =
                        !snap.isLoading && snap.canAccessBackoffice;
                    if (!showStaff) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 14),
                        _sectionLabel('STAFF'),
                        _navTile(
                          context,
                          icon: Icons.arrow_back_rounded,
                          label: 'Torna al pannello amministrativo',
                          onTap: () => _afterDrawerClose(
                            context,
                            () => returnToAdministrativePanel(context, snap),
                          ),
                        ),
                        if (!isPreview) ...[
                          _navTile(
                            context,
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Accessi studio',
                            onTap: () => _push(
                              context,
                              const StaffAccessGate(
                                gateTitle: 'Accessi studio',
                                child: StudyAccessAdminPage(),
                              ),
                            ),
                          ),
                          _navTile(
                            context,
                            icon: Icons.groups_rounded,
                            label: 'Allievi (backoffice)',
                            onTap: () =>
                                _push(context, const BackofficeEntryPage()),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (!isPreview)
            ValueListenableBuilder<StaffAccessSnapshot>(
              valueListenable: staffAccessNotifier,
              builder: (context, staffSnap, _) {
                return ValueListenableBuilder<StudentSession?>(
                  valueListenable: studentSession,
                  builder: (context, sess, _) {
                    final canLogout = staffSnap.hasAuthSession || sess != null;
                    return _navTile(
                      context,
                      icon: Icons.logout_rounded,
                      label: 'Esci',
                      dense: true,
                      onTap: () async {
                        if (!canLogout) {
                          _maybePopDrawer(context);
                          onOpenPlaceholder(
                            'Esci',
                            'Non risulti collegato con un account in questa sessione.',
                            Icons.logout_rounded,
                          );
                          return;
                        }
                        _maybePopDrawer(context);
                        await signOutAndReturnToWelcome();
                      },
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Text(
        text,
        style: TextStyle(
          color: _textPrimaryColor.withValues(alpha: 0.5),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          fontSize: 10,
        ),
      ),
    );
  }

  static Widget _navTile(
    BuildContext context, {
    IconData? icon,
    Widget? leading,
    required String label,
    required VoidCallback onTap,
    bool dense = false,
  }) {
    assert(
      (icon != null) ^ (leading != null),
      'Fornire icon oppure leading, non entrambi.',
    );
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      dense: dense,
      visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
      leading:
          leading ?? Icon(icon, color: _primaryColor.withValues(alpha: 0.92)),
      title: Text(
        label,
        style: textTheme.titleSmall?.copyWith(
          color: _textPrimaryColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
