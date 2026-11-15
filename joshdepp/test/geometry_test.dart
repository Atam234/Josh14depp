import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:joshdepp/engine/geometry.dart';
import 'package:joshdepp/engine/onnx_emap.dart';

void main() {
  test('similarity transform recovers a known rotation, scale and shift', () {
    final src = arcfaceTemplate(112);
    // dst = 2 * R(30deg) * src + (10, -5)
    const a = 1.7320508, b = 1.0; // 2cos30, 2sin30
    final dst = <double>[];
    for (var i = 0; i < 5; i++) {
      final x = src[i * 2], y = src[i * 2 + 1];
      dst
        ..add(a * x - b * y + 10)
        ..add(b * x + a * y - 5);
    }
    final m = estimateSimilarity(src, dst);
    expect(m.a, closeTo(a, 1e-6));
    expect(m.c, closeTo(b, 1e-6));
    expect(m.tx, closeTo(10, 1e-6));
    expect(m.ty, closeTo(-5, 1e-6));

    final inv = m.inverse();
    final x = m.mapX(3, 4), y = m.mapY(3, 4);
    expect(inv.mapX(x, y), closeTo(3, 1e-9));
    expect(inv.mapY(x, y), closeTo(4, 1e-9));
  });

  test('template for 128 matches insightface', () {
    final t = arcfaceTemplate(128);
    expect(t[0], closeTo(38.2946 * 128 / 128 + 8, 1e-9));
    expect(t[1], closeTo(51.6963, 1e-9));
  });

  test('half floats decode', () {
    expect(halfToDouble(0x3C00), 1.0);
    expect(halfToDouble(0xC000), -2.0);
    expect(halfToDouble(0x3555), closeTo(0.33325, 1e-4));
  });

  test('NV21 grey converts to grey and rotates', () {
    const w = 4, h = 2;
    final nv21 = Uint8List(w * h + w * h ~/ 2)..fillRange(0, w * h, 100);
    nv21.fillRange(w * h, nv21.length, 128);
    final f = nv21ToFrame(nv21, w, h, 90);
    expect(f.width, h);
    expect(f.height, w);
    expect(f.rgba.sublist(0, 4), [100, 100, 100, 255]);
  });

  test('warp then paste back with a full mask restores the image', () {
    final frame = Frame(64, 64, Uint8List(64 * 64 * 4));
    for (var i = 0; i < 64 * 64; i++) {
      frame.rgba[i * 4] = i % 64 * 4;
      frame.rgba[i * 4 + 1] = i ~/ 64 * 4;
      frame.rgba[i * 4 + 3] = 255;
    }
    final original = Uint8List.fromList(frame.rgba);
    const m = Affine(1, 0, -10, 0, 1, -10);
    final crop = warpToTensor(frame, m, 32, mean: 0, std: 255);
    final mask = Float32List(32 * 32)..fillRange(0, 32 * 32, 1);
    pasteBack(frame, m, crop, mask, 32);
    expect(frame.rgba, original);
  });
}
