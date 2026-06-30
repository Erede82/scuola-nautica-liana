import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth flow guard wiring', () {
    test('email/password login is guarded until app identity is resolved', () {
      final authState = File(
        'lib/services/auth_flow_state.dart',
      ).readAsStringSync();
      final gate = File('lib/app_auth_gate.dart').readAsStringSync();
      final repo = File(
        'lib/repositories/student_auth_repository_supabase.dart',
      ).readAsStringSync();
      final loginPage = File('lib/pages/login_page.dart').readAsStringSync();

      expect(authState, contains('final ValueNotifier<bool> loginInProgress'));
      expect(authState, contains('bool get authFlowInProgress'));
      expect(
        authState,
        contains('registrationInProgress.value || loginInProgress.value'),
      );

      expect(gate, contains('loginInProgress.addListener'));
      expect(gate, contains('loginInProgress.removeListener'));
      expect(gate, contains('if (authFlowInProgress)'));

      final signInStart = repo.indexOf('Future<StudentLoginResult> signIn');
      final restoreStart = repo.indexOf(
        'Future<void> restoreSessionIfAvailable',
      );
      expect(signInStart, isNonNegative);
      expect(restoreStart, greaterThan(signInStart));

      final signInBody = repo.substring(signInStart, restoreStart);
      expect(
        signInBody.indexOf('loginInProgress.value = true'),
        lessThan(signInBody.indexOf('signInWithPassword')),
      );
      expect(
        signInBody.indexOf('await refreshStaffAccess();'),
        greaterThan(signInBody.indexOf('_hydrateFromCurrentAuth')),
      );
      expect(
        signInBody,
        contains('finally {\n      loginInProgress.value = false;'),
      );

      expect(loginPage, isNot(contains('await refreshStaffAccess();')));
    });
  });
}
