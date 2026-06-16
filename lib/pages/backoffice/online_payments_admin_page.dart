import 'package:flutter/material.dart';

import '../../theme/app_visual_tokens.dart';
import '../../widgets/backoffice/backoffice_ui_tokens.dart';

/// Modulo Pagamenti online — shell UI iniziale (P2), separato da Contabilità.
class OnlinePaymentsAdminPage extends StatelessWidget {
  const OnlinePaymentsAdminPage({super.key, this.embedded = false});

  final bool embedded;

  static const List<_SummaryMetric> _summaryMetrics = [
    _SummaryMetric(
      title: 'Ordini in attesa',
      value: '3',
      subtitle: 'Placeholder',
      icon: Icons.hourglass_top_rounded,
    ),
    _SummaryMetric(
      title: 'Pagamenti riusciti',
      value: '12',
      subtitle: 'Placeholder',
      icon: Icons.check_circle_outline_rounded,
      valueColor: BackofficeUiTokens.success,
    ),
    _SummaryMetric(
      title: 'Privatisti',
      value: '2',
      subtitle: 'Placeholder',
      icon: Icons.person_outline_rounded,
    ),
    _SummaryMetric(
      title: 'Regali / omaggi',
      value: '1',
      subtitle: 'Placeholder',
      icon: Icons.card_giftcard_outlined,
    ),
  ];

  static const List<_FutureSection> _futureSections = [
    _FutureSection(
      title: 'Ordini online',
      description:
          'Elenco ordini, stati checkout e collegamento facoltativo allievo.',
      icon: Icons.receipt_long_outlined,
    ),
    _FutureSection(
      title: 'Videocorsi / Extra',
      description:
          'Fulfillment accessi video dopo pagamento, senza toccare Contabilità.',
      icon: Icons.video_library_outlined,
    ),
    _FutureSection(
      title: 'Privatisti',
      description:
          'Ordini di clienti esterni senza creare record in anagrafica allievi.',
      icon: Icons.groups_outlined,
    ),
    _FutureSection(
      title: 'Regali / omaggi',
      description: 'Sblocco manuale tracciato come regalo o omaggio.',
      icon: Icons.redeem_outlined,
    ),
    _FutureSection(
      title: 'Provider di pagamento',
      description: 'Stripe, PayPal, Revolut e link pagamento manuale.',
      icon: Icons.account_balance_wallet_outlined,
      providers: ['Stripe', 'PayPal', 'Revolut', 'Link manuale'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppVisual.canvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!embedded)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Pagamenti online',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: BackofficeUiTokens.text,
                      ),
                    ),
                  ),
                Text(
                  'Pagamenti online',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: BackofficeUiTokens.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ordini online, link pagamento, privatisti e sblocchi videocorsi '
                  'separati dalla Contabilità',
                  style: textTheme.bodySmall?.copyWith(
                    color: BackofficeUiTokens.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const _SeparationInfoBanner(),
                const SizedBox(height: 20),
                Text(
                  'Riepilogo',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: BackofficeUiTokens.text,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                _SummaryGrid(metrics: _summaryMetrics, wide: wide),
                const SizedBox(height: 24),
                Text(
                  'Sezioni future',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: BackofficeUiTokens.text,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 10),
                ..._futureSections.map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FutureSectionCard(section: section),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SeparationInfoBanner extends StatelessWidget {
  const _SeparationInfoBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppVisual.logoBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppVisual.logoBlue.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 22,
            color: AppVisual.logoBlue.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Questa sezione non modifica Contabilità, registro pagamenti, '
              'Scheda 360 o record_payment',
              style: textTheme.bodyMedium?.copyWith(
                color: BackofficeUiTokens.text,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric {
  const _SummaryMetric({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.valueColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? valueColor;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.metrics, required this.wide});

  final List<_SummaryMetric> metrics;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
        children: metrics
            .map((m) => _SummaryMetricTile(metric: m))
            .toList(growable: false),
      );
    }

    return Column(
      children: metrics
          .map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SummaryMetricTile(metric: m),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({required this.metric});

  final _SummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppVisual.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppVisual.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              metric.icon,
              size: 22,
              color: AppVisual.logoBlue.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    metric.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppVisual.inkMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.value,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: metric.valueColor ?? BackofficeUiTokens.text,
                    ),
                  ),
                  if (metric.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      metric.subtitle!,
                      style: textTheme.labelSmall?.copyWith(
                        color: AppVisual.inkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FutureSection {
  const _FutureSection({
    required this.title,
    required this.description,
    required this.icon,
    this.providers,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<String>? providers;
}

class _FutureSectionCard extends StatelessWidget {
  const _FutureSectionCard({required this.section});

  final _FutureSection section;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: BackofficeUiTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppVisual.brandAzure.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    section.icon,
                    size: 22,
                    color: AppVisual.logoBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              section.title,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: BackofficeUiTokens.text,
                              ),
                            ),
                          ),
                          const _ComingSoonBadge(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.description,
                        style: textTheme.bodySmall?.copyWith(
                          color: BackofficeUiTokens.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (section.providers != null && section.providers!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: section.providers!
                    .map(
                      (label) => Chip(
                        label: Text(label),
                        labelStyle: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: AppVisual.border),
                        backgroundColor: AppVisual.chipFill,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppVisual.warmBeige.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppVisual.warmBeige.withValues(alpha: 0.55)),
      ),
      child: Text(
        'In arrivo',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppVisual.logoBlueDeep,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
