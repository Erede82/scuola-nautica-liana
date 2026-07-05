import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_branding.dart' show AppBranding;
import '../data/guida_badge_notifier.dart';
import '../debug/quiz_flow_debug.dart';
import '../services/demo_student_enrollment.dart';
import '../services/guida_reminders_loader.dart';
import '../services/staff_access_service.dart';
import '../utils/staff_area_navigation.dart';
import '../widgets/dashboard_action_card.dart';
import '../widgets/student_home_sidebar.dart';
import 'extra_page.dart';
import 'feature_placeholder_page.dart';
import 'guida_page.dart';
import 'quiz_dashboard_page.dart';
import '../theme/app_visual_tokens.dart';

String _formatPersonNameForDisplay(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  return t
      .split(RegExp(r'\s+'))
      .map((w) {
        if (w.isEmpty) return w;
        if (w.length == 1) return w.toUpperCase();
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      })
      .join(' ');
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;

  static const double _pageHorizontalPadding = 16;
  static const double _gridCrossSpacing = 12;
  static const double _gridMainSpacing = 12;
  static const double _sidebarBreakpoint = 900;
  static const double _sidebarWidth = 280;

  /// Area centrale più ampia su desktop (sidebar a parte).
  static const double _maxDashboardWidth = 1200;

  void _openPlaceholder(
    BuildContext context,
    String title,
    String message,
    IconData icon,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => FeaturePlaceholderPage(
          title: title,
          message: message,
          icon: icon,
          tagLabel: 'In arrivo',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useFixedSidebar = constraints.maxWidth >= _sidebarBreakpoint;

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            centerTitle: true,
            toolbarHeight: 58,
            automaticallyImplyLeading: !useFixedSidebar,
            leading: useFixedSidebar
                ? null
                : Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      color: Colors.white,
                      tooltip: 'Apri il menu',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AppBranding.logoMarkWhite,
                    height: 32,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    AppBranding.inAppName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            shape: const RoundedRectangleBorder(),
          ),
          drawer: useFixedSidebar
              ? null
              : Drawer(
                  child: StudentHomeSidebar(
                    closeDrawerOnNavigate: true,
                    onOpenPlaceholder: (title, message, icon) {
                      Navigator.pop(context);
                      _openPlaceholder(context, title, message, icon);
                    },
                  ),
                ),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (useFixedSidebar)
                SizedBox(
                  width: _sidebarWidth,
                  child: Material(
                    elevation: 0,
                    color: _backgroundColor,
                    child: StudentHomeSidebar(
                      closeDrawerOnNavigate: false,
                      onOpenPlaceholder: (title, message, icon) {
                        _openPlaceholder(context, title, message, icon);
                      },
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _GuidaBadgeBootstrap(),
                    const _StaffStudentAreaBanner(),
                    Expanded(
                      child: _HomeMainPanel(
                        useFixedSidebar: useFixedSidebar,
                        textTheme: textTheme,
                        dashboardChildren: (ctx) => _dashboardCardChildren(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _dashboardCardChildren(BuildContext context) {
    return [
      DashboardActionCard(
        dense: true,
        title: 'Quiz',
        subtitle: 'Lezioni, schede, ripasso errori, esame e statistiche',
        useStudentBrandStyle: true,
        icon: Icons.quiz_rounded,
        onTap: () {
          qfLog('home: tap card Quiz');
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const QuizDashboardPage()),
          );
        },
      ),
      ValueListenableBuilder<int>(
        valueListenable: GuidaBadgeNotifier.unreadCount,
        builder: (context, unread, _) {
          return DashboardActionCard(
            dense: true,
            title: 'Guida',
            subtitle: 'Comunicazioni della scuola su lezioni e uscite in mare',
            useStudentBrandStyle: true,
            icon: Icons.event_note_rounded,
            badge: unread > 0
                ? DashboardCardBadge.none
                : DashboardCardBadge.nuovo,
            unreadCount: unread > 0 ? unread : null,
            onTap: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const GuidaPage()),
              );
            },
          );
        },
      ),
      DashboardActionCard(
        dense: true,
        title: 'Extra',
        subtitle: 'Video e contenuti aggiuntivi a pagamento',
        useStudentBrandStyle: true,
        icon: Icons.play_circle_outline_rounded,
        badge: DashboardCardBadge.none,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const ExtraPage()),
        ),
      ),
    ];
  }
}

