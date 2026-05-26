import 'package:flutter/material.dart';

import '../models/guida_reminder.dart';
import '../utils/guida_datetime_format.dart';
import '../widgets/guida_reminder_status_chip.dart';
import '../theme/app_visual_tokens.dart';

/// Dettaglio promemoria Guida con messaggio completo e “Segna come letto”.
class GuidaReminderDetailPage extends StatefulWidget {
  const GuidaReminderDetailPage({
    super.key,
    required this.reminder,
  });

  final GuidaReminder reminder;

  @override
  State<GuidaReminderDetailPage> createState() =>
      _GuidaReminderDetailPageState();
}

class _GuidaReminderDetailPageState extends State<GuidaReminderDetailPage> {
  late GuidaReminder _reminder;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  void initState() {
    super.initState();
    _reminder = widget.reminder;
  }

  void _onMarkAsRead() {
    if (!_reminder.canMarkAsRead) return;
    setState(() {
      _reminder = _reminder.markedAsRead();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Segnato come letto.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateStr = GuidaDateTimeFormat.formatDate(_reminder.scheduledAt);
    final timeStr = GuidaDateTimeFormat.formatTime(
      _reminder.scheduledAt,
      override: _reminder.timeDisplayOverride,
    );

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Dettaglio'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: _primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reminder.title,
                      style: textTheme.titleLarge?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GuidaReminderStatusChip(status: _reminder.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _DetailSection(
            title: 'Istruttore',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La scuola assegna l’istruttore e comunica chi accompagna la lezione o l’uscita '
                  'attraverso questo messaggio: non è una scelta da parte dello studente.',
                  style: textTheme.bodySmall?.copyWith(
                    color: _textPrimaryColor.withOpacity(0.78),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _reminder.instructorName,
                  style: textTheme.bodyLarge?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _DetailSection(
            title: 'Data e ora',
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: _primaryColor.withOpacity(0.85),
                ),
                const SizedBox(width: 10),
                Text(
                  dateStr,
                  style: textTheme.bodyLarge?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.schedule_rounded,
                  size: 20,
                  color: _primaryColor.withOpacity(0.85),
                ),
                const SizedBox(width: 10),
                Text(
                  timeStr,
                  style: textTheme.bodyLarge?.copyWith(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_reminder.category != null) ...[
            const SizedBox(height: 14),
            _DetailSection(
              title: 'Tipo',
              child: Text(
                _reminder.category!.label,
                style: textTheme.bodyMedium?.copyWith(
                  color: _textPrimaryColor.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _DetailSection(
            title: 'Messaggio',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _neutralColor),
              ),
              child: Text(
                _reminder.bodyForDetail,
                style: textTheme.bodyMedium?.copyWith(
                  color: _textPrimaryColor,
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          if (_reminder.canMarkAsRead)
            FilledButton.icon(
              onPressed: _onMarkAsRead,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: const Text('Segna come letto'),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Torna indietro'),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: _textPrimaryColor.withOpacity(0.5),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.9,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
