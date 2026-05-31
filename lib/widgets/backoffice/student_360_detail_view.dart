import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/backoffice_mock/school_backoffice_demo_data.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import 'backoffice_formatters.dart';
import 'backoffice_ui_tokens.dart';
import 'student_backoffice_dialogs.dart';
import 'student_onboarding_section.dart';
import 'student_record_dialogs.dart';
import '../../theme/app_visual_tokens.dart';

/// Pannello dettaglio studente (vista 360) — desktop-oriented con azioni staff.
class Student360DetailView extends StatelessWidget {
  const Student360DetailView({
    super.key,
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  static const Color _primary = AppVisual.logoBlue;
  static const Color _accent = AppVisual.brandAzure;
  static const Color _bg = AppVisual.canvas;
  static const Color _neutral = AppVisual.chipFill;
  static const Color _text = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 8,
      child: ColoredBox(
        color: _bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 720;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 16,
                    compact ? 8 : 10,
                    compact ? 12 : 16,
                    compact ? 4 : 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              view.profile.displayName,
                              style: textTheme.titleMedium?.copyWith(
                                color: _text,
                                fontWeight: FontWeight.w800,
                                fontSize: compact ? 18 : 20,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 8 : 10,
                              vertical: compact ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color: _accent.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _neutral),
                            ),
                            child: Text(
                              BackofficeFormatters.enrollmentCoursePath(
                                view.profile.enrolledCoursePath,
                              ),
                              style: textTheme.labelMedium?.copyWith(
                                color: _primary,
                                fontWeight: FontWeight.w800,
                                fontSize: compact ? 11 : 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _SummaryCardsRow(view: view),
            ),
            const SizedBox(height: 4),
            Material(
              color: const Color(0xFFE8EDF5),
              elevation: 0,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                labelColor: _primary,
                unselectedLabelColor: _text.withValues(alpha: 0.55),
                indicatorColor: _primary,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                unselectedLabelStyle: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.pressed)) {
                    return _primary.withValues(alpha: 0.08);
                  }
                  return null;
                }),
                tabs: const [
                  Tab(text: 'Onboarding'),
                  Tab(text: 'Anagrafica'),
                  Tab(text: 'Studio'),
                  Tab(text: 'Guide'),
                  Tab(text: 'Esami'),
                  Tab(text: 'Contabilità'),
                  Tab(text: 'Pratica / Doc.'),
                  Tab(text: 'Registro interno'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  StudentOnboardingSection(
                    view: view,
                    repository: repository,
                    onRefreshDetail: onRefreshDetail,
                  ),
                  _SectionAnagrafica(view: view),
                  _SectionStudio(
                    view: view,
                    repository: repository,
                    onRefreshDetail: onRefreshDetail,
                  ),
                  _SectionGuide(
                    view: view,
                    repository: repository,
                    onRefreshDetail: onRefreshDetail,
                  ),
                  _SectionEsami(
                    view: view,
                    repository: repository,
                    onRefreshDetail: onRefreshDetail,
                  ),
                  _SectionContabilita(
                    view: view,
                    repository: repository,
                    onRefreshDetail: onRefreshDetail,
                  ),
                  _SectionPratica(
                    view: view,
                    repository: repository,
                    onRefreshDetail: onRefreshDetail,
                  ),
                  _SectionRegistroInterno(
                    view: view,
                    repository: repository,
                    onRefreshDetail: onRefreshDetail,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCardsRow extends StatelessWidget {
  const _SummaryCardsRow({required this.view});

  final StudentAdmin360View view;

  GuidanceAppointment? _nextAppointment() {
    final list = List<GuidanceAppointment>.from(view.appointments);
    if (list.isEmpty) return null;
    list.sort((a, b) => a.lessonDate.compareTo(b.lessonDate));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    for (final a in list) {
      final d = DateTime(
        a.lessonDate.year,
        a.lessonDate.month,
        a.lessonDate.day,
      );
      if (!d.isBefore(todayDate)) return a;
    }
    return list.last;
  }

  String _lastExamLabel() {
    final lt = view.examSummary.latestTheory;
    final lp = view.examSummary.latestPractical;
    if (lt == null && lp == null) return 'Nessun esame registrato';
    if (lt == null) {
      final p = lp!; // esclude coppia null sopra
      return '${BackofficeFormatters.examType(p.examType)}: '
          '${BackofficeFormatters.examResult(p.result)} '
          '(${BackofficeFormatters.dateUi(p.examDate)})';
    }
    if (lp == null) {
      final t = lt; // promosso non-null dopo rami precedenti
      return '${BackofficeFormatters.examType(t.examType)}: '
          '${BackofficeFormatters.examResult(t.result)} '
          '(${BackofficeFormatters.dateUi(t.examDate)})';
    }
    final dt = lt.examDate;
    final dp = lp.examDate;
    final pick = (dt != null && dp != null && dt.isAfter(dp)) ? lt : lp;
    return '${BackofficeFormatters.examType(pick.examType)}: '
        '${BackofficeFormatters.examResult(pick.result)} '
        '(${BackofficeFormatters.dateUi(pick.examDate)})';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dossier = view.practiceDossier;
    final next = _nextAppointment();

    final cards = [
      (
        'Stato pratica',
        dossier == null
            ? 'Nessun fascicolo'
            : BackofficeFormatters.practiceStatus(dossier.practiceStatus),
        Icons.folder_special_outlined,
      ),
      (
        'Saldo residuo',
        BackofficeFormatters.moneyEur(
          view.financialSummary.remainingBalanceCents,
        ),
        Icons.account_balance_wallet_outlined,
      ),
      (
        'Prossima guida',
        next == null
            ? 'Nessun appuntamento'
            : '${BackofficeFormatters.dateTimeUi(next.startTime ?? next.lessonDate)} · '
                  '${next.instructorName ?? '—'}',
        Icons.event_available_outlined,
      ),
      ('Ultimo esame', _lastExamLabel(), Icons.fact_check_outlined),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final count = w > 1100
            ? 4
            : w > 700
            ? 2
            : 1;
        final tileW = (w - (count - 1) * 12) / count;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cards
              .map(
                (c) => SizedBox(
                  width: tileW.clamp(150, 400),
                  child: _SummaryCard(
                    title: c.$1,
                    value: c.$2,
                    icon: c.$3,
                    textTheme: textTheme,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.textTheme,
  });

  final String title;
  final String value;
  final IconData icon;
  final TextTheme textTheme;

  static const Color _primary = AppVisual.logoBlue;
  static const Color _text = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppVisual.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppVisual.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: _primary.withValues(alpha: 0.85), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppVisual.inkMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: textTheme.titleSmall?.copyWith(
                      color: _text,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionScroll extends StatelessWidget {
  const _SectionScroll({required this.child});

  final Widget child;

  static const Color _bg = AppVisual.canvas;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final pad = compact ? 12.0 : 16.0;
        return ColoredBox(
          color: _bg,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: SizedBox(
              width: constraints.maxWidth,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  static const Color _card = AppVisual.ivory;
  static const Color _neutral = AppVisual.chipFill;
  static const Color _text = AppVisual.ink;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final padding = compact ? 12.0 : 16.0;
        final titleGap = compact ? 8.0 : 12.0;
        final textTheme = Theme.of(context).textTheme;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            border: Border.all(color: _neutral),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  color: _text,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 15 : null,
                ),
              ),
              SizedBox(height: titleGap),
              child,
            ],
          ),
        );
      },
    );
  }
}

Widget _kvRow(String k, String v, TextTheme textTheme) {
  const textColor = AppVisual.ink;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 160,
          child: Text(
            k,
            style: textTheme.bodySmall?.copyWith(
              color: textColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            v,
            style: textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionAnagrafica extends StatelessWidget {
  const _SectionAnagrafica({required this.view});

  final StudentAdmin360View view;

  @override
  Widget build(BuildContext context) {
    final p = view.profile;
    final textTheme = Theme.of(context).textTheme;
    final addr = p.address;

    return _SectionScroll(
      child: _SectionContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InfoCard(
              title: 'Dati personali e contatti',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kvRow('Nome', p.firstName, textTheme),
                    _kvRow('Cognome', p.lastName, textTheme),
                    _kvRow('Telefono', p.phone ?? '—', textTheme),
                    _kvRow('Email', p.email ?? '—', textTheme),
                    _kvRow(
                      'Data di nascita',
                      p.birthDate != null
                          ? BackofficeFormatters.dateUi(p.birthDate)
                          : '—',
                      textTheme,
                    ),
                    if (p.birthPlace != null &&
                        p.birthPlace!.trim().isNotEmpty)
                      _kvRow(
                        'Luogo di nascita',
                        p.birthPlace!.trim(),
                        textTheme,
                      ),
                    if (p.gender != null && p.gender!.trim().isNotEmpty)
                      _kvRow('Genere', p.gender!.trim(), textTheme),
                    _kvRow('Codice fiscale', p.taxCode ?? '—', textTheme),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Indirizzo',
                child: Text(
                  addr == null || addr.formattedSingleLine.isEmpty
                      ? '—'
                      : addr.formattedSingleLine,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Iscrizione',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kvRow(
                      'Percorso iscrizione',
                      BackofficeFormatters.enrollmentCoursePath(
                        p.enrolledCoursePath,
                      ),
                      textTheme,
                    ),
                    _kvRow(
                      'Moduli contenuto app',
                      BackofficeFormatters.contentModulesForEnrollmentPath(
                        p.enrolledCoursePath,
                      ),
                      textTheme,
                    ),
                    _kvRow(
                      'Categoria catalogo (principale)',
                      BackofficeFormatters.categoryName(
                        p.enrolledLicenseCategory,
                      ),
                      textTheme,
                    ),
                    _kvRow(
                      'Stato iscrizione',
                      BackofficeFormatters.registrationStatus(
                        p.registrationStatus,
                      ),
                      textTheme,
                    ),
                    _kvRow(
                      'Collegamento account app',
                      p.linkedAuthUserId ?? 'Non collegato',
                      textTheme,
                    ),
                    if (p.internalNotes != null &&
                        p.internalNotes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Note interne',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        p.internalNotes!,
                        style: textTheme.bodySmall,
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

class _SectionStudio extends StatelessWidget {
  const _SectionStudio({
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
  });

  static const Color _muted = AppVisual.ink;

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  @override
  Widget build(BuildContext context) {
    final sp = view.studyProgress;
    final textTheme = Theme.of(context).textTheme;

    return _SectionScroll(
      child: _SectionContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: BackofficeUiTokens.primary,
                      ),
                      onPressed: () => showManageLessonSheetsDialog(
                        context,
                        initialView: view,
                        repository: repository,
                        onRefreshDetail: onRefreshDetail,
                      ),
                      icon: const Icon(Icons.grid_view_rounded),
                      label: const Text('Gestisci schede'),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: BackofficeUiTokens.primary,
                      ),
                      onPressed: () => showExamAccessManageDialog(
                        context,
                        initialView: view,
                        repository: repository,
                        onRefreshDetail: onRefreshDetail,
                      ),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Abilita quiz esame'),
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: BackofficeUiTokens.primary,
                      ),
                      onPressed: () => showErrorReviewAssignDialog(
                        context,
                        initialView: view,
                        repository: repository,
                        onRefreshDetail: onRefreshDetail,
                      ),
                      icon: const Icon(Icons.error_outline_rounded),
                      label: const Text('Assegna ripasso'),
                    ),
                  ],
                ),
              ),
              if (view.profile.id ==
                  SchoolBackofficeDemoData.demoStudentLucia) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Allineamento app: per questa scheda demo, le modifiche a schede / esame / ripasso '
                    'aggiornano anche il repository accessi studio condiviso con l’app allievo.',
                    style: textTheme.bodySmall?.copyWith(
                      color: _SectionStudio._muted.withValues(alpha: 0.68),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              if (sp.globalProgressNotes != null &&
                  sp.globalProgressNotes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _InfoCard(
                    title: 'Note percorso',
                    child: SelectableText(
                      sp.globalProgressNotes!,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
              _InfoCard(
                title: 'Lezioni assegnate',
                child: sp.assignedLessons.isEmpty
                    ? Text(
                        'Nessuna lezione assegnata',
                        style: textTheme.bodySmall,
                      )
                    : Column(
                        children: sp.assignedLessons.map((l) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              'Lezione ${l.lessonNumber} · '
                              '${BackofficeFormatters.categoryName(l.categoryId)}',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              BackofficeFormatters.lessonAssignmentStatus(
                                l.status,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Schede quiz sbloccate',
                child: sp.sheetUnlocks.isEmpty
                    ? Text(
                        'Nessuna scheda in elenco',
                        style: textTheme.bodySmall,
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sp.sheetUnlocks.map((s) {
                          final label =
                              'L${s.lessonNumber} · Scheda ${s.sheetNumber}';
                          final on = s.unlocked;
                          return Chip(
                            label: Text(
                              on ? '$label · sì' : '$label · no',
                              style: textTheme.labelSmall,
                            ),
                            backgroundColor: on
                                ? const Color(0xFF2E9E5B).withValues(alpha: 0.15)
                                : AppVisual.chipFill,
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Accesso quiz esame',
                child: Column(
                  children: sp.examAccessByCategory.map((e) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        BackofficeFormatters.categoryName(e.categoryId),
                      ),
                      trailing: Icon(
                        e.examUnlocked
                            ? Icons.check_circle
                            : Icons.lock_outline,
                        color: e.examUnlocked
                            ? const Color(0xFF2E9E5B)
                            : AppVisual.ink.withValues(alpha: 0.45),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Ripasso errori (argomenti)',
                child: sp.errorReviewAssignments.isEmpty
                    ? Text('Nessun argomento', style: textTheme.bodySmall)
                    : Column(
                        children: sp.errorReviewAssignments.map((r) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              'Lezione ${r.lessonNumber}',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              r.topicUnlocked
                                  ? 'Sbloccato'
                                  : 'Non ancora abilitato',
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
        ),
      ),
    );
  }
}

class _SectionGuide extends StatelessWidget {
  const _SectionGuide({
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  List<GuidanceAppointment> _sortedAppointments() {
    final list = List<GuidanceAppointment>.from(view.appointments);
    list.sort((a, b) {
      final da = a.startTime ?? a.lessonDate;
      final db = b.startTime ?? b.lessonDate;
      return db.compareTo(da);
    });
    return list;
  }

  Future<void> _setOutcome(
    BuildContext context,
    GuidanceAppointment a,
    AppointmentCompletionOutcome outcome,
  ) async {
    try {
      await repository.updateGuidanceAppointmentOutcome(
        appointmentId: a.id,
        outcome: outcome,
      );
      final fresh = await repository.getStudentAdmin360(view.profile.id);
      if (fresh != null) await onRefreshDetail(fresh);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome == AppointmentCompletionOutcome.attended
                  ? 'Guida segnata come svolta.'
                  : 'Guida segnata come assente.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore aggiornamento esito: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final list = _sortedAppointments();
    final hasAppointments = list.isNotEmpty;

    return _SectionScroll(
      child: _SectionContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hasAppointments)
              Text(
                'Nessun appuntamento registrato.',
                style: textTheme.bodyLarge,
              )
            else
              Column(
                children: list.map((a) {
                  final canSetOutcome =
                      a.completionOutcome ==
                      AppointmentCompletionOutcome.pending;
                  final timeLine = a.startTime != null && a.endTime != null
                      ? '${BackofficeFormatters.dateTimeUi(a.startTime)} – '
                            '${BackofficeFormatters.dateTimeUi(a.endTime)}'
                      : a.startTime != null
                      ? BackofficeFormatters.dateTimeUi(a.startTime)
                      : '—';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InfoCard(
                      title:
                          '${BackofficeFormatters.dateUi(a.lessonDate)} · '
                          '${BackofficeFormatters.lessonType(a.lessonType)}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kvRow('Orario', timeLine, textTheme),
                          _kvRow(
                            'Istruttore',
                            a.instructorName ?? '—',
                            textTheme,
                          ),
                          _kvRow(
                            'Esito',
                            BackofficeFormatters.appointmentOutcome(
                              a.completionOutcome,
                            ),
                            textTheme,
                          ),
                          if (a.notes != null && a.notes!.isNotEmpty)
                            SelectableText(
                              a.notes!,
                              style: textTheme.bodySmall,
                            ),
                          if (canSetOutcome) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonal(
                                  onPressed: () => _setOutcome(
                                    context,
                                    a,
                                    AppointmentCompletionOutcome.attended,
                                  ),
                                  child: const Text('Svolta'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _setOutcome(
                                    context,
                                    a,
                                    AppointmentCompletionOutcome.absent,
                                  ),
                                  child: const Text('Assente'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionEsami extends StatelessWidget {
  const _SectionEsami({
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  static List<ExamAttempt> _sortedAttempts(List<ExamAttempt> raw) {
    final list = List<ExamAttempt>.from(raw);
    list.sort((a, b) {
      final da =
          a.examDate ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db =
          b.examDate ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final theory = _sortedAttempts(view.examSummary.theoryAttempts);
    final practical = _sortedAttempts(view.examSummary.practicalAttempts);

    return _SectionScroll(
      child: _SectionContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    foregroundColor: BackofficeUiTokens.primary,
                  ),
                  onPressed: () => showRegisterExamOutcomeDialog(
                    context,
                    view: view,
                    repository: repository,
                    onRefreshDetail: onRefreshDetail,
                    examType: ExamAttemptType.theory,
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Registra esito teoria'),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    foregroundColor: BackofficeUiTokens.primary,
                  ),
                  onPressed: () => showRegisterExamOutcomeDialog(
                    context,
                    view: view,
                    repository: repository,
                    onRefreshDetail: onRefreshDetail,
                    examType: ExamAttemptType.practical,
                  ),
                  icon: const Icon(Icons.sailing_outlined),
                  label: const Text('Registra esito pratica'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Teoria',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExamTrackRow(
                    label: 'Carteggio',
                    attempt: theory.isNotEmpty ? theory.first : null,
                  ),
                  const SizedBox(height: 10),
                  _ExamTrackRow(
                    label: 'Quiz',
                    attempt: theory.length > 1 ? theory[1] : null,
                  ),
                  if (theory.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Nessun esito teoria collegato. '
                      'Carteggio/Quiz richiederanno campi DB dedicati in patch successiva.',
                      style: textTheme.bodySmall?.copyWith(
                        color: BackofficeUiTokens.text.withValues(alpha: 0.68),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Guida',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ExamTrackRow(
                    label: 'Esame pratico',
                    attempt: practical.isNotEmpty ? practical.first : null,
                  ),
                  if (practical.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Nessun esito guida registrato.',
                      style: textTheme.bodySmall?.copyWith(
                        color: BackofficeUiTokens.text.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (theory.length > 2 || practical.length > 1) ...[
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Storico tentativi (modello attuale)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (theory.isNotEmpty) ...[
                      Text(
                        'Teoria',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...theory.map(
                        (e) => _ExamAttemptHistoryLine(
                          attempt: e,
                          textTheme: textTheme,
                        ),
                      ),
                    ],
                    if (practical.isNotEmpty) ...[
                      if (theory.isNotEmpty) const SizedBox(height: 8),
                      Text(
                        'Pratica',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...practical.map(
                        (e) => _ExamAttemptHistoryLine(
                          attempt: e,
                          textTheme: textTheme,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExamTrackRow extends StatelessWidget {
  const _ExamTrackRow({required this.label, this.attempt});

  final String label;
  final ExamAttempt? attempt;

  static const _outcomes = ['Promosso', 'Bocciato', 'Assente'];

  static String? _activeOutcome(ExamAttempt? attempt) {
    if (attempt == null) return null;
    switch (attempt.result) {
      case ExamAttemptResult.passed:
        return 'Promosso';
      case ExamAttemptResult.failed:
        return 'Bocciato';
      case ExamAttemptResult.noShow:
        return 'Assente';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = _activeOutcome(attempt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _outcomes.map((outcome) {
            final selected = active == outcome;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? BackofficeUiTokens.primary.withValues(alpha: 0.14)
                    : AppVisual.chipFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? BackofficeUiTokens.primary.withValues(alpha: 0.55)
                      : AppVisual.border.withValues(alpha: 0.55),
                ),
              ),
              child: Text(
                outcome,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? BackofficeUiTokens.primary
                      : BackofficeUiTokens.text.withValues(alpha: 0.55),
                ),
              ),
            );
          }).toList(),
        ),
        if (attempt != null && active != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Registrato: ${BackofficeFormatters.dateUi(attempt!.examDate)} · '
              'tentativo ${attempt!.attemptNumber}',
              style: textTheme.bodySmall?.copyWith(
                color: BackofficeUiTokens.text.withValues(alpha: 0.68),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExamAttemptHistoryLine extends StatelessWidget {
  const _ExamAttemptHistoryLine({
    required this.attempt,
    required this.textTheme,
  });

  final ExamAttempt attempt;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '#${attempt.attemptNumber} · '
        '${BackofficeFormatters.examResult(attempt.result)} · '
        '${BackofficeFormatters.dateUi(attempt.examDate)}',
        style: textTheme.bodySmall,
      ),
    );
  }
}

class _SectionContabilita extends StatelessWidget {
  const _SectionContabilita({
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final f = view.financialSummary;

    return _SectionScroll(
      child: _SectionContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BackofficeUiTokens.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => showAddPaymentDialog(
                  context,
                  view: view,
                  repository: repository,
                  onRefreshDetail: onRefreshDetail,
                ),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Aggiungi pagamento'),
              ),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Riepilogo',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kvRow(
                      'Quota iscrizione',
                      BackofficeFormatters.moneyEur(f.registrationFeeCents),
                      textTheme,
                    ),
                    _kvRow(
                      'Incassato',
                      BackofficeFormatters.moneyEur(f.totalPaidCents),
                      textTheme,
                    ),
                    _kvRow(
                      'Residuo',
                      BackofficeFormatters.moneyEur(f.remainingBalanceCents),
                      textTheme,
                    ),
                    _kvRow(
                      'Stato pagamenti',
                      f.remainingBalanceCents <= 0
                          ? 'Saldo azzerato'
                          : 'Saldo aperto',
                      textTheme,
                    ),
                    if (f.accountingNotes != null &&
                        f.accountingNotes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Note contabili', style: textTheme.labelLarge),
                      SelectableText(
                        f.accountingNotes!,
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _InfoCard(
                title: 'Movimenti (incassi)',
                child: view.payments.isEmpty
                    ? Text(
                        'Nessun pagamento registrato',
                        style: textTheme.bodySmall,
                      )
                    : Column(
                        children: view.payments.map((pay) {
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              BackofficeFormatters.moneyEur(pay.amountCents),
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${BackofficeFormatters.dateUi(pay.receivedAt)} · '
                              '${BackofficeFormatters.paymentMethod(pay.method)}\n'
                              '${pay.receiptReference ?? ''}',
                              style: textTheme.bodySmall,
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
        ),
      ),
    );
  }
}

class _SectionPratica extends StatelessWidget {
  const _SectionPratica({
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  static String _readableToken(String raw) {
    final cleaned = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (cleaned.isEmpty) return '—';
    return cleaned
        .split(RegExp(r'\s+'))
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join(' ');
  }

  static Widget _fileAssociatedLabel(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppVisual.brandAzure.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppVisual.brandAzure.withValues(alpha: 0.24)),
      ),
      child: Text(
        'File associato',
        style: textTheme.labelSmall?.copyWith(
          color: BackofficeUiTokens.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static void _showOpenError(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossibile aprire il file. Riprova più tardi.'),
      ),
    );
  }

  Future<void> _openSignedUrl(
    BuildContext context,
    Future<String> Function() createSignedUrl,
  ) async {
    try {
      final signedUrl = await createSignedUrl();
      if (!context.mounted) return;
      final uri = Uri.tryParse(signedUrl);
      if (uri == null || !uri.hasScheme) {
        _showOpenError(context);
        return;
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showOpenError(context);
      }
    } catch (_) {
      if (!context.mounted) return;
      _showOpenError(context);
    }
  }

  static String _registryPracticeTypeLabelIt(String? t) {
    switch (t) {
      case 'new_license':
        return 'Conseguimento patente';
      case 'renewal':
        return 'Rinnovo patente';
      case 'duplicate':
        return 'Duplicato patente';
      default:
        if (t == null || t.isEmpty) return '—';
        return t;
    }
  }

  Future<void> _openDocument(BuildContext context, String storagePath) {
    return _openSignedUrl(
      context,
      () => repository.createStudentDocumentSignedUrl(storagePath),
    );
  }

  Future<void> _openPhoto(BuildContext context, String storagePath) {
    return _openSignedUrl(
      context,
      () => repository.createStudentPhotoSignedUrl(storagePath),
    );
  }

  static void _showUploadMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_PickedUploadFile?> _pickUploadFile(
    BuildContext context, {
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        withData: true,
      );
      if (!context.mounted) return null;
      if (result == null || result.files.isEmpty) {
        _showUploadMessage(context, 'Nessun file selezionato.');
        return null;
      }
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showUploadMessage(
          context,
          'Il file selezionato non contiene dati leggibili.',
        );
        return null;
      }
      return _PickedUploadFile(
        name: file.name,
        bytes: bytes,
        mimeType: _mimeTypeFromExtension(file.extension),
      );
    } catch (_) {
      if (!context.mounted) return null;
      _showUploadMessage(context, 'Impossibile selezionare il file.');
      return null;
    }
  }

  static String? _mimeTypeFromExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return null;
    }
  }

  Future<void> _refreshAfterUpload(BuildContext context) async {
    final updated = await repository.getStudentAdmin360(view.profile.id);
    if (!context.mounted) return;
    await onRefreshDetail(updated);
  }

  Future<void> _showUploadDocumentDialog(BuildContext context) async {
    const documentTypes = <String, String>{
      'identity_card': 'Carta identità',
      'fiscal_code': 'Codice fiscale',
      'medical_certificate': 'Certificato medico',
      'other': 'Altro documento',
    };

    final titleController = TextEditingController();
    final notesController = TextEditingController();
    var documentType = 'identity_card';
    DateTime? expiresAt;
    _PickedUploadFile? pickedFile;
    var uploading = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> pickFile() async {
                final picked = await _pickUploadFile(dialogContext);
                if (picked == null || !dialogContext.mounted) return;
                setDialogState(() {
                  pickedFile = picked;
                  if (titleController.text.trim().isEmpty) {
                    titleController.text = picked.name;
                  }
                });
              }

              Future<void> pickExpiration() async {
                final now = DateTime.now();
                final selected = await showDatePicker(
                  context: dialogContext,
                  initialDate: expiresAt ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 20),
                );
                if (selected == null || !dialogContext.mounted) return;
                setDialogState(() => expiresAt = selected);
              }

              Future<void> submit() async {
                final file = pickedFile;
                if (file == null) {
                  _showUploadMessage(
                    dialogContext,
                    'Seleziona un file da caricare.',
                  );
                  return;
                }
                setDialogState(() => uploading = true);
                try {
                  await repository.uploadStudentDocument(
                    studentId: view.profile.id,
                    practiceDossierId: view.practiceDossier?.id,
                    documentType: documentType,
                    title: titleController.text.trim().isEmpty
                        ? file.name
                        : titleController.text.trim(),
                    fileName: file.name,
                    bytes: file.bytes,
                    mimeType: file.mimeType,
                    expiresAt: expiresAt,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  _showUploadMessage(
                    context,
                    'Documento caricato correttamente.',
                  );
                  await _refreshAfterUpload(context);
                } catch (error) {
                  debugPrint('Upload documento allievo non riuscito: $error');
                  if (!dialogContext.mounted) return;
                  setDialogState(() => uploading = false);
                  _showUploadMessage(
                    dialogContext,
                    'Upload documento non riuscito. Riprova più tardi.',
                  );
                }
              }

              return AlertDialog(
                title: const Text('Carica documento'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: documentType,
                        decoration: const InputDecoration(
                          labelText: 'Tipo documento',
                        ),
                        items: documentTypes.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: uploading
                            ? null
                            : (value) => setDialogState(
                                () => documentType = value ?? documentType,
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        enabled: !uploading,
                        decoration: const InputDecoration(
                          labelText: 'Titolo documento',
                          hintText: 'Se vuoto usa il nome file',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        enabled: !uploading,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Note opzionali',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: uploading ? null : pickExpiration,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              expiresAt == null
                                  ? 'Scadenza opzionale'
                                  : BackofficeFormatters.dateUi(expiresAt),
                            ),
                          ),
                          if (expiresAt != null)
                            TextButton(
                              onPressed: uploading
                                  ? null
                                  : () =>
                                        setDialogState(() => expiresAt = null),
                              child: const Text('Rimuovi scadenza'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: uploading ? null : pickFile,
                        icon: const Icon(Icons.attach_file_outlined),
                        label: Text(pickedFile?.name ?? 'Seleziona file'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: uploading
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Annulla'),
                  ),
                  FilledButton(
                    onPressed: uploading ? null : submit,
                    child: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Carica'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _showUploadPhotoDialog(BuildContext context) async {
    const photoKinds = <String, String>{
      'profile': 'Profilo',
      'license_photo': 'Foto patente',
      'other': 'Altra foto',
    };

    final notesController = TextEditingController();
    var photoKind = 'profile';
    _PickedUploadFile? pickedFile;
    var uploading = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              Future<void> pickFile() async {
                final picked = await _pickUploadFile(
                  dialogContext,
                  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                );
                if (picked == null || !dialogContext.mounted) return;
                setDialogState(() => pickedFile = picked);
              }

              Future<void> submit() async {
                final file = pickedFile;
                if (file == null) {
                  _showUploadMessage(
                    dialogContext,
                    'Seleziona una foto da caricare.',
                  );
                  return;
                }
                setDialogState(() => uploading = true);
                try {
                  await repository.uploadStudentPhoto(
                    studentId: view.profile.id,
                    photoKind: photoKind,
                    fileName: file.name,
                    bytes: file.bytes,
                    mimeType: file.mimeType,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop();
                  _showUploadMessage(context, 'Foto caricata correttamente.');
                  await _refreshAfterUpload(context);
                } catch (error) {
                  debugPrint('Upload foto allievo non riuscito: $error');
                  if (!dialogContext.mounted) return;
                  setDialogState(() => uploading = false);
                  _showUploadMessage(
                    dialogContext,
                    'Upload foto non riuscito. Riprova più tardi.',
                  );
                }
              }

              return AlertDialog(
                title: const Text('Carica foto'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: photoKind,
                        decoration: const InputDecoration(
                          labelText: 'Tipo foto',
                        ),
                        items: photoKinds.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: uploading
                            ? null
                            : (value) => setDialogState(
                                () => photoKind = value ?? photoKind,
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        enabled: !uploading,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Note opzionali',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: uploading ? null : pickFile,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(pickedFile?.name ?? 'Seleziona foto'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: uploading
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Annulla'),
                  ),
                  FilledButton(
                    onPressed: uploading ? null : submit,
                    child: uploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Carica'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      notesController.dispose();
    }
  }

  Widget _documentTile(BuildContext context, StudentDocument doc) {
    final textTheme = Theme.of(context).textTheme;
    return _InfoCard(
      title: doc.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kvRow('Tipo', _readableToken(doc.documentType), textTheme),
          _kvRow('Stato', _readableToken(doc.status), textTheme),
          if (doc.fileName != null && doc.fileName!.isNotEmpty)
            _kvRow('File', doc.fileName!, textTheme),
          if (doc.expiresAt != null)
            _kvRow(
              'Scadenza',
              BackofficeFormatters.dateUi(doc.expiresAt),
              textTheme,
            ),
          if (doc.notes != null && doc.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Note', style: textTheme.labelLarge),
            SelectableText(doc.notes!, style: textTheme.bodySmall),
          ],
          if (doc.storagePath != null && doc.storagePath!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _fileAssociatedLabel(context),
                OutlinedButton.icon(
                  onPressed: () => _openDocument(context, doc.storagePath!),
                  icon: const Icon(Icons.open_in_new_outlined, size: 18),
                  label: const Text('Apri'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoTile(BuildContext context, StudentPhoto photo) {
    final textTheme = Theme.of(context).textTheme;
    return _InfoCard(
      title: _readableToken(photo.photoKind),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photo.fileName != null && photo.fileName!.isNotEmpty)
            _kvRow('File', photo.fileName!, textTheme),
          if (photo.createdAt != null)
            _kvRow(
              'Caricata il',
              BackofficeFormatters.dateTimeUi(photo.createdAt),
              textTheme,
            ),
          if (photo.notes != null && photo.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Note', style: textTheme.labelLarge),
            SelectableText(photo.notes!, style: textTheme.bodySmall),
          ],
          if (photo.storagePath != null && photo.storagePath!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _fileAssociatedLabel(context),
                OutlinedButton.icon(
                  onPressed: () => _openPhoto(context, photo.storagePath!),
                  icon: const Icon(Icons.open_in_new_outlined, size: 18),
                  label: const Text('Apri'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = view.practiceDossier;
    final documents = view.documents;
    final photos = view.photos;

    return _SectionScroll(
      child: _SectionContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BackofficeUiTokens.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => showUpdatePracticeDossierDialog(
                  context,
                  view: view,
                  repository: repository,
                  onRefreshDetail: onRefreshDetail,
                ),
                icon: const Icon(Icons.folder_shared_outlined),
                label: const Text('Aggiorna pratica e documenti'),
              ),
            ),
            const SizedBox(height: 12),
            d == null
                  ? Text(
                      'Nessun fascicolo ancora registrato — usa “Aggiorna” per '
                      'creare o compilare i dati.',
                      style: textTheme.bodyLarge,
                    )
                  : _InfoCard(
                      title: 'Fascicolo pratica e documenti',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kvRow(
                            'Tipo pratica',
                            _SectionPratica._registryPracticeTypeLabelIt(
                              d.practiceType,
                            ),
                            textTheme,
                          ),
                          _kvRow(
                            'Data iscrizione',
                            BackofficeFormatters.dateUi(d.registrationDate),
                            textTheme,
                          ),
                          if (d.registryYear != null)
                            _kvRow(
                              'Anno registro',
                              '${d.registryYear}',
                              textTheme,
                            ),
                          _kvRow(
                            'Numero registro',
                            (d.registryNumber != null &&
                                    d.registryCode != null &&
                                    d.registryCode!.isNotEmpty)
                                ? '${d.registryNumber}'
                                : 'Numero registro non ancora assegnato',
                            textTheme,
                          ),
                          _kvRow(
                            'Codice registro',
                            (d.registryNumber != null &&
                                    d.registryCode != null &&
                                    d.registryCode!.isNotEmpty)
                                ? d.registryCode!
                                : 'Numero registro non ancora assegnato',
                            textTheme,
                          ),
                          _kvRow(
                            'Numero pratica',
                            d.practiceNumber ?? '—',
                            textTheme,
                          ),
                          _kvRow(
                            'Numero patente / titolo',
                            d.licenseNumber ?? '—',
                            textTheme,
                          ),
                          _kvRow(
                            'Data rilascio',
                            BackofficeFormatters.dateUi(d.issueDate),
                            textTheme,
                          ),
                          _kvRow(
                            'Scadenza',
                            BackofficeFormatters.dateUi(d.expirationDate),
                            textTheme,
                          ),
                          _kvRow(
                            'Stato documenti',
                            BackofficeFormatters.documentStatus(
                              d.documentStatus,
                            ),
                            textTheme,
                          ),
                          _kvRow(
                            'Stato pratica',
                            BackofficeFormatters.practiceStatus(
                              d.practiceStatus,
                            ),
                            textTheme,
                          ),
                          if (d.authorityNotes != null &&
                              d.authorityNotes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Note', style: textTheme.labelLarge),
                            SelectableText(
                              d.authorityNotes!,
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Documenti allievo',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BackofficeUiTokens.text,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      foregroundColor: BackofficeUiTokens.primary,
                    ),
                    onPressed: () => _showUploadDocumentDialog(context),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Carica documento'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (documents.isEmpty)
                Text('Nessun documento caricato.', style: textTheme.bodyMedium)
              else
                ...documents.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _documentTile(context, doc),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Foto allievo',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BackofficeUiTokens.text,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      foregroundColor: BackofficeUiTokens.primary,
                    ),
                    onPressed: () => _showUploadPhotoDialog(context),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Carica foto'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (photos.isEmpty)
                Text('Nessuna foto caricata.', style: textTheme.bodyMedium)
              else
                ...photos.map(
                  (photo) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _photoTile(context, photo),
                  ),
                ),
            ],
        ),
      ),
    );
  }
}

class _PickedUploadFile {
  const _PickedUploadFile({
    required this.name,
    required this.bytes,
    this.mimeType,
  });

  final String name;
  final List<int> bytes;
  final String? mimeType;
}

class _SectionRegistroInterno extends StatelessWidget {
  const _SectionRegistroInterno({
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final notes = view.staffNotes;
    final acts = view.activityLog;

    return _SectionScroll(
      child: _SectionContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Note interne staff',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: BackofficeUiTokens.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Visibili solo in backoffice; non sincronizzate con l’app allievo.',
                style: textTheme.bodySmall?.copyWith(
                  color: BackofficeUiTokens.text.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: BackofficeUiTokens.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => showAddStaffNoteDialog(
                      context,
                      view: view,
                      repository: repository,
                      onRefreshDetail: onRefreshDetail,
                    ),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Aggiungi nota'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showEditProfileInternalNotesDialog(
                      context,
                      view: view,
                      repository: repository,
                      onRefreshDetail: onRefreshDetail,
                    ),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Modifica note anagrafiche'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (notes.isEmpty)
                Text(
                  'Nessuna nota strutturata — aggiungi la prima con “Aggiungi nota”.',
                  style: textTheme.bodyMedium,
                )
              else
                ...notes.map((n) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InfoCard(
                      title:
                          '${BackofficeFormatters.dateTimeUi(n.createdAt)} · '
                          '${BackofficeFormatters.staffNoteCategory(n.category)}',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (n.authorStaffName != null &&
                              n.authorStaffName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Da: ${n.authorStaffName}',
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: BackofficeUiTokens.primary,
                                ),
                              ),
                            ),
                          SelectableText(n.body, style: textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
              Divider(color: BackofficeUiTokens.neutral.withValues(alpha: 0.9)),
              const SizedBox(height: 12),
              Text(
                'Storico attività',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: BackofficeUiTokens.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Registro delle attività operative eseguite sul profilo allievo.',
                style: textTheme.bodySmall?.copyWith(
                  color: BackofficeUiTokens.text.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 12),
              if (acts.isEmpty)
                Text('Nessun evento ancora.', style: textTheme.bodyMedium)
              else
                ...acts.take(80).map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: BackofficeUiTokens.neutral),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 108,
                            child: Text(
                              BackofficeFormatters.dateTimeUi(e.occurredAt),
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: BackofficeUiTokens.text.withValues(
                                  alpha: 0.75,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  BackofficeFormatters.activityType(e.type),
                                  style: textTheme.labelSmall?.copyWith(
                                    color: BackofficeUiTokens.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (e.description != null &&
                                    e.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    e.description!,
                                    style: textTheme.bodySmall?.copyWith(
                                      height: 1.3,
                                      color: BackofficeUiTokens.text
                                          .withValues(alpha: 0.85),
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
                }),
            ],
        ),
      ),
    );
  }
}
