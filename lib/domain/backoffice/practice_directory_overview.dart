import 'backoffice_enums.dart';
import 'practice_document_requirements.dart';
import 'practice_list_item.dart';
import 'practice_registry.dart';

/// Card della dashboard operativa Directory Pratiche (PRATICHE.8A).
enum PracticeDirectoryDashboardCard {
  all,
  newLicense,
  renewal,
  duplicate,
  docsIncomplete,
  medicalAttention,
}

/// True se il certificato medico richiede attenzione operativa.
///
/// Solo `expired` + `expiringSoon`. Esclusi: ok, missing, notApplicable
/// (il missing resta in «Documenti mancanti»).
bool practiceNeedsMedicalAttention(
  PracticeDocumentChecklistSummary summary,
) {
  switch (summary.medicalCertificate) {
    case PracticeMedicalCertificateSummaryKind.expired:
    case PracticeMedicalCertificateSummaryKind.expiringSoon:
      return true;
    case PracticeMedicalCertificateSummaryKind.ok:
    case PracticeMedicalCertificateSummaryKind.missing:
    case PracticeMedicalCertificateSummaryKind.notApplicable:
      return false;
  }
}

/// Conteggi dashboard: sempre su tutta `_items`, mai sulla lista filtrata.
class PracticeDirectoryOverview {
  const PracticeDirectoryOverview({
    required this.total,
    required this.newLicense,
    required this.renewal,
    required this.duplicate,
    required this.docsIncomplete,
    required this.medicalAttention,
  });

  final int total;
  final int newLicense;
  final int renewal;
  final int duplicate;
  final int docsIncomplete;
  final int medicalAttention;

  static const empty = PracticeDirectoryOverview(
    total: 0,
    newLicense: 0,
    renewal: 0,
    duplicate: 0,
    docsIncomplete: 0,
    medicalAttention: 0,
  );

  factory PracticeDirectoryOverview.fromItems(List<PracticeListItem> items) {
    var newLicense = 0;
    var renewal = 0;
    var duplicate = 0;
    var docsIncomplete = 0;
    var medicalAttention = 0;

    for (final item in items) {
      switch (item.practiceType) {
        case 'new_license':
          newLicense++;
        case 'renewal':
          renewal++;
        case 'duplicate':
          duplicate++;
      }
      if (item.isDocumentIncompleteForFilter) docsIncomplete++;
      if (practiceNeedsMedicalAttention(item.documentChecklistSummary)) {
        medicalAttention++;
      }
    }

    return PracticeDirectoryOverview(
      total: items.length,
      newLicense: newLicense,
      renewal: renewal,
      duplicate: duplicate,
      docsIncomplete: docsIncomplete,
      medicalAttention: medicalAttention,
    );
  }

  int countFor(PracticeDirectoryDashboardCard card) {
    switch (card) {
      case PracticeDirectoryDashboardCard.all:
        return total;
      case PracticeDirectoryDashboardCard.newLicense:
        return newLicense;
      case PracticeDirectoryDashboardCard.renewal:
        return renewal;
      case PracticeDirectoryDashboardCard.duplicate:
        return duplicate;
      case PracticeDirectoryDashboardCard.docsIncomplete:
        return docsIncomplete;
      case PracticeDirectoryDashboardCard.medicalAttention:
        return medicalAttention;
    }
  }
}

/// Snapshot filtri directory (testabile; esclusività quick-filter dashboard).
class PracticeDirectoryFilterState {
  const PracticeDirectoryFilterState({
    this.practiceTypeFilter,
    this.practiceStatusFilter,
    this.onlyWithoutRegistry = false,
    this.onlyDocsIncomplete = false,
    this.onlyMedicalAttention = false,
  });

  final String? practiceTypeFilter;
  final PracticeFileStatus? practiceStatusFilter;
  final bool onlyWithoutRegistry;
  final bool onlyDocsIncomplete;
  final bool onlyMedicalAttention;

  PracticeDirectoryFilterState copyWith({
    String? practiceTypeFilter,
    PracticeFileStatus? practiceStatusFilter,
    bool? onlyWithoutRegistry,
    bool? onlyDocsIncomplete,
    bool? onlyMedicalAttention,
    bool clearPracticeType = false,
    bool clearPracticeStatus = false,
  }) {
    return PracticeDirectoryFilterState(
      practiceTypeFilter:
          clearPracticeType ? null : (practiceTypeFilter ?? this.practiceTypeFilter),
      practiceStatusFilter: clearPracticeStatus
          ? null
          : (practiceStatusFilter ?? this.practiceStatusFilter),
      onlyWithoutRegistry: onlyWithoutRegistry ?? this.onlyWithoutRegistry,
      onlyDocsIncomplete: onlyDocsIncomplete ?? this.onlyDocsIncomplete,
      onlyMedicalAttention: onlyMedicalAttention ?? this.onlyMedicalAttention,
    );
  }

