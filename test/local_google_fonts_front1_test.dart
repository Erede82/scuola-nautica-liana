import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  final root = Directory.current;

  const requiredTtfs = <String>[
    'Montserrat-Regular.ttf',
    'Montserrat-Medium.ttf',
    'Montserrat-SemiBold.ttf',
    'Montserrat-Bold.ttf',
    'Montserrat-ExtraBold.ttf',
    'Montserrat-Black.ttf',
    'Ovo-Regular.ttf',
  ];

  bool isFontMagic(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // TrueType / OpenType / 'true'
    return (bytes[0] == 0x00 &&
            bytes[1] == 0x01 &&
            bytes[2] == 0x00 &&
            bytes[3] == 0x00) ||
        (bytes[0] == 0x4F &&
            bytes[1] == 0x54 &&
            bytes[2] == 0x54 &&
            bytes[3] == 0x4F) ||
        (bytes[0] == 0x74 &&
            bytes[1] == 0x72 &&
            bytes[2] == 0x75 &&
            bytes[3] == 0x65);
  }

  test('FRONT.1 — Montserrat/Ovo TTF locali presenti (API filename)', () {
    for (final name in requiredTtfs) {
      final file = File('${root.path}/google_fonts/$name');
      expect(file.existsSync(), isTrue, reason: name);
      expect(file.lengthSync(), greaterThan(1000), reason: '$name size');
      final raf = file.openSync();
      final magic = raf.readSync(4);
      raf.closeSync();
      expect(isFontMagic(magic), isTrue, reason: '$name magic');
    }
    expect(
      File('${root.path}/google_fonts/OFL-Montserrat.txt').existsSync(),
      isTrue,
    );
    expect(File('${root.path}/google_fonts/OFL-Ovo.txt').existsSync(), isTrue);
  });

  test('FRONT.1 — pubspec espone google_fonts/ e main disabilita fetch', () {
    final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- google_fonts/'));

    final mainSrc = File('${root.path}/lib/main.dart').readAsStringSync();
    expect(
      mainSrc,
      contains('GoogleFonts.config.allowRuntimeFetching = false'),
    );
  });

  testWidgets(
    'FRONT.1 — GoogleFonts Montserrat/Ovo risolvono da asset (fetch off)',
    (tester) async {
      final previous = GoogleFonts.config.allowRuntimeFetching;
      addTearDown(() {
        GoogleFonts.config.allowRuntimeFetching = previous;
      });
      GoogleFonts.config.allowRuntimeFetching = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            textTheme: TextTheme(
              titleLarge: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
              bodyMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w500),
              displayLarge: GoogleFonts.ovo(),
            ),
          ),
          home: Builder(
            builder: (context) {
              final theme = Theme.of(context).textTheme;
              return Scaffold(
                body: Column(
                  children: [
                    Text('Montserrat', style: theme.titleLarge),
                    Text('Body', style: theme.bodyMedium),
                    Text('Ovo', style: theme.displayLarge),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Montserrat'), findsOneWidget);
      expect(find.text('Ovo'), findsOneWidget);
    },
  );
}
