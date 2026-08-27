import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app_root_navigator.dart';
import 'package:scuola_nautica_liana/pages/forgot_password_page.dart';
import 'package:scuola_nautica_liana/pages/login_page.dart';
import 'package:scuola_nautica_liana/pages/student_registration_page.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/services/startup_diagnostics.dart';
import 'package:scuola_nautica_liana/services/startup_diagnostics_host.dart';

Widget _harness({required Widget home}) {
  return MaterialApp(
    navigatorKey: appRootNavigatorKey,
    home: home,
    routes: {
      '/login': (_) => const LoginPage(),
      '/register': (_) => const StudentRegistrationPage(),
      '/forgot-password': (_) => const ForgotPasswordPage(),
    },
    builder: (context, child) {
      final content = child ?? const SizedBox.shrink();
      if (!StartupDiagnostics.enabled) return content;
      return StartupDiagnosticsHost(child: content);
    },
  );
}

void main() {
  tearDown(StartupDiagnostics.resetForTest);

  group('RAW HIT classifier', () {
    test('point inside Accedi → Accedi', () {
      final rects = {
        'Accedi': const Rect.fromLTWH(40, 600, 140, 48),
        'Forgot': const Rect.fromLTWH(100, 700, 180, 40),
      };
      expect(
        StartupDiagnostics.classifyHitCandidates(const Offset(80, 620), rects),
        ['Accedi'],
      );
    });

    test('point outside → none', () {
      final rects = {
        'Accedi': const Rect.fromLTWH(40, 600, 140, 48),
        'Forgot': const Rect.fromLTWH(100, 700, 180, 40),
      };
      expect(
        StartupDiagnostics.classifyHitCandidates(const Offset(10, 10), rects),
        isEmpty,
      );
    });

    test('overlap ipotetico → entrambi', () {
      final rects = {
        'Accedi': const Rect.fromLTWH(40, 600, 200, 80),
        'Forgot': const Rect.fromLTWH(100, 640, 180, 80),
      };
      final hits = StartupDiagnostics.classifyHitCandidates(
        const Offset(150, 660),
        rects,
      );
      expect(hits, containsAll(['Accedi', 'Forgot']));
    });
  });

  group('flag OFF', () {
    test('nessun log raw', () {
      if (StartupDiagnostics.enabled) {
        // Questo assert vale solo nella suite default (define OFF).
        return;
      }
      StartupDiagnostics.resetForTest();
      StartupDiagnostics.log('RAW DOWN id=1');
      expect(StartupDiagnostics.capturedEvents, isEmpty);
    });

    testWidgets('Listener assente / tap Accedi funziona', (tester) async {
      if (StartupDiagnostics.enabled) return;

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_harness(home: const WelcomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(StartupDiagnosticsHost), findsNothing);

      await tester.tap(find.text('Accedi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });

  group('RAW Listener (requires STARTUP_DIAGNOSTICS=true)', () {
    testWidgets('PointerDown/Up + tap Accedi → LoginPage', (tester) async {
      if (!StartupDiagnostics.enabled) {
        // Eseguire con: flutter test --dart-define=STARTUP_DIAGNOSTICS=true
        return;
      }

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      StartupDiagnostics.resetForTest();
      StartupDiagnostics.ensureStarted();

      await tester.pumpWidget(_harness(home: const WelcomePage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(StartupDiagnosticsHost), findsOneWidget);

      final center = tester.getCenter(find.text('Accedi'));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final joined = StartupDiagnostics.capturedEvents.join('\n');
      expect(joined, contains('RAW DOWN'));
      expect(joined, contains('RAW UP'));
      expect(joined, contains('FLUTTER_VIEW'));
      expect(joined, contains('RAW HIT'));
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(ForgotPasswordPage), findsNothing);
    });

    testWidgets('regressione: SCOPRICI swipe Accedi', (tester) async {
      if (!StartupDiagnostics.enabled) return;

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      StartupDiagnostics.resetForTest();
      StartupDiagnostics.ensureStarted();

      await tester.pumpWidget(_harness(home: const WelcomePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SCOPRICI'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Drain overflow discover preesistente.
      Object? ex;
      while ((ex = tester.takeException()) != null) {
        expect(
          '$ex'.contains('overflowed') || '$ex'.contains('Multiple exceptions'),
          isTrue,
        );
      }
      await tester.pump(const Duration(milliseconds: 500));
      while ((ex = tester.takeException()) != null) {
        expect(
          '$ex'.contains('overflowed') || '$ex'.contains('Multiple exceptions'),
          isTrue,
        );
      }

      // Swipe leggero sul body.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Torna su e tap Accedi (ensureVisible se fuori viewport).
      await tester.ensureVisible(find.text('Accedi'));
      await tester.tap(find.text('Accedi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });

  test('privacy route sanitize invariata', () {
    expect(StartupDiagnostics.sanitizeRoute('/login'), '/login');
    expect(
      StartupDiagnostics.sanitizeRoute('#access_token=x&type=recovery'),
      '<auth-redacted>',
    );
  });
}
