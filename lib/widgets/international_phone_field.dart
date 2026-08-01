import 'package:flutter/material.dart';
import 'package:phone_form_field/phone_form_field.dart';

import '../domain/international_phone.dart';
import '../theme/app_visual_tokens.dart';

/// Campo cellulare internazionale condiviso (Paese + NSN, validazione dominio).
class InternationalPhoneField extends StatefulWidget {
  const InternationalPhoneField({
    super.key,
    this.initialPhone,
    this.initialCountryIso2,
    this.enabled = true,
    this.requiredField = true,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.onChanged,
    this.onValidChanged,
    this.decorationLabel = 'Cellulare',
    this.showAmbiguousHint = false,
    this.ambiguousHintText,
    this.focusNode,
  });

  /// Valore iniziale grezzo (E.164, nazionale IT, o ambiguo).
  final String? initialPhone;

  /// ISO2 preferito se non ricavabile dal numero (default IT).
  final String? initialCountryIso2;

  final bool enabled;
  final bool requiredField;
  final AutovalidateMode autovalidateMode;

  /// Callback ad ogni modifica (valido o meno).
  final ValueChanged<InternationalPhoneValidationResult>? onChanged;

  /// Solo quando il valore è valido; `null` se vuoto/invalido.
  final ValueChanged<InternationalPhoneValue?>? onValidChanged;

  final String decorationLabel;
  final bool showAmbiguousHint;
  final String? ambiguousHintText;
  final FocusNode? focusNode;

  /// Delegates necessari a `phone_form_field` / country selector.
  static List<LocalizationsDelegate<dynamic>> get localizationsDelegates =>
      PhoneFieldLocalization.delegates.toList(growable: false);

  @override
  State<InternationalPhoneField> createState() =>
      _InternationalPhoneFieldState();
}

class _InternationalPhoneFieldState extends State<InternationalPhoneField> {
  late final PhoneController _controller;
  String? _ambiguousBanner;
  bool _disposed = false;
  bool _applyingExternalValue = false;

  static const _fill = Color(0xFFFBF8F3);
  static const _border = Color(0xFFD8C8B5);

