import 'package:flutter/gestures.dart';
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

/// Drain eccezioni overflow layout preesistenti (discover card).
void _drainKnownOverflow(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    final text = '$ex';
    final known =
        text.contains('overflowed') || text.contains('Multiple exceptions');
    expect(known, isTrue, reason: 'unexpected exception: $text');
  }
}

Future<void> _pumpScrollAnimation(WidgetTester tester) async {
  await tester.pump();
  _drainKnownOverflow(tester);
  await tester.pump(const Duration(milliseconds: 50));
  _drainKnownOverflow(tester);
  await tester.pump(const Duration(milliseconds: 400));
  _drainKnownOverflow(tester);
  await tester.pump(const Duration(milliseconds: 400));
  _drainKnownOverflow(tester);
}

double? _ctaGlobalY(WidgetTester tester, Finder finder) {
  final el = finder.evaluate();
  if (el.isEmpty) return null;
  return tester.getTopLeft(finder).dy;
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

    testWidgets('tap Accedi dopo breve pump → LoginPage', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_welcomeHarness());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Accedi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(ForgotPasswordPage), findsNothing);
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

    testWidgets('hit isolation CTA non overlap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_welcomeHarness());
      await tester.pumpAndSettle();

      final accedi = tester.getRect(find.text('Accedi'));
      final registrati = tester.getRect(find.text('Registrati'));
      final forgot = tester.getRect(find.text('Password dimenticata?'));
      final scopri = tester.getRect(find.text('SCOPRICI'));

      expect(accedi.overlaps(forgot), isFalse);
      expect(accedi.overlaps(registrati), isFalse);
      expect(forgot.contains(accedi.center), isFalse);
      expect(accedi.contains(forgot.center), isFalse);
      expect(scopri.overlaps(forgot), isFalse);
      expect(scopri.overlaps(accedi), isFalse);

      final gap = forgot.top - accedi.bottom;
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

      final before = _outerScrollPixels(tester);
      await tester.tap(find.text('SCOPRICI'));
      await _pumpScrollAnimation(tester);

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
      await _pumpScrollAnimation(tester);

      final after = _outerScrollPixels(tester);
      debugPrint(
        '[P0-C settle] before=$before after=$after '
        'max=${_outerScrollPosition(tester).maxScrollExtent}',
      );
      expect(after, greaterThan(before));
      expect(find.text('Scoprici'), findsOneWidget);
    });

    testWidgets('hero senza nested vertical scroll', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_welcomeHarness());
      await tester.pumpAndSettle();

      // Solo lo scroll esterno della Welcome (ClampingScrollPhysics).
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      debugPrint('[P0-C] hero inner scrollable present=false');
    });

    testWidgets('micro-drag SCOPRICI: tap con 2px drift', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await _pumpEarlyFrames(tester);
      final before = _outerScrollPixels(tester);
      final center = tester.getCenter(find.text('SCOPRICI'));

      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, 2));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await _pumpScrollAnimation(tester);

      final after = _outerScrollPixels(tester);
      final scrolled = after > before;
      debugPrint(
        '[P0-C micro-drag] scrolled=$scrolled '
        'before=$before after=$after '
        '(touchSlop=${kTouchSlop.toStringAsFixed(1)})',
      );
      // Con nested scroll rimosso, un drift 2px sotto touchSlop deve restare tap.
      expect(scrolled, isTrue);
    });
  });

  group('CTA geometry stability', () {
    testWidgets('delta Y CTA limitato durante startup', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(_welcomeHarness());
      await tester.pump();

      final samples = <String, List<double>>{
        'Accedi': <double>[],
        'Registrati': <double>[],
        'Forgot': <double>[],
        'Scopri': <double>[],
      };

      void sample() {
        final a = _ctaGlobalY(tester, find.text('Accedi'));
        final r = _ctaGlobalY(tester, find.text('Registrati'));
        final f = _ctaGlobalY(tester, find.text('Password dimenticata?'));
        final s = _ctaGlobalY(tester, find.text('SCOPRICI'));
        if (a != null) samples['Accedi']!.add(a);
        if (r != null) samples['Registrati']!.add(r);
        if (f != null) samples['Forgot']!.add(f);
        if (s != null) samples['Scopri']!.add(s);
      }

      sample();
      await tester.pump(const Duration(milliseconds: 50));
      sample();
      await tester.pump(const Duration(milliseconds: 100));
      sample();
      await tester.pump(const Duration(milliseconds: 300));
      sample();
      await tester.pump(const Duration(milliseconds: 700));
      sample();
      await tester.pumpAndSettle();
      sample();

      double maxDelta(List<double> ys) {
        if (ys.length < 2) return 0;
        var maxD = 0.0;
        final base = ys.first;
        for (final y in ys.skip(1)) {
          final d = (y - base).abs();
          if (d > maxD) maxD = d;
        }
        return maxD;
      }

      final deltas = <String, double>{
        for (final e in samples.entries) e.key: maxDelta(e.value),
      };

      debugPrint(
        '[CTA ΔY] Accedi=${deltas['Accedi']!.toStringAsFixed(1)} '
        'Registrati=${deltas['Registrati']!.toStringAsFixed(1)} '
        'Forgot=${deltas['Forgot']!.toStringAsFixed(1)} '
        'Scopri=${deltas['Scopri']!.toStringAsFixed(1)}',
      );

      // CTA ancorate in basso: nessun salto da reveal/nested scroll.
      // Soglia ampia per eventuali shift font (Google Fonts non toccati).
      for (final e in deltas.entries) {
        expect(
          e.value,
          lessThan(24),
          reason: '${e.key} deltaY=${e.value.toStringAsFixed(1)}',
        );
      }
    });
  });

  group('Viewport iPhone Welcome', () {
    for (final size in const [
      Size(375, 812),
      Size(390, 844),
      Size(393, 852),
      Size(430, 932),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()}: CTA visibili, no nested, no overlap',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() async {
            await tester.binding.setSurfaceSize(null);
          });

          await tester.pumpWidget(_welcomeHarness());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.byType(SingleChildScrollView), findsOneWidget);
          expect(find.text('Accedi'), findsOneWidget);
          expect(find.text('Registrati'), findsOneWidget);
          expect(find.text('Password dimenticata?'), findsOneWidget);
          expect(find.text('SCOPRICI'), findsOneWidget);

          final accedi = tester.getRect(find.text('Accedi'));
          final forgot = tester.getRect(find.text('Password dimenticata?'));
          final scopri = tester.getRect(find.text('SCOPRICI'));
          expect(accedi.overlaps(forgot), isFalse);
          expect(scopri.overlaps(forgot), isFalse);

          // CTA nel viewport.
          expect(accedi.top, greaterThanOrEqualTo(0));
          expect(scopri.bottom, lessThanOrEqualTo(size.height + 1));

          await tester.tap(find.text('SCOPRICI'));
          await _pumpScrollAnimation(tester);
          expect(_outerScrollPixels(tester), greaterThan(0));
        },
      );
    }
  });
}
