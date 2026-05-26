import 'package:flutter/material.dart';

import '../widgets/branded_app_bar_title.dart';
import '../data/guida_badge_notifier.dart';
import '../data/guida_reminders_mock.dart';
import '../models/guida_reminder.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/guida_reminder_card.dart';
import 'guida_reminder_detail_page.dart';
import '../theme/app_visual_tokens.dart';

/// Promemoria e avvisi per le lezioni di guida.
class GuidaPage extends StatefulWidget {
  const GuidaPage({
    super.key,
    this.initialReminders,
  });

  final List<GuidaReminder>? initialReminders;

  @override
  State<GuidaPage> createState() => _GuidaPageState();
}

class _GuidaPageState extends State<GuidaPage> {
  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;

  late List<GuidaReminder> _reminders;

  @override
  void initState() {
    super.initState();
    _reminders = List<GuidaReminder>.from(
      widget.initialReminders ?? GuidaRemindersMock.seeded,
    );
    GuidaBadgeNotifier.refreshFrom(_reminders);
  }

  List<GuidaReminder> get _sorted =>
      GuidaRemindersMock.sortedUpcomingFirst(_reminders);

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isArchivio(GuidaReminder r) {
    if (r.status == GuidaReminderStatus.completato) return true;
    return r.scheduledAt.isBefore(_startOfToday);
  }

  bool _isProssima(GuidaReminder r) => !_isArchivio(r);

  Future<void> _openDetail(GuidaReminder r) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => GuidaReminderDetailPage(reminder: r),
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      setState(() {
        final i = _reminders.indexWhere((e) => e.id == r.id);
        if (i >= 0) {
          _reminders[i] = _reminders[i].markedAsRead();
        }
      });
      GuidaBadgeNotifier.refreshFrom(_reminders);
    }
  }

  void _syncBadge() => GuidaBadgeNotifier.refreshFrom(_reminders);

  List<Widget> _buildReminderBlocks() {
    final filtered = _sorted;
    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppEmptyState(
            title: 'Nessun promemoria',
            message: 'Al momento non ci sono comunicazioni da mostrare.',
            icon: Icons.inbox_outlined,
            tagLabel: 'Guida',
          ),
        ),
      ];
    }

    final prossime = filtered.where(_isProssima).toList();
    final archivio = filtered.where(_isArchivio).toList();

    final blocks = <Widget>[];

    if (prossime.isNotEmpty) {
      blocks.add(_SectionHeader(title: 'Prossime'));
      blocks.add(const SizedBox(height: 10));
      for (final r in prossime) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GuidaReminderCard(
              reminder: r,
              isInArchivio: false,
              onTap: () => _openDetail(r),
            ),
          ),
        );
      }
    }

    if (prossime.isEmpty && archivio.isNotEmpty) {
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppEmptyState(
            title: 'Nessuna guida imminente',
            message:
                'Per le prossime uscite, quando la scuola pubblicherà un avviso, lo vedrai in questa sezione. '
                "Sotto trovi l'archivio.",
            icon: Icons.inbox_outlined,
            tagLabel: 'Calendario',
          ),
        ),
      );
    }

    if (archivio.isNotEmpty) {
      blocks.add(const SizedBox(height: 6));
      blocks.add(_SectionHeader(title: 'Archivio'));
      blocks.add(const SizedBox(height: 10));
      for (final r in archivio) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GuidaReminderCard(
              reminder: r,
              isInArchivio: true,
              onTap: () => _openDetail(r),
            ),
          ),
        );
      }
    }

    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_reminders.isEmpty) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(),
          title: const SectionAppBarTitle('Guida', logoHeight: 28),
        ),
        body: AppEmptyState(
          title: 'Nessun promemoria',
          message:
              'Quando la scuola pubblicherà avvisi sulle lezioni di guida, li vedrai qui.',
          icon: Icons.event_available_outlined,
          tagLabel: 'Area studenti',
          primaryActionLabel: 'Carica esempi',
          primaryActionIcon: Icons.refresh_rounded,
          onPrimaryActionPressed: () => setState(() {
            _reminders = List<GuidaReminder>.from(GuidaRemindersMock.seeded);
            _syncBadge();
          }),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(),
        title: const SectionAppBarTitle('Guida', logoHeight: 28),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            'Guida: promemoria e archivio',
            style: textTheme.titleMedium?.copyWith(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Istruttore e dettagli sono definiti dalla scuola. Qui trovi prossime uscite e guide già svolte.',
            style: textTheme.bodySmall?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.82),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ..._buildReminderBlocks(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        title.toUpperCase(),
        style: textTheme.labelSmall?.copyWith(
          color: _textPrimaryColor.withValues(alpha: 0.52),
          fontWeight: FontWeight.w800,
          letterSpacing: 1.05,
          fontSize: 10,
        ),
      ),
    );
  }
}
