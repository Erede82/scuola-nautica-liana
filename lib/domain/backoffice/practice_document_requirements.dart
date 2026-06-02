import 'practice_document.dart';
import 'student_document_types.dart';

/// Identificatore stabile di un requisito documentale pratica.
enum PracticeDocumentRequirementId {
  identityDocument,
  fiscalCode,
  medicalCertificate,
  licensePhoto,
  practiceForm,
  paymentReceipt,
  privacyForm,
  currentNauticalLicense,
  lossReport,
}

/// Obbligatorio vs consigliato / da verificare.
enum PracticeDocumentRequirementLevel {
  required,
  recommended,
}

/// Stato singola voce checklist.
enum PracticeDocumentChecklistItemStatus {
  present,
  missing,
  expired,
  expiringSoon,
  recommendedMissing,
  recommendedPresent,
}

class PracticeDocumentRequirementDef {
  const PracticeDocumentRequirementDef({
    required this.id,
    required this.label,
    required this.level,
    this.documentUiType,
    this.photoUiType,
  });

  final PracticeDocumentRequirementId id;
  final String label;
  final PracticeDocumentRequirementLevel level;

  /// Tipo pre-selezionato nel dialog documenti (chiave UI).
  final String? documentUiType;

  /// Tipo pre-selezionato nel dialog foto (chiave UI), se applicabile.
  final String? photoUiType;

  bool get isRequired => level == PracticeDocumentRequirementLevel.required;
}

class PracticeDocumentChecklistItem {
  const PracticeDocumentChecklistItem({
    required this.requirement,
    required this.status,
    this.matchedDocument,
    this.matchedPhoto,
  });

  final PracticeDocumentRequirementDef requirement;
  final PracticeDocumentChecklistItemStatus status;
  final StudentDocument? matchedDocument;
  final StudentPhoto? matchedPhoto;

  bool get isRequired => requirement.isRequired;

  bool get countsAsMissingRequired =>
      isRequired &&
      (status == PracticeDocumentChecklistItemStatus.missing ||
          status == PracticeDocumentChecklistItemStatus.expired);

  bool get isExpired => status == PracticeDocumentChecklistItemStatus.expired;

  bool get isExpiringSoon =>
      status == PracticeDocumentChecklistItemStatus.expiringSoon;
}

class PracticeDocumentChecklist {
  const PracticeDocumentChecklist({
    required this.practiceType,
    required this.applicable,
    required this.items,
    required this.expiringWithinDays,
  });

  /// Valore DB `practice_dossiers.practice_type` o null.
  final String? practiceType;

  /// `false` per D1, `other`, tipi sconosciuti o assenza fascicolo.
  final bool applicable;
  final List<PracticeDocumentChecklistItem> items;
  final int expiringWithinDays;

  List<PracticeDocumentChecklistItem> get presentItems => items
      .where(
        (i) =>
            i.status == PracticeDocumentChecklistItemStatus.present ||
            i.status == PracticeDocumentChecklistItemStatus.expiringSoon ||
            i.status == PracticeDocumentChecklistItemStatus.recommendedPresent,
      )
      .toList(growable: false);

  List<PracticeDocumentChecklistItem> get missingRequiredItems => items
      .where((i) => i.countsAsMissingRequired)
      .toList(growable: false);

  List<PracticeDocumentChecklistItem> get expiredItems => items
      .where((i) => i.status == PracticeDocumentChecklistItemStatus.expired)
      .toList(growable: false);

  List<PracticeDocumentChecklistItem> get expiringSoonItems => items
      .where((i) => i.status == PracticeDocumentChecklistItemStatus.expiringSoon)
      .toList(growable: false);

  int get missingRequiredCount => missingRequiredItems.length;

  bool get isRequiredChecklistComplete =>
      applicable && missingRequiredCount == 0;

  PracticeDocumentChecklistItem? get medicalCertificateItem {
    for (final item in items) {
      if (item.requirement.id == PracticeDocumentRequirementId.medicalCertificate) {
        return item;
      }
    }
    return null;
  }
}

/// Giorni predefiniti per avviso scadenza certificato medico.
const kPracticeDocumentExpiringSoonDays = 30;

