import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/backoffice/backoffice.dart';
import '../../domain/course_taxonomy.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import '../../repositories/backoffice/management_repository_registry.dart';
import '../../theme/app_visual_tokens.dart';
import 'backoffice_formatters.dart';

enum _BackofficePracticeCategory { entro12Motore, d1, oltre12VelaMotore }

enum _StudentGender { male, female }

enum _RegistryPracticeType { newLicense, renewal, duplicate }

extension on _RegistryPracticeType {
  String get dbValue => switch (this) {
    _RegistryPracticeType.newLicense => 'new_license',
    _RegistryPracticeType.renewal => 'renewal',
    _RegistryPracticeType.duplicate => 'duplicate',
  };
}

class _PracticeCategorySpec {
  const _PracticeCategorySpec({
    required this.pathStorage,
    required this.licenseCategory,
  });

  /// Valore `students.enrolled_course_path` ammesso dal CHECK SQL.
  final String pathStorage;

  /// Valore `students.enrolled_license_category` (`motore` | `vela` | `d1`).
  final String licenseCategory;
}

/// Riferimento leggibile richiesto in note (gli enum DB restano compatibili).
String _operatorCatalogRef(_BackofficePracticeCategory c) {
  switch (c) {
    case _BackofficePracticeCategory.entro12Motore:
      return 'entro_12_miglia_motore';
    case _BackofficePracticeCategory.d1:
      return 'd1';
    case _BackofficePracticeCategory.oltre12VelaMotore:
      return 'oltre_12_miglia_vela_motore';
  }
}

_PracticeCategorySpec _specFor(_BackofficePracticeCategory c) {
  switch (c) {
    case _BackofficePracticeCategory.entro12Motore:
      return const _PracticeCategorySpec(
        pathStorage: EnrollmentCoursePathStorage.entro12Miglia,
        licenseCategory: 'motore',
      );
    case _BackofficePracticeCategory.d1:
      return const _PracticeCategorySpec(
        pathStorage: EnrollmentCoursePathStorage.d1,
        licenseCategory: 'd1',
      );
    case _BackofficePracticeCategory.oltre12VelaMotore:
      return const _PracticeCategorySpec(
        pathStorage: EnrollmentCoursePathStorage.entro12MigliaVela,
        licenseCategory: 'vela',
      );
  }
}

_BackofficePracticeCategory? _chipForPathAndCategory(
  String path,
  String licenseCategory,
) {
  for (final c in _BackofficePracticeCategory.values) {
    final spec = _specFor(c);
    if (spec.pathStorage == path && spec.licenseCategory == licenseCategory) {
      return c;
    }
  }
  return null;
}

_RegistryPracticeType? _registryTypeFromDb(String dbValue) {
  return switch (dbValue) {
    'new_license' => _RegistryPracticeType.newLicense,
    'renewal' => _RegistryPracticeType.renewal,
    'duplicate' => _RegistryPracticeType.duplicate,
    _ => null,
  };
}

String _composeInternalNotes({
  required String operatorNotes,
  required bool usesGlasses,
  required String categoryReference,
  required String? birthProvince,
}) {
  final blocks = <String>[];
  final op = operatorNotes.trim();
  if (op.isNotEmpty) {
    blocks.add(op);
  }
  final bp = birthProvince?.trim();
  if (bp != null && bp.isNotEmpty) {
    blocks.add('Provincia di nascita (indicata in segreteria): $bp');
  }
  final meta = <String>[
    'Categoria pratica (riferimento operatore): $categoryReference',
    'Occhiali/lenti: ${usesGlasses ? 'Sì' : 'No'}',
  ];
  blocks.add(meta.join('\n'));
  return blocks.join('\n\n');
}

