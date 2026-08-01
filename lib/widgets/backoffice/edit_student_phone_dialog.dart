import 'package:flutter/material.dart';

import '../../domain/backoffice/ids.dart';
import '../../domain/international_phone.dart';
import '../../repositories/backoffice/backoffice_repository.dart';
import '../../theme/app_visual_tokens.dart';
import '../international_phone_field.dart';

/// Dialog dedicato per correggere il cellulare dalla Scheda 360.
Future<bool> showEditStudentPhoneDialog({
  required BuildContext context,
  required BackofficeRepository repository,
  required StudentId studentId,
  required String? currentPhone,
  required String? currentPhoneCountryIso2,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EditStudentPhoneDialog(
      repository: repository,
      studentId: studentId,
      currentPhone: currentPhone,
      currentPhoneCountryIso2: currentPhoneCountryIso2,
    ),
  );
  return result == true;
}

class _EditStudentPhoneDialog extends StatefulWidget {
  const _EditStudentPhoneDialog({
    required this.repository,
    required this.studentId,
    required this.currentPhone,
    required this.currentPhoneCountryIso2,
  });

  final BackofficeRepository repository;
  final StudentId studentId;
  final String? currentPhone;
  final String? currentPhoneCountryIso2;

  @override
  State<_EditStudentPhoneDialog> createState() =>
      _EditStudentPhoneDialogState();
}

class _EditStudentPhoneDialogState extends State<_EditStudentPhoneDialog> {
  final _formKey = GlobalKey<FormState>();
  InternationalPhoneValue? _phoneValue;
  bool _busy = false;
  String? _error;

  late final bool _ambiguousInitial;

  @override
  void initState() {
    super.initState();
    final parsed = InternationalPhoneRules.parseStored(
      phone: widget.currentPhone,
      phoneCountryIso2: widget.currentPhoneCountryIso2,
    );
    _ambiguousInitial =
        (widget.currentPhone?.trim().isNotEmpty ?? false) && !parsed.isValid;
    if (parsed.isValid) {
      _phoneValue = parsed.value;
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = _phoneValue;
    if (value == null) {
      setState(() => _error = InternationalPhoneValidationResult.emptyMessage);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.updateStudentPhone(
        studentId: widget.studentId,
        phoneE164: value.e164,
        phoneCountryIso2: value.countryIso2,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Impossibile aggiornare il cellulare. Riprova tra poco.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      backgroundColor: AppVisual.ivory,
      title: Text(
        'Modifica cellulare',
        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ((widget.currentPhone?.trim().isNotEmpty ?? false) &&
                  _ambiguousInitial)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Valore attuale: ${widget.currentPhone!.trim()}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppVisual.inkMuted,
                    ),
                  ),
                ),
              InternationalPhoneField(
                key: const ValueKey('edit-student-phone-field'),
                initialPhone: widget.currentPhone,
                initialCountryIso2: widget.currentPhoneCountryIso2,
                enabled: !_busy,
                requiredField: true,
                showAmbiguousHint: _ambiguousInitial,
                onValidChanged: (v) => _phoneValue = v,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
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
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const ValueKey('edit-student-phone-save'),
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
