import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.decorationLabel = 'Numero nazionale',
    this.showAmbiguousHint = false,
    this.ambiguousHintText,
    this.focusNode,
    this.showDigitCounter = true,
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

  /// Contatore discreto `7/10`. Su layout molto stretti può essere nascosto.
  final bool showDigitCounter;

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
  late int _maxDigits;
  int _digitCount = 0;

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
    _maxDigits = InternationalPhoneRules.maxNationalDigits(
      seed.phoneNumber.isoCode.name,
    );
    _digitCount = _digitsOf(seed.phoneNumber.nsn).length;
    _controller.addListener(_onControllerTick);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) return;
      _applyExternalSeed(emit: true);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(_onControllerTick);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerTick() {
    if (_disposed || !mounted) return;
    final iso = _controller.value.isoCode.name;
    final max = InternationalPhoneRules.maxNationalDigits(iso);
    final digits = _digitsOf(_controller.value.nsn);
    if (max != _maxDigits || digits.length != _digitCount) {
      setState(() {
        _maxDigits = max;
        _digitCount = digits.length;
      });
    }
  }

  static String _digitsOf(String raw) => raw.replaceAll(RegExp(r'\D'), '');

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

  /// Dopo cambio Paese, azzera l'NSN se supera il nuovo limite.
  ///
  /// Non tronca: un prefisso di un numero lungo può essere un altro cellulare
  /// valido e verrebbe salvato silenziosamente (es. `393331234567` → IT).
  bool _clearNsnIfOverCountryLimit(PhoneNumber number) {
    final iso = number.isoCode.name;
    final currentDigits = _digitsOf(number.nsn);
    final max = InternationalPhoneRules.maxNationalDigits(iso);
    if (currentDigits.length <= max) return false;

    _applyingExternalValue = true;
    try {
      _controller.value = PhoneNumber(isoCode: number.isoCode, nsn: '');
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
    if (_clearNsnIfOverCountryLimit(number)) {
      if (!_disposed && mounted) _emitFromController();
      return;
    }
    _emitFromController();
  }

  List<TextInputFormatter> _inputFormattersFor(IsoCode iso) {
    final max = InternationalPhoneRules.maxNationalDigits(iso.name);
    return [
      _PhoneNationalLimitFormatter(maxDigits: max),
      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s().-]')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final showAmbiguous =
        widget.showAmbiguousHint &&
        _ambiguousBanner != null &&
        _ambiguousBanner!.isNotEmpty;
    final showCounter = widget.showDigitCounter;

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
          shouldLimitLengthByCountry: false,
          inputFormatters: _inputFormattersFor(_controller.value.isoCode),
          countrySelectorNavigator:
              const CountrySelectorNavigator.draggableBottomSheet(
                favorites: [
                  IsoCode.IT,
                  IsoCode.FR,
                  IsoCode.DE,
                  IsoCode.GB,
                  IsoCode.US,
                ],
              ),
          isCountrySelectionEnabled: widget.enabled,
          isCountryButtonPersistent: true,
          countryButtonStyle: CountryButtonStyle(
            showFlag: true,
            showDialCode: true,
            showDropdownIcon: true,
            showIsoCode: false,
            flagSize: 24,
            textStyle: textTheme.bodyMedium?.copyWith(
              color: AppVisual.ink,
              fontWeight: FontWeight.w800,
            ),
            padding: const EdgeInsets.only(left: 6, right: 10),
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
        if (showCounter) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_digitCount/$_maxDigits',
              key: const ValueKey('international-phone-digit-counter'),
              style: textTheme.labelSmall?.copyWith(
                color: AppVisual.inkMuted.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Limita le cifre nazionali rifiutando l'overflow (niente troncamento).
///
/// Consente temporaneamente paste `+…` / `00…` fino a 15 cifre E.164.
/// Troncare un NSN troppo lungo può produrre un altro cellulare valido
/// (es. `393331234567` → `3933312345`) e corrompere il contatto in salvataggio.
class _PhoneNationalLimitFormatter extends TextInputFormatter {
  _PhoneNationalLimitFormatter({required this.maxDigits});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final trimmed = raw.trimLeft();
    final looksInternational =
        trimmed.startsWith('+') || RegExp(r'^00[1-9]').hasMatch(trimmed);
    final digits = raw.replaceAll(RegExp(r'\D'), '');

    if (looksInternational) {
      // E.164 max 15 cifre (senza +): rifiuta oltre, non troncare.
      if (digits.length <= 15) return newValue;
      return oldValue;
    }

    if (digits.length <= maxDigits) return newValue;
    return oldValue;
  }
}