Future<void> showAppAccessCredentialsDialog(
  BuildContext context,
  StudentAppAccessCredentials credentials,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      Future<void> copyToClipboard() async {
        final text =
            'Email: ${credentials.email}\n'
            'Password temporanea: ${credentials.temporaryPassword}';
        await Clipboard.setData(ClipboardData(text: text));
        if (!ctx.mounted) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Credenziali copiate negli appunti.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return AlertDialog(
        title: const Text('Accesso app creato'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText('Email: ${credentials.email}'),
              const SizedBox(height: 10),
              SelectableText(
                'Password temporanea: ${credentials.temporaryPassword}',
              ),
              const SizedBox(height: 14),
              Text(
                'Accedi all’app studente con questa email (tutto minuscolo) e questa password. '
                'Se il messaggio è «Email o password non corrette», verifica di aver copiato '
                'esattamente quanto riportato qui, senza spazi in più.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppVisual.inkMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Copia queste credenziali e comunicale all’allievo. '
                'La password non sarà più visibile dopo la chiusura.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppVisual.inkMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => copyToClipboard(),
            child: const Text('Copia credenziali'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      );
    },
  );
}

String _generateReadablePassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = math.Random();
  return List.generate(14, (_) => chars[r.nextInt(chars.length)]).join();
}

String _normalizePhone(String raw) => raw.replaceAll(RegExp(r'\s'), '');

/// Estrae le sole cifre nazionali (rimuove spazi e prefisso +39 se presente).
String _phoneNationalDigits(String raw) {
  final normalized = _normalizePhone(raw);
  var digits = normalized.startsWith('+') ? normalized.substring(1) : normalized;
  if (digits.startsWith('39') && digits.length == 12) {
    digits = digits.substring(2);
  }
  return digits;
}

String? _validateBirthProvince(String raw) {
  final p = raw.trim().toUpperCase();
  if (p.isEmpty) {
    return 'Inserisci la provincia di nascita.';
  }
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(p)) {
    return 'La provincia di nascita deve essere una sigla di 2 lettere (es. NA, SA, RM).';
  }
  return null;
}

String? _validatePhone(String raw) {
  final normalized = _normalizePhone(raw);
  if (normalized.isEmpty) {
    return 'Inserisci il telefono.';
  }
  if (!RegExp(r'^\+?[0-9]+$').hasMatch(normalized)) {
    return 'Il telefono può contenere solo cifre e un prefisso internazionale (+).';
  }
  final digits = _phoneNationalDigits(raw);
  if (digits.length != 10) {
    return 'Il telefono deve avere 10 cifre (es. 333 1234567, anche con prefisso +39).';
  }
  return null;
}

String? _validateItalianCap(String raw) {
  final cap = raw.replaceAll(RegExp(r'\s'), '');
  if (cap.isEmpty) {
    return 'Inserisci il CAP.';
  }
  if (!RegExp(r'^\d{5}$').hasMatch(cap)) {
    return 'Il CAP deve essere di 5 cifre (solo numeri).';
  }
  return null;
}

String? _validateNewPracticeFields({
  required String lastName,
  required String firstName,
  required String phone,
  required String email,
  required bool createAppAccess,
  required String accessPasswordDraft,
  required String fiscalCode,
  required DateTime? birthDate,
  required String birthPlace,
  required String birthProvince,
  required String address,
  required String city,
  required String province,
  required String cap,
  required _StudentGender? gender,
  required bool? usesGlasses,
  required bool createPracticeDossier,
  required DateTime registrationDateForRegistry,
  required bool requiresEnrollmentSelection,
  required String? enrolledCoursePath,
  required String? enrolledLicenseCategory,
}) {
  if (lastName.trim().isEmpty) {
    return 'Inserisci il cognome.';
  }
  if (firstName.trim().isEmpty) {
    return 'Inserisci il nome.';
  }
  if (gender == null) {
    return 'Seleziona il sesso.';
  }
  if (birthDate == null) {
    return 'Seleziona la data di nascita.';
  }
  if (birthPlace.trim().isEmpty) {
    return 'Inserisci il luogo di nascita.';
  }
  final birthProvinceErr = _validateBirthProvince(birthProvince);
  if (birthProvinceErr != null) {
    return birthProvinceErr;
  }
  if (fiscalCode.trim().isEmpty) {
    return 'Inserisci il codice fiscale.';
  }
  if (address.trim().isEmpty) {
    return 'Inserisci l’indirizzo.';
  }
  if (city.trim().isEmpty) {
    return 'Inserisci la città.';
  }
  if (province.trim().isEmpty) {
    return 'Inserisci la provincia di residenza.';
  }
  if (cap.trim().isEmpty) {
    return 'Inserisci il CAP.';
  }
  final capErr = _validateItalianCap(cap);
  if (capErr != null) {
    return capErr;
  }
  final phoneErr = _validatePhone(phone);
  if (phoneErr != null) {
    return phoneErr;
  }
  if (usesGlasses == null) {
    return 'Indica se l’allievo usa occhiali o lenti.';
  }
  if (requiresEnrollmentSelection) {
    if (enrolledCoursePath == null ||
        enrolledCoursePath.trim().isEmpty ||
        enrolledLicenseCategory == null ||
        enrolledLicenseCategory.trim().isEmpty) {
      return 'Seleziona la categoria pratica (percorso e modulo).';
    }
  }
  if (createPracticeDossier) {
    final rd = registrationDateForRegistry;
    if (rd.year < 1990 || rd.year > DateTime.now().year + 1) {
      return 'Verifica la data di iscrizione al registro.';
    }
  }
  final em = email.trim();
  if (createAppAccess) {
    if (em.isEmpty) {
      return 'Inserisci l’email per l’accesso app.';
    }
    if (!em.contains('@')) {
      return 'L’email deve contenere il simbolo @.';
    }
    final ap = accessPasswordDraft.trim();
    if (ap.isNotEmpty && ap.length < 8) {
      return 'La password temporanea deve avere almeno 8 caratteri (oppure lascia vuoto per generarla).';
    }
  } else {
    if (em.isNotEmpty && !em.contains('@')) {
      return 'L’email deve contenere il simbolo @.';
    }
  }
  return null;
}

