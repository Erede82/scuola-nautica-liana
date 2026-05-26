import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/branded_app_bar_title.dart';

/// Mock UI: in futuro la scansione QR collega l'app al PC. Nessun token reale.
void showAccediDaPcBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return const _AccediDaPcBottomSheetShell();
    },
  );
}

/// Palette brand: beige protagonista, inchiostro su chiaro, blu/azzurro come accenti.
class _AccediPalette {
  /// Sfondo guida del popup (dominante).
  static const Color warmBeige = Color(0xFFC7B299);
  /// Variazioni beige molto vicine — solo profondità, senza freddo.
  static const Color beigeHighlight = Color(0xFFD2C4B0);
  static const Color beigeDepth = Color(0xFFC5B396);
  /// Blu logo (stessa famiglia dell’app bar pagina intera).
  static const Color logoBlue = Color(0xFF005E83);
  static const Color logoBlueDeep = Color(0xFF004A66);
  static const Color brandAzure = Color(0xFF17A1C8);
  static const Color accentLight = Color(0xFF6FD6E8);
  /// Testo principale su beige — alto contrasto.
  static const Color ink = Color(0xFF0A0A0A);
  static const Color ivory = Color(0xFFF7F3ED);
}

/// Schermata intera opzionale (test / link diretti).
class AccediDaPcPage extends StatelessWidget {
  const AccediDaPcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AccediPalette.warmBeige,
      appBar: AppBar(
        backgroundColor: _AccediPalette.logoBlue,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const SectionAppBarTitle('Usa QR code', logoHeight: 30),
        shape: const RoundedRectangleBorder(),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 640;
          final pad = EdgeInsets.fromLTRB(
            wide ? 32 : 18,
            18,
            wide ? 32 : 18,
            24 + MediaQuery.paddingOf(context).bottom,
          );
          if (wide && c.maxHeight > 520) {
            return SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Padding(
                  padding: pad,
                  child: const _AccediDaPcPremiumBody(compactSteps: true),
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: pad,
            child: const _AccediDaPcPremiumBody(compactSteps: false),
          );
        },
      ),
    );
  }
}

class _AccediDaPcBottomSheetShell extends StatelessWidget {
  const _AccediDaPcBottomSheetShell();