  /// Tap dashboard → stato prevedibile (ricerca testuale gestita a parte).
  PracticeDirectoryFilterState applyDashboard(
    PracticeDirectoryDashboardCard card,
  ) {
    switch (card) {
      case PracticeDirectoryDashboardCard.all:
        return const PracticeDirectoryFilterState();
      case PracticeDirectoryDashboardCard.newLicense:
        return const PracticeDirectoryFilterState(
          practiceTypeFilter: 'new_license',
        );
      case PracticeDirectoryDashboardCard.renewal:
        return const PracticeDirectoryFilterState(
          practiceTypeFilter: 'renewal',
        );
      case PracticeDirectoryDashboardCard.duplicate:
        return const PracticeDirectoryFilterState(
          practiceTypeFilter: 'duplicate',
        );
      case PracticeDirectoryDashboardCard.docsIncomplete:
        return const PracticeDirectoryFilterState(onlyDocsIncomplete: true);
      case PracticeDirectoryDashboardCard.medicalAttention:
        return const PracticeDirectoryFilterState(onlyMedicalAttention: true);
    }
  }

  /// Card evidenziata quando lo stato coincide con un quick-filter esclusivo.
  PracticeDirectoryDashboardCard? get activeDashboardCard {
    if (practiceStatusFilter != null) return null;
    if (onlyWithoutRegistry) {
      return null;
    }
    if (onlyDocsIncomplete &&
        !onlyMedicalAttention &&
        practiceTypeFilter == null) {
      return PracticeDirectoryDashboardCard.docsIncomplete;
    }
    if (onlyMedicalAttention &&
        !onlyDocsIncomplete &&
        practiceTypeFilter == null) {
      return PracticeDirectoryDashboardCard.medicalAttention;
    }
    if (!onlyDocsIncomplete &&
        !onlyMedicalAttention &&
        practiceTypeFilter == 'new_license') {
      return PracticeDirectoryDashboardCard.newLicense;
    }
    if (!onlyDocsIncomplete &&
        !onlyMedicalAttention &&
        practiceTypeFilter == 'renewal') {
      return PracticeDirectoryDashboardCard.renewal;
    }
    if (!onlyDocsIncomplete &&
        !onlyMedicalAttention &&
        practiceTypeFilter == 'duplicate') {
      return PracticeDirectoryDashboardCard.duplicate;
    }
    if (!onlyDocsIncomplete &&
        !onlyMedicalAttention &&
        practiceTypeFilter == null) {
      return PracticeDirectoryDashboardCard.all;
    }
    return null;
  }
}

/// Applica filtri directory (stessa logica della pagina).
Iterable<PracticeListItem> filterPracticeDirectoryItems({
  required List<PracticeListItem> items,
  required PracticeDirectoryFilterState filters,
  String searchQuery = '',
}) sync* {
  final q = searchQuery.trim().toLowerCase();
  for (final i in items) {
    if (filters.practiceTypeFilter != null &&
        i.practiceType != filters.practiceTypeFilter) {
      continue;
    }
    if (filters.practiceStatusFilter != null &&
        i.practiceStatus != filters.practiceStatusFilter) {
      continue;
    }
    if (filters.onlyWithoutRegistry && i.hasRegistryNumberAssigned) {
      continue;
    }
    if (filters.onlyDocsIncomplete && !i.isDocumentIncompleteForFilter) {
      continue;
    }
    if (filters.onlyMedicalAttention &&
        !practiceNeedsMedicalAttention(i.documentChecklistSummary)) {
      continue;
    }
    if (q.isNotEmpty) {
      final hay = [
        i.studentFullName,
        i.studentEmail ?? '',
        i.studentPhone ?? '',
        i.registryCode ?? '',
        i.registryNumber?.toString() ?? '',
        i.registryYear?.toString() ?? '',
        i.practiceNumber ?? '',
      ].join(' ').toLowerCase();
      if (!hay.contains(q)) continue;
    }
    yield i;
  }
}

// --- PRATICHE.8B: priorità operativa (solo client-side) ---

/// Livello aggregato per badge / raggruppamento.
enum PracticeAttentionLevel {
  critical,
  warning,
  normal,
}

/// Motivo primario (una sola priorità per pratica).
///
/// Precedenza: medico scaduto > documenti mancanti > medico in scadenza > normale.
enum PracticeAttentionKind {
  medicalExpired,
  docsIncomplete,
  medicalExpiringSoon,
  none,
}

