import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../domain/staff/staff_school_role.dart';
import '../repositories/staff_role_registry.dart';
import '../repositories/staff_role_repository.dart';
import 'demo_student_enrollment.dart';

/// Stato permessi backoffice staff (lettura centralizzata per UI e guard).
class StaffAccessSnapshot {
  const StaffAccessSnapshot({
    required this.isLoading,
    this.lastError,
    this.staffRole,
    required this.hasAuthSession,
  });

  final bool isLoading;
  final Object? lastError;

  /// Ruolo operativo scuola; `null` se assente, studente, o non applicabile.
  final StaffSchoolRole? staffRole;

  /// Sessione presente: JWT Supabase o sessione studente mock.
  final bool hasAuthSession;

  bool get canAccessBackoffice => staffRole != null;

  StaffAccessSnapshot copyWith({
    bool? isLoading,
    Object? lastError,
    StaffSchoolRole? staffRole,
    bool clearError = false,
    bool? hasAuthSession,
  }) {
    return StaffAccessSnapshot(
      isLoading: isLoading ?? this.isLoading,
      lastError: clearError ? null : (lastError ?? this.lastError),
      staffRole: staffRole ?? this.staffRole,
      hasAuthSession: hasAuthSession ?? this.hasAuthSession,
    );
  }

  static StaffAccessSnapshot initial() => const StaffAccessSnapshot(
        isLoading: true,
        hasAuthSession: false,
      );
}

/// Notifier globale — aggiornare dopo login/logout e all’avvio app.
final ValueNotifier<StaffAccessSnapshot> staffAccessNotifier =
    ValueNotifier<StaffAccessSnapshot>(StaffAccessSnapshot.initial());

StreamSubscription<AuthState>? _authSubscription;

bool _staffAccessListenersAttached = false;

/// Inizializza listener e prima risoluzione (chiamare da `main` dopo Supabase + restore sessione).
Future<void> initializeStaffAccess() async {
  await refreshStaffAccess();

  if (_staffAccessListenersAttached) {
    return;
  }
  _staffAccessListenersAttached = true;

  _authSubscription?.cancel();
  if (SupabaseConfig.isConfigured) {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      unawaited(refreshStaffAccess());
    });
  }

  studentSession.addListener(_onLocalSessionChanged);
}

void _onLocalSessionChanged() {
  unawaited(refreshStaffAccess());
}

/// Ricalcola ruolo staff (dopo login, logout, o errore rete).
Future<void> refreshStaffAccess() async {
  staffAccessNotifier.value = staffAccessNotifier.value.copyWith(
    isLoading: true,
    clearError: true,
  );

  final hasAuth = _hasAuthSession();

  try {
    final role = await _resolveStaffRole(hasAuth);
    staffAccessNotifier.value = StaffAccessSnapshot(
      isLoading: false,
      lastError: null,
      staffRole: role,
      hasAuthSession: hasAuth,
    );
  } catch (e, st) {
    debugPrint(
      '[AUTH session] refreshStaffAccess FAILED: $e\n$st',
    );
    staffAccessNotifier.value = StaffAccessSnapshot(
      isLoading: false,
      lastError: e,
      staffRole: null,
      hasAuthSession: hasAuth,
    );
  }
}

bool _hasAuthSession() {
  if (SupabaseConfig.isConfigured) {
    return Supabase.instance.client.auth.currentUser != null;
  }
  return studentSession.value != null;
}

Future<StaffSchoolRole?> _resolveStaffRole(bool hasAuth) async {
  final StaffRoleRepository repo = staffRoleRepository;

  if (!SupabaseConfig.isConfigured) {
    return null;
  }

  if (!hasAuth) return null;
  return repo.resolveCurrentUserRole();
}

/// Rimuove listener (test / shutdown).
void disposeStaffAccessListeners() {
  _authSubscription?.cancel();
  _authSubscription = null;
  if (_staffAccessListenersAttached) {
    studentSession.removeListener(_onLocalSessionChanged);
    _staffAccessListenersAttached = false;
  }
}
