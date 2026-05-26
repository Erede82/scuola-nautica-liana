import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import '../domain/course_taxonomy.dart';
import '../models/student_registration.dart';
import '../repositories/student_auth_registry.dart';
import '../theme/app_visual_tokens.dart';

/// Onboarding: registrazione con scelta esplicita del percorso di iscrizione.
class StudentRegistrationPage extends StatefulWidget {
  const StudentRegistrationPage({super.key});

  @override
  State<StudentRegistrationPage> createState() => _StudentRegistrationPageState();
}

class _StudentRegistrationPageState extends State<StudentRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  EnrollmentCoursePath? _selectedPath;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _backgroundColor = AppVisual.canvas;
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleziona il percorso di iscrizione per continuare.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final req = StudentRegistrationRequest(
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        enrolledCoursePath: _selectedPath!,
      );
      final result = await studentAuthRepository.register(req);
      if (!mounted) return;

      if (result.success && result.session != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrazione completata. Benvenuto!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1800),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Registrazione non riuscita.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Crea account'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
          children: [
            Text(
              AppBranding.schoolName,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Compila i dati e scegli il percorso che hai scelto con la segreteria. '
              'Riceverai conferma quando l’iscrizione sarà attiva.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Scegli il tuo percorso',
              style: textTheme.titleMedium?.copyWith(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Il percorso definisce quali moduli didattici saranno disponibili nell’app.',
              style: textTheme.bodySmall?.copyWith(
                color: _textPrimaryColor.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 14),
            ...EnrollmentCoursePath.values.map(
              (path) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EnrollmentPathSelectableCard(
                  path: path,
                  selected: _selectedPath == path,
                  onTap: () => setState(() => _selectedPath = path),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'I tuoi dati',
              style: textTheme.titleMedium?.copyWith(
                color: _textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _firstNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration('Nome'),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Inserisci il nome.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration('Cognome'),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Inserisci il cognome.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration('Telefono'),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().length < 8) {
                  return 'Inserisci un numero di telefono valido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: _fieldDecoration('Email'),
              textInputAction: TextInputAction.next,
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Inserisci l’email.';
                if (!_emailRegex.hasMatch(t)) return 'Inserisci un’email valida.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              decoration: _fieldDecoration('Password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: _primaryColor.withValues(alpha: 0.7),
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.length < 8) {
                  return 'La password deve avere almeno 8 caratteri.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirm,
              decoration: _fieldDecoration('Conferma password').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: _primaryColor.withValues(alpha: 0.7),
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                if (v != _passwordCtrl.text) return 'Le password non coincidono.';
                return null;
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: _primaryColor,
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Registrati'),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Registrandoti accetti che i dati siano trattati per la gestione del corso, '
                'in linea con le informative della scuola.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: _textPrimaryColor.withValues(alpha: 0.55),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _cardColor,
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _EnrollmentPathSelectableCard extends StatelessWidget {
  const _EnrollmentPathSelectableCard({
    required this.path,
    required this.selected,
    required this.onTap,
  });

  final EnrollmentCoursePath path;
  final bool selected;
  final VoidCallback onTap;

  static const Color _primaryColor = AppVisual.logoBlue;
  static const Color _accentColor = Color(0xFF44BBCA);
  static const Color _cardColor = Color(0xFFFFFFFF);
  static const Color _neutralColor = AppVisual.chipFill;
  static const Color _textPrimaryColor = AppVisual.ink;

  String get _title {
    switch (path) {
      case EnrollmentCoursePath.entro12MigliaVela:
        return 'Oltre le 12 miglia motore + vela';
      case EnrollmentCoursePath.entro12Miglia:
      case EnrollmentCoursePath.d1:
        return path.labelIt;
    }
  }

  String get _subtitle {
    switch (path) {
      case EnrollmentCoursePath.entro12Miglia:
        return 'Teoria e quiz per navigazione entro le 12 miglia dalla costa (motore).';
      case EnrollmentCoursePath.d1:
        return 'Percorso dedicato alla patente D1.';
      case EnrollmentCoursePath.entro12MigliaVela:
        return 'Motore + vela: contenuti motore attivi; modulo vela in completamento dove non ancora disponibile.';
    }
  }

  String get _hint {
    switch (path) {
      case EnrollmentCoursePath.entro12Miglia:
        return 'Ideale se ti stai preparando al quiz entro 12 miglia.';
      case EnrollmentCoursePath.d1:
        return 'Materiali e quiz allineati alla categoria D1.';
      case EnrollmentCoursePath.entro12MigliaVela:
        return 'Include teoria vela: dove i contenuti sono in arrivo vedrai un avviso “in arrivo”.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final borderColor = selected ? _primaryColor : _neutralColor;
    final bg = selected ? _accentColor.withValues(alpha: 0.12) : _cardColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: selected ? _primaryColor : _neutralColor,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: textTheme.titleSmall?.copyWith(
                        color: _textPrimaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: _textPrimaryColor.withValues(alpha: 0.82),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hint,
                      style: textTheme.labelSmall?.copyWith(
                        color: _primaryColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        height: 1.3,
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
