import 'package:flutter/material.dart';

import '../../domain/backoffice/backoffice.dart';
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
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

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
    final cat = p.hasEnrollmentCoursePath ? p.enrolledLicenseCategory : null;

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  if (_busy)
                    const LinearProgressIndicator(minHeight: 3),
                  if (_busy) const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.updateStudentOnboardingStatus(
                                    studentId: p.id,
                                    status: StudentOnboardingStatus.approved,
                                  ),
                                  'Iscrizione approvata (onboarding).',
                                ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Approva iscritto'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.updateStudentOnboardingStatus(
                                    studentId: p.id,
                                    status: StudentOnboardingStatus.awaitingContact,
                                  ),
                                  'Segnato: da contattare.',
                                ),
                        icon: const Icon(Icons.phone_callback_outlined),
                        label: const Text('Segna da contattare'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.updateStudentOnboardingStatus(
                                    studentId: p.id,
                                    status:
                                        StudentOnboardingStatus.awaitingDocuments,
                                  ),
                                  'Segnato: documenti mancanti.',
                                ),
                        icon: const Icon(Icons.folder_off_outlined),
                        label: const Text('Segna documenti mancanti'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.markStudentFirstContacted(
                                    p.id,
                                  ),
                                  'Primo contatto registrato.',
                                ),
                        icon: const Icon(Icons.mark_chat_read_outlined),
                        label: const Text('Registra primo contatto'),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: BackofficeUiTokens.success,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _busy
                            ? null
                            : () => _run(
                                  () => widget.repository.activateStudentCourse(
                                    p.id,
                                  ),
                                  'Percorso attivato.',
                                ),
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Attiva percorso'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => showOnboardingRegistrationFeeDialog(
                                  context,
                                  view: widget.view,
                                  repository: widget.repository,
                                  onRefreshDetail: widget.onRefreshDetail,
                                ),
                        icon: const Icon(Icons.euro_symbol),
                        label: const Text('Imposta quota iscrizione'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => showAddStaffNoteDialog(
                                  context,
                                  view: widget.view,
                                  repository: widget.repository,
                                  onRefreshDetail: widget.onRefreshDetail,
                                ),
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('Aggiungi nota iniziale'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || cat == null
                            ? null
                            : () => _run(
                                  () => widget.repository.setLessonSheetUnlocked(
                                    studentId: p.id,
                                    categoryId: cat!,
                                    lessonNumber: 1,
                                    sheetNumber: 1,
                                    unlocked: true,
                                  ),
                                  'Prima scheda lezione 1 sbloccata.',
                                ),
                        icon: const Icon(Icons.lock_open_outlined),
                        label: const Text('Sblocca prima scheda (lez. 1)'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy || cat == null
                            ? null
                            : () => _run(
                                  () => widget.repository.setExamQuizAccessForCategory(
                                    studentId: p.id,
                                    categoryId: cat!,
                                    examUnlocked: false,
                                  ),
                                  'Quiz esame disabilitato per categoria.',
                                ),
                        icon: const Icon(Icons.quiz_outlined),
                        label: const Text('Quiz esame non abilitato'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoCard(
                    title: 'Stato e date',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(
                        'Stato onboarding',
                        BackofficeFormatters.onboardingStatus(p.onboardingStatus),
                      ),
                      _kv(
                        'Stato iscrizione',
                        BackofficeFormatters.registrationStatus(
                          p.registrationStatus,
                        ),
                      ),
                      _kv(
                        'Percorso iscritto',
                        p.hasEnrollmentCoursePath
                            ? BackofficeFormatters.enrollmentCoursePath(
                                p.enrolledCoursePath,
                              )
                            : 'Non applicabile',
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
                            ? BackofficeFormatters.dateTimeUi(p.firstContactedAt)
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
            ),
          ),
        );
        },
      ),
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
                color: BackofficeUiTokens.text.withOpacity(0.65),
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
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BackofficeUiTokens.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BackofficeUiTokens.neutral),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: BackofficeUiTokens.text,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
