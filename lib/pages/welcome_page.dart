import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constants/app_branding.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/school_contact_launcher.dart';

/// Welcome a blocchi: [WelcomePage] espone già [GlobalKey] per hero / scoprici / percorso
/// e un [ScrollController] — in un secondo step si possono collegare a visibility + reveal.

class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    this.onLoginTap,
    this.onRegisterTap,
    this.onForgotPasswordTap,
  });

  final VoidCallback? onLoginTap;
  final VoidCallback? onRegisterTap;
  final VoidCallback? onForgotPasswordTap;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final ScrollController _scrollController = ScrollController();

  /// Anchor per scroll/reveal: hero, blocco “Scoprici”, percorso.
  final GlobalKey _heroSectionKey = GlobalKey();
  final GlobalKey _discoverKey = GlobalKey();

  /// Puntamento scroll “SCOPRICI”: allinea il titolo in cima al viewport.
  final GlobalKey _discoverTitleKey = GlobalKey();
  final GlobalKey _journeySectionKey = GlobalKey();

  bool _heroVisible = false;
  bool _discoverVisible = false;
  bool _journeyVisible = false;
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleScroll();
    });
  }

  void _handleScroll() {
    final hv = _visibilityForKey(_heroSectionKey);
    final dv = _visibilityForKey(_discoverKey);
    final jv = _visibilityForKey(_journeySectionKey);

    final nh = hv ?? _heroVisible;
    final nd = dv ?? _discoverVisible;
    final nj = jv ?? _journeyVisible;

    final showTop =
        _scrollController.hasClients && _scrollController.offset > 280;

    if (nh != _heroVisible ||
        nd != _discoverVisible ||
        nj != _journeyVisible ||
        showTop != _showBackToTop) {
      setState(() {
        _heroVisible = nh;
        _discoverVisible = nd;
        _journeyVisible = nj;
        _showBackToTop = showTop;
      });
    }
  }

  /// `null` se il render object non è ancora pronto (non sovrascrivere lo stato).
  bool? _visibilityForKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;

    final visible =
        position.dy < screenHeight * 0.82 &&
        (position.dy + renderBox.size.height) > screenHeight * 0.10;

    return visible;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollToDiscover() async {
    if (!mounted) return;

    // La sezione deve essere già “svelata” (niente AnimatedSlide spostato) prima dello scroll.
    setState(() => _discoverVisible = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final targetContext =
        _discoverTitleKey.currentContext ?? _discoverKey.currentContext;
    if (targetContext == null || !targetContext.mounted) return;
    if (!_scrollController.hasClients) return;

    final viewH = MediaQuery.sizeOf(context).height;
    // Stessi parametri di prima, ma arriviamo al punto finale in una sola animazione (niente “doppio passaggio”).
    final alignment = viewH >= 800
        ? 0.035
        : viewH >= 640
        ? 0.028
        : 0.022;
    final nudgeUp = viewH >= 800
        ? 56.0
        : viewH >= 640
        ? 44.0
        : 36.0;

    final renderObject = targetContext.findRenderObject();
    if (renderObject == null) return;

    final viewport = RenderAbstractViewport.of(renderObject);
    final position = _scrollController.position;
    final revealed = viewport.getOffsetToReveal(renderObject, alignment);
    final destination = (revealed.offset - nudgeUp).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await position.animateTo(
      destination,
      duration: const Duration(milliseconds: 780),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleAction(
    BuildContext context,
    VoidCallback? callback,
    String fallbackRoute,
  ) {
    if (callback != null) {
      callback();
      return;
    }

    Navigator.maybeOf(context)?.pushNamed(fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      // Stesso blu del footer: in app, il bounce iOS oltre la fine pagina non mostra una “striscia” bianca.
      backgroundColor: const Color(0xFF123A5A),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            // Niente effetto elastico oltre il contenuto: si ferma sul footer senza rivelare bianco sotto.
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                KeyedSubtree(
                  key: _heroSectionKey,
                  child: _RevealOnScroll(
                    visible: _heroVisible,
                    offsetY: 18,
                    child: _HeroSection(
                      onDiscoverTap: _scrollToDiscover,
                      onLoginTap: () =>
                          _handleAction(context, widget.onLoginTap, '/login'),
                      onRegisterTap: () => _handleAction(
                        context,
                        widget.onRegisterTap,
                        '/register',
                      ),
                      onForgotPasswordTap: () => _handleAction(
                        context,
                        widget.onForgotPasswordTap,
                        '/forgot-password',
                      ),
                    ),
                  ),
                ),
                _RevealOnScroll(
                  visible: _discoverVisible,
                  offsetY: 0,
                  child: _SplitDiscoverSection(
                    key: _discoverKey,
                    titleAnchorKey: _discoverTitleKey,
                    cardsRevealVisible: _discoverVisible,
                  ),
                ),
                KeyedSubtree(
                  key: _journeySectionKey,
                  child: _RevealOnScroll(
                    visible: _journeyVisible,
                    offsetY: 0,
                    child: const _JourneySection(),
                  ),
                ),
                const _FooterSection(),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 18 + bottomSafe,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              offset: _showBackToTop ? Offset.zero : const Offset(0, 1.2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: _showBackToTop ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !_showBackToTop,
                  child: Material(
                    color: AppVisual.logoBlue,
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: _scrollToTop,
                      borderRadius: BorderRadius.circular(14),
                      child: Semantics(
                        button: true,
                        label: 'Torna in cima alla pagina',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          child: Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: Colors.white.withValues(alpha: 0.96),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onDiscoverTap,
    required this.onLoginTap,
    required this.onRegisterTap,
    required this.onForgotPasswordTap,
  });

  final VoidCallback onDiscoverTap;
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;
  final VoidCallback onForgotPasswordTap;

  static const Color _ctaBlue = Color(0xFF1B5583);

  static bool _ctaActive(Set<WidgetState> states) {
    return states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused) ||
        states.contains(WidgetState.pressed);
  }

  /// Accedi / Registrati: outline chiaro a riposo, pieno su hover / focus / pressed.
  static ButtonStyle _heroMainCtaStyle() {
    return ButtonStyle(
      elevation: WidgetStateProperty.all(0),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return _ctaActive(states) ? Colors.white : Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return _ctaActive(states) ? _ctaBlue : Colors.white;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final active = _ctaActive(states);
        return BorderSide(
          color: Colors.white.withValues(alpha: active ? 0.92 : 0.50),
          width: active ? 1.35 : 1.2,
        );
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return Colors.white.withValues(alpha: 0.10);
        }
        return Colors.transparent;
      }),
    );
  }

  /// Stesso linguaggio di Accedi/Registrati (angoli 18), leggermente più compatto.
  static ButtonStyle _heroDiscoverStyle() {
    return ButtonStyle(
      elevation: WidgetStateProperty.all(0),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
      minimumSize: WidgetStateProperty.all(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.05,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return _ctaActive(states) ? Colors.white : Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return _ctaActive(states) ? _ctaBlue : Colors.white;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        final active = _ctaActive(states);
        return BorderSide(
          color: Colors.white.withValues(alpha: active ? 0.92 : 0.50),
          width: active ? 1.35 : 1.2,
        );
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withValues(alpha: 0.14);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return Colors.white.withValues(alpha: 0.10);
        }
        return Colors.transparent;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bool isCompact = size.width < 900;
    final bool cramped = isCompact && size.height < 720;
    // Su mobile la hero occupa tutta l’altezza finestra così non resta fascia bianca sotto.
    final double heroHeight = isCompact
        ? size.height
        : (size.height < 760 ? 760 : size.height * 0.96);

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Sfondo: in futuro sostituibile con video (stesso Stack + overlay).
          Image.asset(
            AppBranding.welcomeBoatJpg,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F3553),
                      Color(0xFF1B5583),
                      Color(0xFF46BED0),
                    ],
                  ),
                ),
              );
            },
          ),
          // Overlay “vedo non vedo”: scuro e uniforme, l’immagine resta appena percettibile.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.65, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.72),
                  Colors.black.withValues(alpha: 0.62),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.48),
                ],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, viewport) {
                return _HeroSection._heroForeground(
                  viewportConstraints: viewport,
                  isCompact: isCompact,
                  cramped: cramped,
                  onLoginTap: onLoginTap,
                  onRegisterTap: onRegisterTap,
                  onForgotPasswordTap: onForgotPasswordTap,
                  onDiscoverTap: onDiscoverTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _heroForeground({
    required BoxConstraints viewportConstraints,
    required bool isCompact,
    required bool cramped,
    required VoidCallback onLoginTap,
    required VoidCallback onRegisterTap,
    required VoidCallback onForgotPasswordTap,
    required VoidCallback onDiscoverTap,
  }) {
    final horizontalPadding = isCompact ? 24.0 : 40.0;
    final verticalPadding = isCompact ? (cramped ? 12.0 : 20.0) : 36.0;

    final ctaColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _heroHeadlineBlock(cramped: cramped, isCompact: isCompact),
        SizedBox(height: cramped ? 12 : 22),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            OutlinedButton(
              onPressed: onLoginTap,
              style: _heroMainCtaStyle(),
              child: const Text('Accedi'),
            ),
            OutlinedButton(
              onPressed: onRegisterTap,
              style: _heroMainCtaStyle(),
              child: const Text('Registrati'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onForgotPasswordTap,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white.withValues(alpha: 0.88),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: const Text(
            'Password dimenticata?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(height: isCompact ? (cramped ? 14 : 20) : 22),
        OutlinedButton(
          onPressed: onDiscoverTap,
          style: _heroDiscoverStyle(),
          child: const Text('SCOPRICI'),
        ),
      ],
    );

    if (isCompact) {
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewportConstraints.maxHeight),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _HeroLogo(height: cramped ? 56 : 70),
                ),
                SizedBox(height: cramped ? 12 : 24),
                ctaColumn,
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned(top: 0, left: 0, child: _HeroLogo(height: 86)),
              Center(child: ctaColumn),
            ],
          ),
        ),
      ),
    );
  }

  /// Titolo brand, sottotitolo di benvenuto e riga editoriale (hero).
  static Widget _heroHeadlineBlock({
    required bool cramped,
    required bool isCompact,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            AppBranding.schoolName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: cramped ? 32 : (isCompact ? 40 : 68),
              fontWeight: FontWeight.w700,
              height: 1.08,
              letterSpacing: isCompact ? 0.2 : 0.35,
            ),
          ),
        ),
        SizedBox(height: cramped ? 10 : (isCompact ? 12 : 14)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            'Benvenuto, sei pronto a navigare con noi?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: cramped ? 16 : (isCompact ? 17 : 20),
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ),
        SizedBox(height: cramped ? 10 : (isCompact ? 12 : 14)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Text(
            "Un'esperienza di studio che parte dalla scuola e guarda subito al mare.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: cramped ? 13 : (isCompact ? 14 : 15),
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

/// Marchio in alto a sinistra nella hero: solo variante [AppLogoMarkVariant.white]
/// su overlay scuro (nessun logo centrale, nessun aqua/blu in hero).
class _HeroLogo extends StatelessWidget {
  const _HeroLogo({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.52),
            blurRadius: 26,
            spreadRadius: -1,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.14),
            blurRadius: 20,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Image.asset(
        AppBranding.logoMarkWhite,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => SizedBox(height: height),
      ),
    );
  }
}

