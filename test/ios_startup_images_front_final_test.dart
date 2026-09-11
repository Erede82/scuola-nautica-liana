import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current;
  File web(String relative) => File('${root.path}/web/$relative');

  const capri = (0x00, 0xBF, 0xFF);

  final specs = <String, (int, int, String)>{
    'icons/startup/launch-1125x2436.png': (1125, 2436, '375x812'),
    'icons/startup/launch-1170x2532.png': (1170, 2532, '390x844'),
    'icons/startup/launch-1179x2556.png': (1179, 2556, '393x852'),
    'icons/startup/launch-1206x2622.png': (1206, 2622, '402x874'),
    'icons/startup/launch-1242x2688.png': (1242, 2688, '414x896'),
    'icons/startup/launch-1284x2778.png': (1284, 2778, '428x926'),
    'icons/startup/launch-1290x2796.png': (1290, 2796, '430x932'),
  };

  test('STARTUP.DECISIVE apple PNG = Capri + logo + title', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final entry in specs.entries) {
      final file = web(entry.key);
      expect(file.existsSync(), isTrue, reason: entry.key);
      final bytes = file.readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      expect(image.width, entry.value.$1, reason: entry.key);
      expect(image.height, entry.value.$2, reason: entry.key);

      final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bd, isNotNull);
      final px = bd!.buffer.asUint8List();
      for (final offset in [
        0,
        (image.width - 1) * 4,
        ((image.height - 1) * image.width) * 4,
      ]) {
        expect(px[offset], capri.$1, reason: '${entry.key} R@$offset');
        expect(px[offset + 1], capri.$2, reason: '${entry.key} G@$offset');
        expect(px[offset + 2], capri.$3, reason: '${entry.key} B@$offset');
      }
      var nonCapri = 0;
      final cy = image.height ~/ 2;
      final cx = image.width ~/ 2;
      for (var dy = -120; dy <= 120; dy += 8) {
        for (var dx = -120; dx <= 120; dx += 8) {
          final x = cx + dx;
          final y = cy + dy;
          if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
          final o = (y * image.width + x) * 4;
          if (px[o] != capri.$1 ||
              px[o + 1] != capri.$2 ||
              px[o + 2] != capri.$3) {
            nonCapri++;
          }
        }
      }
      expect(nonCapri, greaterThan(30), reason: '${entry.key} no brand pixels');
      image.dispose();
    }
  });

  test('STARTUP.DECISIVE index theme Capri + matrix', () {
    final html = web('index.html').readAsStringSync();
    expect(html, contains('name="theme-color" content="#005E83"'));
    expect(html, contains('liana-splash-title'));
    for (final path in specs.keys) {
      expect(html, contains(path), reason: path);
    }
  });
}
