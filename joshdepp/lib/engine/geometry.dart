import 'dart:math' as math;
import 'dart:typed_data';

/// An upright RGBA8888 image held in memory.
class Frame {
  Frame(this.width, this.height, this.rgba)
    : assert(rgba.length == width * height * 4);

  final int width;
  final int height;
  final Uint8List rgba;
}

/// A 2x3 affine matrix: x' = a*x + b*y + tx, y' = c*x + d*y + ty.
class Affine {
  const Affine(this.a, this.b, this.tx, this.c, this.d, this.ty);

  final double a, b, tx, c, d, ty;

  double mapX(double x, double y) => a * x + b * y + tx;
  double mapY(double x, double y) => c * x + d * y + ty;

  Affine inverse() {
    final det = a * d - b * c;
    final ia = d / det, ib = -b / det, ic = -c / det, id = a / det;
    return Affine(ia, ib, -(ia * tx + ib * ty), ic, id, -(ic * tx + id * ty));
  }
}

/// The five-point ArcFace template for a 112x112 crop
/// (left eye, right eye, nose, left mouth corner, right mouth corner).
const List<double> arcfaceTemplate112 = [
  38.2946, 51.6963, //
  73.5318, 51.5014, //
  56.0252, 71.7366, //
  41.5493, 92.3655, //
  70.7299, 92.2041, //
];

/// Template for a crop of [size] pixels, matching insightface's estimate_norm.
List<double> arcfaceTemplate(int size) {
  final double ratio;
  final double dx;
  if (size % 112 == 0) {
    ratio = size / 112.0;
    dx = 0;
  } else {
    ratio = size / 128.0;
    dx = 8.0 * ratio;
  }
  final out = List<double>.filled(10, 0);
  for (var i = 0; i < 5; i++) {
    out[i * 2] = arcfaceTemplate112[i * 2] * ratio + dx;
    out[i * 2 + 1] = arcfaceTemplate112[i * 2 + 1] * ratio;
  }
  return out;
}

/// Least-squares similarity transform (rotation, uniform scale, translation)
/// mapping [src] points onto [dst] points. Both are flat x,y lists.
Affine estimateSimilarity(List<double> src, List<double> dst) {
  final n = src.length ~/ 2;
  var sx = 0.0, sy = 0.0, dx = 0.0, dy = 0.0;
  for (var i = 0; i < n; i++) {
    sx += src[i * 2];
    sy += src[i * 2 + 1];
    dx += dst[i * 2];
    dy += dst[i * 2 + 1];
  }
  sx /= n;
  sy /= n;
  dx /= n;
  dy /= n;

  var dot = 0.0, cross = 0.0, norm = 0.0;
  for (var i = 0; i < n; i++) {
    final px = src[i * 2] - sx, py = src[i * 2 + 1] - sy;
    final qx = dst[i * 2] - dx, qy = dst[i * 2 + 1] - dy;
    dot += px * qx + py * qy;
    cross += px * qy - py * qx;
    norm += px * px + py * py;
  }
  if (norm < 1e-9) {
    return Affine(1, 0, dx - sx, 0, 1, dy - sy);
  }
  final a = dot / norm;
  final b = cross / norm;
  return Affine(a, -b, dx - (a * sx - b * sy), b, a, dy - (b * sx + a * sy));
}

/// Samples an aligned [size]x[size] crop out of [frame] as a planar RGB
/// float tensor (NCHW without the batch axis): value = (pixel - mean) / std.
Float32List warpToTensor(
  Frame frame,
  Affine frameToCrop,
  int size, {
  required double mean,
  required double std,
}) {
  final inv = frameToCrop.inverse();
  final out = Float32List(3 * size * size);
  final plane = size * size;
  final w = frame.width, h = frame.height;
  final px = frame.rgba;
  final fill = (0 - mean) / std;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final fx = inv.mapX(x.toDouble(), y.toDouble());
      final fy = inv.mapY(x.toDouble(), y.toDouble());
      final o = y * size + x;
      if (fx < 0 || fy < 0 || fx > w - 1 || fy > h - 1) {
        out[o] = fill;
        out[plane + o] = fill;
        out[2 * plane + o] = fill;
        continue;
      }
      final x0 = fx.floor(), y0 = fy.floor();
      final x1 = math.min(x0 + 1, w - 1), y1 = math.min(y0 + 1, h - 1);
      final ax = fx - x0, ay = fy - y0;
      final w00 = (1 - ax) * (1 - ay), w10 = ax * (1 - ay);
      final w01 = (1 - ax) * ay, w11 = ax * ay;
      final i00 = (y0 * w + x0) * 4, i10 = (y0 * w + x1) * 4;
      final i01 = (y1 * w + x0) * 4, i11 = (y1 * w + x1) * 4;
      for (var c = 0; c < 3; c++) {
        final v =
            px[i00 + c] * w00 +
            px[i10 + c] * w10 +
            px[i01 + c] * w01 +
            px[i11 + c] * w11;
        out[c * plane + o] = (v - mean) / std;
      }
    }
  }
  return out;
}

