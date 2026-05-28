/// Catalogo prestazioni/pratiche preimpostate (Impostazioni backoffice).
class PracticeServiceTemplate {
  const PracticeServiceTemplate({
    required this.id,
    required this.slug,
    required this.title,
    this.description,
    required this.practiceType,
    this.enrolledCoursePath,
    this.enrolledLicenseCategory,
    required this.defaultRegistrationFeeCents,
    required this.suggestedDepositCents,
    this.internalNotes,
    this.active = true,
    this.sortOrder = 0,
  });

  final String id;
  final String slug;
  final String title;
  final String? description;

  /// DB: `new_license` | `renewal` | `duplicate` | `other`.
  final String practiceType;

  /// DB: `entro_12_miglia` | `entro_12_miglia_vela` | `d1` | null.
  final String? enrolledCoursePath;

  /// DB: `motore` | `vela` | `d1` | null.
  final String? enrolledLicenseCategory;

  final int defaultRegistrationFeeCents;
  final int suggestedDepositCents;
  final String? internalNotes;
  final bool active;
  final int sortOrder;

  PracticeServiceTemplate copyWith({
    String? id,
    String? slug,
    String? title,
    String? description,
    String? practiceType,
    String? enrolledCoursePath,
    String? enrolledLicenseCategory,
    int? defaultRegistrationFeeCents,
    int? suggestedDepositCents,
    String? internalNotes,
    bool? active,
    int? sortOrder,
  }) {
    return PracticeServiceTemplate(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      description: description ?? this.description,
      practiceType: practiceType ?? this.practiceType,
      enrolledCoursePath: enrolledCoursePath ?? this.enrolledCoursePath,
      enrolledLicenseCategory:
          enrolledLicenseCategory ?? this.enrolledLicenseCategory,
      defaultRegistrationFeeCents:
          defaultRegistrationFeeCents ?? this.defaultRegistrationFeeCents,
      suggestedDepositCents:
          suggestedDepositCents ?? this.suggestedDepositCents,
      internalNotes: internalNotes ?? this.internalNotes,
      active: active ?? this.active,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

/// Payload creazione/aggiornamento prestazione preimpostata.
class PracticeServiceTemplateInput {
  const PracticeServiceTemplateInput({
    required this.slug,
    required this.title,
    this.description,
    required this.practiceType,
    this.enrolledCoursePath,
    this.enrolledLicenseCategory,
    required this.defaultRegistrationFeeCents,
    required this.suggestedDepositCents,
    this.internalNotes,
    this.active = true,
    this.sortOrder = 0,
  });

  final String slug;
  final String title;
  final String? description;
  final String practiceType;
  final String? enrolledCoursePath;
  final String? enrolledLicenseCategory;
  final int defaultRegistrationFeeCents;
  final int suggestedDepositCents;
  final String? internalNotes;
  final bool active;
  final int sortOrder;

  static const allowedPracticeTypes = {
    'new_license',
    'renewal',
    'duplicate',
    'other',
  };

  static const allowedCoursePaths = {
    'entro_12_miglia',
    'entro_12_miglia_vela',
    'd1',
  };

  static const allowedLicenseCategories = {'motore', 'vela', 'd1'};
}

/// Percorso iscrizione D1 (`students.enrolled_course_path`).
bool isD1EnrollmentPath(String? path) {
  final p = path?.trim();
  return p != null && p.isNotEmpty && p == 'd1';
}

extension PracticeServiceTemplateNewPractice on PracticeServiceTemplate {
  /// Percorso e categoria entrambi valorizzati nel catalogo.
  bool get definesEnrollment =>
      enrolledCoursePath != null &&
      enrolledCoursePath!.isNotEmpty &&
      enrolledLicenseCategory != null &&
      enrolledLicenseCategory!.isNotEmpty;

  /// Prestazioni «other» non generano dossier / registro pratica.
  bool get excludesRegistry => practiceType == 'other';

  /// Patente D1: registro in stand-by (nessuna numerazione automatica).
  bool get isD1RegistryStandby =>
      slug == 'patente-d1' || isD1EnrollmentPath(enrolledCoursePath);

  /// Nessuna numerazione registro automatica (other o D1 stand-by).
  bool get excludesAutomaticRegistry => excludesRegistry || isD1RegistryStandby;

  /// Rinnovo o duplicato: percorso patente non obbligatorio in nuova pratica.
  bool get isRenewalOrDuplicate =>
      practiceType == 'renewal' || practiceType == 'duplicate';

  /// Valore DB per `practice_dossiers.practice_type`, se ammesso dal registro.
  String? get registryPracticeTypeDbValue {
    if (excludesAutomaticRegistry) return null;
    const allowed = {'new_license', 'renewal', 'duplicate'};
    return allowed.contains(practiceType) ? practiceType : null;
  }
}

/// Note operative da un template da includere in `students.notes`.
String composeNewPracticeTemplateNotes(PracticeServiceTemplate? template) {
  if (template == null) return '';
  final blocks = <String>[];
  blocks.add('Prestazione preimpostata: ${template.title}');
  final desc = template.description?.trim();
  if (desc != null && desc.isNotEmpty) {
    blocks.add(desc);
  }
  final notes = template.internalNotes?.trim();
  if (notes != null && notes.isNotEmpty) {
    blocks.add(notes);
  }
  if (template.suggestedDepositCents > 0) {
    final euros = (template.suggestedDepositCents / 100).toStringAsFixed(2);
    blocks.add('Acconto consigliato (informativo): $euros €');
  }
  return blocks.join('\n\n');
}

/// Etichetta leggibile per percorso/categoria da catalogo.
String practiceServiceTemplateEnrollmentLabel(
  PracticeServiceTemplate template,
) {
  if (!template.definesEnrollment) {
    return 'Da selezionare manualmente';
  }
  return '${template.enrolledCoursePath} · ${template.enrolledLicenseCategory}';
}

/// Etichetta descrittiva quando rinnovo/duplicato non richiede percorso patente.
String renewalDuplicatePracticePathLabel({
  PracticeServiceTemplate? template,
  String? registryPracticeTypeDb,
}) {
  final fromTemplate = template?.practiceType;
  final type = (fromTemplate == 'renewal' || fromTemplate == 'duplicate')
      ? fromTemplate
      : registryPracticeTypeDb;
  return switch (type) {
    'renewal' => 'Rinnovo patente nautica (percorso non applicabile)',
    'duplicate' => 'Duplicato patente nautica (percorso non applicabile)',
    _ => 'Rinnovo / duplicato (percorso non applicabile)',
  };
}
