import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/anagrafica/anagrafica_field_validation.dart';
import '../../domain/anagrafica/anagrafica_format.dart';
import '../../domain/backoffice/backoffice.dart';
import '../../domain/international_phone.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import '../../theme/app_visual_tokens.dart';
import '../international_phone_field.dart';

/// Dialog Modifica anagrafica (ALLIEVI.P1A) dalla Scheda 360.
Future<bool> showEditStudentAnagraficaDialog({
  required BuildContext context,
  required BackofficeRepository repository,
  required StudentProfile profile,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EditStudentAnagraficaDialog(
      repository: repository,
      profile: profile,
    ),
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

  DateTime? _birthDate;
  _GenderChoice? _gender;
  InternationalPhoneValue? _phoneValue;
  bool _busy = false;
  String? _error;
  late final bool _ambiguousInitialPhone;
  late final bool _hasLinkedAuth;

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
    _birthDate = p.birthDate;
    _gender = _parseGender(p.gender);
    _hasLinkedAuth = p.linkedAuthUserId != null &&
        p.linkedAuthUserId!.trim().isNotEmpty;

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
    if (_busy) return;

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
      await widget.repository.updateStudentAnagrafica(
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
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Impossibile aggiornare l’anagrafica. Riprova tra poco.';
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

  Widget _field({
    required String label,
    required Widget child,
  }) {
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
                        key: const ValueKey('edit-anagrafica-auth-email-disclaimer'),
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
                      enabled: !_busy,
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
                      enabled: !_busy,
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
                          onSelected: _busy
                              ? null
                              : (_) => setState(
                                    () => _gender = _GenderChoice.male,
                                  ),
                        ),
                        ChoiceChip(
                          key: const ValueKey('edit-anagrafica-gender-female'),
                          label: const Text('Femmina'),
                          selected: _gender == _GenderChoice.female,
                          onSelected: _busy
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
                      enabled: !_busy,
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
                  _field(
                    label: 'Luogo di nascita *',
                    child: TextField(
                      key: const ValueKey('edit-anagrafica-birth-place'),
                      controller: _birthPlaceCtrl,
                      enabled: !_busy,
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
                      enabled: !_busy,
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
                      enabled: !_busy,
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
                      enabled: !_busy,
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
                    enabled: !_busy,
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
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
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
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const ValueKey('edit-anagrafica-save'),
          onPressed: _busy ? null : _save,
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
