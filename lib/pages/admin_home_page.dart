import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import '../domain/backoffice/ids.dart';
import '../models/student_session.dart';
import '../repositories/backoffice/backoffice_registry.dart';
import '../services/auth_identity.dart';
import '../services/auth_logout_navigation.dart';
import '../services/demo_student_enrollment.dart';
import '../services/staff_access_service.dart';
import '../utils/admin_access_utils.dart';
import '../widgets/backoffice/backoffice_new_practice_dialog.dart';
import '../widgets/branded_app_bar_title.dart';
import '../widgets/staff/staff_access_gate.dart';
import 'account_hub_page.dart';
import 'backoffice/accounting_payments_directory_page.dart';
import 'backoffice/guidance_appointments_directory_page.dart';
import 'backoffice/practice_dossiers_directory_page.dart';
import 'backoffice/school_management_shell_page.dart';
import 'backoffice/settings_directory_page.dart';
import 'backoffice/student_360_direct_page.dart';
import 'feature_placeholder_page.dart';
import 'home_page.dart';
import 'study_access_admin_page.dart';
import '../theme/app_visual_tokens.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _primaryDarkColor = AppVisual.logoBlueDeep;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = AppVisual.ivory;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _textSecondaryColor = AppVisual.inkMuted;

  static const double _pageHorizontalPadding = 16;
  static const double _maxContentWidth = 1180;

  double _contentWidth(double viewportWidth) {
    final inner = viewportWidth - _pageHorizontalPadding * 2;
    return math.min(inner, _maxContentWidth);
  }

  double _itemWidth({
    required double totalWidth,
    required int columns,
    required double spacing,
  }) {
    return (totalWidth - (spacing * (columns - 1))) / columns;
  }

  void _openPlaceholder(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    String tagLabel = 'In arrivo',
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FeaturePlaceholderPage(
          title: title,
          message: message,
          icon: icon,
          tagLabel: tagLabel,
        ),
      ),
    );
  }

  void _openManagementModule(
    BuildContext context,
    _ManagementModuleKind module, {
    StudentId? initialOpenStudentId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _ManagementModulePage(
          initialModule: module,
          initialOpenStudentId: initialOpenStudentId,
        ),
      ),
    );
  }

  Future<void> _onNewPracticeFromDashboard(BuildContext context) async {
    final outcome = await showBackofficeNewPracticeDialog(
      context,
      repository: backofficeRepository,
    );
    if (!context.mounted || outcome == null) return;
    _openManagementModule(
      context,
      _ManagementModuleKind.students,
      initialOpenStudentId: outcome.profile.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<StaffAccessSnapshot>(
      valueListenable: staffAccessNotifier,
      builder: (context, snap, _) {
        final isAdmin = AdminAccessUtils.isSchoolAdmin(
          email: AuthIdentity.resolvedAccountEmail(),
          staffRole: snap.staffRole,
        );

        if (snap.isLoading) {
          return Scaffold(
            backgroundColor: _backgroundColor,
            body: const Center(
              child: CircularProgressIndicator(color: AppVisual.logoBlue),
            ),
          );
        }

        if (!isAdmin) {
          return Scaffold(
            backgroundColor: _backgroundColor,
            appBar: AppBar(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: const Text('Accesso non consentito'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 56,
                      color: _primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Questa area è riservata agli amministratori.',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Il tuo account non dispone dei permessi necessari per accedere al pannello gestionale.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: _textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const HomePage(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Torna alla Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            toolbarHeight: 52,
            automaticallyImplyLeading: false,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                color: Colors.white,
                tooltip: 'Apri il menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: const AdminPanelAppBarTitle(
              title: 'Pannello amministrativo',
              logoHeight: 30,
            ),
          ),
          drawer: _AdminDrawer(
            onOpenPlaceholder: (title, message, icon) {
              Navigator.pop(context);
              _openPlaceholder(
                context,
                title: title,
                message: message,
                icon: icon,
              );
            },
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final viewportW = constraints.maxWidth;
              final contentW = _contentWidth(viewportW);

              final moduleColumns = contentW >= 980
                  ? 4
                  : contentW >= 620
                  ? 2
                  : 1;
              const actionSpacing = 16.0;
              final actionItemWidth = _itemWidth(
                totalWidth: contentW,
                columns: moduleColumns,
                spacing: actionSpacing,
              );

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  _pageHorizontalPadding,
                  18,
                  _pageHorizontalPadding,
                  22,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentW),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Moduli gestionali',
                                    style: textTheme.titleLarge?.copyWith(
                                      color: _textPrimaryColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Accesso rapido alle aree operative della scuola.',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: _textSecondaryColor,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _onNewPracticeFromDashboard(context),
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 20,
                                ),
                                label: const Text('Nuova pratica'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppVisual.logoBlue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, inner) {
                              final rowCount =
                                  (_managementModules.length / moduleColumns)
                                      .ceil();
                              final rawH = rowCount > 0
                                  ? (inner.maxHeight -
                                            actionSpacing * (rowCount - 1)) /
                                        rowCount
                                  : inner.maxHeight;
                              final cardHeight = rawH.clamp(168.0, 260.0);
                              return Column(
                                children: [
                                  const Spacer(),
                                  Align(
                                    alignment: Alignment.center,
                                    child: Wrap(
                                      spacing: actionSpacing,
                                      runSpacing: actionSpacing,
                                      alignment: WrapAlignment.center,
                                      children: _managementModules.map((
                                        module,
                                      ) {
                                        return SizedBox(
                                          width: actionItemWidth,
                                          height: cardHeight,
                                          child: _ManagementModuleCard(
                                            module: module,
                                            onTap: () => _openManagementModule(
                                              context,
                                              module.kind,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const Spacer(),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

enum _ManagementModuleKind {
  students,
  practices,
  agenda,
  accounting,
  studyAccess,
  videoCourses,
  reports,
  settings,
}

class _ManagementModule {
  const _ManagementModule({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.message,
    this.available = false,
  });

  final _ManagementModuleKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final String message;
  final bool available;
}

const List<_ManagementModule> _managementModules = [
  _ManagementModule(
    kind: _ManagementModuleKind.students,
    title: 'Allievi',
    subtitle: 'Profili, iscrizioni e schede 360°',
    icon: Icons.groups_rounded,
    message: 'Gestione allievi reale.',
    available: true,
  ),
  _ManagementModule(
    kind: _ManagementModuleKind.practices,
    title: 'Pratiche',
    subtitle: 'Dossier, documenti e stato pratica',
    icon: Icons.folder_copy_rounded,
    message:
        'Elenco fascicoli dal database: ricerca, filtri e apertura Scheda 360.',
    available: true,
  ),
  _ManagementModule(
    kind: _ManagementModuleKind.agenda,
    title: 'Guide / Agenda',
    subtitle: 'Guide, uscite e appuntamenti',
    icon: Icons.sailing_rounded,
    message:
        'Elenco appuntamenti guida: filtri e apertura Scheda 360. Il dettaglio e la registrazione restano nella Scheda 360.',
    available: true,
  ),
  _ManagementModule(
    kind: _ManagementModuleKind.accounting,
    title: 'Contabilità',
    subtitle: 'Incassi registrati',
    icon: Icons.payments_rounded,
    message:
        'Elenco globale incassi (sola lettura), filtri e apertura Scheda 360. '
        'La registrazione avviene solo dalla Scheda 360.',
    available: true,
  ),
  _ManagementModule(
    kind: _ManagementModuleKind.studyAccess,
    title: 'Accessi studio',
    subtitle: 'QR code e presenze in aula',
    icon: Icons.admin_panel_settings_outlined,
    message: 'Gestione accessi studio reale.',
    available: true,
  ),
  _ManagementModule(
    kind: _ManagementModuleKind.videoCourses,
    title: 'Videocorsi',
    subtitle: 'Extra, prodotti e contenuti video',
    icon: Icons.video_library_rounded,
    message:
        'Qui collegheremo prodotti Extra, video acquistabili e stato acquisti allievo.',
  ),
  _ManagementModule(
    kind: _ManagementModuleKind.reports,
    title: 'Report',
    subtitle: 'Andamento scuola e statistiche',
    icon: Icons.bar_chart_rounded,
    message:
        'Qui inseriremo report operativi su incassi, uscite, utile/perdita e attività.',
  ),
  _ManagementModule(
    kind: _ManagementModuleKind.settings,
    title: 'Impostazioni',
    subtitle: 'Prestazioni, istruttori e parametri',
    icon: Icons.tune_rounded,
    message:
        'Catalogo prestazioni preimpostate e parametri gestionali della scuola.',
    available: true,
  ),
];

_ManagementModule _moduleByKind(_ManagementModuleKind kind) {
  return _managementModules.firstWhere((module) => module.kind == kind);
}

class _ManagementModuleCard extends StatelessWidget {
  const _ManagementModuleCard({required this.module, required this.onTap});

  final _ManagementModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AdminHomePage._cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox.expand(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppVisual.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppVisual.brandAzure.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    module.icon,
                    size: 30,
                    color: AdminHomePage._primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              module.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: AdminHomePage._textPrimaryColor,
                                fontWeight: FontWeight.w800,
                                fontSize:
                                    (textTheme.titleMedium?.fontSize ?? 16) + 1,
                              ),
                            ),
                          ),
                          if (!module.available) const _ComingSoonBadge(),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        module.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AdminHomePage._textSecondaryColor,
                          height: 1.28,
                          fontSize:
                              (textTheme.bodyMedium?.fontSize ?? 14) + 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppVisual.warmBeige.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppVisual.warmBeige.withValues(alpha: 0.55)),
      ),
      child: Text(
        'In arrivo',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AdminHomePage._primaryDarkColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ManagementModulePage extends StatefulWidget {
  const _ManagementModulePage({
    required this.initialModule,
    this.initialOpenStudentId,
  });

  final _ManagementModuleKind initialModule;
  final StudentId? initialOpenStudentId;

  @override
  State<_ManagementModulePage> createState() => _ManagementModulePageState();
}

class _ManagementModulePageState extends State<_ManagementModulePage> {
  late _ManagementModuleKind _activeModule = widget.initialModule;
  final GlobalKey<SchoolManagementShellPageState> _studentsShellKey =
      GlobalKey<SchoolManagementShellPageState>();
  StudentId? _shellBootstrapStudentId;

  void _openStudent360(StudentId studentId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Student360DirectPage(studentId: studentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final module = _moduleByKind(_activeModule);
    return Scaffold(
      backgroundColor: AppVisual.canvas,
      appBar: AppBar(
        backgroundColor: AdminHomePage._primaryColor,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(module.title),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Image.asset(
              AppBranding.logoMarkWhite,
              height: 22,
              width: 22,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.home_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
            label: const Text(
              'Home',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _ModuleSwitcher(
            activeModule: _activeModule,
            onChanged: (next) => setState(() => _activeModule = next),
          ),
          Expanded(child: _buildModuleContent(module)),
        ],
      ),
    );
  }

  Widget _buildModuleContent(_ManagementModule module) {
    switch (module.kind) {
      case _ManagementModuleKind.students:
        return StaffAccessGate(
          showStaffWelcomeSnack: true,
          gateTitle: 'Backoffice scuola',
          child: SchoolManagementShellPage(
            key: _studentsShellKey,
            embedded: true,
            bootstrapSelectStudentId:
                _shellBootstrapStudentId ?? widget.initialOpenStudentId,
          ),
        );
      case _ManagementModuleKind.studyAccess:
        return const StudyAccessAdminPage(embedded: true);
      case _ManagementModuleKind.practices:
        return StaffAccessGate(
          showStaffWelcomeSnack: true,
          gateTitle: 'Backoffice scuola',
          child: PracticeDossiersDirectoryPage(
            embedded: true,
            onOpenStudent360: _openStudent360,
          ),
        );
      case _ManagementModuleKind.agenda:
        return StaffAccessGate(
          showStaffWelcomeSnack: true,
          gateTitle: 'Backoffice scuola',
          child: GuidanceAppointmentsDirectoryPage(
            embedded: true,
            onOpenStudent360: _openStudent360,
          ),
        );
      case _ManagementModuleKind.accounting:
        return StaffAccessGate(
          showStaffWelcomeSnack: true,
          gateTitle: 'Backoffice scuola',
          child: AccountingPaymentsDirectoryPage(
            embedded: true,
            onOpenStudent360: _openStudent360,
          ),
        );
      case _ManagementModuleKind.videoCourses:
      case _ManagementModuleKind.reports:
        return _ModulePlaceholder(module: module);
      case _ManagementModuleKind.settings:
        return StaffAccessGate(
          showStaffWelcomeSnack: true,
          gateTitle: 'Backoffice scuola',
          child: const SettingsDirectoryPage(embedded: true),
        );
    }
  }
}

class _ModuleSwitcher extends StatelessWidget {
  const _ModuleSwitcher({required this.activeModule, required this.onChanged});

  final _ManagementModuleKind activeModule;
  final ValueChanged<_ManagementModuleKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppVisual.ivory,
      child: Container(
        height: 58,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppVisual.border)),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          itemCount: _managementModules.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final module = _managementModules[index];
            final selected = module.kind == activeModule;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => onChanged(module.kind),
              avatar: Icon(
                module.icon,
                size: 18,
                color: selected ? Colors.white : AdminHomePage._primaryColor,
              ),
              label: Text(module.title),
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : AdminHomePage._textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
              selectedColor: AdminHomePage._primaryColor,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected
                    ? AdminHomePage._primaryColor
                    : AppVisual.border,
              ),
              showCheckmark: false,
            );
          },
        ),
      ),
    );
  }
}

class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({required this.module});

  final _ManagementModule module;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppVisual.ivory,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppVisual.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(module.icon, size: 46, color: AdminHomePage._primaryColor),
              const SizedBox(height: 14),
              Text(
                module.title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  color: AdminHomePage._textPrimaryColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                module.message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AdminHomePage._textSecondaryColor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              const _ComingSoonBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.onOpenPlaceholder});

  final void Function(String title, String message, IconData icon)
  onOpenPlaceholder;

  static const Color _primaryColor = AdminHomePage._primaryColor;
  static const Color _backgroundColor = AdminHomePage._backgroundColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: _backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: _primaryColor,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        AppBranding.logoMarkWhite,
                        height: 48,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Area amministrativa',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppBranding.inAppName,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppVisual.border.withValues(alpha: 0.5),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              children: [
                _DrawerItem(
                  icon: Icons.space_dashboard_rounded,
                  label: 'Home admin',
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.manage_accounts_rounded,
                  label: 'Account',
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountHubPage(),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.lock_open_rounded,
                  label: 'Accessi studio',
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const _ManagementModulePage(
                          initialModule: _ManagementModuleKind.studyAccess,
                        ),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.groups_rounded,
                  label: 'Allievi',
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const _ManagementModulePage(
                          initialModule: _ManagementModuleKind.students,
                        ),
                      ),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.visibility_rounded,
                  label: 'Area allievo',
                  onTap: () {
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push<void>(
                      MaterialPageRoute<void>(builder: (_) => const HomePage()),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_suggest_rounded,
                  label: 'Configurazioni',
                  onTap: () {
                    onOpenPlaceholder(
                      'Configurazioni',
                      'Qui inseriremo le impostazioni generali del gestionale.',
                      Icons.settings_suggest_rounded,
                    );
                  },
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppVisual.border.withValues(alpha: 0.5),
          ),
          ValueListenableBuilder<StaffAccessSnapshot>(
            valueListenable: staffAccessNotifier,
            builder: (context, staffSnap, _) {
              return ValueListenableBuilder<StudentSession?>(
                valueListenable: studentSession,
                builder: (context, sess, _) {
                  final canLogout = staffSnap.hasAuthSession || sess != null;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: _DrawerItem(
                      icon: Icons.logout_rounded,
                      label: 'Esci',
                      onTap: () async {
                        if (!canLogout) {
                          onOpenPlaceholder(
                            'Esci',
                            'Non risulti collegato con un account attivo in questa sessione.',
                            Icons.logout_rounded,
                          );
                          return;
                        }

                        Navigator.of(context).pop();
                        await signOutAndReturnToWelcome();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const Color _textPrimaryColor = AdminHomePage._textPrimaryColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(icon, color: AppVisual.logoBlue),
          title: Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: onTap,
          hoverColor: AppVisual.chipFill,
          splashColor: AppVisual.logoBlue.withValues(alpha: 0.09),
        ),
      ),
    );
  }
}
