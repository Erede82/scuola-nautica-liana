import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Verifica statica asset/manifest/index PWA (senza deploy).
void main() {
  final root = Directory.current;

  File web(String relative) => File('${root.path}/web/$relative');

  test('icone PWA presenti con dimensioni attese', () {
    final expected = <String, (int, int)>{
      'favicon.png': (32, 32),
      'icons/Icon-192.png': (192, 192),
      'icons/Icon-512.png': (512, 512),
      'icons/Icon-maskable-192.png': (192, 192),
      'icons/Icon-maskable-512.png': (512, 512),
      'icons/apple-touch-icon.png': (180, 180),
      'icons/Icon-1024.png': (1024, 1024),
    };

    for (final entry in expected.entries) {
      final file = web(entry.key);
      expect(file.existsSync(), isTrue, reason: entry.key);
      final bytes = file.readAsBytesSync();
      expect(_isPng(bytes), isTrue, reason: '${entry.key} non è PNG');
      final size = _pngSize(bytes);
      expect(
        size,
        entry.value,
        reason: '${entry.key} size $size != ${entry.value}',
      );
    }
  });

  test('icone maskable distinte dalle standard', () {
    final standard512 = web('icons/Icon-512.png').readAsBytesSync();
    final maskable512 = web('icons/Icon-maskable-512.png').readAsBytesSync();
    final standard192 = web('icons/Icon-192.png').readAsBytesSync();
    final maskable192 = web('icons/Icon-maskable-192.png').readAsBytesSync();

    expect(standard512, isNot(equals(maskable512)));
    expect(standard192, isNot(equals(maskable192)));
  });

  test('icone PWA senza halo e con background #005E83', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    const bg = (0x00, 0x5E, 0x83);
    const white = (0xFF, 0xFF, 0xFF);

    for (final relative in [
      'icons/Icon-512.png',
      'icons/Icon-192.png',
      'icons/apple-touch-icon.png',
      'icons/Icon-maskable-512.png',
      'icons/Icon-maskable-192.png',
      'favicon.png',
    ]) {
      final pixels = await _loadRgbPixelsFromFile(web(relative));
      expect(
        pixels.every((px) => px == bg || px == white),
        isTrue,
        reason: '$relative contiene pixel di fringe',
      );
      expect(pixels.first, bg, reason: '$relative angolo non #005E83');
    }
  });

  test('manifest.json valido e installabile standalone', () {
    final raw = web('manifest.json').readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    expect(json['name'], 'Scuola Nautica Liana');
    expect(json['short_name'], 'Nautica Liana');
    expect(json['id'], '/');
    expect(json['start_url'], '/#/');
    expect(json['scope'], '/');
    expect(json['display'], 'standalone');
    expect(json['background_color'], '#F7F3ED');
    expect(json['theme_color'], '#005E83');
    expect(json.containsKey('orientation'), isFalse);

    final icons = (json['icons'] as List).cast<Map<String, dynamic>>();
    expect(icons, isNotEmpty);
    for (final icon in icons) {
      final src = icon['src'] as String;
      expect(web(src).existsSync(), isTrue, reason: 'icon missing: $src');
      expect(icon['type'], 'image/png');
      expect(icon['purpose'], anyOf('any', 'maskable'));
    }

    final purposes = icons.map((i) => i['purpose']).toSet();
    expect(purposes, containsAll(['any', 'maskable']));
  });

  test('index.html punta a branding Liana e meta iOS', () {
    final html = web('index.html').readAsStringSync();
    expect(html, contains('<title>Scuola Nautica Liana</title>'));
    expect(
      html,
      contains('content="Scuola Nautica Liana — area studenti e gestionale."'),
    );
    expect(
      html,
      contains(
        'name="viewport" content="width=device-width, initial-scale=1.0"',
      ),
    );
    expect(html, isNot(contains('viewport-fit=cover')));
    expect(html, contains('name="theme-color" content="#005E83"'));
    expect(html, contains('name="apple-mobile-web-app-capable" content="yes"'));
    expect(
      html,
      contains(
        'name="apple-mobile-web-app-status-bar-style" content="black-translucent"',
      ),
    );
    expect(
      html,
      contains('name="apple-mobile-web-app-title" content="Nautica Liana"'),
    );
    expect(html, contains('href="icons/apple-touch-icon.png"'));
    expect(html, contains('href="favicon.png"'));
    expect(html, contains('href="manifest.json"'));
    expect(html, isNot(contains('icons/Icon-192.png')));
    expect(html.toLowerCase(), isNot(contains('flutter demo')));
  });

  test('index.html splash è static Welcome shell (no blu pieno)', () {
    final html = web('index.html').readAsStringSync();
    expect(html, contains('id="liana-splash"'));
    expect(html, contains('flutter-first-frame'));
    expect(html, contains('pointer-events: none'));
    expect(
      html,
      contains('assets/assets/images/welcome/welcome_boat.jpg'),
    );
    expect(html, contains('assets/assets/branding/logo_mark_white.png'));
    expect(html, contains('background-color: #0A1620'));
    expect(html, isNot(contains('background-color: #005E83')));
    expect(html, isNot(contains('src="icons/Icon-512.png"')));
    expect(html, contains('env(safe-area-inset-top'));
    expect(html, contains('forgot-password'));
    expect(html, contains("+ '#/"));
    expect(html, contains('hashEmpty'));
    expect(html, contains('atRoot'));
    expect(html, isNot(contains('https://fonts.googleapis.com')));
    expect(html, isNot(contains('-webkit-only')));
    expect(html, isNot(contains('viewport-fit=cover')));
  });

  test('index.html splash Z1 — continuità visiva Welcome (snapshot iOS)', () {
    final html = web('index.html').readAsStringSync();

    for (final snippet in [
      'liana-splash',
      'welcome_boat',
      'logo_mark_white',
      'Scuola Nautica',
      'Liana',
      'Benvenuto',
      'Accedi',
      'Registrati',
      'Password dimenticata?',
      'SCOPRICI',
      'pointer-events: none',
      'flutter-first-frame',
    ]) {
      expect(html, contains(snippet), reason: snippet);
    }

    // NO-COVER: niente logo gigante 168px centrato come unica hero.
    expect(html, isNot(contains('width="168"')));
    expect(html, isNot(contains('width: min(42vw, 168px)')));

    // Gradient allineato alla Welcome (72 → 62 → 55 → 48).
    expect(html, contains('rgba(0, 0, 0, 0.72)'));
    expect(html, contains('rgba(0, 0, 0, 0.62)'));
    expect(html, contains('rgba(0, 0, 0, 0.55)'));
    expect(html, contains('rgba(0, 0, 0, 0.48)'));
    expect(html, contains('padding: 6px 12px'));
    expect(html, contains('box-sizing: border-box'));
    expect(html, contains('background-size: cover'));
  });

  test('asset Welcome boat e logo mark white presenti in sorgente', () {
    expect(
      File('${root.path}/assets/images/welcome/welcome_boat.jpg').existsSync(),
      isTrue,
    );
    expect(
      File('${root.path}/assets/branding/logo_mark_white.png').existsSync(),
      isTrue,
    );
  });

  test('nessun riferimento HTML alle icone Flutter template residue', () {
    final html = web('index.html').readAsStringSync();
    expect(html, isNot(contains('icons/Icon-192.png')));
    // Favicon deve essere PNG Liana (non 16×16 Flutter): già verificato sopra.
    final fav = web('favicon.png').readAsBytesSync();
    expect(_pngSize(fav), (32, 32));
  });
}

bool _isPng(List<int> bytes) {
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 24) return false;
  for (var i = 0; i < sig.length; i++) {
    if (bytes[i] != sig[i]) return false;
  }
  return true;
}

(int, int) _pngSize(List<int> bytes) {
  // IHDR: width/height big-endian at offset 16/20.
  final w =
      (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  final h =
      (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  return (w, h);
}

Future<List<(int, int, int)>> _loadRgbPixelsFromFile(File pngFile) async {
  final codec = await ui.instantiateImageCodec(pngFile.readAsBytesSync());
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(byteData, isNotNull);

  final out = <(int, int, int)>[];
  final bytes = byteData!.buffer.asUint8List();
  for (var i = 0; i < bytes.length; i += 4) {
    out.add((bytes[i], bytes[i + 1], bytes[i + 2]));
  }
  image.dispose();
  return out;
}
