import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'pages/admin_home_page.dart';
import 'pages/home_page.dart';
import 'pages/welcome_page.dart';
import 'repositories/student_auth_registry.dart';
import 'services/app_auth_bootstrap.dart';
import 'services/auth_flow_state.dart';
import 'services/auth_gate_bootstrap.dart';
import 'services/auth_logout_navigation.dart';
import 'services/demo_student_enrollment.dart';
import 'services/html_splash_lifecycle.dart';
import 'services/staff_access_service.dart';
import 'services/startup_diagnostics.dart';
import 'utils/admin_access_utils.dart';
import 'widgets/startup_visual_shell.dart';
import 'widgets/welcome_asset_hints.dart';

/// Root dell’app: Welcome se non autenticato, altrimenti Home o Admin.
/// Dopo login/registrazione le pagine fanno solo `Navigator.pop` e questo widget si aggiorna.
class AppAuthGate extends StatefulWidget {
  const AppAuthGate({
    super.key,
    @visibleForTesting this.heroWarmupOverride,
  });

  /// FRONT.8 test hook: bypassa [precacheImage] (fake-async / VM).
  @visibleForTesting
  final Future<void> Function(BuildContext context)? heroWarmupOverride;

  @override
  State<AppAuthGate> createState() => _AppAuthGateState();
}

class _AppAuthGateState extends State<AppAuthGate> {
  bool _bootstrapping = true;
  bool _authComplete = false;
  bool _heroWarmupComplete = false;
  bool _heroWarmupStarted = false;
  StreamSubscription<AuthState>? _authSub;
  VoidCallback? _studentListener;
  VoidCallback? _staffListener;
  VoidCallback? _registrationListener;

  @override
  void initState() {
    super.initState();
    _studentListener = () {
      if (mounted) setState(() {});
    };
    _staffListener = () {
      if (mounted) setState(() {});
    };
    _registrationListener = () {
      if (mounted) setState(() {});
    };
    studentSession.addListener(_studentListener!);
    staffAccessNotifier.addListener(_staffListener!);
    registrationInProgress.addListener(_registrationListener!);

    if (SupabaseConfig.isConfigured) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }

    unawaited(_runAuthBootstrap());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery disponibile qui: un solo hero precache (FRONT.8).
    if (_heroWarmupStarted) return;
    _heroWarmupStarted = true;
    unawaited(_runHeroWarmup());
  }

  Future<void> _runAuthBootstrap() async {
    try {
      await _finalizeAuthBootstrap();
    } catch (_) {
      // Auth bootstrap best-effort: gate procede comunque dopo hero.
    }
    if (!mounted) return;
    setState(() {
      _authComplete = true;
      _applyBootstrapGate();
    });
  }

  Future<void> _runHeroWarmup() async {
    StartupDiagnostics.log('HERO_WARMUP start');
    try {
      final override = widget.heroWarmupOverride;
      if (override != null) {
        await override(context);
      } else {
        await precacheImage(
          WelcomeAssetHints.heroProvider(context),
          context,
        ).timeout(const Duration(seconds: 12));
      }
    } catch (_) {
      // Decode fallito/timeout: Welcome ha ColoredBox + errorBuilder.
    }
    if (!mounted) return;
    StartupDiagnostics.log('HERO_WARMUP ready');
    setState(() {
      _heroWarmupComplete = true;
      _applyBootstrapGate();
    });
  }

  void _applyBootstrapGate() {
    if (!isAuthGateReady(
      authComplete: _authComplete,
      heroWarmupComplete: _heroWarmupComplete,
    )) {
      return;
    }
    if (!_bootstrapping) return;
    _bootstrapping = false;
    if (!SupabaseConfig.isConfigured ||
        Supabase.instance.client.auth.currentUser == null) {
      StartupDiagnostics.log('AUTH gateWelcome');
    }
  }

  Future<void> _finalizeAuthBootstrap() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await refreshSupabaseSessionIfExpired();
      await refreshStaffAccess();
      if (!mounted) return;
      if (studentSession.value == null) {
        await studentAuthRepository.restoreSessionIfAvailable();
        if (!mounted) return;
        await refreshStaffAccess();
        if (!mounted) return;
      }
      final snap = staffAccessNotifier.value;
      final email = user.email;
      final hasStudent = studentSession.value != null;
      final hasStaff = snap.staffRole != null;
      final privileged = AdminAccessUtils.isPrivilegedEmail(email);
      if (!hasStudent && !hasStaff && !privileged) {
        if (registrationInProgress.value) {
          debugPrint(
            '[AUTH gate] bootstrap: registrazione in corso, nessun logout forzato',
          );
        } else {
          debugPrint(
            '[AUTH gate] logout forzato (bootstrap): JWT senza studente/staff/email privilegiata',
          );
          await signOutAndReturnToWelcome();
        }
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    if (_studentListener != null) {
      studentSession.removeListener(_studentListener!);
    }
    if (_staffListener != null) {
      staffAccessNotifier.removeListener(_staffListener!);
    }
    if (_registrationListener != null) {
      registrationInProgress.removeListener(_registrationListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      // Sotto lo splash HTML: Azzurro Capri + logo (STARTUP.CAPRI). Splash resta fino a
      // WELCOME_VISUAL_READY / app-surface-ready.
      return const StartupVisualShell();
    }

    if (!SupabaseConfig.isConfigured) {
      return const WelcomePage();
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const WelcomePage();
    }

    final email = user.email;
    final hasStudent = studentSession.value != null;
    final snap = staffAccessNotifier.value;
    final hasStaff = snap.staffRole != null;
    final privileged = AdminAccessUtils.isPrivilegedEmail(email);

    // Allievo: Home appena studentSession è idratata — non attendere staff access.
    if (hasStudent) {
      final admin = AdminAccessUtils.isSchoolAdmin(
        email: email,
        staffRole: snap.staffRole,
      );
      _scheduleAppSurfaceReady();
      return admin ? const AdminHomePage() : const HomePage();
    }

    // Nessun profilo studente: attendi risoluzione staff o fine registrazione.
    if (snap.isLoading || registrationInProgress.value) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!hasStaff && !privileged) {
      debugPrint(
        '[AUTH gate] JWT senza accesso studente/staff: signOut post-frame '
        'user.id=${user.id}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(signOutAndReturnToWelcome());
      });
      return const WelcomePage();
    }

    final admin = AdminAccessUtils.isSchoolAdmin(
      email: email,
      staffRole: snap.staffRole,
    );
    _scheduleAppSurfaceReady();
    return admin ? const AdminHomePage() : const HomePage();
  }

  void _scheduleAppSurfaceReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HtmlSplashLifecycle.markAppSurfaceReady();
    });
  }
}
