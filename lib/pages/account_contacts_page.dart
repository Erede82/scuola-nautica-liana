import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import '../widgets/branded_app_bar_title.dart';
import '../utils/school_contact_launcher.dart';
import '../theme/app_visual_tokens.dart';

/// Pagina contatti: orari chiari + blocco compatto 2×2 (Maps, WhatsApp, Instagram, recensioni).
class AccountContactsPage extends StatelessWidget {
  const AccountContactsPage({super.key});

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
        title: const SectionAppBarTitle('Contatti', logoHeight: 30),
        shape: const RoundedRectangleBorder(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            AppBranding.schoolName,
            style: textTheme.titleLarge?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppBranding.schoolAddressLine.trim(),
            style: textTheme.bodyMedium?.copyWith(
              color: _textPrimaryColor.withOpacity(0.82),
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Telefono / WhatsApp: ${AppBranding.supportPhoneDisplay}',
            style: textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor.withOpacity(0.68),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          _HoursPanel(textTheme: textTheme),
          const SizedBox(height: 22),
          Text(
            'Collegamenti rapidi',
            style: textTheme.titleSmall?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Apri Maps, WhatsApp, Instagram o le recensioni con un tocco.',
            style: textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor.withOpacity(0.72),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _ContactLinksList(
            items: [
              _ContactLinkSpec(
                icon: Icons.map_rounded,
                title: 'Google Maps',
                subtitle: 'Indicazioni verso la sede',
                enabled: AppBranding.hasMapUrl,
                onTap: () => SchoolContactLauncher.openMap(context),
              ),
              _ContactLinkSpec(
                icon: Icons.chat_rounded,
                title: 'WhatsApp',
                subtitle: AppBranding.supportPhoneDisplay,
                enabled: AppBranding.hasWhatsApp,
                onTap: () => SchoolContactLauncher.openWhatsApp(context),
              ),
              _ContactLinkSpec(
                icon: Icons.camera_alt_rounded,
                title: 'Instagram',
                subtitle: '@scuolanauticaliana',
                enabled: AppBranding.hasInstagramUrl,
                onTap: () => SchoolContactLauncher.openInstagram(context),
              ),
              _ContactLinkSpec(
                icon: Icons.star_rounded,
                title: 'Recensioni Google',
                subtitle: 'Lascia o leggi le recensioni',
                enabled: AppBranding.hasReviewsUrl,
                onTap: () => SchoolContactLauncher.openReviews(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Le iscrizioni e le pratiche restano gestite in segreteria; '
            'questa pagina riassume orari e collegamenti utili.',
            style: textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor.withOpacity(0.65),
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursPanel extends StatelessWidget {
  const _HoursPanel({required this.textTheme});

  final TextTheme textTheme;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: _primaryColor.withOpacity(0.92),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orari',
                  style: textTheme.labelSmall?.copyWith(
                    color: _textPrimaryColor.withOpacity(0.55),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppBranding.officeAndCourseHoursDetail,
                  style: textTheme.bodyMedium?.copyWith(
                    color: _textPrimaryColor.withOpacity(0.9),
                    height: 1.42,
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

class _ContactLinkSpec {
  const _ContactLinkSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
}

class _ContactLinksList extends StatelessWidget {
  const _ContactLinksList({required this.items});

  final List<_ContactLinkSpec> items;

  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: _neutralColor.withOpacity(0.85),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: items[i].enabled ? items[i].onTap : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: items[i].enabled
                                ? _primaryColor.withOpacity(0.1)
                                : _neutralColor.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            items[i].icon,
                            size: 22,
                            color: items[i].enabled
                                ? _primaryColor
                                : _textPrimaryColor.withOpacity(0.38),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i].title,
                                style: textTheme.titleSmall?.copyWith(
                                  color: items[i].enabled
                                      ? _textPrimaryColor
                                      : _textPrimaryColor.withOpacity(0.45),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                items[i].subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: _textPrimaryColor.withOpacity(
                                    items[i].enabled ? 0.65 : 0.4,
                                  ),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _textPrimaryColor.withOpacity(
                            items[i].enabled ? 0.35 : 0.22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
