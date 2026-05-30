import '../../models/license_models.dart';
import '../course_taxonomy.dart';
import '../enrollment_content_mapping.dart';
import 'address.dart';
import 'backoffice_enums.dart';
import 'ids.dart';

/// Anagrafica allievo — tabella centrale `students` (o `profiles`) nel backend.
///
/// **App studente:** subset in sola lettura (nome, corso, stato) sincronizzato dopo login.
/// **Backoffice:** CRUD completo; collegamento a `auth.users` tramite [linkedAuthUserId]
/// (colonna DB tipica: `public.students.user_id`).
///
/// [enrolledCoursePath] è il **percorso di iscrizione** (segreteria). I moduli contenuto
/// app si derivano con [EnrollmentContentMapping] (`lib/domain/enrollment_content_mapping.dart`).
class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
    this.birthDate,

    /// Codice fiscale o identificativo fiscale nazionale.
    this.taxCode,

    /// Comune/stato di nascita (`students.birth_place` in produzione).
    this.birthPlace,

    /// Genere anagrafico (`students.gender`), es. «Maschio» / «Femmina».
    this.gender,
    this.address,
    required this.enrolledCoursePath,
    this.hasEnrollmentCoursePath = true,
    required this.registrationStatus,
    this.onboardingStatus = StudentOnboardingStatus.activeCourse,
    this.firstContactedAt,
    this.onboardingNotes,
    this.linkedAuthUserId,
    this.internalNotes,
    this.createdAt,
    this.updatedAt,
    this.practiceDossierType,
  });

  final StudentId id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;

  /// Solo data (timezone locale scuola); in DB tipicamente `DATE`.
  final DateTime? birthDate;
  final String? taxCode;
  final String? birthPlace;
  final String? gender;
  final PostalAddress? address;

  /// Percorso corso scelto in iscrizione (Entro 12 miglia, D1, misto vela, …).
  final EnrollmentCoursePath enrolledCoursePath;

  /// False per pratiche amministrative (rinnovo/duplicato) che non hanno un
  /// percorso didattico collegato. [enrolledCoursePath] resta valorizzato solo
  /// per compatibilità con schermate legacy.
  final bool hasEnrollmentCoursePath;

  final StudentRegistrationStatus registrationStatus;

  /// Flusso operativo segreteria (nuovi iscritti, contatti, documenti, …).
  final StudentOnboardingStatus onboardingStatus;

  /// Prima registrazione contatto da parte dello staff.
  final DateTime? firstContactedAt;

  /// Note rapide onboarding (non sostituisce le note interne strutturate).
  final String? onboardingNotes;

  /// FK verso identity provider (Supabase Auth UUID).
  final String? linkedAuthUserId;

  /// Note interne visibili solo allo staff (non mostrate nell’app allievo).
  final String? internalNotes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Tipo fascicolo registro (`new_license` | `renewal` | `duplicate`), se presente.
  /// Usato in elenco allievi per distinguere rinnovo/duplicato dal percorso.
  final String? practiceDossierType;

  /// Compatibilità: categoria catalogo “principale” per schermate che usano ancora
  /// una sola [LicenseCategoryId] (primo modulo del percorso: motore entro 12, D1, …).
  LicenseCategoryId get enrolledLicenseCategory =>
      EnrollmentContentMapping.primaryLicenseCategory(enrolledCoursePath);

  String get displayName => '$firstName $lastName'.trim();

  StudentProfile copyWith({
    String? practiceDossierType,
    bool? hasEnrollmentCoursePath,
  }) {
    return StudentProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      email: email,
      birthDate: birthDate,
      taxCode: taxCode,
      birthPlace: birthPlace,
      gender: gender,
      address: address,
      enrolledCoursePath: enrolledCoursePath,
      hasEnrollmentCoursePath:
          hasEnrollmentCoursePath ?? this.hasEnrollmentCoursePath,
      registrationStatus: registrationStatus,
      onboardingStatus: onboardingStatus,
      firstContactedAt: firstContactedAt,
      onboardingNotes: onboardingNotes,
      linkedAuthUserId: linkedAuthUserId,
      internalNotes: internalNotes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      practiceDossierType: practiceDossierType ?? this.practiceDossierType,
    );
  }
}
