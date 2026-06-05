import 'package:flutter/material.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import 'backoffice_formatters.dart';
import 'backoffice_ui_tokens.dart';
import 'student_360_photo_signature_section.dart';
import 'student_360_section_layout.dart';
import 'student_onboarding_section.dart';
import 'student_record_dialogs.dart';

/// Tab Scheda: anagrafica, iscrizione, pratica/registro, foto/firma, azioni segreteria.
class Student360SchedaSection extends StatelessWidget {
  const Student360SchedaSection({
    super.key,
    required this.view,
    required this.repository,
    required this.onRefreshDetail,
  });

  final StudentAdmin360View view;
  final BackofficeRepository repository;
  final BackofficeDetailRefresh onRefreshDetail;

  static const double _photoColumnWidth = 200;

  static String registryPracticeTypeLabelIt(String? t) {
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

  static String _documentiLine(StudentAdmin360View view) {
    final d = view.practiceDossier;
    if (d == null) {
      return 'Fascicolo non ancora aperto';
    }
    return BackofficeFormatters.documentStatus(d.documentStatus);
  }

  Widget _anagraficaColonna(
    StudentProfile p,
    PostalAddress? addr,
    TextTheme textTheme,
  ) {
    const kvLabel = 132.0;
    const kvPad = 6.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        student360SubsectionTitle('Dati personali', textTheme),
        student360KvRow('Nome', p.firstName, textTheme,
            labelWidth: kvLabel, bottomPadding: kvPad),
        student360KvRow('Cognome', p.lastName, textTheme,
            labelWidth: kvLabel, bottomPadding: kvPad),
        student360KvRow('Codice fiscale', p.taxCode ?? '—', textTheme,
            labelWidth: kvLabel, bottomPadding: kvPad),
        student360KvRow(
          'Data di nascita',
          p.birthDate != null ? BackofficeFormatters.dateUi(p.birthDate) : '—',
          textTheme,
          labelWidth: kvLabel,
          bottomPadding: kvPad,
        ),
        if (p.birthPlace != null && p.birthPlace!.trim().isNotEmpty)
          student360KvRow(
            'Luogo di nascita',
            p.birthPlace!.trim(),
            textTheme,
            labelWidth: kvLabel,
            bottomPadding: kvPad,
          ),
        if (p.gender != null && p.gender!.trim().isNotEmpty)
          student360KvRow('Genere', p.gender!.trim(), textTheme,
              labelWidth: kvLabel, bottomPadding: kvPad),
        const SizedBox(height: 8),
        student360SubsectionTitle('Contatti', textTheme),
        student360KvRow('Telefono', p.phone ?? '—', textTheme,
            labelWidth: kvLabel, bottomPadding: kvPad),
        student360KvRow('Email', p.email ?? '—', textTheme,
            labelWidth: kvLabel, bottomPadding: kvPad),
        const SizedBox(height: 8),
        student360SubsectionTitle('Residenza', textTheme),
        student360KvRow(
          'Indirizzo',
          (addr?.streetLine1 != null && addr!.streetLine1!.trim().isNotEmpty)
              ? addr.streetLine1!.trim()
              : '—',
          textTheme,
          labelWidth: kvLabel,
          bottomPadding: kvPad,
        ),
        student360KvRow(
          'CAP',
          (addr?.postalCode != null && addr!.postalCode!.trim().isNotEmpty)
              ? addr.postalCode!.trim()
              : '—',
          textTheme,
          labelWidth: kvLabel,
          bottomPadding: kvPad,
        ),
        student360KvRow(
          'Comune',
          (addr?.city != null && addr!.city!.trim().isNotEmpty)
              ? addr.city!.trim()
              : '—',
          textTheme,
          labelWidth: kvLabel,
          bottomPadding: kvPad,
        ),
        student360KvRow(
          'Provincia',
          (addr?.provinceCode != null && addr!.provinceCode!.trim().isNotEmpty)
              ? addr.provinceCode!.trim()
              : '—',
          textTheme,
          labelWidth: kvLabel,
          bottomPadding: kvPad,
        ),
      ],
    );
  }

  static const double _siblingCardMinHeight = 320;

  Widget _iscrizioneCard(
    StudentProfile p,
    TextTheme textTheme, {
    bool stretch = false,
  }) {
    return Student360InfoCard(
      title: 'Iscrizione',
      stretch: stretch,
      minHeight: stretch ? _siblingCardMinHeight : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          student360KvRow(
            'Percorso',
            BackofficeFormatters.enrollmentCoursePath(p.enrolledCoursePath),
            textTheme,
            labelWidth: 140,
            bottomPadding: 8,
          ),
          student360KvRow(
            'Categoria',
            BackofficeFormatters.categoryName(p.enrolledLicenseCategory),
            textTheme,
            labelWidth: 140,
            bottomPadding: 8,
          ),
          student360KvRow(
            'Stato iscrizione',
            BackofficeFormatters.registrationStatus(p.registrationStatus),
            textTheme,
            labelWidth: 140,
            bottomPadding: 8,
          ),
          student360KvRow(
            'Stato onboarding',
            BackofficeFormatters.onboardingStatus(p.onboardingStatus),
            textTheme,
            labelWidth: 140,
            bottomPadding: 8,
          ),
          student360KvRow(
            'Account app',
            p.linkedAuthUserId ?? 'Non collegato',
            textTheme,
            labelWidth: 140,
            bottomPadding: 8,
          ),
          student360KvRow(
            'Data iscrizione',
            p.createdAt != null
                ? BackofficeFormatters.dateUi(p.createdAt)
                : '—',
            textTheme,
            labelWidth: 140,
            bottomPadding: 8,
          ),
          student360KvRow(
            'Stato documenti',
            _documentiLine(view),
            textTheme,
            labelWidth: 140,
            bottomPadding: 8,
          ),
          if (p.onboardingNotes != null && p.onboardingNotes!.trim().isNotEmpty)
            ...[
              const SizedBox(height: 4),
              Text(
                'Note onboarding',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(p.onboardingNotes!, style: textTheme.bodySmall),
            ],
        ],
      ),
    );
  }

  Widget _praticaCard(
    BuildContext context,
    PracticeLicenseDossier? d,
    TextTheme textTheme, {
    bool stretch = false,
  }) {
    return Student360InfoCard(
      title: 'Pratica',
      stretch: stretch,
      minHeight: stretch ? _siblingCardMinHeight : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (d == null)
            Text(
              'Nessun fascicolo aperto.',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            student360KvRow(
              'Tipo pratica',
              registryPracticeTypeLabelIt(d.practiceType),
              textTheme,
              labelWidth: 140,
              bottomPadding: 8,
            ),
            student360KvRow(
              'Stato pratica',
              BackofficeFormatters.practiceStatus(d.practiceStatus),
              textTheme,
              labelWidth: 140,
              bottomPadding: 8,
            ),
            student360KvRow(
              'Stato documenti',
              BackofficeFormatters.documentStatus(d.documentStatus),
              textTheme,
              labelWidth: 140,
              bottomPadding: 8,
            ),
            student360KvRow(
              'Data iscrizione',
              BackofficeFormatters.dateUi(d.registrationDate),
              textTheme,
              labelWidth: 140,
              bottomPadding: 8,
            ),
            if (d.registryYear != null)
              student360KvRow(
                'Anno registro',
                '${d.registryYear}',
                textTheme,
                labelWidth: 140,
                bottomPadding: 8,
              ),
            student360KvRow(
              'N. registro',
              (d.registryNumber != null &&
                      d.registryCode != null &&
                      d.registryCode!.isNotEmpty)
                  ? '${d.registryNumber}'
                  : 'Non assegnato',
              textTheme,
              labelWidth: 140,
              bottomPadding: 8,
            ),
            student360KvRow(
              'Codice registro',
              (d.registryCode != null && d.registryCode!.isNotEmpty)
                  ? d.registryCode!
                  : '—',
              textTheme,
              labelWidth: 140,
              bottomPadding: 8,
            ),
            if (d.practiceNumber != null && d.practiceNumber!.trim().isNotEmpty)
              student360KvRow(
                'N. pratica',
                d.practiceNumber!,
                textTheme,
                labelWidth: 140,
                bottomPadding: 8,
              ),
            if (d.licenseNumber != null && d.licenseNumber!.trim().isNotEmpty)
              student360KvRow(
                'N. patente',
                d.licenseNumber!,
                textTheme,
                labelWidth: 140,
                bottomPadding: 8,
              ),
            if (d.issueDate != null)
              student360KvRow(
                'Rilascio',
                BackofficeFormatters.dateUi(d.issueDate),
                textTheme,
                labelWidth: 140,
                bottomPadding: 8,
              ),
            if (d.expirationDate != null)
              student360KvRow(
                'Scadenza',
                BackofficeFormatters.dateUi(d.expirationDate),
                textTheme,
                labelWidth: 140,
                bottomPadding: 8,
              ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: BackofficeUiTokens.primary,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => showUpdatePracticeDossierDialog(
              context,
              view: view,
              repository: repository,
              onRefreshDetail: onRefreshDetail,
            ),
            icon: const Icon(Icons.folder_shared_outlined, size: 18),
            label: const Text('Aggiorna fascicolo'),
          ),
          const SizedBox(height: 12),
          student360SubsectionTitle('Azioni', textTheme),
          const SizedBox(height: 8),
          StudentOnboardingSection(
            view: view,
            repository: repository,
            onRefreshDetail: onRefreshDetail,
            embeddedInScheda: true,
            compactActions: true,
            inlineInPraticaCard: true,
            hideRegistrationFee: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = view.profile;
    final d = view.practiceDossier;
    final textTheme = Theme.of(context).textTheme;
    final addr = p.address;

    return Student360SectionScroll(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= student360TwoColumnBreakpoint;

          final schedaAllievo = Student360InfoCard(
            title: 'Scheda allievo',
            child: wide
                ? Student360ResponsiveRow(
                    spacing: 20,
                    leftFixedWidth: _photoColumnWidth,
                    left: Student360PhotoSignatureSection(
                      view: view,
                      repository: repository,
                      onRefreshDetail: onRefreshDetail,
                      sidebarLayout: true,
                    ),
                    right: _anagraficaColonna(p, addr, textTheme),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Student360PhotoSignatureSection(
                        view: view,
                        repository: repository,
                        onRefreshDetail: onRefreshDetail,
                        sidebarLayout: true,
                      ),
                      const SizedBox(height: 16),
                      _anagraficaColonna(p, addr, textTheme),
                    ],
                  ),
          );

          final iscrizionePratica = Student360SiblingCardsRow(
            spacing: 12,
            left: _iscrizioneCard(p, textTheme, stretch: wide),
            right: _praticaCard(context, d, textTheme, stretch: wide),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              schedaAllievo,
              const SizedBox(height: 12),
              iscrizionePratica,
            ],
          );
        },
      ),
    );
  }
}
