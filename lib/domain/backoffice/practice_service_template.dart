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
