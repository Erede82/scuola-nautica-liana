import 'package:flutter/material.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../repositories/backoffice/backoffice_registry.dart';
import '../../widgets/backoffice/backoffice_formatters.dart';
import '../../widgets/backoffice/backoffice_ui_tokens.dart';
import '../../theme/app_visual_tokens.dart';

/// Directory pratiche (V1): elenco da `practice_dossiers` + apertura Scheda 360 allievo.
class PracticeDossiersDirectoryPage extends StatefulWidget {
  const PracticeDossiersDirectoryPage({
    super.key,
    this.embedded = false,
    required this.onOpenStudent360,
  });

  final bool embedded;

  /// Passa al modulo Allievi e focalizza la scheda dell’allievo (niente duplicazione 360).
  final ValueChanged<StudentId> onOpenStudent360;

  @override
  State<PracticeDossiersDirectoryPage> createState() =>
      _PracticeDossiersDirectoryPageState();
}

class _PracticeDossiersDirectoryPageState
    extends State<PracticeDossiersDirectoryPage> {
  final _searchCtrl = TextEditingController();

  List<PracticeListItem>? _items;
  Object? _error;
  bool _loading = true;

  /// `null` = tutte.
  String? _practiceTypeFilter;

  PracticeFileStatus? _practiceStatusFilter;
  LicenseDocumentStatus? _documentStatusFilter;
  bool _onlyWithoutRegistry = false;
  bool _onlyDocsIncomplete = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchCtrl.clear();
      _practiceTypeFilter = null;
      _practiceStatusFilter = null;
      _documentStatusFilter = null;
      _onlyWithoutRegistry = false;
      _onlyDocsIncomplete = false;
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await backofficeRepository.listPracticeDossiers();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('PracticeDossiersDirectoryPage load: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _items = null;
      });
    }
  }

  static String _practiceTypeLabelIt(String? t) {
    switch (t) {
      case 'new_license':
        return 'Nuova patente';
      case 'renewal':
        return 'Rinnovo';
      case 'duplicate':
        return 'Duplicato';
      default:
        if (t == null || t.isEmpty) return '—';
        return t;
    }
  }

  Iterable<PracticeListItem> _filtered(List<PracticeListItem> raw) sync* {
    final q = _searchCtrl.text.trim().toLowerCase();
    for (final i in raw) {
      if (_practiceTypeFilter != null && i.practiceType != _practiceTypeFilter) {
        continue;
      }
      if (_practiceStatusFilter != null &&
          i.practiceStatus != _practiceStatusFilter) {
        continue;
      }
      if (_documentStatusFilter != null &&
          i.documentStatus != _documentStatusFilter) {
        continue;
      }
      if (_onlyWithoutRegistry && i.hasRegistryNumberAssigned) continue;
      if (_onlyDocsIncomplete && !i.isDocumentIncompleteForFilter) continue;
      if (q.isNotEmpty) {
        final regNum = i.registryNumber?.toString() ?? '';
        final regYear = i.registryYear?.toString() ?? '';
        final match =
            i.studentFullName.toLowerCase().contains(q) ||
            (i.studentEmail?.toLowerCase().contains(q) ?? false) ||
            (i.studentPhone?.toLowerCase().contains(q) ?? false) ||
            (i.registryCode?.toLowerCase().contains(q) ?? false) ||
            regNum.contains(q) ||
            regYear.contains(q) ||
            (i.practiceNumber?.toLowerCase().contains(q) ?? false);
        if (!match) continue;
      }
      yield i;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppVisual.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded)
            Material(
              color: AppVisual.logoBlue,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Text(
                  'Pratiche',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Elenco fascicoli da database. Il dettaglio completo è nella Scheda 360 dell’allievo.',
              style: textTheme.bodySmall?.copyWith(
                color: AppVisual.inkMuted,
                height: 1.35,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText:
                          'Cerca per nome, email, telefono, codice registro, n. pratica…',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Aggiorna elenco',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final dropW = (c.maxWidth - 16) / 3;
                    final w = dropW.clamp(200.0, 320.0);
                    Widget drop<T>({
                      required Widget child,
                    }) {
                      return SizedBox(
                        width: w,
                        child: child,
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        drop<String?>(
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey('ptype_${_practiceTypeFilter ?? 'all'}'),
                            initialValue: _practiceTypeFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tipo pratica',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Tutte')),
                              DropdownMenuItem(
                                value: 'new_license',
                                child: Text('Nuova patente'),
                              ),
                              DropdownMenuItem(
                                value: 'renewal',
                                child: Text('Rinnovo'),
                              ),
                              DropdownMenuItem(
                                value: 'duplicate',
                                child: Text('Duplicato'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _practiceTypeFilter = v),
                          ),
                        ),
                        drop<PracticeFileStatus?>(
                          child: DropdownButtonFormField<PracticeFileStatus?>(
                            key: ValueKey(
                              'pstat_${_practiceStatusFilter ?? 'all'}',
                            ),
                            initialValue: _practiceStatusFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Stato pratica',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Tutti'),
                              ),
                              ...PracticeFileStatus.values.map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    BackofficeFormatters.practiceStatus(s),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _practiceStatusFilter = v),
                          ),
                        ),
                        drop<LicenseDocumentStatus?>(
                          child: DropdownButtonFormField<
                              LicenseDocumentStatus?>(
                            key: ValueKey(
                              'dstat_${_documentStatusFilter ?? 'all'}',
                            ),
                            initialValue: _documentStatusFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Stato documenti',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Tutti'),
                              ),
                              ...LicenseDocumentStatus.values.map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    BackofficeFormatters.documentStatus(s),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _documentStatusFilter = v),
                          ),
                        ),
                        FilterChip(
                          label: const Text('Senza n. registro'),
                          selected: _onlyWithoutRegistry,
                          onSelected: (v) =>
                              setState(() => _onlyWithoutRegistry = v),
                        ),
                        FilterChip(
                          label: const Text('Documenti da completare'),
                          selected: _onlyDocsIncomplete,
                          onSelected: (v) =>
                              setState(() => _onlyDocsIncomplete = v),
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Reimposta filtri'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(textTheme)),
        ],
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Impossibile caricare le pratiche.\n$_error',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }
    final raw = _items ?? const <PracticeListItem>[];
    final filtered = _filtered(raw).toList(growable: false);
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          raw.isEmpty
              ? 'Nessun fascicolo pratica in elenco.'
              : 'Nessun risultato con i filtri correnti.',
          style: textTheme.bodyLarge,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final i = filtered[index];
            return _PracticeRowCard(
              item: i,
              wide: wide,
              typeLabel: _practiceTypeLabelIt(i.practiceType),
              onOpen360: () => widget.onOpenStudent360(i.studentId),
            );
          },
        );
      },
    );
  }
}