class _SplitDiscoverSection extends StatelessWidget {
  const _SplitDiscoverSection({
    super.key,
    required this.titleAnchorKey,
    required this.cardsRevealVisible,
  });

  final GlobalKey titleAnchorKey;
  final bool cardsRevealVisible;

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 900;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 20 : 30,
        isCompact ? 36 : 48,
        isCompact ? 20 : 30,
        isCompact ? 52 : 68,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              KeyedSubtree(
                key: titleAnchorKey,
                child: Text(
                  'Scoprici',
                  style: TextStyle(
                    color: const Color(0xFF14232E),
                    fontSize: isCompact ? 34 : 48,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  'Tra aula e navigazione, tra studio e pratica: una prima impressione che racconta subito il carattere della scuola.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF4A5C6A),
                    fontSize: isCompact ? 15 : 17,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Transform.translate(
                offset: const Offset(0, -14),
                child: isCompact
                    ? Column(
                        children: [
                          _RevealOnScroll(
                            visible: cardsRevealVisible,
                            fade: false,
                            offsetY: 24,
                            child: const _DiscoverImageCard(
                              imagePath: AppBranding.welcomeClassroomJpg,
                              tag: 'AULA',
                              title: 'Spazi di studio chiari e curati',
                              description:
                                  'Un ambiente riconoscibile, ordinato e vicino agli allievi.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _RevealOnScroll(
                            visible: cardsRevealVisible,
                            fade: false,
                            offsetY: 32,
                            duration: const Duration(milliseconds: 760),
                            curve: Curves.easeOutCubic,
                            child: const _DiscoverImageCard(
                              imagePath: AppBranding.welcomeBoatJpg,
                              tag: 'MARE',
                              title: 'La navigazione come esperienza reale',
                              description:
                                  'Non solo teoria: il mare resta sempre il punto di arrivo.',
                            ),
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _RevealOnScroll(
                              visible: cardsRevealVisible,
                              fade: false,
                              offsetY: 24,
                              child: const _DiscoverImageCard(
                                imagePath: AppBranding.welcomeClassroomJpg,
                                tag: 'AULA',
                                title: 'Spazi di studio chiari e curati',
                                description:
                                    'Un ambiente riconoscibile, ordinato e vicino agli allievi.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _RevealOnScroll(
                              visible: cardsRevealVisible,
                              fade: false,
                              offsetY: 32,
                              duration: const Duration(milliseconds: 760),
                              curve: Curves.easeOutCubic,
                              child: const _DiscoverImageCard(
                                imagePath: AppBranding.welcomeBoatJpg,
                                tag: 'MARE',
                                title: 'La navigazione come esperienza reale',
                                description:
                                    'Non solo teoria: il mare resta sempre il punto di arrivo.',
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverImageCard extends StatelessWidget {
  const _DiscoverImageCard({
    required this.imagePath,
    required this.tag,
    required this.title,
    required this.description,
  });

  final String imagePath;
  final String tag;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 900;

    return AspectRatio(
      aspectRatio: isCompact ? 1.18 : 1.14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2473AE), Color(0xFF0E3150)],
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.14),
                    Colors.black.withValues(alpha: 0.68),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCFEFF5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFF9FD9E6)),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFF0F3553),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.05,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneySection extends StatelessWidget {
  const _JourneySection();

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 940;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isCompact ? 20 : 30,
        isCompact ? 40 : 56,
        isCompact ? 20 : 30,
        isCompact ? 48 : 72,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppVisual.border.withValues(alpha: 0.55)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              Text(
                'Il tuo percorso',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppVisual.ink,
                  fontSize: isCompact ? 32 : 44,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  'Dalla prima lezione alla preparazione finale, ogni passaggio è pensato per accompagnarti con chiarezza, metodo e continuità.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppVisual.inkMuted,
                    fontSize: isCompact ? 15 : 16,
                    height: 1.58,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 18 : 26,
                  isCompact ? 22 : 28,
                  isCompact ? 18 : 26,
                  isCompact ? 24 : 30,
                ),
                decoration: BoxDecoration(
                  color: AppVisual.ivory,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppVisual.logoBlue.withValues(alpha: 0.14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppVisual.ink.withValues(alpha: 0.06),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: AppVisual.brandAzure.withValues(alpha: 0.05),
                      blurRadius: 36,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isCompact
                    ? const Column(
                        children: [
                          _FeatureTile(
                            title: 'Lezioni',
                            description:
                                'Contenuti chiari, ordinati e pensati per accompagnare lo studio senza appesantire la lettura.',
                          ),
                          SizedBox(height: 16),
                          _FeatureTile(
                            title: 'Quiz',
                            description:
                                'Allenamento progressivo per argomento, con una navigazione semplice e immediata.',
                          ),
                          SizedBox(height: 16),
                          _FeatureTile(
                            title: 'Esame',
                            description:
                                'Un percorso finale più vicino alla prova reale, per arrivare preparati e sicuri.',
                          ),
                        ],
                      )
                    : const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _FeatureTile(
                              title: 'Lezioni',
                              description:
                                  'Contenuti chiari, ordinati e pensati per accompagnare lo studio senza appesantire la lettura.',
                            ),
                          ),
                          SizedBox(width: 18),
                          Expanded(
                            child: _FeatureTile(
                              title: 'Quiz',
                              description:
                                  'Allenamento progressivo per argomento, con una navigazione semplice e immediata.',
                            ),
                          ),
                          SizedBox(width: 18),
                          Expanded(
                            child: _FeatureTile(
                              title: 'Esame',
                              description:
                                  'Un percorso finale più vicino alla prova reale, per arrivare preparati e sicuri.',
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppVisual.border.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: AppVisual.ink.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppVisual.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppVisual.inkMuted,
              fontSize: 15,
              height: 1.58,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterSection extends StatelessWidget {
  const _FooterSection();

  static const Color _footerBlue = Color(0xFF123A5A);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      color: _footerBlue,
      padding: EdgeInsets.fromLTRB(20, 36, 20, 24 + bottomInset),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool desktop = constraints.maxWidth >= 920;
              final bool twoColumns =
                  constraints.maxWidth >= 420 && constraints.maxWidth < 920;

              double itemWidth;
              if (desktop) {
                itemWidth = (constraints.maxWidth - 72) / 4;
              } else if (twoColumns) {
                itemWidth = (constraints.maxWidth - 20) / 2;
              } else {
                itemWidth = constraints.maxWidth;
              }

              final lineStyle = TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 14,
                height: 1.5,
              );
              final titleStyle = TextStyle(
                color: Colors.white.withValues(alpha: 0.96),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              );

              return Column(
                children: [
                  Wrap(
                    spacing: desktop ? 24 : 20,
                    runSpacing: 28,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _FooterColumn(
                          title: 'Dove',
                          titleStyle: titleStyle,
                          children: [
                            Text(
                              'Via Amato, 4',
                              textAlign: TextAlign.center,
                              style: lineStyle,
                            ),
                            Text(
                              '80053 Castellammare di Stabia (NA)',
                              textAlign: TextAlign.center,
                              style: lineStyle,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _FooterColumn(
                          title: 'Contatti',
                          titleStyle: titleStyle,
                          children: [
                            _FooterTappableLine(
                              icon: Icons.phone_rounded,
                              label: AppBranding.supportPhoneDisplay,
                              onTap: () =>
                                  SchoolContactLauncher.dialSupportPhone(
                                    context,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            _FooterTappableLine(
                              iconWidget: FaIcon(
                                FontAwesomeIcons.whatsapp,
                                size: 17,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              label: 'Anche WhatsApp',
                              onTap: () =>
                                  SchoolContactLauncher.openWhatsApp(context),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _FooterColumn(
                          title: 'Orari',
                          titleStyle: titleStyle,
                          children: [
                            Text(
                              'Lunedì – Venerdì',
                              textAlign: TextAlign.center,
                              style: lineStyle.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '9:00 – 13:00',
                              textAlign: TextAlign.center,
                              style: lineStyle,
                            ),
                            Text(
                              '14:15 – 21:00',
                              textAlign: TextAlign.center,
                              style: lineStyle,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _FooterColumn(
                          title: 'Instagram',
                          titleStyle: titleStyle,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.instagram,
                              size: 28,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            const SizedBox(height: 10),
                            _FooterLinkText(
                              text: '@scuolanauticaliana',
                              onTap: () =>
                                  SchoolContactLauncher.openInstagram(context),
                              style: lineStyle.copyWith(
                                decoration: TextDecoration.underline,
                                decorationColor: Colors.white.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Scuola Nautica Liana',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tutti i diritti sono riservati.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.52),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({
    required this.title,
    required this.titleStyle,
    required this.children,
  });

  final String title;
  final TextStyle titleStyle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(title, textAlign: TextAlign.center, style: titleStyle),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _FooterTappableLine extends StatelessWidget {
  const _FooterTappableLine({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
  }) : assert(
         (icon != null) ^ (iconWidget != null),
         'Usa icon oppure iconWidget',
       );

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.white.withValues(alpha: 0.12),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.9))
              else
                iconWidget!,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 14,
                    height: 1.45,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLinkText extends StatelessWidget {
  const _FooterLinkText({
    required this.text,
    required this.onTap,
    required this.style,
  });

  final String text;
  final VoidCallback onTap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashColor: Colors.white.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(text, textAlign: TextAlign.center, style: style),
        ),
      ),
    );
  }
}

class _RevealOnScroll extends StatelessWidget {
  const _RevealOnScroll({
    required this.visible,
    required this.child,
    this.offsetY = 32,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.fade = true,
  });

  final bool visible;
  final Widget child;
  final double offsetY;
  final Duration duration;
  final Curve curve;

  /// Se false, solo slide (evita doppio fade annidato).
  final bool fade;

  @override
  Widget build(BuildContext context) {
    final slide = AnimatedSlide(
      offset: visible ? Offset.zero : Offset(0, offsetY / 100),
      duration: duration,
      curve: curve,
      child: child,
    );

    if (!fade) return slide;

    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: curve,
      child: slide,
    );
  }
}
