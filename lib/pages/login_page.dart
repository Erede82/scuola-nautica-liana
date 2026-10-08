import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import '../models/app_auth_summary.dart';
import '../repositories/student_auth_registry.dart';
import '../services/staff_access_service.dart';
import '../services/startup_diagnostics.dart';
import '../theme/app_visual_tokens.dart';
import '../utils/admin_access_utils.dart';
import '../utils/ios_edge_catcher.dart';
import '../widgets/branded_app_bar_title.dart';
import 'accedi_da_pc_page.dart' show showAccediDaPcBottomSheet;
import 'forgot_password_page.dart';
import 'student_registration_page.dart';

/// Accesso con email e password.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.isInternalIosWebLogin = false});

  /// FRONT.FINAL: aperta da Welcome su iOS web (unnamed route).
  final bool isInternalIosWebLogin;

  /// Split brand | form (desktop / web largo).
  @visibleForTesting
  static const double desktopSplitMinWidth = 1024;

  /// Card centrata a larghezza controllata (tablet / medium).
  @visibleForTesting
  static const double tabletMinWidth = 600;

  /// Max width form card desktop/tablet.
  @visibleForTesting
  static const double loginCardMaxWidth = 440;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final GlobalKey _loginBackKey = GlobalKey();

  bool _obscure = true;
  bool _loading = false;
  bool _edgeBackHandled = false;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _textPrimaryColor = AppVisual.ink;
  static const Color _neutralColor = AppVisual.chipFill;

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  String _normalizeEmail(String value) =>
      AdminAccessUtils.normalizeEmail(value);

  @override
  void initState() {
    super.initState();
    if (StartupDiagnostics.enabled) {
      StartupDiagnostics.registerTarget('LoginBack', _loginBackKey);
    }
    IosEdgeCatcher.installIfNeeded(
      isInternalIosWebLogin: widget.isInternalIosWebLogin,
      onBack: _onDomEdgeBack,
    );
  }

  void _onDomEdgeBack() {
    if (!mounted || _edgeBackHandled) return;
    _edgeBackHandled = true;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    if (widget.isInternalIosWebLogin) {
      IosEdgeCatcher.uninstall();
    }
    StartupDiagnostics.unregisterTarget('LoginBack');
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final normalizedEmail = _normalizeEmail(_emailCtrl.text);

    setState(() => _loading = true);

    try {
      final result = await studentAuthRepository.signIn(
        email: normalizedEmail,
        password: _passwordCtrl.text,
      );

      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? 'Email o password non corrette',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await refreshStaffAccess();

      if (!mounted) return;

      final staffSnap = staffAccessNotifier.value;
      final summary = AppAuthSummary.fromSources(
        student: result.session,
        staffSnap: staffSnap,
      );

      final isAdminDashboard = AdminAccessUtils.isSchoolAdmin(
        email: normalizedEmail,
        staffRole: staffSnap.staffRole,
      );

      if (isAdminDashboard) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final String msg;
      if (summary.hasStaffAccess && !summary.hasStudentProfile) {
        msg =
            'Accesso staff effettuato (nessun profilo allievo collegato a questo account).';
      } else {
        msg = 'Accesso effettuato';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primaryColor,
          duration: const Duration(milliseconds: 1800),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[LOGIN] exception: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore durante l’accesso: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        // Key diagnostica sul back standard (comportamento AppBar invariato).
        leading: BackButton(key: _loginBackKey),
        title: const SectionAppBarTitle('Accedi', logoHeight: 30),
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (width >= LoginPage.desktopSplitMinWidth) {
              return _buildDesktopSplit(context, constraints);
            }
            if (width >= LoginPage.tabletMinWidth) {
              return _buildCenteredCardLayout(context, showBrandLogo: true);
            }
            return _buildMobileColumn(context);
          },
        ),
      ),
    );
  }

  Widget _buildDesktopSplit(BuildContext context, BoxConstraints constraints) {
    return KeyedSubtree(
      key: const Key('login_desktop_split'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 58, child: _buildBrandPanel(context)),
          Expanded(
            flex: 42,
            child: ColoredBox(
              color: _backgroundColor,
              child: _buildCenteredCardLayout(context, showBrandLogo: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandPanel(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return KeyedSubtree(
      key: const Key('login_brand_panel'),
      child: ColoredBox(
        color: _primaryColor,
        child: Stack(
          children: [
            Positioned(
              right: -48,
              top: -36,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppVisual.brandAzure.withValues(alpha: 0.14),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: 64,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 2,
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        AppBranding.logoScuolaNauticaLianaWhite,
                        width: 220,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        semanticLabel: AppBranding.schoolName,
                        errorBuilder: (context, error, stackTrace) => Text(
                          AppBranding.schoolName,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        AppBranding.schoolName,
                        textAlign: TextAlign.center,
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Il tuo percorso, sempre con te.',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dalla prima lezione alla preparazione finale.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredCardLayout(
    BuildContext context, {
    required bool showBrandLogo,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            showBrandLogo ? 28 : 36,
            24,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite
                  ? (constraints.maxHeight -
                            28 -
                            32 -
                            MediaQuery.paddingOf(context).bottom)
                        .clamp(0.0, double.infinity)
                  : 0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: LoginPage.loginCardMaxWidth,
                ),
                child: _buildLoginCard(context, showBrandLogo: showBrandLogo),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileColumn(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return KeyedSubtree(
      key: const Key('login_mobile_column'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final logoWidth = (constraints.maxWidth * 0.55).clamp(
                150.0,
                210.0,
              );
              final cacheWidth = constraints.maxWidth >= 1200
                  ? null
                  : (logoWidth * MediaQuery.devicePixelRatioOf(context) * 1.15)
                        .round()
                        .clamp(300, 480);
              return Center(
                child: Image.asset(
                  AppBranding.logoScuolaNauticaLianaBlue,
                  width: logoWidth,
                  fit: BoxFit.contain,
                  cacheWidth: cacheWidth,
                  filterQuality: FilterQuality.high,
                  semanticLabel: AppBranding.schoolName,
                  errorBuilder: (context, error, stackTrace) => Text(
                    AppBranding.schoolName,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Accedi con le credenziali usate in fase di registrazione.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: _textPrimaryColor.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          ..._buildCredentialFields(context),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context, {required bool showBrandLogo}) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      key: const Key('login_form_card'),
      color: AppVisual.ivory,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppVisual.border.withValues(alpha: 0.9)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBrandLogo) ...[
              Center(
                child: Image.asset(
                  AppBranding.logoScuolaNauticaLianaBlue,
                  width: 168,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  semanticLabel: AppBranding.schoolName,
                  errorBuilder: (context, error, stackTrace) => Text(
                    AppBranding.schoolName,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(
              'Accedi',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accedi con le credenziali usate in fase di registrazione.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.85),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            ..._buildCredentialFields(context),
          ],
        ),
      ),
    );
  }

  /// Campi + CTA condivisi (unica logica form).
  List<Widget> _buildCredentialFields(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return [
      TextFormField(
        key: const Key('login_email_field'),
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: _decoration('Email'),
        textInputAction: TextInputAction.next,
        validator: (v) {
          final t = v?.trim() ?? '';
          if (t.isEmpty) return 'Inserisci l’email.';
          if (!_emailRegex.hasMatch(t)) {
            return 'Inserisci un’email valida.';
          }
          return null;
        },
      ),
      const SizedBox(height: 14),
      TextFormField(
        key: const Key('login_password_field'),
        controller: _passwordCtrl,
        obscureText: _obscure,
        decoration: _decoration('Password').copyWith(
          suffixIcon: IconButton(
            key: const Key('login_password_visibility'),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _primaryColor.withValues(alpha: 0.7),
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Inserisci la password.';
          return null;
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          key: const Key('login_forgot_password'),
          onPressed: _loading
              ? null
              : () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ForgotPasswordPage(),
                    ),
                  );
                },
          child: Text(
            'Hai dimenticato la password?',
            style: textTheme.labelLarge?.copyWith(
              color: _primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      FilledButton(
        key: const Key('login_submit'),
        onPressed: _loading ? null : _submit,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: _primaryColor,
        ),
        child: _loading
            ? const SizedBox(
                key: Key('login_loading_indicator'),
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Accedi'),
      ),
      const SizedBox(height: 14),
      OutlinedButton(
        key: const Key('login_create_account'),
        onPressed: _loading
            ? null
            : () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const StudentRegistrationPage(),
                  ),
                );
              },
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: const Text('Crea account'),
      ),
      const SizedBox(height: 10),
      Center(
        child: TextButton.icon(
          key: const Key('login_qr_code'),
          onPressed: _loading ? null : () => showAccediDaPcBottomSheet(context),
          icon: Icon(
            Icons.qr_code_scanner_rounded,
            color: _primaryColor.withValues(alpha: 0.9),
            size: 22,
          ),
          label: Text(
            'Usa QR code',
            style: textTheme.labelLarge?.copyWith(
              color: _primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ];
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _neutralColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _neutralColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 1.4),
      ),
    );
  }
}
