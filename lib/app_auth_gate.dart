import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'pages/admin_home_page.dart';
import 'pages/home_page.dart';
import 'pages/welcome_page.dart';
import 'repositories/student_auth_registry.dart';
import 'services/app_auth_bootstrap.dart';
import 'services/auth_logout_navigation.dart';
import 'services/demo_student_enrollment.dart';
import 'services/staff_access_service.dart';
import 'utils/admin_access_utils.dart';

/// Root dell’app: Welcome se non autenticato, altrimenti Home o Admin.
/// Dopo login/registrazione le pagine fanno solo `Navigator.pop` e questo widget si aggiorna.
class AppAuthGate extends StatefulWidget {
  const AppAuthGate({super.key});

  @override
  State<AppAuthGate> createState() => _AppAuthGateState();
}

class _AppAuthGateState extends State<AppAuthGate> {
  bool _bootstrapping = true;
  StreamSubscription<AuthState>? _authSub;
  VoidCallback? _studentListener;
  VoidCallback? _staffListener;

  @override
  void initState() {
    super.initState();
    _studentListener = () {
      if (mounted) setState(() {});
    };
    _staffListener = () {
      if (mounted) setState(() {});
    };
    studentSession.addListener(_studentListener!);
    staffAccessNotifier.addListener(_staffListener!);

    if (SupabaseConfig.isConfigured) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }

    unawaited(_finalizeBootstrap());
  }

  Future<void> _finalizeBootstrap() async {
    if (!SupabaseConfig.isConfigured) {
      if (mounted) setState(() => _bootstrapping = false);
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
        debugPrint(
          '[AUTH gate] logout forzato (bootstrap): JWT senza studente/staff/email privilegiata',
        );
        await signOutAndReturnToWelcome();
      }
    }
    if (mounted) setState(() => _bootstrapping = false);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!SupabaseConfig.isConfigured) {
      return const WelcomePage();
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return const WelcomePage();
    }

    final snap = staffAccessNotifier.value;
    if (snap.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final email = user.email;
    final hasStudent = studentSession.value != null;
    final hasStaff = snap.staffRole != null;
    final privileged = AdminAccessUtils.isPrivilegedEmail(email);

    if (!hasStudent && !hasStaff && !privileged) {
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
    return admin ? const AdminHomePage() : const HomePage();
  }
}