  @override
  void initState() {
    super.initState();
    final seed = _resolveSeed(
      phone: widget.initialPhone,
      countryIso2: widget.initialCountryIso2,
    );
    _controller = PhoneController(initialValue: seed.phoneNumber);
    _ambiguousBanner = seed.ambiguousMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      _emitFromController();
    });
  }

  @override
  void didUpdateWidget(covariant InternationalPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final phoneChanged = oldWidget.initialPhone != widget.initialPhone;
    final isoChanged =
        oldWidget.initialCountryIso2 != widget.initialCountryIso2;
    if (!phoneChanged && !isoChanged) return;
    // Aggiornare PhoneController durante build fa notificare il Form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      _applyExternalSeed(emit: true);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  ({PhoneNumber phoneNumber, String? ambiguousMessage}) _resolveSeed({
    required String? phone,
    required String? countryIso2,
  }) {
    final raw = phone?.trim();
    final isoHint =
        countryIso2?.trim().toUpperCase() ??
        InternationalPhoneRules.defaultCountryIso2;

    if (raw == null || raw.isEmpty) {
      return (
        phoneNumber: PhoneNumber(
          isoCode: InternationalPhoneRules.isoCodeFromString(isoHint),
          nsn: '',
        ),
        ambiguousMessage: null,
      );
    }

    final stored = InternationalPhoneRules.parseStored(
      phone: raw,
      phoneCountryIso2: countryIso2,
    );
    if (stored.isValid && stored.value != null) {
      final v = stored.value!;
      return (
        phoneNumber: PhoneNumber(
          isoCode: InternationalPhoneRules.isoCodeFromString(v.countryIso2),
          nsn: v.nationalNumber,
        ),
        ambiguousMessage: null,
      );
    }

    return (
      phoneNumber: PhoneNumber(
        isoCode: InternationalPhoneRules.isoCodeFromString(isoHint),
        nsn: '',
      ),
      ambiguousMessage:
          widget.ambiguousHintText ??
          InternationalPhoneValidationResult.ambiguousMessage,
    );
  }

  void _applyExternalSeed({required bool emit}) {
    if (_disposed || !mounted) return;
    final seed = _resolveSeed(
      phone: widget.initialPhone,
      countryIso2: widget.initialCountryIso2,
    );
    _applyingExternalValue = true;
    try {
      _controller.value = seed.phoneNumber;
      if (_ambiguousBanner != seed.ambiguousMessage) {
        setState(() => _ambiguousBanner = seed.ambiguousMessage);
      }
    } finally {
      _applyingExternalValue = false;
    }
    if (emit && !_disposed && mounted) {
      _emitFromController();
    }
  }

  InternationalPhoneValidationResult _validatePhoneNumber(PhoneNumber? number) {
    if (number == null || number.nsn.trim().isEmpty) {
      return InternationalPhoneValidationResult.invalid(
        code: InternationalPhoneValidationCode.empty,
        message: InternationalPhoneValidationResult.emptyMessage,
      );
    }

    return InternationalPhoneRules.validateInput(
      rawInput: number.nsn.trim(),
      countryIso2: number.isoCode.name,
    );
  }

  /// Se l’incolla produce un E.164 valido, allinea Paese + NSN (niente doppio prefisso).
  bool _tryNormalizeInternationalPaste(PhoneNumber number) {
    final raw = number.nsn.trim();
    final looksInternational =
        raw.startsWith('+') || RegExp(r'^00[1-9]').hasMatch(raw);
    if (!looksInternational) return false;

    final result = InternationalPhoneRules.validateInput(
      rawInput: raw,
      countryIso2: number.isoCode.name,
    );
    if (!result.isValid || result.value == null) return false;

    final v = result.value!;
    final next = PhoneNumber(
      isoCode: InternationalPhoneRules.isoCodeFromString(v.countryIso2),
      nsn: v.nationalNumber,
    );
    if (number.isoCode == next.isoCode && number.nsn == next.nsn) {
      return false;
    }

    _applyingExternalValue = true;
    try {
      _controller.value = next;
    } finally {
      _applyingExternalValue = false;
    }
    return true;
  }

  void _emitFromController() {
    if (_disposed) return;
    final number = _controller.value;
    if (!widget.requiredField && number.nsn.trim().isEmpty) {
      widget.onChanged?.call(
        InternationalPhoneValidationResult.invalid(
          code: InternationalPhoneValidationCode.empty,
          message: '',
        ),
      );
      widget.onValidChanged?.call(null);
      return;
    }
    final result = _validatePhoneNumber(number);
    widget.onChanged?.call(result);
    widget.onValidChanged?.call(result.isValid ? result.value : null);
  }

  String? _formValidator(PhoneNumber? number) {
    if (!widget.requiredField &&
        (number == null || number.nsn.trim().isEmpty)) {
      return null;
    }
    final result = _validatePhoneNumber(number);
    if (result.isValid) return null;
    return result.message;
  }

  void _onPhoneChanged(PhoneNumber number) {
    if (_applyingExternalValue || _disposed) return;
    if (_ambiguousBanner != null && number.nsn.trim().isNotEmpty) {
      setState(() => _ambiguousBanner = null);
    }
    if (_tryNormalizeInternationalPaste(number)) {
      if (!_disposed && mounted) _emitFromController();
      return;
    }
    _emitFromController();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showAmbiguous =
        widget.showAmbiguousHint &&
        _ambiguousBanner != null &&
        _ambiguousBanner!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAmbiguous) ...[
          Semantics(
            liveRegion: true,
            child: Container(
              key: const ValueKey('international-phone-ambiguous-hint'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppVisual.chipFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Text(
                _ambiguousBanner!,
                style: textTheme.bodySmall?.copyWith(
                  color: AppVisual.ink,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        PhoneFormField(
          key: const ValueKey('international-phone-field'),
          controller: _controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autovalidateMode: widget.autovalidateMode,
          countrySelectorNavigator:
              const CountrySelectorNavigator.draggableBottomSheet(
                favorites: [IsoCode.IT, IsoCode.FR, IsoCode.DE, IsoCode.US],
              ),
          isCountrySelectionEnabled: widget.enabled,
          isCountryButtonPersistent: true,
          countryButtonStyle: CountryButtonStyle(
            showFlag: true,
            showDialCode: true,
            showDropdownIcon: true,
            showIsoCode: false,
            flagSize: 22,
            textStyle: textTheme.bodyMedium?.copyWith(
              color: AppVisual.ink,
              fontWeight: FontWeight.w700,
            ),
            padding: const EdgeInsets.only(left: 4, right: 8),
          ),
          style: textTheme.bodyLarge?.copyWith(
            color: AppVisual.ink,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            labelText: widget.decorationLabel,
            filled: true,
            fillColor: _fill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppVisual.logoBlue,
                width: 1.6,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppVisual.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppVisual.error, width: 1.6),
            ),
            labelStyle: textTheme.bodyMedium?.copyWith(
              color: AppVisual.inkMuted,
            ),
          ),
          keyboardType: TextInputType.phone,
          validator: _formValidator,
          onChanged: _onPhoneChanged,
        ),
      ],
    );
  }
}
