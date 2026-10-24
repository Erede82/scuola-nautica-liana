import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:tutor_liana_generator/tutor_generator.dart';

void main() {
  final png = Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
  ]);
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
  final html = Uint8List.fromList(utf8.encode('<html>not an image</html>'));

  test('a png path, image/png header, and png signature are accepted', () {
    final asset = validateFetchedQuizImage(
      path: 'figures/figura_10.png',
      statusCode: 200,
      contentType: 'image/png; charset=binary',
      bytes: png,
    );
    expect(asset.mediaType, 'image/png');
    expect(identical(asset.bytes, png), isTrue);
  });

  test('html with a png path is rejected', () {
    expect(
      () => validateFetchedQuizImage(
        path: 'figures/figure.png',
        statusCode: 200,
        contentType: 'text/html',
        bytes: html,
      ),
      throwsA(isA<TutorImageException>()),
    );
  });

  test('image/png with a non-png body is rejected', () {
    expect(
      () => validateFetchedQuizImage(
        path: 'figures/figura_10.png',
        statusCode: 200,
        contentType: 'image/png',
        bytes: html,
      ),
      throwsA(isA<TutorImageException>()),
    );
  });

  test('a png path does not accept a jpeg response', () {
    expect(
      () => validateFetchedQuizImage(
        path: 'figures/figura_10.png',
        statusCode: 200,
        contentType: 'image/jpeg',
        bytes: jpeg,
      ),
      throwsA(isA<TutorImageException>()),
    );
  });

  test('octet-stream and a missing content type fail closed', () {
    expect(
      () => validateFetchedQuizImage(
        path: 'figures/figura_10.png',
        statusCode: 200,
        contentType: 'application/octet-stream',
        bytes: png,
      ),
      throwsA(isA<TutorImageException>()),
    );
    expect(
      () => validateFetchedQuizImage(
        path: 'figures/figura_10.png',
        statusCode: 200,
        contentType: null,
        bytes: png,
      ),
      throwsA(isA<TutorImageException>()),
    );
  });
}