/// Soft-edged square mask for a [size]x[size] crop: 1 in the middle, fading
/// to 0 toward the border so a pasted face blends into its surroundings.
Float32List featherMask(int size) {
  final mask = Float32List(size * size);
  final inset = size * 0.04;
  final feather = size * 0.14;
  double ramp(double d) {
    final t = ((d - inset) / feather).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  for (var y = 0; y < size; y++) {
    final my = ramp(math.min(y, size - 1 - y).toDouble());
    for (var x = 0; x < size; x++) {
      final mx = ramp(math.min(x, size - 1 - x).toDouble());
      mask[y * size + x] = mx * my;
    }
  }
  return mask;
}

/// Blends a generated face crop (planar RGB floats in 0..1) back into
/// [frame] in place, using [mask] for the alpha.
void pasteBack(
  Frame frame,
  Affine frameToCrop,
  Float32List face,
  Float32List mask,
  int size,
) {
  final inv = frameToCrop.inverse();
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  final s = (size - 1).toDouble();
  for (final corner in const [
    [0.0, 0.0],
    [1.0, 0.0],
    [0.0, 1.0],
    [1.0, 1.0],
  ]) {
    final x = inv.mapX(corner[0] * s, corner[1] * s);
    final y = inv.mapY(corner[0] * s, corner[1] * s);
    minX = math.min(minX, x);
    maxX = math.max(maxX, x);
    minY = math.min(minY, y);
    maxY = math.max(maxY, y);
  }
  final x0 = math.max(0, minX.floor());
  final y0 = math.max(0, minY.floor());
  final x1 = math.min(frame.width - 1, maxX.ceil());
  final y1 = math.min(frame.height - 1, maxY.ceil());
  final plane = size * size;
  final px = frame.rgba;

  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final cx = frameToCrop.mapX(x.toDouble(), y.toDouble());
      final cy = frameToCrop.mapY(x.toDouble(), y.toDouble());
      if (cx < 0 || cy < 0 || cx > s || cy > s) continue;
      final ix = cx.floor(), iy = cy.floor();
      final jx = math.min(ix + 1, size - 1), jy = math.min(iy + 1, size - 1);
      final ax = cx - ix, ay = cy - iy;
      final w00 = (1 - ax) * (1 - ay), w10 = ax * (1 - ay);
      final w01 = (1 - ax) * ay, w11 = ax * ay;
      final i00 = iy * size + ix, i10 = iy * size + jx;
      final i01 = jy * size + ix, i11 = jy * size + jx;
      final alpha =
          mask[i00] * w00 + mask[i10] * w10 + mask[i01] * w01 + mask[i11] * w11;
      if (alpha <= 0.001) continue;
      final o = (y * frame.width + x) * 4;
      for (var c = 0; c < 3; c++) {
        final p = c * plane;
        final v =
            (face[p + i00] * w00 +
                face[p + i10] * w10 +
                face[p + i01] * w01 +
                face[p + i11] * w11) *
            255.0;
        final blended = px[o + c] * (1 - alpha) + v * alpha;
        px[o + c] = blended.round().clamp(0, 255);
      }
    }
  }
}

/// L2-normalises [v] in place and returns it.
Float32List normalize(Float32List v) {
  var sum = 0.0;
  for (final x in v) {
    sum += x * x;
  }
  final n = math.sqrt(sum);
  if (n > 0) {
    for (var i = 0; i < v.length; i++) {
      v[i] = v[i] / n;
    }
  }
  return v;
}

/// Converts NV21 camera bytes into an upright RGBA [Frame], rotating
/// clockwise by [rotation] degrees (0, 90, 180 or 270).
Frame nv21ToFrame(
  Uint8List nv21,
  int width,
  int height,
  int rotation, {
  int? rowStride,
}) {
  final stride = rowStride ?? width;
  final swap = rotation == 90 || rotation == 270;
  final ow = swap ? height : width;
  final oh = swap ? width : height;
  final out = Uint8List(ow * oh * 4);
  final uvStart = stride * height;
  for (var y = 0; y < height; y++) {
    final uvRow = uvStart + (y >> 1) * stride;
    for (var x = 0; x < width; x++) {
      final yy = nv21[y * stride + x];
      final uvIndex = uvRow + (x & ~1);
      final v = nv21[uvIndex] - 128;
      final u = nv21[uvIndex + 1] - 128;
      final r = (yy + 1.402 * v).round().clamp(0, 255);
      final g = (yy - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
      final b = (yy + 1.772 * u).round().clamp(0, 255);
      final int dx, dy;
      switch (rotation) {
        case 90:
          dx = height - 1 - y;
          dy = x;
        case 180:
          dx = width - 1 - x;
          dy = height - 1 - y;
        case 270:
          dx = y;
          dy = width - 1 - x;
        default:
          dx = x;
          dy = y;
      }
      final o = (dy * ow + dx) * 4;
      out[o] = r;
      out[o + 1] = g;
      out[o + 2] = b;
      out[o + 3] = 255;
    }
  }
  return Frame(ow, oh, out);
}

/// Converts BGRA camera bytes (iOS) into an upright RGBA [Frame].
Frame bgraToFrame(
  Uint8List bgra,
  int width,
  int height,
  int rotation,
  int rowStride,
) {
  final swap = rotation == 90 || rotation == 270;
  final ow = swap ? height : width;
  final oh = swap ? width : height;
  final out = Uint8List(ow * oh * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * rowStride + x * 4;
      final int dx, dy;
      switch (rotation) {
        case 90:
          dx = height - 1 - y;
          dy = x;
        case 180:
          dx = width - 1 - x;
          dy = height - 1 - y;
        case 270:
          dx = y;
          dy = width - 1 - x;
        default:
          dx = x;
          dy = y;
      }
      final o = (dy * ow + dx) * 4;
      out[o] = bgra[i + 2];
      out[o + 1] = bgra[i + 1];
      out[o + 2] = bgra[i];
      out[o + 3] = 255;
    }
  }
  return Frame(ow, oh, out);
}
