import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/anagrafica/anagrafica_field_validation.dart';
import '../../domain/anagrafica/anagrafica_format.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../domain/international_phone.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import '../../repositories/backoffice/student_fiscal_code_write_error.dart';
import '../../services/app_update/update_protected_dialog.dart';
import '../../services/app_update/update_protected_mutation.dart';
import '../../theme/app_visual_tokens.dart';
import '../../utils/app_access_password_generator.dart';
import '../international_phone_field.dart';
import 'backoffice_new_practice_dialog.dart'
    show showAppAccessCredentialsDialog;

/// Dialog Modifica anagrafica (ALLIEVI.P1A) dalla Scheda 360.
///
/// «Salva» aggiorna solo anagrafica. «Crea accesso app» è un’azione separata
/// (Edge Function) per allievi senza `students.user_id`.
Future<bool> showEditStudentAnagraficaDialog({
  required BuildContext context,
  required BackofficeRepository repository,
  required StudentProfile profile,
}) async {
  final result = await showUpdateProtectedDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) =>
        _EditStudentAnagraficaDialog(repository: repository, profile: profile),
  );
  return result == true;
}

enum _GenderChoice { male, female }

class _EditStudentAnagraficaDialog extends StatefulWidget {
  const _EditStudentAnagraficaDialog({
    required this.repository,
    required this.profile,
  });

  final BackofficeRepository repository;
  final StudentProfile profile;

  @override
  State<_EditStudentAnagraficaDialog> createState() =>
      _EditStudentAnagraficaDialogState();
}