PracticeDocumentChecklist evaluatePracticeDocumentChecklist({
  required String? practiceType,
  required List<StudentDocument> documents,
  required List<StudentPhoto> photos,
  DateTime? now,
}) {
  final reference = _dateOnly(now ?? DateTime.now());
  final requirements = _requirementsForPracticeType(practiceType);
  if (requirements.isEmpty) {
    return PracticeDocumentChecklist(
      practiceType: practiceType,
      applicable: false,
      items: const [],
      expiringWithinDays: kPracticeDocumentExpiringSoonDays,
    );
  }

  final items = requirements
      .map(
        (req) => _evaluateRequirement(
          requirement: req,
          documents: documents,
          photos: photos,
          reference: reference,
          expiringWithinDays: kPracticeDocumentExpiringSoonDays,
        ),
      )
      .toList(growable: false);

  return PracticeDocumentChecklist(
    practiceType: practiceType,
    applicable: true,
    items: items,
    expiringWithinDays: kPracticeDocumentExpiringSoonDays,
  );
}

List<PracticeDocumentRequirementDef> _requirementsForPracticeType(
  String? practiceType,
) {
  switch (practiceType) {
    case 'new_license':
      return const [
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.identityDocument,
          label: 'Documento identità',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiIdentityCard,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.fiscalCode,
          label: 'Codice fiscale / tessera sanitaria',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiFiscalCode,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.medicalCertificate,
          label: 'Certificato medico',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiMedicalCertificate,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.licensePhoto,
          label: 'Foto patente',
          level: PracticeDocumentRequirementLevel.required,
          photoUiType: StudentDocumentTypes.uiPhotoKindLicense,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.practiceForm,
          label: 'Modulo iscrizione / pratica',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiPracticeForm,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.paymentReceipt,
          label: 'Ricevuta pagamento',
          level: PracticeDocumentRequirementLevel.recommended,
          documentUiType: StudentDocumentTypes.uiPaymentReceipt,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.privacyForm,
          label: 'Modulo privacy',
          level: PracticeDocumentRequirementLevel.recommended,
          documentUiType: StudentDocumentTypes.uiPrivacyForm,
        ),
      ];
    case 'renewal':
      return const [
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.currentNauticalLicense,
          label: 'Patente nautica attuale',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiCurrentNauticalLicense,
          photoUiType: StudentDocumentTypes.uiPhotoKindLicense,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.identityDocument,
          label: 'Documento identità',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiIdentityCard,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.fiscalCode,
          label: 'Codice fiscale / tessera sanitaria',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiFiscalCode,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.medicalCertificate,
          label: 'Certificato medico',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiMedicalCertificate,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.licensePhoto,
          label: 'Foto patente',
          level: PracticeDocumentRequirementLevel.recommended,
          photoUiType: StudentDocumentTypes.uiPhotoKindLicense,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.paymentReceipt,
          label: 'Ricevuta pagamento',
          level: PracticeDocumentRequirementLevel.recommended,
          documentUiType: StudentDocumentTypes.uiPaymentReceipt,
        ),
      ];
    case 'duplicate':
      return const [
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.identityDocument,
          label: 'Documento identità',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiIdentityCard,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.fiscalCode,
          label: 'Codice fiscale / tessera sanitaria',
          level: PracticeDocumentRequirementLevel.required,
          documentUiType: StudentDocumentTypes.uiFiscalCode,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.licensePhoto,
          label: 'Foto',
          level: PracticeDocumentRequirementLevel.required,
          photoUiType: StudentDocumentTypes.uiPhotoKindLicense,
          documentUiType: StudentDocumentTypes.uiPhoto,
        ),
        PracticeDocumentRequirementDef(
          id: PracticeDocumentRequirementId.lossReport,
          label: 'Denuncia smarrimento/furto',
          level: PracticeDocumentRequirementLevel.recommended,
          documentUiType: StudentDocumentTypes.uiLossReport,
        ),
      ];
    default:
      return const [];
  }
}

PracticeDocumentChecklistItem _evaluateRequirement({
  required PracticeDocumentRequirementDef requirement,
  required List<StudentDocument> documents,
  required List<StudentPhoto> photos,
  required DateTime reference,
  required int expiringWithinDays,
}) {
  final match = _findMatch(requirement: requirement, documents: documents, photos: photos);

  if (match.document == null && match.photo == null) {
    return PracticeDocumentChecklistItem(
      requirement: requirement,
      status: requirement.isRequired
          ? PracticeDocumentChecklistItemStatus.missing
          : PracticeDocumentChecklistItemStatus.recommendedMissing,
    );
  }

  if (requirement.id == PracticeDocumentRequirementId.medicalCertificate) {
    final doc = match.document!;
    final expiry = doc.expiresAt != null ? _dateOnly(doc.expiresAt!) : null;
    if (expiry != null) {
      if (expiry.isBefore(reference)) {
        return PracticeDocumentChecklistItem(
          requirement: requirement,
          status: PracticeDocumentChecklistItemStatus.expired,
          matchedDocument: doc,
        );
      }
      final limit = reference.add(Duration(days: expiringWithinDays));
      if (!expiry.isAfter(limit)) {
        return PracticeDocumentChecklistItem(
          requirement: requirement,
          status: PracticeDocumentChecklistItemStatus.expiringSoon,
          matchedDocument: doc,
        );
      }
    }
  }

  return PracticeDocumentChecklistItem(
    requirement: requirement,
    status: requirement.isRequired
        ? PracticeDocumentChecklistItemStatus.present
        : PracticeDocumentChecklistItemStatus.recommendedPresent,
    matchedDocument: match.document,
    matchedPhoto: match.photo,
  );
}