/// Dialog staff-safe: crea anagrafica `students` (e opzionalmente `practice_dossiers`)
/// senza Auth né sessione studente.
Future<BackofficeNewStudentOutcome?> showBackofficeNewPracticeDialog(
  BuildContext context, {
  required BackofficeRepository repository,
}) async {
  return showDialog<BackofficeNewStudentOutcome>(
    context: context,
    builder: (ctx) => _BackofficeNewPracticeDialogBody(repository: repository),
  );
}

class _BackofficeNewPracticeDialogBody extends StatefulWidget {
  const _BackofficeNewPracticeDialogBody({required this.repository});

  final BackofficeRepository repository;

  @override
  State<_BackofficeNewPracticeDialogBody> createState() =>
      _BackofficeNewPracticeDialogBodyState();
}

class _BackofficeNewPracticeDialogBodyState
    extends State<_BackofficeNewPracticeDialogBody> {
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _birthProvinceCtrl = TextEditingController();
  final _fiscalCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _capCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _birthPlaceCtrl = TextEditingController();
  final _emailAppCtrl = TextEditingController();
  final _passwordTempCtrl = TextEditingController();

  _BackofficePracticeCategory? _categoryChip =
      _BackofficePracticeCategory.entro12Motore;
  String? _enrolledCoursePath;
  String? _enrolledLicenseCategory;
  PracticeServiceTemplate? _selectedTemplate;
  List<PracticeServiceTemplate> _templates = const [];
  bool _templatesLoading = true;
  String? _templatesLoadError;
  _StudentGender? _gender;
  bool? _usesGlasses;
  DateTime? _birthDate;
  bool _createDossier = true;
  bool _dossierCheckboxEnabled = true;
  _RegistryPracticeType _registryPracticeType =
      _RegistryPracticeType.newLicense;
  late DateTime _registrationDate;
  bool _createAppAccess = false;
  bool _busy = false;
  bool _obscurePassword = true;

  bool get _enrollmentFromTemplate =>
      _selectedTemplate != null && _selectedTemplate!.definesEnrollment;

  bool get _requiresManualCategory => !_enrollmentFromTemplate;

  bool get _isD1RegistryStandby =>
      (_selectedTemplate?.isD1RegistryStandby ?? false) ||
      isD1EnrollmentPath(_enrolledCoursePath);

  bool get _isRenewalOrDuplicatePractice {
    if (_selectedTemplate?.isRenewalOrDuplicate ?? false) return true;
    if (!_createPracticeDossierForSubmit) return false;
    return _registryPracticeType == _RegistryPracticeType.renewal ||
        _registryPracticeType == _RegistryPracticeType.duplicate;
  }

  bool get _requiresEnrollmentSelection => !_isRenewalOrDuplicatePractice;

  bool get _createPracticeDossierForSubmit {
    if (_selectedTemplate?.excludesRegistry ?? false) return false;
    if (_isD1RegistryStandby) return false;
    return _createDossier;
  }

  /// Solo il conseguimento (entro/oltre 12) genera numero di registro automatico.
  /// Rinnovo e duplicato creano il fascicolo ma NON consumano un numero di registro.
  bool get _assignRegistryForSubmit =>
      _createPracticeDossierForSubmit && !_isRenewalOrDuplicatePractice;

  void _resolveEnrollmentFromChip(_BackofficePracticeCategory category) {
    final spec = _specFor(category);
    _enrolledCoursePath = spec.pathStorage;
    _enrolledLicenseCategory = spec.licenseCategory;
  }

  void _refreshDossierControls() {
    final blocked =
        (_selectedTemplate?.excludesRegistry ?? false) || _isD1RegistryStandby;
    if (blocked) {
      _createDossier = false;
      _dossierCheckboxEnabled = false;
    } else {
      _dossierCheckboxEnabled = true;
      _createDossier = true;
    }
  }

  void _applyTemplate(PracticeServiceTemplate? template) {
    _selectedTemplate = template;
    if (template == null) {
      _categoryChip = _BackofficePracticeCategory.entro12Motore;
      _resolveEnrollmentFromChip(_categoryChip!);
      _registryPracticeType = _RegistryPracticeType.newLicense;
      _refreshDossierControls();
      return;
    }

    if (!template.excludesAutomaticRegistry) {
      _registryPracticeType =
          _registryTypeFromDb(template.practiceType) ??
          _RegistryPracticeType.newLicense;
    }

    if (template.definesEnrollment) {
      _enrolledCoursePath = template.enrolledCoursePath;
      _enrolledLicenseCategory = template.enrolledLicenseCategory;
      _categoryChip = _chipForPathAndCategory(
        template.enrolledCoursePath!,
        template.enrolledLicenseCategory!,
      );
    } else {
      _enrolledCoursePath = null;
      _enrolledLicenseCategory = null;
      _categoryChip = null;
    }

    _refreshDossierControls();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await managementRepository.listPracticeServiceTemplates(
        includeInactive: false,
      );
      if (!mounted) return;
      setState(() {
        _templates = list;
        _templatesLoading = false;
        _templatesLoadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _templatesLoading = false;
        _templatesLoadError =
            'Catalogo prestazioni non disponibile. Puoi continuare con inserimento manuale.';
      });
    }
  }

  String _categoryReferenceForNotes() {
    if (_isRenewalOrDuplicatePractice &&
        (_enrolledCoursePath == null || _enrolledCoursePath!.trim().isEmpty)) {
      return renewalDuplicatePracticePathLabel(
        template: _selectedTemplate,
        registryPracticeTypeDb: _createPracticeDossierForSubmit
            ? _registryPracticeType.dbValue
            : null,
      );
    }
    if (_enrollmentFromTemplate && _selectedTemplate != null) {
      return practiceServiceTemplateEnrollmentLabel(_selectedTemplate!);
    }
    if (_categoryChip != null) {
      return _operatorCatalogRef(_categoryChip!);
    }
    if (_enrolledCoursePath != null && _enrolledLicenseCategory != null) {
      return '$_enrolledCoursePath · $_enrolledLicenseCategory';
    }
    return 'non specificata';
  }

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _registrationDate = DateTime(n.year, n.month, n.day);
    _resolveEnrollmentFromChip(_BackofficePracticeCategory.entro12Motore);
    _loadTemplates();
  }

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _birthProvinceCtrl.dispose();
    _fiscalCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _capCtrl.dispose();
    _phoneCtrl.dispose();
    _birthPlaceCtrl.dispose();
    _emailAppCtrl.dispose();
    _passwordTempCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
    );
    if (!mounted) return;
    if (d != null) {
      setState(() => _birthDate = d);
    }
  }

  Future<void> _pickRegistrationDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _registrationDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (!mounted) return;
    if (d != null) {
      setState(() => _registrationDate = DateTime(d.year, d.month, d.day));
    }
  }

  Future<void> _submit() async {
    final err = _validateNewPracticeFields(
      lastName: _lastNameCtrl.text,
      firstName: _firstNameCtrl.text,
      phone: _phoneCtrl.text,
      email: _emailAppCtrl.text,
      createAppAccess: _createAppAccess,
      accessPasswordDraft: _passwordTempCtrl.text,
      fiscalCode: _fiscalCtrl.text,
      birthDate: _birthDate,
      birthPlace: _birthPlaceCtrl.text,
      birthProvince: _birthProvinceCtrl.text,
      address: _addressCtrl.text,
      city: _cityCtrl.text,
      province: _provinceCtrl.text,
      cap: _capCtrl.text,
      gender: _gender,
      usesGlasses: _usesGlasses,
      createPracticeDossier: _createPracticeDossierForSubmit,
      registrationDateForRegistry: _registrationDate,
      requiresEnrollmentSelection: _requiresEnrollmentSelection,
      enrolledCoursePath: _enrolledCoursePath,
      enrolledLicenseCategory: _enrolledLicenseCategory,
    );
    if (err != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final pathRaw = _enrolledCoursePath?.trim();
      final licenseRaw = _enrolledLicenseCategory?.trim();
      final path = _requiresEnrollmentSelection
          ? pathRaw
          : (pathRaw != null && pathRaw.isNotEmpty ? pathRaw : null);
      final licenseCat = _requiresEnrollmentSelection
          ? licenseRaw
          : (licenseRaw != null && licenseRaw.isNotEmpty ? licenseRaw : null);
      final birthProvince = _birthProvinceCtrl.text.trim().toUpperCase();
      final phone = _phoneNationalDigits(_phoneCtrl.text);
      final cap = _capCtrl.text.replaceAll(RegExp(r'\s'), '');
      final templateNotes = composeNewPracticeTemplateNotes(_selectedTemplate);
      final mergedNotes = _composeInternalNotes(
        operatorNotes: templateNotes,
        usesGlasses: _usesGlasses!,
        categoryReference: _categoryReferenceForNotes(),
        birthProvince: birthProvince,
      );
      final outcome = await widget.repository.createBackofficeStudent(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: phone,
        email: _emailAppCtrl.text.trim().isEmpty
            ? null
            : _emailAppCtrl.text.trim(),
        fiscalCode: _fiscalCtrl.text.trim(),
        birthDate: _birthDate,
        birthPlace: _birthPlaceCtrl.text.trim(),
        gender: _gender == _StudentGender.male ? 'Maschio' : 'Femmina',
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        province: _provinceCtrl.text.trim().toUpperCase(),
        cap: cap,
        enrolledCoursePath: path,
        enrolledLicenseCategory: licenseCat,
        notes: mergedNotes,
        createPracticeDossier: _createPracticeDossierForSubmit,
        practiceType: _createPracticeDossierForSubmit
            ? _registryPracticeType.dbValue
            : null,
        registrationDate:
            _createPracticeDossierForSubmit ? _registrationDate : null,
        assignRegistryNumber: _assignRegistryForSubmit,
      );

      final feeCents = _selectedTemplate?.defaultRegistrationFeeCents ?? 0;
      var feeSetOk = false;
      if (feeCents > 0) {
        try {
          await widget.repository.setStudentRegistrationFeeCents(
            studentId: outcome.profile.id,
            registrationFeeCents: feeCents,
          );
          feeSetOk = true;
        } catch (e) {
          final detail = e is StateError
              ? e.message.trim()
              : e is ArgumentError
              ? (e.message?.toString().trim() ?? '')
              : '';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  detail.isEmpty
                      ? 'La pratica è stata creata, ma la quota iscrizione non '
                            'è stata impostata. Puoi impostarla dalla Scheda 360.'
                      : 'La pratica è stata creata, ma la quota iscrizione non '
                            'è stata impostata. Puoi impostarla dalla Scheda 360.\n\n'
                            '$detail',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      if (_createAppAccess) {
        final draft = _passwordTempCtrl.text.trim();
        final temporaryPassword = draft.length >= 8
            ? draft
            : _generateReadablePassword();
        try {
          final creds = await widget.repository.createStudentAppAccess(
            studentId: outcome.profile.id,
            email: _emailAppCtrl.text.trim(),
            temporaryPassword: temporaryPassword,
          );
          if (mounted) {
            await showAppAccessCredentialsDialog(context, creds);
          }
        } catch (e) {
          final detail = e is StateError
              ? e.message.trim()
              : e is ArgumentError
              ? (e.message?.toString().trim() ?? '')
              : '';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  detail.isEmpty
                      ? 'La pratica è stata salvata, ma l’accesso app non è '
                            'stato creato. Verifica il caso prima di consegnare '
                            'le credenziali all’allievo.'
                      : 'La pratica è stata salvata, ma l’accesso app non è '
                            'stato creato. Verifica il caso prima di consegnare '
                            'le credenziali all’allievo.\n\n'
                            '$detail',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }

      if (mounted &&
          _createPracticeDossierForSubmit &&
          outcome.assignedRegistryCode != null) {
        final feePart = feeSetOk
            ? ' Quota iscrizione: ${BackofficeFormatters.moneyEur(feeCents)}.'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pratica creata. Numero registro: ${outcome.assignedRegistryCode}.$feePart',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted &&
          _createPracticeDossierForSubmit &&
          outcome.registryAssignmentNote != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pratica creata, ma l’assegnazione del numero registro non è andata a buon fine. '
              'Potrai riprovare dalla scheda allievo.\n\n'
              '${outcome.registryAssignmentNote}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted &&
          _createPracticeDossierForSubmit &&
          !_assignRegistryForSubmit) {
        final feePart = feeSetOk
            ? ' Quota iscrizione: ${BackofficeFormatters.moneyEur(feeCents)}.'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fascicolo creato senza numero di registro (rinnovo/duplicato).$feePart',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted && feeSetOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pratica creata. Quota iscrizione impostata: '
              '${BackofficeFormatters.moneyEur(feeCents)}.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (mounted) {
        Navigator.of(context).pop(outcome);
      }
    } catch (e) {
      final msg = e is StateError
          ? e.message
          : e is ArgumentError
          ? (e.message?.toString() ?? 'Dati non validi.')
          : 'Operazione non riuscita. Controlla i campi e riprova.';
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppVisual.logoBlueDeep,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _labeledField(String label, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppVisual.ink,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _choiceSegment<T>({
    required T value,
    required T? selectedValue,
    required String label,
    required ValueChanged<T> onSelect,
  }) {
    final selected = selectedValue == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: _busy
          ? null
          : (nowSelected) {
              if (nowSelected) {
                onSelect(value);
              }
            },
      selectedColor: AppVisual.logoBlue.withValues(alpha: 0.2),
      checkmarkColor: AppVisual.logoBlue,
      labelStyle: TextStyle(
        color: selected ? AppVisual.logoBlue : AppVisual.ink,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      ),
      side: BorderSide(color: selected ? AppVisual.logoBlue : AppVisual.border),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.person_add_alt_1_rounded,
            color: AppVisual.logoBlue,
            size: 26,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Nuova pratica',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scheda pratica segreteria. Per l’accesso app è disponibile l’opzione '
                '«Crea accesso app» (Edge Function server, senza signUp da questo client).',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppVisual.inkMuted),
              ),
              _sectionTitle('Anagrafica'),
              _labeledField(
                'Cognome *',
                child: TextField(
                  controller: _lastNameCtrl,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Cognome',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _labeledField(
                'Nome *',
                child: TextField(
                  controller: _firstNameCtrl,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Nome',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _labeledField(
                'Sesso *',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _choiceSegment<_StudentGender>(
                      value: _StudentGender.male,
                      selectedValue: _gender,
                      label: 'Maschio',
                      onSelect: (v) => setState(() => _gender = v),
                    ),
                    _choiceSegment<_StudentGender>(
                      value: _StudentGender.female,
                      selectedValue: _gender,
                      label: 'Femmina',
                      onSelect: (v) => setState(() => _gender = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _labeledField(
                'Data di nascita *',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _pickBirthDate,
                    icon: const Icon(Icons.calendar_month_rounded, size: 20),
                    label: Text(
                      _birthDate == null
                          ? 'Seleziona data'
                          : '${_birthDate!.day.toString().padLeft(2, '0')}/'
                                '${_birthDate!.month.toString().padLeft(2, '0')}/'
                                '${_birthDate!.year}',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppVisual.logoBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _labeledField(
                'Luogo di nascita *',
                child: TextField(
                  controller: _birthPlaceCtrl,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Comune o stato estero',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _labeledField(
                'Provincia di nascita *',
                child: TextField(
                  controller: _birthProvinceCtrl,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 2,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                        composing: TextRange.empty,
                      );
                    }),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Sigla provincia',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _labeledField(
                'Codice fiscale *',
                child: TextField(
                  controller: _fiscalCtrl,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Codice fiscale',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Inserisci il codice fiscale manualmente, verificandolo dal '
                  'documento dell’allievo.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppVisual.inkMuted.withValues(alpha: 0.78),
                    height: 1.35,
                  ),
                ),
              ),
              _sectionTitle('Residenza'),
              _labeledField(
                'Indirizzo *',
                child: TextField(
                  controller: _addressCtrl,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Via e numero civico',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _labeledField(
                      'Città *',
                      child: TextField(
                        controller: _cityCtrl,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Città',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _labeledField(
                      'Provincia *',
                      child: TextField(
                        controller: _provinceCtrl,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 2,
                        decoration: const InputDecoration(
                          hintText: 'Prov.',
                          border: OutlineInputBorder(),
                          counterText: '',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _labeledField(
                      'CAP *',
                      child: TextField(
                        controller: _capCtrl,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          hintText: 'CAP',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _sectionTitle('Pratica'),
              if (_templatesLoadError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    _templatesLoadError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppVisual.inkMuted,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              _labeledField(
                'Prestazione preimpostata',
                child: _templatesLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(
                          color: AppVisual.logoBlue,
                          minHeight: 2,
                        ),
                      )
                    : DropdownButtonFormField<String?>(
                        key: ValueKey('practice-template-${_selectedTemplate?.id}'),
                        initialValue: _selectedTemplate?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Inserimento manuale',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Inserimento manuale'),
                          ),
                          ..._templates.map(
                            (t) => DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text(t.title),
                            ),
                          ),
                        ],
                        onChanged: _busy
                            ? null
                            : (id) {
                                setState(() {
                                  if (id == null) {
                                    _applyTemplate(null);
                                  } else {
                                    _applyTemplate(
                                      _templates.firstWhere((t) => t.id == id),
                                    );
                                  }
                                });
                              },
                      ),
              ),
              if (_selectedTemplate != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppVisual.ivoryDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppVisual.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedTemplate!.title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppVisual.logoBlueDeep,
                        ),
                      ),
                      if (_selectedTemplate!.description?.trim().isNotEmpty ??
                          false) ...[
                        const SizedBox(height: 6),
                        Text(
                          _selectedTemplate!.description!.trim(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppVisual.inkMuted,
                                height: 1.35,
                              ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Quota totale attesa: '
                        '${BackofficeFormatters.moneyEur(_selectedTemplate!.defaultRegistrationFeeCents)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_selectedTemplate!.suggestedDepositCents > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Acconto consigliato (informativo): '
                          '${BackofficeFormatters.moneyEur(_selectedTemplate!.suggestedDepositCents)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppVisual.inkMuted),
                        ),
                      ],
                      if (_enrollmentFromTemplate) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Percorso: ${practiceServiceTemplateEnrollmentLabel(_selectedTemplate!)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppVisual.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _labeledField(
                'Telefono *',
                child: TextField(
                  controller: _phoneCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '10 cifre (es. 333 1234567)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_enrollmentFromTemplate) ...[
                _labeledField(
                  'Percorso / categoria *',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppVisual.ivoryDeep,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppVisual.border),
                    ),
                    child: Text(
                      practiceServiceTemplateEnrollmentLabel(_selectedTemplate!),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else if (_isRenewalOrDuplicatePractice) ...[
                _labeledField(
                  'Percorso patente',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppVisual.ivoryDeep,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppVisual.border),
                    ),
                    child: Text(
                      renewalDuplicatePracticePathLabel(
                        template: _selectedTemplate,
                        registryPracticeTypeDb: _createPracticeDossierForSubmit
                            ? _registryPracticeType.dbValue
                            : null,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                _labeledField(
                  'Categoria pratica *',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Tooltip(
                        message: 'entro_12_miglia_motore',
                        child: _choiceSegment<_BackofficePracticeCategory>(
                          value: _BackofficePracticeCategory.entro12Motore,
                          selectedValue: _categoryChip,
                          label: 'Entro le 12 miglia motore',
                          onSelect: (v) => setState(() {
                            _categoryChip = v;
                            _resolveEnrollmentFromChip(v);
                            _refreshDossierControls();
                          }),
                        ),
                      ),
                      Tooltip(
                        message: 'd1',
                        child: _choiceSegment<_BackofficePracticeCategory>(
                          value: _BackofficePracticeCategory.d1,
                          selectedValue: _categoryChip,
                          label: 'D1',
                          onSelect: (v) => setState(() {
                            _categoryChip = v;
                            _resolveEnrollmentFromChip(v);
                            _refreshDossierControls();
                          }),
                        ),
                      ),
                      Tooltip(
                        message: 'oltre_12_miglia_vela_motore',
                        child: _choiceSegment<_BackofficePracticeCategory>(
                          value: _BackofficePracticeCategory.oltre12VelaMotore,
                          selectedValue: _categoryChip,
                          label: 'Oltre 12 miglia vela e motore',
                          onSelect: (v) => setState(() {
                            _categoryChip = v;
                            _resolveEnrollmentFromChip(v);
                            _refreshDossierControls();
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_requiresManualCategory && _categoryChip == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Seleziona il percorso per proseguire.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              _labeledField(
                'Occhiali / lenti *',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _choiceSegment<bool>(
                      value: false,
                      selectedValue: _usesGlasses,
                      label: 'No',
                      onSelect: (v) => setState(() => _usesGlasses = v),
                    ),
                    _choiceSegment<bool>(
                      value: true,
                      selectedValue: _usesGlasses,
                      label: 'Sì',
                      onSelect: (v) => setState(() => _usesGlasses = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_isD1RegistryStandby &&
                  !(_selectedTemplate?.excludesRegistry ?? false)) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Colors.amber.shade900,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Registro D1 in stand-by: per questa prestazione non '
                          'viene generato automaticamente il numero di registro.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppVisual.inkMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_selectedTemplate?.excludesRegistry ?? false) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppVisual.logoBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Questa prestazione non genera dossier pratica né numero '
                          'registro. L’anagrafica verrà creata senza iscrizione al registro.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppVisual.inkMuted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(
                    context,
                  ).colorScheme.copyWith(primary: AppVisual.logoBlue),
                ),
                child: CheckboxListTile(
                  value: _createDossier,
                  onChanged: _busy || !_dossierCheckboxEnabled
                      ? null
                      : (v) => setState(() => _createDossier = v ?? true),
                  title: const Text('Crea dossier pratica'),
                  subtitle: !_dossierCheckboxEnabled
                      ? Text(
                          _isD1RegistryStandby
                              ? 'Registro D1 in stand-by — numerazione non automatica.'
                              : 'Non disponibile per questa prestazione.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppVisual.inkMuted,
                          ),
                        )
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (_createDossier) ...[
                _sectionTitle('Registro pratica'),
                _labeledField(
                  'Tipo pratica *',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _choiceSegment<_RegistryPracticeType>(
                        value: _RegistryPracticeType.newLicense,
                        selectedValue: _registryPracticeType,
                        label: 'Conseguimento patente',
                        onSelect: (v) =>
                            setState(() => _registryPracticeType = v),
                      ),
                      _choiceSegment<_RegistryPracticeType>(
                        value: _RegistryPracticeType.renewal,
                        selectedValue: _registryPracticeType,
                        label: 'Rinnovo patente',
                        onSelect: (v) =>
                            setState(() => _registryPracticeType = v),
                      ),
                      _choiceSegment<_RegistryPracticeType>(
                        value: _RegistryPracticeType.duplicate,
                        selectedValue: _registryPracticeType,
                        label: 'Duplicato patente',
                        onSelect: (v) =>
                            setState(() => _registryPracticeType = v),
                      ),
                    ],
                  ),
                ),
                if (_isRenewalOrDuplicatePractice) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Rinnovo/duplicato: il fascicolo viene creato ma non viene '
                    'assegnato alcun numero di registro automatico.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppVisual.inkMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _labeledField(
                  'Data iscrizione al registro *',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _pickRegistrationDate,
                      icon: const Icon(Icons.calendar_month_rounded, size: 20),
                      label: Text(
                        '${_registrationDate.day.toString().padLeft(2, '0')}/'
                        '${_registrationDate.month.toString().padLeft(2, '0')}/'
                        '${_registrationDate.year}',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppVisual.logoBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppVisual.ivoryDeep,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppVisual.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: AppVisual.logoBlue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Import e numerazione registro',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppVisual.logoBlueDeep,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Per pratiche storiche seleziona la data reale di iscrizione al registro '
                        'cartaceo. All’apertura del modulo la data proposta è quella odierna: se stai '
                        'inserendo pratiche del 2025 o del 2026, impostala dal calendario.\n\n'
                        'Se scegli una data nel 2025, il codice sarà del tipo 2025/00001 '
                        '(con progressivo assegnato automaticamente). Se scegli una data nel 2026, '
                        'sarà del tipo 2026/00001 (sempre con progressivo automatico). L’anno nel '
                        'codice segue l’anno della data che imposti qui.\n\n'
                        'Il numero progressivo non è scelto manualmente e non viene calcolato dall’app: '
                        'viene assegnato solo dalla procedura sul database (RPC) dopo la creazione del dossier.\n\n'
                        'Inserisci le pratiche nello stesso ordine del registro cartaceo per mantenere la '
                        'numerazione coerente.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppVisual.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _sectionTitle('Accesso app'),
              Text(
                '(nessun signUp dal client). La password non viene mai salvata in anagrafica.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppVisual.inkMuted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(
                    context,
                  ).colorScheme.copyWith(primary: AppVisual.logoBlue),
                ),
                child: CheckboxListTile(
                  value: _createAppAccess,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _createAppAccess = v ?? false;
                          if (!_createAppAccess) {
                            _passwordTempCtrl.clear();
                          }
                        }),
                  title: const Text('Crea accesso app per l’allievo'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 6),
              _labeledField(
                _createAppAccess
                    ? 'Email (accesso app) *'
                    : 'Email di contatto (opzionale)',
                child: TextField(
                  controller: _emailAppCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'email@esempio.it',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (_createAppAccess) ...[
                const SizedBox(height: 12),
                _labeledField(
                  'Password temporanea (min. 8 caratteri, o lascia vuoto per generarla)',
                  child: TextField(
                    controller: _passwordTempCtrl,
                    enabled: !_busy,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Almeno 8 caratteri',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Mostra' : 'Nascondi',
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _passwordTempCtrl.text =
                                  _generateReadablePassword();
                            });
                          },
                    icon: const Icon(Icons.key_rounded, size: 20),
                    label: const Text('Genera password'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 20),
          label: Text(_busy ? 'Creazione…' : 'Crea pratica'),
          style: FilledButton.styleFrom(
            backgroundColor: AppVisual.logoBlue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