class _EditStudentAnagraficaDialogState
    extends State<_EditStudentAnagraficaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _fiscalCtrl;
  late final TextEditingController _birthPlaceCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _capCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _appEmailCtrl;
  late final TextEditingController _appPasswordCtrl;

  DateTime? _birthDate;
  _GenderChoice? _gender;
  InternationalPhoneValue? _phoneValue;
  bool _busy = false;
  bool _creatingAccess = false;
  String? _error;
  late final bool _ambiguousInitialPhone;
  late bool _hasLinkedAuth;
  late String? _linkedAuthEmail;
  bool _obscureAppPassword = true;

  bool get _interactionLocked => _busy || _creatingAccess;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    final addr = p.address;
    _firstNameCtrl = TextEditingController(text: p.firstName);
    _lastNameCtrl = TextEditingController(text: p.lastName);
    _fiscalCtrl = TextEditingController(text: p.taxCode ?? '');
    _birthPlaceCtrl = TextEditingController(text: p.birthPlace ?? '');
    _addressCtrl = TextEditingController(text: addr?.streetLine1 ?? '');
    _cityCtrl = TextEditingController(text: addr?.city ?? '');
    _capCtrl = TextEditingController(text: addr?.postalCode ?? '');
    _provinceCtrl = TextEditingController(text: addr?.provinceCode ?? '');
    _emailCtrl = TextEditingController(text: p.email ?? '');
    _appEmailCtrl = TextEditingController(text: (p.email ?? '').trim());
    _appPasswordCtrl = TextEditingController();
    _birthDate = p.birthDate;
    _gender = _parseGender(p.gender);
    _hasLinkedAuth =
        p.linkedAuthUserId != null && p.linkedAuthUserId!.trim().isNotEmpty;
    _linkedAuthEmail = _hasLinkedAuth ? (p.email?.trim()) : null;

    final parsed = InternationalPhoneRules.parseStored(
      phone: p.phone,
      phoneCountryIso2: p.phoneCountryIso2,
    );
    _ambiguousInitialPhone =
        (p.phone?.trim().isNotEmpty ?? false) && !parsed.isValid;
    if (parsed.isValid) {
      _phoneValue = parsed.value;
    }
  }

  static _GenderChoice? _parseGender(String? raw) {
    final t = raw?.trim().toLowerCase();
    if (t == null || t.isEmpty) return null;
    if (t == 'maschio' || t == 'm' || t == 'male') return _GenderChoice.male;
    if (t == 'femmina' || t == 'f' || t == 'female') {
      return _GenderChoice.female;
    }
    return null;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _fiscalCtrl.dispose();
    _birthPlaceCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _capCtrl.dispose();
    _provinceCtrl.dispose();
    _emailCtrl.dispose();
    _appEmailCtrl.dispose();
    _appPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 14, now.month, now.day),
      locale: const Locale('it', 'IT'),
    );
    if (d != null) {
      setState(() => _birthDate = d);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_interactionLocked) return;

    final genderLabel = _gender == null
        ? null
        : (_gender == _GenderChoice.male ? 'Maschio' : 'Femmina');
    final validationErr = AnagraficaFieldValidation.validateEditableAnagrafica(
      lastName: _lastNameCtrl.text,
      firstName: _firstNameCtrl.text,
      gender: genderLabel,
      birthDate: _birthDate,
      birthPlace: _birthPlaceCtrl.text,
      fiscalCode: _fiscalCtrl.text,
      address: _addressCtrl.text,
      city: _cityCtrl.text,
      province: _provinceCtrl.text,
      cap: _capCtrl.text,
      phoneValue: _phoneValue,
      email: _emailCtrl.text,
      requireEmail: false,
    );
    if (validationErr != null) {
      setState(() => _error = validationErr);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = _phoneValue!;
    final birthDate = _birthDate!;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await runUpdateProtectedMutation(
        () => widget.repository.updateStudentAnagrafica(
          studentId: widget.profile.id,
          firstName: AnagraficaFormat.titleCase(_firstNameCtrl.text),
          lastName: AnagraficaFormat.titleCase(_lastNameCtrl.text),
          fiscalCode: AnagraficaFieldValidation.normalizeFiscalCode(
            _fiscalCtrl.text,
          ),
          birthDate: birthDate,
          birthPlace: AnagraficaFormat.titleCase(_birthPlaceCtrl.text),
          gender: genderLabel!,
          address: AnagraficaFormat.titleCase(_addressCtrl.text),
          city: AnagraficaFormat.titleCase(_cityCtrl.text),
          province: _provinceCtrl.text.trim().toUpperCase(),
          cap: _capCtrl.text.replaceAll(RegExp(r'\s'), ''),
          phoneE164: phone.e164,
          phoneCountryIso2: phone.countryIso2,
          email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error =
            friendlyStudentWriteError(e) ??
            'Impossibile aggiornare l’anagrafica. Riprova tra poco.';
      });
    }
  }

  Future<void> _createAppAccess() async {
    FocusScope.of(context).unfocus();
    if (_interactionLocked || _hasLinkedAuth) return;

    final emailErr = AnagraficaFieldValidation.validateEmail(
      _appEmailCtrl.text,
      requireNonEmpty: true,
      emptyMessage: 'Inserisci l’email per l’accesso app.',
    );
    if (emailErr != null) {
      setState(() => _error = emailErr);
      return;
    }

    var password = _appPasswordCtrl.text.trim();
    if (password.isEmpty) {
      password = generateReadableAppAccessPassword();
      _appPasswordCtrl.text = password;
    }
    if (password.length < 8) {
      setState(
        () => _error =
            'La password iniziale deve avere almeno 8 caratteri '
            '(oppure usa «Genera password»).',
      );
      return;
    }

    setState(() {
      _creatingAccess = true;
      _error = null;
    });

    try {
      final creds = await runUpdateProtectedMutation(
        () => widget.repository.createStudentAppAccess(
          studentId: widget.profile.id,
          email: _appEmailCtrl.text.trim(),
          temporaryPassword: password,
        ),
      );
      if (!mounted) return;

      _appPasswordCtrl.clear();
      setState(() {
        _creatingAccess = false;
        _hasLinkedAuth = true;
        _linkedAuthEmail = creds.email;
        _obscureAppPassword = true;
      });

      await showAppAccessCredentialsDialog(context, creds);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final detail = e is StateError
          ? e.message.trim()
          : e is ArgumentError
          ? (e.message?.toString().trim() ?? '')
          : '';
      setState(() {
        _creatingAccess = false;
        _error = detail.isEmpty
            ? 'Impossibile creare l’accesso app. Riprova tra poco.'
            : detail;
      });
    }
  }

  Widget _sectionTitle(String label, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        label,
        style: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppVisual.ink,
        ),
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppVisual.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  Widget _buildAppAccessSection(TextTheme textTheme) {
    return Column(
      key: const ValueKey('edit-anagrafica-app-access-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Divider(height: 24),
        _sectionTitle('Accesso app', textTheme),
        if (_hasLinkedAuth) ...[
          Container(
            key: const ValueKey('edit-anagrafica-app-access-active'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppVisual.logoBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppVisual.logoBlue.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accesso app attivo',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppVisual.logoBlueDeep,
                  ),
                ),
                if (_linkedAuthEmail != null &&
                    _linkedAuthEmail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _linkedAuthEmail!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppVisual.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Non è possibile creare un secondo account da qui. '
                  'La password non è recuperabile dalla Scheda 360.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppVisual.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Text(
            'Crea le credenziali Auth per questo allievo (senza signUp dal client). '
            'La password non viene salvata in anagrafica.',
            style: textTheme.bodySmall?.copyWith(
              color: AppVisual.inkMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          _field(
            label: 'Email accesso app *',
            child: TextField(
              key: const ValueKey('edit-anagrafica-app-email'),
              controller: _appEmailCtrl,
              enabled: !_interactionLocked,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'email@esempio.it',
              ),
            ),
          ),
          _field(
            label: 'Password iniziale *',
            child: TextField(
              key: const ValueKey('edit-anagrafica-app-password'),
              controller: _appPasswordCtrl,
              enabled: !_interactionLocked,
              obscureText: _obscureAppPassword,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                isDense: true,
                hintText: 'Almeno 8 caratteri',
                suffixIcon: IconButton(
                  key: const ValueKey('edit-anagrafica-app-password-toggle'),
                  tooltip: _obscureAppPassword ? 'Mostra' : 'Nascondi',
                  onPressed: _interactionLocked
                      ? null
                      : () => setState(
                          () => _obscureAppPassword = !_obscureAppPassword,
                        ),
                  icon: Icon(
                    _obscureAppPassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('edit-anagrafica-app-generate-password'),
              onPressed: _interactionLocked
                  ? null
                  : () {
                      setState(() {
                        _appPasswordCtrl.text =
                            generateReadableAppAccessPassword();
                        _obscureAppPassword = false;
                      });
                    },
              icon: const Icon(Icons.password_rounded, size: 18),
              label: const Text('Genera password'),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              key: const ValueKey('edit-anagrafica-create-app-access'),
              onPressed: _interactionLocked ? null : _createAppAccess,
              icon: _creatingAccess
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.vpn_key_rounded, size: 18),
              label: Text(_creatingAccess ? 'Creazione…' : 'Crea accesso app'),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.85;

    return AlertDialog(
      backgroundColor: AppVisual.ivory,
      title: Text(
        'Modifica anagrafica',
        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 480,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_hasLinkedAuth)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        key: const ValueKey(
                          'edit-anagrafica-auth-email-disclaimer',
                        ),
                        'L’email di accesso all’app non viene modificata.',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppVisual.inkMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  _sectionTitle('Anagrafica', textTheme),
                  _field(
                    label: 'Nome *',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-first-name'),
                      controller: _firstNameCtrl,
                      enabled: !_interactionLocked,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  _field(
                    label: 'Cognome *',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-last-name'),
                      controller: _lastNameCtrl,
                      enabled: !_interactionLocked,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  _field(
                    label: 'Sesso *',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('edit-anagrafica-gender-male'),
                          label: const Text('Maschio'),
                          selected: _gender == _GenderChoice.male,
                          onSelected: _interactionLocked
                              ? null
                              : (_) => setState(
                                  () => _gender = _GenderChoice.male,
                                ),
                        ),
                        ChoiceChip(
                          key: const ValueKey('edit-anagrafica-gender-female'),
                          label: const Text('Femmina'),
                          selected: _gender == _GenderChoice.female,
                          onSelected: _interactionLocked
                              ? null
                              : (_) => setState(
                                  () => _gender = _GenderChoice.female,
                                ),
                        ),
                      ],
                    ),
                  ),
                  _field(
                    label: 'Codice fiscale *',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-fiscal-code'),
                      controller: _fiscalCtrl,
                      enabled: !_interactionLocked,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return newValue.copyWith(
                            text: newValue.text.toUpperCase().replaceAll(
                              RegExp(r'\s'),
                              '',
                            ),
                            selection: newValue.selection,
                            composing: TextRange.empty,
                          );
                        }),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  _field(
                    label: 'Data di nascita *',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey('edit-anagrafica-birth-date'),
                        onPressed: _interactionLocked ? null : _pickBirthDate,
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                        ),
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
                  _field(
                    label: 'Luogo di nascita *',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-birth-place'),
                      controller: _birthPlaceCtrl,
                      enabled: !_interactionLocked,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  _sectionTitle('Residenza', textTheme),
                  _field(
                    label: 'Indirizzo *',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-address'),
                      controller: _addressCtrl,
                      enabled: !_interactionLocked,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  _field(
                    label: 'Città / Comune *',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-city'),
                      controller: _cityCtrl,
                      enabled: !_interactionLocked,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  _field(
                    label: 'CAP *',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-cap'),
                      controller: _capCtrl,
                      enabled: !_interactionLocked,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  _field(
                    label: 'Provincia *',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-province'),
                      controller: _provinceCtrl,
                      enabled: !_interactionLocked,
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
                        border: OutlineInputBorder(),
                        isDense: true,
                        counterText: '',
                      ),
                    ),
                  ),
                  _sectionTitle('Contatti', textTheme),
                  InternationalPhoneField(
                    key: const ValueKey('edit-anagrafica-phone'),
                    initialPhone: widget.profile.phone,
                    initialCountryIso2: widget.profile.phoneCountryIso2,
                    enabled: !_interactionLocked,
                    requiredField: true,
                    showAmbiguousHint: _ambiguousInitialPhone,
                    onValidChanged: (v) => _phoneValue = v,
                  ),
                  const SizedBox(height: 10),
                  _field(
                    label: 'Email anagrafica',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-email'),
                      controller: _emailCtrl,
                      enabled: !_interactionLocked,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  _buildAppAccessSection(textTheme),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      key: const ValueKey('edit-anagrafica-error'),
                      _error!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppVisual.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _interactionLocked
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const ValueKey('edit-anagrafica-save'),
          onPressed: _interactionLocked ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppVisual.logoBlue,
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salva'),
        ),
      ],
    );
  }
}