class _PracticeRowCard extends StatelessWidget {
  const _PracticeRowCard({
    required this.item,
    required this.wide,
    required this.typeLabel,
    required this.onOpen360,
  });

  final PracticeListItem item;
  final bool wide;
  final String typeLabel;
  final VoidCallback onOpen360;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final registryLine = item.hasRegistryNumberAssigned
        ? [
            item.registryCode ?? '—',
            if (item.registryNumber != null) 'n. ${item.registryNumber}',
            if (item.registryYear != null) 'anno ${item.registryYear}',
          ].join(' · ')
        : 'Senza numero registro assegnato';
    final contact = [
      if (item.studentEmail != null && item.studentEmail!.trim().isNotEmpty)
        item.studentEmail,
      if (item.studentPhone != null && item.studentPhone!.trim().isNotEmpty)
        item.studentPhone,
    ].join(' · ');

    return Material(
      color: AppVisual.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppVisual.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: AppVisual.logoBlue.withValues(alpha: 0.04),
        onTap: onOpen360,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.studentFullName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: BackofficeUiTokens.text,
                            ),
                          ),
                          if (contact.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              contact,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppVisual.inkMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Chip(
                                label: Text(typeLabel),
                                visualDensity: VisualDensity.compact,
                                labelStyle: textTheme.labelSmall,
                              ),
                              ..._PracticeDocumentSummaryChips.build(
                                item: item,
                                textTheme: textTheme,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Iscrizione',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppVisual.inkMuted,
                            ),
                          ),
                          Text(
                            item.registrationDate != null
                                ? BackofficeFormatters.dateUi(
                                    item.registrationDate,
                                  )
                                : '—',
                            style: textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Registro',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppVisual.inkMuted,
                            ),
                          ),
                          Text(
                            registryLine,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stati',
                            style: textTheme.labelSmall?.copyWith(
                              color: AppVisual.inkMuted,
                            ),
                          ),
                          Text(
                            'Pratica: ${BackofficeFormatters.practiceStatus(item.practiceStatus)}',
                            style: textTheme.bodySmall,
                          ),
                          Text(
                            'Documenti: ${BackofficeFormatters.documentStatus(item.documentStatus)}',
                            style: textTheme.bodySmall,
                          ),
                          if (item.practiceNumber != null &&
                              item.practiceNumber!.trim().isNotEmpty)
                            Text(
                              'N. pratica: ${item.practiceNumber}',
                              style: textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: onOpen360,
                      child: const Text('Apri Scheda 360'),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      item.studentFullName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (contact.isNotEmpty)
                      Text(
                        contact,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppVisual.inkMuted,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      typeLabel,
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: BackofficeUiTokens.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Iscrizione: ${item.registrationDate != null ? BackofficeFormatters.dateUi(item.registrationDate) : '—'}',
                    ),
                    Text('Registro: $registryLine'),
                    Text(
                      'Pratica: ${BackofficeFormatters.practiceStatus(item.practiceStatus)} · '
                      'Documenti: ${BackofficeFormatters.documentStatus(item.documentStatus)}',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _PracticeDocumentSummaryChips.build(
                          item: item,
                          textTheme: textTheme,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                      onPressed: onOpen360,
                      child: const Text('Apri Scheda 360'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Badge checklist documenti compatti per riga directory (Fase C).
abstract final class _PracticeDocumentSummaryChips {
  static List<Widget> build({
    required PracticeListItem item,
    required TextTheme textTheme,
  }) {
    final summary = item.documentChecklistSummary;
    if (!summary.applicable) {
      if (!item.isDocumentFlowIncomplete) return const [];
      return [
        _pill(
          label: 'Documenti da completare',
          bg: const Color(0xFFFFF4E5),
          fg: const Color(0xFFB45309),
          textTheme: textTheme,
        ),
      ];
    }

    final chips = <Widget>[];
    if (summary.isRequiredChecklistComplete) {
      chips.add(
        _pill(
          label: 'Completa',
          bg: Colors.green.shade50,
          fg: Colors.green.shade900,
          textTheme: textTheme,
        ),
      );
    } else {
      chips.add(
        _pill(
          label: 'Mancano ${summary.missingRequiredCount}',
          bg: Colors.orange.shade50,
          fg: Colors.orange.shade900,
          textTheme: textTheme,
        ),
      );
    }

    switch (summary.medicalCertificate) {
      case PracticeMedicalCertificateSummaryKind.missing:
        chips.add(
          _pill(
            label: 'Cert. medico assente',
            bg: Colors.orange.shade50,
            fg: Colors.orange.shade900,
            textTheme: textTheme,
          ),
        );
      case PracticeMedicalCertificateSummaryKind.expired:
        chips.add(
          _pill(
            label: 'Cert. medico scaduto',
            bg: Colors.red.shade50,
            fg: Colors.red.shade900,
            textTheme: textTheme,
          ),
        );
      case PracticeMedicalCertificateSummaryKind.expiringSoon:
        chips.add(
          _pill(
            label: 'Cert. medico in scadenza',
            bg: Colors.amber.shade50,
            fg: Colors.amber.shade900,
            textTheme: textTheme,
          ),
        );
      case PracticeMedicalCertificateSummaryKind.ok:
      case PracticeMedicalCertificateSummaryKind.notApplicable:
        break;
    }

    return chips;
  }

  static Widget _pill({
    required String label,
    required Color bg,
    required Color fg,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
