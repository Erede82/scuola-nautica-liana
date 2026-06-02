/// Normalizzazione tipi documento/foto tra UI (snake_case) e DB (camelCase).
///
/// Retrocompatibile: accetta valori già in formato DB o UI misti.
abstract final class StudentDocumentTypes {
  // --- Valori canonici DB (migration foundation) ---
  static const dbIdentityCard = 'identityCard';
  static const dbTaxCode = 'taxCode';
  static const dbMedicalCertificate = 'medicalCertificate';
  static const dbPhoto = 'photo';
  static const dbPrivacyForm = 'privacyForm';
  static const dbPaymentReceipt = 'paymentReceipt';
  static const dbPracticeForm = 'practiceForm';
  static const dbOther = 'other';

  static const dbPhotoKindProfile = 'profile';
  static const dbPhotoKindDocument = 'document';
  static const dbPhotoKindLicense = 'license';
  static const dbPhotoKindOther = 'other';

  // --- Chiavi UI (dropdown / checklist) ---
  static const uiIdentityCard = 'identity_card';
  static const uiFiscalCode = 'fiscal_code';
  static const uiMedicalCertificate = 'medical_certificate';
  static const uiPhoto = 'photo';
  static const uiPracticeForm = 'practice_form';
  static const uiPaymentReceipt = 'payment_receipt';
  static const uiPrivacyForm = 'privacy_form';
  static const uiCurrentNauticalLicense = 'current_nautical_license';
  static const uiLossReport = 'loss_report';
  static const uiOther = 'other';

  static const uiPhotoKindProfile = 'profile';
  static const uiPhotoKindLicense = 'license_photo';
  static const uiPhotoKindDocument = 'document_photo';
  static const uiPhotoKindSignature = 'signature_photo';
  static const uiPhotoKindOther = 'other';

  /// Marker note DB per distinguere firma (`photo_kind = other` senza migration).
  static const signaturePhotoNotesMarker = 'Firma';

  /// Opzioni dropdown upload documenti (chiave UI → etichetta).
  static const uploadDocumentOptions = <String, String>{
    uiIdentityCard: 'Documento identità',
    uiFiscalCode: 'Codice fiscale / tessera sanitaria',
    uiMedicalCertificate: 'Certificato medico',
    uiPhoto: 'Foto / documento foto',
    uiPracticeForm: 'Modulo pratica / iscrizione',
    uiPaymentReceipt: 'Ricevuta pagamento',
    uiPrivacyForm: 'Modulo privacy',
    uiCurrentNauticalLicense: 'Patente nautica attuale',
    uiLossReport: 'Denuncia smarrimento/furto',
    uiOther: 'Altro',
  };

  /// Opzioni dropdown upload foto (chiave UI → etichetta).
  static const uploadPhotoOptions = <String, String>{
    uiPhotoKindProfile: 'Foto profilo / allievo',
    uiPhotoKindLicense: 'Foto patente',
    uiPhotoKindDocument: 'Foto documento',
    uiPhotoKindOther: 'Altra foto',
  };

  /// Solo dialog dedicato firma (salvata come `other` + note [signaturePhotoNotesMarker]).
  static const uploadSignaturePhotoOptions = <String, String>{
    uiPhotoKindSignature: 'Firma',
  };

  static const _documentDbToUi = <String, String>{
    dbIdentityCard: uiIdentityCard,
    dbTaxCode: uiFiscalCode,
    dbMedicalCertificate: uiMedicalCertificate,
    dbPhoto: uiPhoto,
    dbPracticeForm: uiPracticeForm,
    dbPaymentReceipt: uiPaymentReceipt,
    dbPrivacyForm: uiPrivacyForm,
    dbOther: uiOther,
  };

  static const _photoDbToUi = <String, String>{
    dbPhotoKindProfile: uiPhotoKindProfile,
    dbPhotoKindDocument: uiPhotoKindDocument,
    dbPhotoKindLicense: uiPhotoKindLicense,
    dbPhotoKindOther: uiPhotoKindOther,
  };

  static const _documentDbLabels = <String, String>{
    dbIdentityCard: 'Documento identità',
    dbTaxCode: 'Codice fiscale / tessera sanitaria',
    dbMedicalCertificate: 'Certificato medico',
    dbPhoto: 'Foto / documento foto',
    dbPracticeForm: 'Modulo pratica / iscrizione',
    dbPaymentReceipt: 'Ricevuta pagamento',
    dbPrivacyForm: 'Modulo privacy',
    dbOther: 'Altro documento',
  };

  static const _photoDbLabels = <String, String>{
    dbPhotoKindProfile: 'Foto profilo',
    dbPhotoKindDocument: 'Foto documento',
    dbPhotoKindLicense: 'Foto patente',
    dbPhotoKindOther: 'Altra foto',
  };

