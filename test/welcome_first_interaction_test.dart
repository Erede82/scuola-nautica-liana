import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/pages/forgot_password_page.dart';
import 'package:scuola_nautica_liana/pages/login_page.dart';
import 'package:scuola_nautica_liana/pages/student_registration_page.dart';
import 'package:scuola_nautica_liana/pages/welcome_page.dart';
import 'package:scuola_nautica_liana/services/startup_diagnostics.dart';

Widget _welcomeHarness() {
  return MaterialApp(
    home: const WelcomePage(),
    routes: {
      '/login': (_) => const LoginPage(),
      '/register': (_) => const StudentRegistrationPage(),
      '/forgot-password': (_) => const ForgotPasswordPage(),
    },
  );
}

/// Primi frame senza settle lungo (timing più vicino al cold start).
Future<void> _pumpEarlyFrames(WidgetTester tester) async {
  await tester.pumpWidget(_welcomeHarness());
  await tester.pump(); // first frame
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Offset dello scroll esterno (ClampingScrollPhysics sul body).
double _outerScrollPixels(WidgetTester tester) {
  return _outerScrollPosition(tester).pixels;
}

ScrollPosition _outerScrollPosition(WidgetTester tester) {
  final outer = find.byWidgetPredicate(
    (w) => w is SingleChildScrollView && w.physics is ClampingScrollPhysics,
  );
  final scrollable = find.descendant(
    of: outer,
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable.first).position;
}

/// Drain eccezioni overflow layout preesistenti (discover card), non scope PWA.7-P.
void _drainKnownOverflow(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    expect('$ex', contains('overflowed'));
  }
}

void main() {
  group('StartupDiagnostics privacy / flag', () {
    test('sanitizeRoute permette solo path noti', () {
      expect(StartupDiagnostics.sanitizeRoute('/login'), '/login');
      expect(StartupDiagnostics.sanitizeRoute('/register'), '/register');
      expect(
        StartupDiagnostics.sanitizeRoute('/forgot-password'),
        '/forgot-password',
      );
      expect(StartupDiagnostics.sanitizeRoute('/'), '/');
      expect(
        StartupDiagnostics.sanitizeRoute('/login?email=x@y.z'),
        '/login',
      );
      expect(
        StartupDiagnostics.sanitizeRoute('#access_token=abc&type=recovery'),
        '<auth-redacted>',
      );
      expect(
        StartupDiagnostics.sanitizeRoute('/students/uuid-secret'),
        '<unknown>',
      );
    });

    test('flag OFF: log non produce eventi', () {
      // Default test compile: STARTUP_DIAGNOSTICS=false.
      expect(StartupDiagnostics.enabled, isFalse);
      StartupDiagnostics.resetForTest();
      StartupDiagnostics.log('TAP Accedi');
      expect(StartupDiagnostics.capturedEvents, isEmpty);
    });
  });

  group('P0-B first tap Accedi', () {
    testWidgets('tap precoce Accedi → LoginPage (mai Forgot)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await _pumpEarlyFrames(tester);

      await tester.tap(find.text('Accedi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(ForgotPasswordPage), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap Accedi dopo settle → LoginPage', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_welcomeHarness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accedi'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(ForgotPasswordPage), findsNothing);
    });

    testWidgets('hit isolation Accedi vs Forgot', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_welcomeHarness());
      await tester.pumpAndSettle();

      final accedi = tester.getRect(find.text('Accedi'));
      final forgot = tester.getRect(find.text('Password dimenticata?'));
      final accediCenter = accedi.center;

      expect(forgot.contains(accediCenter), isFalse);
      final gap = forgot.top - accedi.bottom;
      // Gap verticale atteso tra i due target (dp).
      expect(gap, greaterThan(8));
      debugPrint('[P0-B] Accedi↔Forgot gap≈${gap.toStringAsFixed(1)} dp');
    });
  });

  group('P0-C first tap SCOPRICI', () {
    testWidgets('tap precoce SCOPRICI → scroll parte', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await _pumpEarlyFrames(tester);

      // Hero reveal: lascia qualche frame senza settle lungo.
      await tester.pump(const Duration(milliseconds: 700));

      final before = _outerScrollPixels(tester);

      await tester.tap(find.text('SCOPRICI'));
      await tester.pump();
      _drainKnownOverflow(tester);
      await tester.pump(const Duration(milliseconds: 200));
      _drainKnownOverflow(tester);
      await tester.pump(const Duration(milliseconds: 600));
      _drainKnownOverflow(tester);

      final after = _outerScrollPixels(tester);
      expect(
        after,
        greaterThan(before),
        reason: 'SCOPRICI deve far partire lo scroll (early tap)',
      );
    });

    testWidgets('tap SCOPRICI dopo settle → scroll parte', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_welcomeHarness());
      await tester.pumpAndSettle();

      final beforePos = _outerScrollPosition(tester);
      final before = beforePos.pixels;
      expect(beforePos.maxScrollExtent, greaterThan(0));

      await tester.tap(find.widgetWithText(OutlinedButton, 'SCOPRICI'));
      await tester.pump();
      _drainKnownOverflow(tester);
      await tester.pump(const Duration(milliseconds: 50));
      _drainKnownOverflow(tester);
      await tester.pump(const Duration(milliseconds: 400));
      _drainKnownOverflow(tester);
      await tester.pump(const Duration(milliseconds: 400));
      _drainKnownOverflow(tester);

      final after = _outerScrollPixels(tester);
      debugPrint(
        '[P0-C settle] before=$before after=$after '
        'max=${_outerScrollPosition(tester).maxScrollExtent}',
      );
      expect(after, greaterThan(before));
      expect(find.text('Scoprici'), findsOneWidget);
    });

    testWidgets('hero inner scrollable present (nested)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_welcomeHarness());
      await tester.pumpAndSettle();

      // Outer + compact-hero inner SingleChildScrollView.
      expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(2));
      debugPrint('[P0-C] hero inner scrollable present=true');
    });
  });
}
