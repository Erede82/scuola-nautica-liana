import 'package:flutter/material.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../models/license_models.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import 'backoffice_formatters.dart';
import 'backoffice_ui_tokens.dart';
import 'student_backoffice_dialogs.dart';
import 'student_record_dialogs.dart';

/// Pannello onboarding: stato operativo e azioni rapide segreteria.
class StudentOnboardingSection extends StatefulWidget {
  const StudentOnboardingSection({
    super.key,
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
    this.embeddedInScheda = false,
    this.compactActions = false,
    this.inlineInPraticaCard = false,
    this.hideRegistrationFee = false,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  /// Se true: senza titolo onboarding né «Stato e date» (tab Scheda).
  final bool embeddedInScheda;

  /// Pulsanti più compatti (tab Scheda).
  final bool compactActions;

  /// Se true con [embeddedInScheda]: solo pulsanti, senza card wrapper (dentro card Pratica).
  final bool inlineInPraticaCard;

  /// Nasconde «Imposta quota iscrizione» (es. tab Scheda).
  final bool hideRegistrationFee;

  @override
  State<StudentOnboardingSection> createState() =>
      _StudentOnboardingSectionState();
}

class _StudentOnboardingSectionState extends State<StudentOnboardingSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      final fresh =
          await widget.repository.getStudentAdmin360(widget.view.profile.id);
      if (fresh != null) await widget.onRefreshDetail(fresh);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(okMessage), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aggiornamento fallito: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _documentiLine(StudentAdmin360View view) {
    final d = view.practiceDossier;
    if (d == null) {
      return 'Pratica: non ancora aperta — verificare documenti in segreteria.';
    }
    return 'Pratica: ${BackofficeFormatters.documentStatus(d.documentStatus)}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = widget.view.profile;
    final cat = p.enrolledLicenseCategory;

    final body = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.embeddedInScheda) ...[
                    Text(
                      'Onboarding',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: BackofficeUiTokens.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Azioni rapide',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: BackofficeUiTokens.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (widget.embeddedInScheda && !widget.inlineInPraticaCard)
                    _InfoCard(
                      title: 'Azioni',
                      compact: widget.compactActions,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_busy)
                            const LinearProgressIndicator(minHeight: 2),
                          if (_busy) const SizedBox(height: 6),
                          _buildActionButtons(p, cat),
                        ],
                      ),
                    )
                  else if (widget.embeddedInScheda && widget.inlineInPraticaCard)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_busy)
                          const LinearProgressIndicator(minHeight: 2),
                        if (_busy) const SizedBox(height: 6),
                        _buildActionButtons(p, cat),
                      ],
                    )
                  else ...[
                    if (_busy)
                      const LinearProgressIndicator(minHeight: 3),
                    if (_busy) const SizedBox(height: 8),
                    _buildActionButtons(p, cat),
                  ],
                  if (!widget.embeddedInScheda) ...[
                    const SizedBox(height: 14),
                    _InfoCard(
                      title: 'Stato e date',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kv(
                            'Stato onboarding',
                            BackofficeFormatters.onboardingStatus(
                              p.onboardingStatus,
                            ),
                          ),
                          _kv(
                            'Stato iscrizione',
                            BackofficeFormatters.registrationStatus(
                              p.registrationStatus,
                            ),
                          ),
                          _kv(
                            'Percorso iscritto',
                            BackofficeFormatters.enrollmentCoursePath(
                              p.enrolledCoursePath,
                            ),
                          ),
                          _kv(
                            'Data registrazione',
                            p.createdAt != null
                                ? BackofficeFormatters.dateUi(p.createdAt)
                                : '—',
                          ),
                          _kv(
                            'Primo contatto',
                            p.firstContactedAt != null
                                ? BackofficeFormatters.dateTimeUi(
                                    p.firstContactedAt,
                                  )
                                : 'Non ancora registrato',
                          ),
                          _kv('Documenti', _documentiLine(widget.view)),
                          if (p.onboardingNotes != null &&
                              p.onboardingNotes!.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Note onboarding',
                              style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: BackofficeUiTokens.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              p.onboardingNotes!,
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              );

    if (widget.embeddedInScheda || widget.inlineInPraticaCard) {
      return body;
    }

    return ColoredBox(
      color: BackofficeUiTokens.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final pad = compact ? 12.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: SizedBox(
              width: constraints.maxWidth,
              child: body,
            ),
          );
        },
      ),
    );
  }

  void _showInfoSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _setOnboardingStatus(
    StudentProfile p,
    StudentOnboardingStatus status, {
    required String okMessage,
    required String alreadyMessage,
  }) async {
    if (p.onboardingStatus == status) {
      _showInfoSnack(alreadyMessage);
      return;
    }
    await _run(
      () => widget.repository.updateStudentOnboardingStatus(
        studentId: p.id,
        status: status,
      ),
      okMessage,
    );
  }

  Widget _buildActionButtons(
    StudentProfile p,
    LicenseCategoryId cat,
  ) {
    final awaitingContact =
        p.onboardingStatus == StudentOnboardingStatus.awaitingContact;
    final awaitingDocuments =
        p.onboardingStatus == StudentOnboardingStatus.awaitingDocuments;
    final dense = widget.compactActions;
    final iconSize = dense ? 16.0 : 18.0;
    final btnStyle = dense
        ? const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : null;

    return Wrap(
      spacing: dense ? 6 : 8,
      runSpacing: dense ? 6 : 8,
      children: [
                      FilledButton.icon(
                        style: btnStyle,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.updateStudentOnboardingStatus(
                                    studentId: p.id,
                                    status: StudentOnboardingStatus.approved,
                                  ),
                                  'Iscrizione approvata (onboarding).',
                                ),
                        icon: Icon(Icons.check_circle_outline, size: iconSize),
                        label: const Text('Approva iscritto'),
                      ),
                      OutlinedButton.icon(
                        style: btnStyle?.merge(
                          awaitingContact
                              ? ButtonStyle(
                                  side: WidgetStatePropertyAll(
                                    BorderSide(
                                      color: BackofficeUiTokens.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  foregroundColor: WidgetStatePropertyAll(
                                    BackofficeUiTokens.primary,
                                  ),
                                )
                              : null,
                        ),
                        onPressed: _busy
                            ? null
                            : () => _setOnboardingStatus(
                                  p,
                                  StudentOnboardingStatus.awaitingContact,
                                  okMessage: 'Segnato: da contattare.',
                                  alreadyMessage:
                                      'Allievo già segnato da contattare.',
                                ),
                        icon: Icon(
                          awaitingContact
                              ? Icons.check_circle
                              : Icons.phone_callback_outlined,
                          size: iconSize,
                        ),
                        label: Text(
                          awaitingContact
                              ? 'Da contattare ✓'
                              : 'Segna da contattare',
                        ),
                      ),
                      OutlinedButton.icon(
                        style: btnStyle?.merge(
                          awaitingDocuments
                              ? ButtonStyle(
                                  side: WidgetStatePropertyAll(
                                    BorderSide(
                                      color: BackofficeUiTokens.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  foregroundColor: WidgetStatePropertyAll(
                                    BackofficeUiTokens.primary,
                                  ),
                                )
                              : null,
                        ),
                        onPressed: _busy
                            ? null
                            : () => _setOnboardingStatus(
                                  p,
                                  StudentOnboardingStatus.awaitingDocuments,
                                  okMessage: 'Segnato: documenti mancanti.',
                                  alreadyMessage:
                                      'Allievo già segnato con documenti mancanti.',
                                ),
                        icon: Icon(
                          awaitingDocuments
                              ? Icons.check_circle
                              : Icons.folder_off_outlined,
                          size: iconSize,
                        ),
                        label: Text(
                          awaitingDocuments
                              ? 'Documenti mancanti ✓'
                              : 'Segna documenti mancanti',
                        ),
                      ),
                      OutlinedButton.icon(
                        style: btnStyle,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.markStudentFirstContacted(
                                    p.id,
                                  ),
                                  'Primo contatto registrato.',
                                ),
                        icon: Icon(Icons.mark_chat_read_outlined, size: iconSize),
                        label: const Text('Registra primo contatto'),
                      ),
                      FilledButton.icon(
                        style: btnStyle?.merge(
                          FilledButton.styleFrom(
                            backgroundColor: BackofficeUiTokens.success,
                            foregroundColor: Colors.white,
                          ),
                        ) ??
                            FilledButton.styleFrom(
                              backgroundColor: BackofficeUiTokens.success,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.activateStudentCourse(
                                    p.id,
                                  ),
                                  'Percorso attivato.',
                                ),
                        icon: Icon(Icons.play_circle_outline, size: iconSize),
                        label: const Text('Attiva percorso'),
                      ),
                      if (!widget.hideRegistrationFee)
                        OutlinedButton.icon(
                          style: btnStyle,
                          onPressed: _busy
                              ? null
                              : () => showOnboardingRegistrationFeeDialog(
                                    context,
                                    view: widget.view,
                                    repository: widget.repository,
                                    onRefreshDetail: widget.onRefreshDetail,
                                  ),
                          icon: Icon(Icons.euro_symbol, size: iconSize),
                          label: const Text('Imposta quota iscrizione'),
                        ),
                      OutlinedButton.icon(
                        style: btnStyle,
                        onPressed: _busy
                            ? null
                            : () => showAddStaffNoteDialog(
                                  context,
                                  view: widget.view,
                                  repository: widget.repository,
                                  onRefreshDetail: widget.onRefreshDetail,
                                ),
                        icon: Icon(Icons.note_add_outlined, size: iconSize),
                        label: const Text('Aggiungi nota iniziale'),
                      ),
                      OutlinedButton.icon(
                        style: btnStyle,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.setLessonSheetUnlocked(
                                    studentId: p.id,
                                    categoryId: cat,
                                    lessonNumber: 1,
                                    sheetNumber: 1,
                                    unlocked: true,
                                  ),
                                  'Prima scheda lezione 1 sbloccata.',
                                ),
                        icon: Icon(Icons.lock_open_outlined, size: iconSize),
                        label: const Text('Sblocca prima scheda (lez. 1)'),
                      ),
                      OutlinedButton.icon(
                        style: btnStyle,
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.setExamQuizAccessForCategory(
                                    studentId: p.id,
                                    categoryId: cat,
                                    examUnlocked: false,
                                  ),
                                  'Quiz esame disabilitato per categoria.',
                                ),
                        icon: Icon(Icons.quiz_outlined, size: iconSize),
                        label: const Text('Quiz esame non abilitato'),
                      ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 168,
            child: Text(
              k,
              style: textTheme.labelMedium?.copyWith(
                color: BackofficeUiTokens.text.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.child,
    this.compact = false,
  });

  final String title;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pad = compact ? 10.0 : 16.0;
    final gap = compact ? 8.0 : 12.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BackofficeUiTokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BackofficeUiTokens.neutral),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: BackofficeUiTokens.text,
                fontSize: compact ? 14 : null,
              ),
            ),
            SizedBox(height: gap),
            child,
          ],
        ),
      ),
    );
  }
}
