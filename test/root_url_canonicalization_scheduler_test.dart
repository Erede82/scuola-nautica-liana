import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/services/root_url_canonicalizer.dart';

void main() {
  group('RootUrlCanonicalizationScheduler', () {
    testWidgets('root navigation: canonicalize deferred until post-frame', (
      tester,
    ) async {
      var calls = 0;
      final navKey = GlobalKey<NavigatorState>();
      final observer = RootUrlCanonicalizationObserver(
        scheduler: RootUrlCanonicalizationScheduler(
          canonicalize: ({required bool flutterRouteIsRoot}) => calls++,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          navigatorObservers: [observer],
          routes: {
            '/': (_) => const SizedBox(key: Key('root')),
            '/login': (_) => const SizedBox(key: Key('login')),
          },
          initialRoute: '/',
        ),
      );
      await tester.pump();

      navKey.currentState!.pushNamed('/login');
      await tester.pump();
      calls = 0;

      navKey.currentState!.pop();
      expect(calls, 0);
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('scheduled root skipped if route no longer current', (
      tester,
    ) async {
      var calls = 0;
      final navKey = GlobalKey<NavigatorState>();
      final scheduler = RootUrlCanonicalizationScheduler(
        canonicalize: ({required bool flutterRouteIsRoot}) => calls++,
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          routes: {
            '/': (_) => const SizedBox(key: Key('root')),
            '/login': (_) => const SizedBox(key: Key('login')),
          },
          initialRoute: '/',
        ),
      );
      await tester.pump();

      final rootRoute = ModalRoute.of(
        tester.element(find.byKey(const Key('root'))),
      )!;

      navKey.currentState!.pushNamed('/login');
      scheduler.schedule(rootRoute);
      await tester.pump();
      expect(calls, 0);
    });

    testWidgets('didPop login reveals root: canonicalize after frame', (
      tester,
    ) async {
      var calls = 0;
      final navKey = GlobalKey<NavigatorState>();
      final observer = RootUrlCanonicalizationObserver(
        scheduler: RootUrlCanonicalizationScheduler(
          canonicalize: ({required bool flutterRouteIsRoot}) => calls++,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          navigatorObservers: [observer],
          routes: {
            '/': (_) => const SizedBox(key: Key('root')),
            '/login': (_) => const SizedBox(key: Key('login')),
          },
          initialRoute: '/',
        ),
      );
      await tester.pump();

      navKey.currentState!.pushNamed('/login');
      await tester.pump();
      calls = 0;

      navKey.currentState!.pop();
      expect(calls, 0);
      await tester.pump();
      expect(calls, 1);
    });

    testWidgets('didRemove: root previous but not current skips canonicalize', (
      tester,
    ) async {
      var calls = 0;
      final navKey = GlobalKey<NavigatorState>();
      Route<dynamic>? middleRoute;
      final observer = RootUrlCanonicalizationObserver(
        scheduler: RootUrlCanonicalizationScheduler(
          canonicalize: ({required bool flutterRouteIsRoot}) => calls++,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          navigatorObservers: [observer],
          onGenerateRoute: (settings) {
            final route = MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => SizedBox(key: Key(settings.name ?? 'root')),
            );
            if (settings.name == '/middle') {
              middleRoute = route;
            }
            return route;
          },
          initialRoute: '/',
        ),
      );
      await tester.pump();
      calls = 0;

      navKey.currentState!.pushNamed('/middle');
      await tester.pump();
      navKey.currentState!.pushNamed('/top');
      await tester.pump();
      calls = 0;

      navKey.currentState!.removeRoute(middleRoute!);
      expect(calls, 0);
      await tester.pump();
      expect(calls, 0);
    });

    test('coalesces duplicate schedule into one pending post-frame slot', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final binding = TestWidgetsFlutterBinding.instance;
      final scheduler = RootUrlCanonicalizationScheduler(binding: binding);
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
      );

      scheduler.schedule(route);
      expect(scheduler.hasPendingPostFrameForTest, isTrue);
      scheduler.schedule(route);
      expect(scheduler.hasPendingPostFrameForTest, isTrue);
    });

    testWidgets('non-root push does not schedule canonicalization', (
      tester,
    ) async {
      var calls = 0;
      final navKey = GlobalKey<NavigatorState>();
      final observer = RootUrlCanonicalizationObserver(
        scheduler: RootUrlCanonicalizationScheduler(
          canonicalize: ({required bool flutterRouteIsRoot}) => calls++,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          navigatorObservers: [observer],
          routes: {
            '/': (_) => const SizedBox(key: Key('root')),
            '/login': (_) => const SizedBox(key: Key('login')),
          },
          initialRoute: '/',
        ),
      );
      await tester.pump();
      calls = 0;

      navKey.currentState!.pushNamed('/login');
      await tester.pump();
      expect(calls, 0);
    });
  });
}
