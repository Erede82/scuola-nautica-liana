import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import '../models/app_auth_summary.dart';
import '../repositories/student_auth_registry.dart';
import '../services/staff_access_service.dart';
import '../utils/admin_access_utils.dart';
import '../widgets/branded_app_bar_title.dart';
import 'accedi_da_pc_page.dart' show showAccediDaPcBottomSheet;
import 'forgot_password_page.dart';
import 'student_registration_page.dart';
import '../theme/app_visual_tokens.dart';

/// Accesso con email e password.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

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
  void dispose() {
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
        msg = 'Accesso staff effettuato (nessun profilo allievo collegato a questo account).';
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const SectionAppBarTitle('Accedi', logoHeight: 30),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          children: [
            Text(
              AppBranding.schoolName,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Accedi con le credenziali usate in fase di registrazione.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.85),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
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
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: _decoration('Password').copyWith(
                suffixIcon: IconButton(
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
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _primaryColor,
              ),
              child: _loading
                  ? const SizedBox(
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Crea account'),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: _loading
                    ? null
                    : () => showAccediDaPcBottomSheet(context),
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
          ],
        ),
      ),
    );
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
