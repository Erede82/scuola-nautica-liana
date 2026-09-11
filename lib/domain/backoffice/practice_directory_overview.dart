import 'backoffice_enums.dart';
import 'practice_document_requirements.dart';
import 'practice_list_item.dart';

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