class _RequirementMatch {
  const _RequirementMatch({this.document, this.photo});

  final StudentDocument? document;
  final StudentPhoto? photo;
}

_RequirementMatch _findMatch({
  required PracticeDocumentRequirementDef requirement,
  required List<StudentDocument> documents,
  required List<StudentPhoto> photos,
}) {
  switch (requirement.id) {
    case PracticeDocumentRequirementId.identityDocument:
      return _RequirementMatch(
        document: _firstDocument(documents, StudentDocumentTypes.dbIdentityCard),
      );
    case PracticeDocumentRequirementId.fiscalCode:
      return _RequirementMatch(
        document: _firstDocument(documents, StudentDocumentTypes.dbTaxCode),
      );
    case PracticeDocumentRequirementId.medicalCertificate:
      return _RequirementMatch(
        document: _firstDocument(
          documents,
          StudentDocumentTypes.dbMedicalCertificate,
        ),
      );
    case PracticeDocumentRequirementId.practiceForm:
      return _RequirementMatch(
        document: _firstDocument(documents, StudentDocumentTypes.dbPracticeForm),
      );
    case PracticeDocumentRequirementId.paymentReceipt:
      return _RequirementMatch(
        document: _firstDocument(
          documents,
          StudentDocumentTypes.dbPaymentReceipt,
        ),
      );
    case PracticeDocumentRequirementId.privacyForm:
      return _RequirementMatch(
        document: _firstDocument(documents, StudentDocumentTypes.dbPrivacyForm),
      );
    case PracticeDocumentRequirementId.licensePhoto:
      final photo = _firstPhoto(photos, StudentDocumentTypes.dbPhotoKindLicense);
      if (photo != null) return _RequirementMatch(photo: photo);
      return _RequirementMatch(
        document: _firstDocument(documents, StudentDocumentTypes.dbPhoto),
      );
    case PracticeDocumentRequirementId.currentNauticalLicense:
      final licensePhoto =
          _firstPhoto(photos, StudentDocumentTypes.dbPhotoKindLicense);
      if (licensePhoto != null) return _RequirementMatch(photo: licensePhoto);
      return _RequirementMatch(
        document: _firstOtherDocumentMatching(
          documents,
          keywords: const ['patente', 'titolo nautico'],
        ),
      );
    case PracticeDocumentRequirementId.lossReport:
      return _RequirementMatch(
        document: _firstOtherDocumentMatching(
          documents,
          keywords: const ['denuncia', 'smarrimento', 'furto'],
        ),
      );
  }
}

StudentDocument? _firstDocument(List<StudentDocument> documents, String dbType) {
  for (final doc in documents) {
    if (StudentDocumentTypes.normalizeDocumentDbValue(doc.documentType) ==
        dbType) {
      return doc;
    }
  }
  return null;
}

StudentPhoto? _firstPhoto(List<StudentPhoto> photos, String dbKind) {
  for (final photo in photos) {
    if (StudentDocumentTypes.normalizePhotoDbValue(photo.photoKind) == dbKind) {
      return photo;
    }
  }
  return null;
}

StudentDocument? _firstOtherDocumentMatching(
  List<StudentDocument> documents, {
  required List<String> keywords,
}) {
  for (final doc in documents) {
    if (StudentDocumentTypes.normalizeDocumentDbValue(doc.documentType) !=
        StudentDocumentTypes.dbOther) {
      continue;
    }
    final haystack = '${doc.title} ${doc.notes ?? ''}'.toLowerCase();
    if (keywords.any(haystack.contains)) return doc;
  }
  return null;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String practiceTypeLabelIt(String? practiceType) {
  switch (practiceType) {
    case 'new_license':
      return 'Conseguimento patente';
    case 'renewal':
      return 'Rinnovo patente';
    case 'duplicate':
      return 'Duplicato patente';
    default:
      if (practiceType == null || practiceType.isEmpty) return '—';
      return practiceType;
  }
}
