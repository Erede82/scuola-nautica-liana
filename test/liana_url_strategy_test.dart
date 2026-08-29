import 'package:flutter_test/flutter_test.dart';
import 'package:scuola_nautica_liana/services/liana_url_strategy.dart';

void main() {
  group('prepareLianaHashExternalUrl', () {
    test('root "/" → "/#/"', () {
      expect(
        prepareLianaHashExternalUrl(
          internalUrl: '/',
          pathname: '/',
          search: '',
        ),
        '/#/',
      );
    });

    test('root "" → "/#/"', () {
      expect(
        prepareLianaHashExternalUrl(
          internalUrl: '',
          pathname: '/',
          search: '',
        ),
        '/#/',
      );
    });

    test('root external is never hashless "/"', () {
      final external = prepareLianaHashExternalUrl(
        internalUrl: '/',
        pathname: '/',
        search: '',
      );
      expect(external, isNot('/'));
      expect(external, contains('#/'));
    });

    test('login → "/#/login"', () {
      expect(
        prepareLianaHashExternalUrl(
          internalUrl: '/login',
          pathname: '/',
          search: '',
        ),
        '/#/login',
      );
    });

    test('register → "/#/register"', () {
      expect(
        prepareLianaHashExternalUrl(
          internalUrl: '/register',
          pathname: '/',
          search: '',
        ),
        '/#/register',
      );
    });

    test('forgot-password → "/#/forgot-password"', () {
      expect(
        prepareLianaHashExternalUrl(
          internalUrl: '/forgot-password',
          pathname: '/',
          search: '',
        ),
        '/#/forgot-password',
      );
    });

    test('preserves query on root', () {
      expect(
        prepareLianaHashExternalUrl(
          internalUrl: '/',
          pathname: '/',
          search: '?foo=bar',
        ),
        '/?foo=bar#/',
      );
    });

    test('preserves query on non-root', () {
      expect(
        prepareLianaHashExternalUrl(
          internalUrl: '/login',
          pathname: '/',
          search: '?foo=bar',
        ),
        '/?foo=bar#/login',
      );
    });
  });
}