  /// Converte un valore UI o legacy in valore DB canonico per INSERT.
  static String documentTypeToDb(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return dbOther;

    final directDb = _knownDocumentDbValues.contains(trimmed) ? trimmed : null;
    if (directDb != null) return directDb;

    switch (_normalizeToken(trimmed)) {
      case 'identity_card':
      case 'identitycard':
        return dbIdentityCard;
      case 'fiscal_code':
      case 'tax_code':
      case 'taxcode':
        return dbTaxCode;
      case 'medical_certificate':
      case 'medicalcertificate':
        return dbMedicalCertificate;
      case 'photo':
        return dbPhoto;
      case 'practice_form':
      case 'practiceform':
        return dbPracticeForm;
      case 'payment_receipt':
      case 'paymentreceipt':
        return dbPaymentReceipt;
      case 'privacy_form':
      case 'privacyform':
        return dbPrivacyForm;
      case 'current_nautical_license':
      case 'loss_report':
      case 'other':
        return dbOther;
    }

    return dbOther;
  }

  /// Normalizza un valore già persistito (DB o legacy) al formato DB canonico.
  static String normalizeDocumentDbValue(String raw) => documentTypeToDb(raw);

  /// Converte DB → chiave UI preferita (se nota).
  static String? documentUiKeyFromDb(String raw) {
    final db = normalizeDocumentDbValue(raw);
    return _documentDbToUi[db];
  }

  /// Etichetta italiana per visualizzazione (accetta DB o UI).
  static String documentTypeLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '—';
    if (uploadDocumentOptions.containsKey(trimmed)) {
      return uploadDocumentOptions[trimmed]!;
    }
    final uiKey = documentUiKeyFromDb(trimmed);
    if (uiKey != null && uploadDocumentOptions.containsKey(uiKey)) {
      return uploadDocumentOptions[uiKey]!;
    }
    final db = normalizeDocumentDbValue(trimmed);
    return _documentDbLabels[db] ?? _humanizeToken(trimmed);
  }

  /// Titolo predefinito per tipi UI che mappano su `other`.
  static String? defaultTitleForDocumentUiType(String uiType) {
    switch (uiType) {
      case uiCurrentNauticalLicense:
        return 'Patente nautica attuale';
      case uiLossReport:
        return 'Denuncia smarrimento/furto';
      default:
        return null;
    }
  }

  /// Titolo automatico per upload: etichetta italiana del tipo documento (chiave UI).
  static String autoTitleForDocumentUiType(String uiType) {
    final label = uploadDocumentOptions[uiType];
    if (label != null && label.isNotEmpty) return label;
    return documentTypeLabel(uiType);
  }

  static String photoKindToDb(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return dbPhotoKindOther;

    if (_knownPhotoDbValues.contains(trimmed)) return trimmed;

    switch (_normalizeToken(trimmed)) {
      case 'profile':
      case 'profile_photo':
        return dbPhotoKindProfile;
      case 'license':
      case 'license_photo':
        return dbPhotoKindLicense;
      case 'document':
      case 'document_photo':
        return dbPhotoKindDocument;
      case 'other':
      case 'signature':
      case 'signature_photo':
        return dbPhotoKindOther;
    }

    return dbPhotoKindOther;
  }

  /// Firma salvata come foto `other` con note marker (nessuna migration).
  static bool isSignaturePhoto({
    required String photoKind,
    String? notes,
    String? fileName,
  }) {
    if (_normalizeToken(photoKind) == 'signature_photo') return true;
    final note = (notes ?? '').trim().toLowerCase();
    if (note == signaturePhotoNotesMarker.toLowerCase()) return true;
    final name = (fileName ?? '').toLowerCase();
    return name.contains('firma') || name.contains('signature');
  }

  /// Note da impostare in upload firma (compat DB attuale).
  static String? signatureUploadNotes(String photoUiKind) {
    if (photoUiKind == uiPhotoKindSignature) {
      return signaturePhotoNotesMarker;
    }
    return null;
  }

  static String normalizePhotoDbValue(String raw) => photoKindToDb(raw);

  static String? photoUiKeyFromDb(String raw) {
    final db = normalizePhotoDbValue(raw);
    return _photoDbToUi[db];
  }

  static String photoKindLabel(
    String raw, {
    String? notes,
    String? fileName,
  }) {
    if (isSignaturePhoto(photoKind: raw, notes: notes, fileName: fileName)) {
      return 'Firma';
    }
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '—';
    if (uploadPhotoOptions.containsKey(trimmed)) {
      return uploadPhotoOptions[trimmed]!;
    }
    if (uploadSignaturePhotoOptions.containsKey(trimmed)) {
      return uploadSignaturePhotoOptions[trimmed]!;
    }
    final uiKey = photoUiKeyFromDb(trimmed);
    if (uiKey != null && uploadPhotoOptions.containsKey(uiKey)) {
      return uploadPhotoOptions[uiKey]!;
    }
    final db = normalizePhotoDbValue(trimmed);
    return _photoDbLabels[db] ?? _humanizeToken(trimmed);
  }

  static const _knownDocumentDbValues = {
    dbIdentityCard,
    dbTaxCode,
    dbMedicalCertificate,
    dbPhoto,
    dbPrivacyForm,
    dbPaymentReceipt,
    dbPracticeForm,
    dbOther,
  };

  static const _knownPhotoDbValues = {
    dbPhotoKindProfile,
    dbPhotoKindDocument,
    dbPhotoKindLicense,
    dbPhotoKindOther,
  };

  static String _normalizeToken(String raw) =>
      raw.trim().replaceAll('-', '_').replaceAll(' ', '_').toLowerCase();

  static String _humanizeToken(String raw) {
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
}