  static const double _kWideBreakpoint = 640;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final wide = mq.width >= _kWideBreakpoint;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _AccediPalette.beigeHighlight,
              _AccediPalette.warmBeige,
              _AccediPalette.beigeDepth,
            ],
            stops: [0.0, 0.48, 1.0],
          ),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: wide ? 0.86 : 0.78,
          minChildSize: wide ? 0.42 : 0.38,
          maxChildSize: wide ? 0.94 : 0.92,
          builder: (context, scrollController) {
            return LayoutBuilder(
              builder: (context, box) {
                final canFitNoScroll = wide && box.maxHeight >= 560;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    _SheetDragHandle(),
                    const SizedBox(height: 6),
                    Expanded(
                      child: canFitNoScroll
                          ? SingleChildScrollView(
                              controller: scrollController,
                              physics: const NeverScrollableScrollPhysics(),
                              child: ConstrainedBox(
                                constraints:
                                    BoxConstraints(minHeight: box.maxHeight),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 28 : 18,
                                    4,
                                    wide ? 28 : 18,
                                    16 + MediaQuery.paddingOf(context).bottom,
                                  ),
                                  child: const _AccediDaPcPremiumBody(
                                    embeddedInSheet: true,
                                    compactSteps: true,
                                  ),
                                ),
                              ),
                            )
                          : ListView(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                18,
                                4,
                                18,
                                16 + MediaQuery.paddingOf(context).bottom,
                              ),
                              children: const [
                                _AccediDaPcPremiumBody(
                                  embeddedInSheet: true,
                                  compactSteps: false,
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: _AccediPalette.ink.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _AccediDaPcPremiumBody extends StatelessWidget {
  const _AccediDaPcPremiumBody({
    this.embeddedInSheet = false,
    this.compactSteps = false,
  });

  final bool embeddedInSheet;
  final bool compactSteps;

  static const List<String> _steps = [
    'Apri il sito o il programma sulla tua postazione PC.',
    'Seleziona l\'opzione "Accedi con app" o "Mostra codice QR".',
    'Torna qui e inquadra il codice quando sarà attivo (anteprima sotto).',
    'Conferma sulla schermata del PC se richiesto.',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          embeddedInSheet ? 'Usa QR code' : 'Collega l\'app al computer',
          style: textTheme.titleLarge?.copyWith(
            color: _AccediPalette.ink,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
            height: 1.15,
            fontSize: embeddedInSheet ? 24 : null,
          ),
        ),
        SizedBox(height: compactSteps ? 9 : 10),
        Text(
          embeddedInSheet
              ? 'Funzione in arrivo: allinea l’app al PC per quiz e schede più rapidi. Nessun accesso reale da questa anteprima.'
              : 'Usa il codice QR per accedere dalla postazione in aula o da casa, senza digitare ogni volta le credenziali.',
          style: textTheme.bodySmall?.copyWith(
            color: _AccediPalette.ink.withValues(alpha: 0.92),
            height: compactSteps ? 1.4 : 1.48,
            fontSize: compactSteps ? 13.5 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: compactSteps ? 16 : 20),
        _QrPreviewCard(
          boxSize: compactSteps
              ? math.min(252.0, w - (embeddedInSheet ? 56 : 36))
              : math.min(264.0, w - 40),
          textTheme: textTheme,
        ),
        SizedBox(height: compactSteps ? 14 : 18),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: _AccediPalette.logoBlue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Anteprima tecnica — dati non trasmessi',
                style: textTheme.labelSmall?.copyWith(
                  color: _AccediPalette.ink.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.12,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compactSteps ? 16 : 20),
        Text(
          'Come funzionerà',
          style: textTheme.titleSmall?.copyWith(
            color: _AccediPalette.ink,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.28,
            fontSize: compactSteps ? 15 : 15.5,
          ),
        ),
        SizedBox(height: compactSteps ? 10 : 13),
        ...List.generate(_steps.length, (i) {
          final last = i == _steps.length - 1;
          return Padding(
            padding: EdgeInsets.only(
              bottom: last
                  ? 0
                  : (compactSteps ? 10 : 13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: compactSteps ? 30 : 32,
                  height: compactSteps ? 30 : 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: _AccediPalette.brandAzure.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _AccediPalette.ink.withValues(alpha: 0.07),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '${i + 1}',
                    style: textTheme.labelLarge?.copyWith(
                      color: _AccediPalette.logoBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: compactSteps ? 13 : 14,
                      height: 1,
                    ),
                  ),
                ),
                SizedBox(width: compactSteps ? 13 : 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _steps[i],
                      style: textTheme.bodySmall?.copyWith(
                        color: _AccediPalette.ink.withValues(alpha: 0.91),
                        height: compactSteps ? 1.42 : 1.46,
                        fontSize: compactSteps ? 13.5 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _QrPreviewCard extends StatelessWidget {
  const _QrPreviewCard({
    required this.boxSize,
    required this.textTheme,
  });

  final double boxSize;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _AccediPalette.ivory,
        border: Border.all(
          color: _AccediPalette.logoBlue.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _AccediPalette.ink.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: _AccediPalette.brandAzure.withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: boxSize,
            height: boxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _AccediPalette.logoBlue,
                  _AccediPalette.logoBlueDeep,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _AccediPalette.logoBlue.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: boxSize * 0.34,
                  color: _AccediPalette.accentLight,
                ),
                const SizedBox(height: 14),
                Text(
                  'Area QR',
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'Il codice comparirà quando il servizio sarà attivo',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.38,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
