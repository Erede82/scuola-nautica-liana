import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/services/root_url_canonicalizer.dart';

void main() {
  group('shouldCanonicalizeRootUrl', () {
    test('root hashless pathname="/" hash="" auth=false → true', () {
      expect(
        RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
          pathname: '/',
          hash: '',
          search: '',
          flutterRouteIsRoot: true,
        ),
        isTrue,
      );
    });

    test('root hash="#" → true', () {
      expect(
        RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
          pathname: '/',
          hash: '#',
          search: '',
          flutterRouteIsRoot: true,
        ),
        isTrue,
      );
    });

    test('già canonico hash="#/" → false', () {
      expect(
        RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
          pathname: '/',
          hash: '#/',
          search: '',
          flutterRouteIsRoot: true,
        ),
        isFalse,
      );
    });

    test('login hash="#/login" → false', () {
      expect(
        RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
          pathname: '/',
          hash: '#/login',
          search: '',
          flutterRouteIsRoot: true,
        ),
        isFalse,
      );
    });

    test('register hash="#/register" → false', () {
      expect(
        RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
          pathname: '/',
          hash: '#/register',
          search: '',
          flutterRouteIsRoot: true,
        ),
        isFalse,
      );
    });

    test('forgot hash="#/forgot-password" → false', () {
      expect(
        RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
          pathname: '/',
          hash: '#/forgot-password',
          search: '',
          flutterRouteIsRoot: true,
        ),
        isFalse,
      );
    });

    test('auth payload → false', () {
      expect(
        RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
          pathname: '/',
          hash: '#access_token=secret',
          search: '',
          flutterRouteIsRoot: true,
        ),
        isFalse,
      );
    });

    test('recovery payload → false', () {
      expect(
        RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
          pathname: '/',
          hash: '',
          search: '?type=recovery&access_token=abc',
          flutterRouteIsRoot: true,
        ),
        isFalse,
      );
    });

    test('Flutter non root → false anche se hashless', () {
      expect(
        RootUrlCanonicalizer.shouldCanonicalizeRootUrl(
          pathname: '/',
          hash: '',
          search: '',
          flutterRouteIsRoot: false,
        ),
        isFalse,
      );
    });
  });

  group('idempotenza', () {
    test('due valutazioni consecutive: prima replace, poi no-op', () {
      const args = (
        pathname: '/',
        hash: '',
        search: '',
        flutterRouteIsRoot: true,
      );

      expect(
        RootUrlCanonicalizer.plannedAction(
          pathname: args.pathname,
          hash: args.hash,
          search: args.search,
          flutterRouteIsRoot: args.flutterRouteIsRoot,
        ),
        RootCanonicalizeAction.replace,
      );

      expect(
        RootUrlCanonicalizer.plannedAction(
          pathname: args.pathname,
          hash: '#/',
          search: args.search,
          flutterRouteIsRoot: args.flutterRouteIsRoot,
        ),
        RootCanonicalizeAction.none,
      );
    });
  });

  group('replace vs push', () {
    test('azione pianificata è replace, non push', () {
      expect(
        RootUrlCanonicalizer.plannedAction(
          pathname: '/',
          hash: '',
          search: '',
          flutterRouteIsRoot: true,
        ),
        RootCanonicalizeAction.replace,
      );
      expect(
        RootUrlCanonicalizer.buildCanonicalRootReplaceUrl(
          pathname: '/',
          search: '',
        ),
        '/#/',
      );
    });

    test('preserva query in replace URL', () {
      expect(
        RootUrlCanonicalizer.buildCanonicalRootReplaceUrl(
          pathname: '/',
          search: '?foo=bar',
        ),
        '/?foo=bar#/',
      );
    });
  });

  group('isFlutterRootRoute', () {
    test('route senza name è root', () {
      final route = MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
      );
      expect(RootUrlCanonicalizer.isFlutterRootRoute(route), isTrue);
    });

    test('/login non è root', () {
      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/login'),
        builder: (_) => const SizedBox.shrink(),
      );
      expect(RootUrlCanonicalizer.isFlutterRootRoute(route), isFalse);
    });
  });
}