PracticeAttentionKind practiceAttentionKind(PracticeListItem item) {
  final medical = item.documentChecklistSummary.medicalCertificate;
  if (medical == PracticeMedicalCertificateSummaryKind.expired) {
    return PracticeAttentionKind.medicalExpired;
  }
  if (item.isDocumentIncompleteForFilter) {
    return PracticeAttentionKind.docsIncomplete;
  }
  if (medical == PracticeMedicalCertificateSummaryKind.expiringSoon) {
    return PracticeAttentionKind.medicalExpiringSoon;
  }
  return PracticeAttentionKind.none;
}

PracticeAttentionLevel practiceAttentionLevel(PracticeListItem item) {
  switch (practiceAttentionKind(item)) {
    case PracticeAttentionKind.medicalExpired:
    case PracticeAttentionKind.docsIncomplete:
      return PracticeAttentionLevel.critical;
    case PracticeAttentionKind.medicalExpiringSoon:
      return PracticeAttentionLevel.warning;
    case PracticeAttentionKind.none:
      return PracticeAttentionLevel.normal;
  }
}

/// Rank numerico crescente = priorità più alta (0 prima in lista).
int practiceAttentionRank(PracticeListItem item) {
  switch (practiceAttentionKind(item)) {
    case PracticeAttentionKind.medicalExpired:
      return 0;
    case PracticeAttentionKind.docsIncomplete:
      return 1;
    case PracticeAttentionKind.medicalExpiringSoon:
      return 2;
    case PracticeAttentionKind.none:
      return 3;
  }
}

/// Label chip aggiuntiva (null = nessun chip attention extra).
///
/// Docs-only critical: nessun label (resta «Mancano N»).
String? practiceAttentionLabel(PracticeListItem item) {
  switch (practiceAttentionKind(item)) {
    case PracticeAttentionKind.medicalExpired:
      return 'Medico scaduto';
    case PracticeAttentionKind.medicalExpiringSoon:
      return 'Medico in scadenza';
    case PracticeAttentionKind.docsIncomplete:
    case PracticeAttentionKind.none:
      return null;
  }
}

/// Comparator Priorità: rank ASC, poi `registrationDate` DESC, null date in coda.
int comparePracticeAttention(PracticeListItem a, PracticeListItem b) {
  final rankCmp =
      practiceAttentionRank(a).compareTo(practiceAttentionRank(b));
  if (rankCmp != 0) return rankCmp;

  final ad = a.registrationDate;
  final bd = b.registrationDate;
  if (ad == null && bd == null) return 0;
  if (ad == null) return 1;
  if (bd == null) return -1;
  return bd.compareTo(ad);
}

/// Sort stabile sulla lista già filtrata. OFF → ordine input invariato.
List<PracticeListItem> sortPracticeDirectoryByAttention(
  List<PracticeListItem> filtered, {
  required bool priorityOn,
}) {
  if (!priorityOn || filtered.length < 2) {
    return filtered;
  }
  final indexed = <(int, PracticeListItem)>[
    for (var i = 0; i < filtered.length; i++) (i, filtered[i]),
  ];
  indexed.sort((a, b) {
    final c = comparePracticeAttention(a.$2, b.$2);
    if (c != 0) return c;
    return a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

// --- PRATICHE.8C: azioni rapide card (navigation / contact only) ---

enum PracticeQuickAction {
  openOverview,
  openDocuments,
  call,
  email,
  assignRegistry,
}

/// Tab Scheda 360 allineati a [Student360DetailView] (0 = Scheda, 1 = Documenti).
const int practiceQuickActionTabScheda = 0;
const int practiceQuickActionTabDocumenti = 1;

bool practiceContactFieldPresent(String? raw) =>
    raw != null && raw.trim().isNotEmpty;

/// Voci menu disponibili per la card.
///
/// Sempre Scheda + Documenti; Chiama/Email se contatto;
/// «Assegna n. registro» SOLO per new_license senza registro (8D).
List<PracticeQuickAction> availablePracticeQuickActions(PracticeListItem item) {
  return [
    PracticeQuickAction.openOverview,
    PracticeQuickAction.openDocuments,
    if (practiceContactFieldPresent(item.studentPhone)) PracticeQuickAction.call,
    if (practiceContactFieldPresent(item.studentEmail)) PracticeQuickAction.email,
    if (canAssignPracticeRegistryNumberToListItem(item))
      PracticeQuickAction.assignRegistry,
  ];
}

/// Tab iniziale per azioni di navigazione 360; `null` per contatto/assegnazione.
int? practiceQuickActionInitialTabIndex(PracticeQuickAction action) {
  switch (action) {
    case PracticeQuickAction.openOverview:
      return practiceQuickActionTabScheda;
    case PracticeQuickAction.openDocuments:
      return practiceQuickActionTabDocumenti;
    case PracticeQuickAction.call:
    case PracticeQuickAction.email:
    case PracticeQuickAction.assignRegistry:
      return null;
  }
}
