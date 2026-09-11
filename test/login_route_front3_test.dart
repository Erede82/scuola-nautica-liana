import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/app.dart';

void main() {
  test('FRONT.3 — /login web: transitionDuration zero', () {
    final route = generateAppRoute(
      const RouteSettings(name: '/login'),
      zeroLoginTransition: true,
    );
    expect(route, isA<PageRouteBuilder<void>>());
    final pageRoute = route! as PageRouteBuilder<void>;
    expect(pageRoute.settings.name, '/login');
    expect(pageRoute.transitionDuration, Duration.zero);
    expect(pageRoute.reverseTransitionDuration, Duration.zero);
  });

  test('FRONT.3 — /login native: MaterialPageRoute (transizione Material)', () {
    final route = generateAppRoute(
      const RouteSettings(name: '/login'),
      zeroLoginTransition: false,
    );
    expect(route, isA<MaterialPageRoute<void>>());
    expect(route, isNot(isA<PageRouteBuilder<void>>()));
    expect(route!.settings.name, '/login');
  });

  test('FRONT.3 — /register e /forgot-password invariate (Material)', () {
    for (final name in ['/register', '/forgot-password']) {
      final route = generateAppRoute(
        RouteSettings(name: name),
        zeroLoginTransition: true,
      );
      expect(route, isA<MaterialPageRoute<void>>(), reason: name);
      expect(route, isNot(isA<PageRouteBuilder<void>>()), reason: name);
      expect(route!.settings.name, name);
    }
  });

  test('FRONT.3 — route sconosciuta → null', () {
    expect(
      generateAppRoute(const RouteSettings(name: '/unknown')),
      isNull,
    );
  });
}