/// Banner visibile solo allo staff che sta visualizzando l'area allievo.
class _StaffStudentAreaBanner extends StatelessWidget {
  const _StaffStudentAreaBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ValueListenableBuilder<StaffAccessSnapshot>(
      valueListenable: staffAccessNotifier,
      builder: (context, snap, _) {
        if (snap.isLoading || !snap.canAccessBackoffice) {
          return const SizedBox.shrink();
        }

        final returnButton = TextButton(
          onPressed: () => returnToAdministrativePanel(context, snap),
          style: TextButton.styleFrom(
            foregroundColor: HomePage._primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('Torna al pannello amministrativo'),
        );

        return Material(
          color: HomePage._primaryColor.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 480;
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 20,
                            color: HomePage._primaryColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Stai visualizzando l\'area allievo come staff',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppVisual.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: returnButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 20,
                      color: HomePage._primaryColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Stai visualizzando l\'area allievo come staff',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppVisual.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    returnButton,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Pannello contenuto principale: con sidebar, raccordo arrotondato a sinistra
/// e ombra leggera; senza sidebar stesso aspetto a tutta larghezza.
class _HomeMainPanel extends StatelessWidget {
  const _HomeMainPanel({
    required this.useFixedSidebar,
    required this.textTheme,
    required this.dashboardChildren,
  });

  final bool useFixedSidebar;
  final TextTheme textTheme;
  final List<Widget> Function(BuildContext) dashboardChildren;

  static const Color _backgroundColor = HomePage._backgroundColor;
  static const double _pageHorizontalPadding = HomePage._pageHorizontalPadding;
  static const double _gridCrossSpacing = HomePage._gridCrossSpacing;
  static const double _gridMainSpacing = HomePage._gridMainSpacing;
  static const double _maxDashboardWidth = HomePage._maxDashboardWidth;
  static const double _contentPanelLeftRadius = 20;

  double _contentWidth(double bodyViewportWidth) {
    final inner = bodyViewportWidth - _pageHorizontalPadding * 2;
    return math.min(inner, _maxDashboardWidth);
  }

  double _gridChildAspectRatio(double viewportWidth) {
    if (viewportWidth >= 900) return 1.38;
    if (viewportWidth >= 600) return 1.28;
    return 1.14;
  }

  double _gridHeight(double contentWidth, double aspectRatio) {
    final tileWidth = (contentWidth - _gridCrossSpacing) / 2;
    final tileHeight = tileWidth / aspectRatio;
    return tileHeight * 2 + _gridMainSpacing;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, layout) {
        final bodyW = layout.maxWidth;
        final contentW = _contentWidth(bodyW);
        final aspect = _gridChildAspectRatio(bodyW);
        final gridH = _gridHeight(contentW, aspect);
        final wideCards = useFixedSidebar && bodyW >= 640;

        final scrollable = Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              _pageHorizontalPadding,
              12,
              _pageHorizontalPadding,
              24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentW),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompactWelcomePanel(
                    textTheme: textTheme,
                    wideLayout: bodyW >= 640 && contentW >= 400,
                  ),
                  SizedBox(height: bodyW >= 600 ? 14 : 12),
                  if (wideCards)
                    const _DesktopDashboardCards()
                  else
                    SizedBox(
                      height: gridH,
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: _gridCrossSpacing,
                        mainAxisSpacing: _gridMainSpacing,
                        childAspectRatio: aspect,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        children: dashboardChildren(context),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        if (!useFixedSidebar) {
          return ColoredBox(color: _backgroundColor, child: scrollable);
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_contentPanelLeftRadius),
              bottomLeft: Radius.circular(_contentPanelLeftRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x14005E83),
                offset: Offset(-2, 0),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: scrollable,
        );
      },
    );
  }
}

/// Layout desktop: prima riga Quiz + Guida, seconda riga Extra a tutta larghezza.
class _DesktopDashboardCards extends StatelessWidget {
  const _DesktopDashboardCards();

  static const double _rowH = 204;
  static const double _gap = 14;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: _rowH,
                child: DashboardActionCard(
                  dense: false,
                  title: 'Quiz',
                  subtitle:
                      'Lezioni, schede, ripasso errori, esame e statistiche',
                  useStudentBrandStyle: true,
                  icon: Icons.quiz_rounded,
                  onTap: () {
                    qfLog('home: tap card Quiz (desktop row)');
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const QuizDashboardPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(
              child: SizedBox(
                height: _rowH,
                child: ValueListenableBuilder<int>(
                  valueListenable: GuidaBadgeNotifier.unreadCount,
                  builder: (context, unread, _) {
                    return DashboardActionCard(
                      dense: false,
                      title: 'Guida',
                      subtitle:
                          'Comunicazioni della scuola su lezioni e uscite in mare',
                      useStudentBrandStyle: true,
                      icon: Icons.event_note_rounded,
                      badge: unread > 0
                          ? DashboardCardBadge.none
                          : DashboardCardBadge.nuovo,
                      unreadCount: unread > 0 ? unread : null,
                      onTap: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const GuidaPage(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: _gap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: _rowH,
                child: DashboardActionCard(
                  dense: false,
                  title: 'Extra',
                  subtitle: 'Video e contenuti aggiuntivi a pagamento',
                  useStudentBrandStyle: true,
                  icon: Icons.play_circle_outline_rounded,
                  badge: DashboardCardBadge.none,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const ExtraPage()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactWelcomePanel extends StatelessWidget {
  const _CompactWelcomePanel({
    required this.textTheme,
    required this.wideLayout,
  });

  final TextTheme textTheme;
  final bool wideLayout;

  static const Color _brandAqua = Color(0xFF17A1C8);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: studentSession,
      builder: (context, sess, _) {
        final greeting = sess != null && sess.displayName.trim().isNotEmpty
            ? 'Ciao, ${_formatPersonNameForDisplay(sess.displayName)}'
            : AppBranding.inAppName;
        const hint = 'Scegli una sezione per continuare il tuo percorso.';

        final iconBubble = Container(
          width: wideLayout ? 52 : 46,
          height: wideLayout ? 52 : 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.directions_boat_rounded,
            color: Colors.white,
            size: wideLayout ? 28 : 25,
          ),
        );

        final title = Text(
          greeting,
          style: (wideLayout ? textTheme.titleMedium : textTheme.titleSmall)
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        );

        final subtitle = Text(
          hint,
          maxLines: wideLayout ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          textAlign: wideLayout ? TextAlign.start : TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.32,
            fontWeight: FontWeight.w500,
          ),
        );

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: wideLayout ? 20 : 16,
            vertical: wideLayout ? 18 : 16,
          ),
          decoration: BoxDecoration(
            color: _brandAqua,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _brandAqua.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: wideLayout
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    iconBubble,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [title, const SizedBox(height: 6), subtitle],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconBubble,
                    const SizedBox(height: 10),
                    title,
                    const SizedBox(height: 8),
                    subtitle,
                  ],
                ),
        );
      },
    );
  }
}

/// Precarica il badge Guida da Supabase quando l’allievo entra in Home.
class _GuidaBadgeBootstrap extends StatefulWidget {
  const _GuidaBadgeBootstrap();

  @override
  State<_GuidaBadgeBootstrap> createState() => _GuidaBadgeBootstrapState();
}

class _GuidaBadgeBootstrapState extends State<_GuidaBadgeBootstrap> {
  @override
  void initState() {
    super.initState();
    studentSession.addListener(_onSessionChanged);
    GuidaRemindersLoader.loadForCurrentStudent();
  }

  void _onSessionChanged() {
    GuidaRemindersLoader.loadForCurrentStudent();
  }

  @override
  void dispose() {
    studentSession.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
