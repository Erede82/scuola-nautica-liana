import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_form_field/phone_form_field.dart';
import 'package:scuola_nautica_liana/domain/international_phone.dart';
import 'package:scuola_nautica_liana/widgets/international_phone_field.dart';

Widget _wrap(Widget child, {Size size = const Size(390, 844)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      locale: const Locale('it', 'IT'),
      supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        ...InternationalPhoneField.localizationsDelegates,
      ],
      home: Scaffold(
        body: Form(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
}

Future<void> _enterNsn(WidgetTester tester, String digits) async {
  final field = find.byType(PhoneFormField);
  expect(field, findsOneWidget);
  await tester.enterText(field, digits);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('default Italia e callback E.164', (tester) async {
    InternationalPhoneValue? valid;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(InternationalPhoneField(onValidChanged: (v) => valid = v)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PhoneFormField), findsOneWidget);
    expect(find.byType(InternationalPhoneField), findsOneWidget);

    // Default country IT: country button semantics include dial code.
    expect(find.byType(CountryButton), findsOneWidget);

    await _enterNsn(tester, '3331234567');
    expect(valid?.e164, '+393331234567');
    expect(valid?.countryIso2, 'IT');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Italia 9 cifre e fisso → errore; 11ª cifra bloccata', (
    tester,
  ) async {
    InternationalPhoneValue? valid;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(InternationalPhoneField(onValidChanged: (v) => valid = v)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CountryButton), findsOneWidget);
    expect(find.textContaining('39'), findsWidgets);
    expect(
      find.byKey(const ValueKey('international-phone-digit-counter')),
      findsOneWidget,
    );

    await _enterNsn(tester, '331123456');
    expect(valid, isNull);
    expect(
      find.text(InternationalPhoneValidationResult.italyMessage),
      findsOneWidget,
    );

    // 11 cifre: formatter trattiene solo 10 → numero valido.
    await _enterNsn(tester, '33312345678');
    final nsn = tester
        .widget<PhoneFormField>(find.byType(PhoneFormField))
        .controller!
        .value
        .nsn
        .replaceAll(RegExp(r'\D'), '');
    expect(nsn.length, 10);
    expect(nsn, '3331234567');
    expect(valid?.e164, '+393331234567');
    expect(find.text('10/10'), findsOneWidget);

    await _enterNsn(tester, '0811234567');
    expect(valid, isNull);
    expect(
      find.text(InternationalPhoneValidationResult.italyMessage),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Italia: paste troppo lungo limitato a 10 cifre nazionali', (
    tester,
  ) async {
    InternationalPhoneValue? valid;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(InternationalPhoneField(onValidChanged: (v) => valid = v)),
    );
    await tester.pumpAndSettle();

    await _enterNsn(tester, '333123456789999');
    final nsn = tester
        .widget<PhoneFormField>(find.byType(PhoneFormField))
        .controller!
        .value
        .nsn
        .replaceAll(RegExp(r'\D'), '');
    expect(nsn.length, 10);
    expect(nsn, '3331234567');
    expect(valid?.e164, '+393331234567');
    expect(tester.takeException(), isNull);
  });

  testWidgets('FR: limite nazionale 9 cifre e E.164', (tester) async {
    InternationalPhoneValue? valid;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(
        InternationalPhoneField(
          initialPhone: '+33612345678',
          onValidChanged: (v) => valid = v,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(valid?.countryIso2, 'FR');
    expect(valid?.e164, '+33612345678');
    expect(InternationalPhoneRules.maxNationalDigits('FR'), 9);
    expect(find.textContaining('9'), findsWidgets);

    await _enterNsn(tester, '6123456789'); // 10 → clamp a 9
    final nsn = tester
        .widget<PhoneFormField>(find.byType(PhoneFormField))
        .controller!
        .value
        .nsn
        .replaceAll(RegExp(r'\D'), '');
    expect(nsn.length, lessThanOrEqualTo(9));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambio Paese IT → FR rivalida e limita', (tester) async {
    InternationalPhoneValue? valid;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(
        _PhoneSeedHost(
          initialPhone: '+393331234567',
          onValidChanged: (v) => valid = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(valid?.countryIso2, 'IT');

    final host = tester.state<_PhoneSeedHostState>(find.byType(_PhoneSeedHost));
    host.updateSeed('+33612345678');
    await tester.pumpAndSettle();
    expect(valid?.countryIso2, 'FR');
    expect(valid?.e164, '+33612345678');
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial E.164 popola il campo', (tester) async {
    InternationalPhoneValue? valid;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(
        InternationalPhoneField(
          initialPhone: '+393331234567',
          onValidChanged: (v) => valid = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(valid?.e164, '+393331234567');
    expect(valid?.nationalNumber, '3331234567');
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial nazionale IT popola il campo', (tester) async {
    InternationalPhoneValue? valid;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(
        InternationalPhoneField(
          initialPhone: '3200000001',
          onValidChanged: (v) => valid = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(valid?.e164, '+393200000001');
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial ambiguo mostra hint', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(
        const InternationalPhoneField(
          initialPhone: '12-ABC',
          showAmbiguousHint: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('international-phone-ambiguous-hint')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('responsive senza overflow', (tester) async {
    for (final size in const [
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
      Size(768, 1024),
      Size(1366, 768),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _wrap(const InternationalPhoneField(), size: size),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PhoneFormField), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('didUpdateWidget: valido → valido', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    InternationalPhoneValue? valid;
    await tester.pumpWidget(
      _wrap(
        _PhoneSeedHost(
          initialPhone: '+393331234567',
          onValidChanged: (v) => valid = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(valid?.e164, '+393331234567');
    expect(valid?.countryIso2, 'IT');

    final host = tester.state<_PhoneSeedHostState>(find.byType(_PhoneSeedHost));
    host.updateSeed('+393887654321');
    await tester.pumpAndSettle();

    expect(valid?.e164, '+393887654321');
    expect(valid?.countryIso2, 'IT');
    expect(valid?.nationalNumber, '3887654321');
    expect(tester.takeException(), isNull);
  });

  testWidgets('didUpdateWidget: null → valido (FR)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    InternationalPhoneValue? valid;
    await tester.pumpWidget(
      _wrap(_PhoneSeedHost(onValidChanged: (v) => valid = v)),
    );
    await tester.pumpAndSettle();
    expect(valid, isNull);

    final host = tester.state<_PhoneSeedHostState>(find.byType(_PhoneSeedHost));
    host.updateSeed('+33612345678');
    await tester.pumpAndSettle();

    expect(valid?.e164, '+33612345678');
    expect(valid?.countryIso2, 'FR');
    expect(valid?.nationalNumber, isNot(contains('39')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('didUpdateWidget: valido → null', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    InternationalPhoneValue? valid = const InternationalPhoneValue(
      countryIso2: 'IT',
      countryCallingCode: '39',
      nationalNumber: '3331234567',
      e164: '+393331234567',
      displayInternational: '+39 333 123 4567',
    );
    await tester.pumpWidget(
      _wrap(
        _PhoneSeedHost(
          initialPhone: '+393331234567',
          onValidChanged: (v) => valid = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(valid?.e164, '+393331234567');

    final host = tester.state<_PhoneSeedHostState>(find.byType(_PhoneSeedHost));
    host.updateSeed(null);
    await tester.pumpAndSettle();

    expect(valid, isNull);
    final field = tester.widget<PhoneFormField>(find.byType(PhoneFormField));
    expect(field.controller!.value.isoCode, IsoCode.IT);
    expect(field.controller!.value.nsn, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('didUpdateWidget: ambiguo → valido', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    InternationalPhoneValue? valid;
    await tester.pumpWidget(
      _wrap(
        _PhoneSeedHost(
          initialPhone: '0811234567',
          showAmbiguousHint: true,
          onValidChanged: (v) => valid = v,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('international-phone-ambiguous-hint')),
      findsOneWidget,
    );
    expect(valid, isNull);

    final host = tester.state<_PhoneSeedHostState>(find.byType(_PhoneSeedHost));
    host.updateSeed('+393331234567', showAmbiguousHint: true);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('international-phone-ambiguous-hint')),
      findsNothing,
    );
    expect(valid?.e164, '+393331234567');
    expect(tester.takeException(), isNull);
  });

  testWidgets('didUpdateWidget: valido → ambiguo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    InternationalPhoneValue? valid;
    InternationalPhoneValidationResult? last;
    await tester.pumpWidget(
      _wrap(
        _PhoneSeedHost(
          initialPhone: '+393331234567',
          onValidChanged: (v) => valid = v,
          onChanged: (r) => last = r,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(valid?.e164, '+393331234567');

    final host = tester.state<_PhoneSeedHostState>(find.byType(_PhoneSeedHost));
    host.updateSeed('0811234567', showAmbiguousHint: true);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('international-phone-ambiguous-hint')),
      findsOneWidget,
    );
    expect(find.textContaining('0811234567'), findsNothing);
    expect(
      find.textContaining(
        InternationalPhoneValidationResult.ambiguousMessage.substring(0, 24),
      ),
      findsOneWidget,
    );
    expect(valid, isNull);
    expect(last?.isValid, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incolla +39 normalizza senza doppio prefisso', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    InternationalPhoneValue? valid;
    await tester.pumpWidget(
      _wrap(InternationalPhoneField(onValidChanged: (v) => valid = v)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(PhoneFormField), '+393331234567');
    await tester.pumpAndSettle();

    expect(valid?.countryIso2, 'IT');
    expect(valid?.nationalNumber, '3331234567');
    expect(valid?.e164, '+393331234567');
    expect(valid?.nationalNumber, isNot(startsWith('39')));
    expect(valid?.e164, isNot(contains('+39+39')));
    expect(valid?.e164, isNot('+39393331234567'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('incolla 0039 normalizza senza doppio prefisso', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    InternationalPhoneValue? valid;
    await tester.pumpWidget(
      _wrap(InternationalPhoneField(onValidChanged: (v) => valid = v)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(PhoneFormField), '00393331234567');
    await tester.pumpAndSettle();

    expect(valid?.countryIso2, 'IT');
    expect(valid?.nationalNumber, '3331234567');
    expect(valid?.e164, '+393331234567');
    expect(valid?.nationalNumber, isNot('393331234567'));
    expect(tester.takeException(), isNull);
  });
}

class _PhoneSeedHost extends StatefulWidget {
  const _PhoneSeedHost({
    this.initialPhone,
    this.showAmbiguousHint = false,
    this.onValidChanged,
    this.onChanged,
  });

  final String? initialPhone;
  final bool showAmbiguousHint;
  final ValueChanged<InternationalPhoneValue?>? onValidChanged;
  final ValueChanged<InternationalPhoneValidationResult>? onChanged;

  @override
  State<_PhoneSeedHost> createState() => _PhoneSeedHostState();
}

class _PhoneSeedHostState extends State<_PhoneSeedHost> {
  late String? _phone = widget.initialPhone;
  late bool _showAmbiguous = widget.showAmbiguousHint;

  void updateSeed(String? phone, {bool? showAmbiguousHint}) {
    setState(() {
      _phone = phone;
      if (showAmbiguousHint != null) _showAmbiguous = showAmbiguousHint;
    });
  }

  @override
  Widget build(BuildContext context) {
    return InternationalPhoneField(
      initialPhone: _phone,
      showAmbiguousHint: _showAmbiguous,
      onValidChanged: widget.onValidChanged,
      onChanged: widget.onChanged,
    );
  }
}
