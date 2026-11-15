import 'dart:io';
import 'dart:typed_data';

/// Reads the last initializer tensor of an ONNX file without loading the
/// whole model into memory.
///
/// The inswapper model stores the 512x512 "emap" matrix there; a source
/// face embedding has to be multiplied by it before it is fed to the model.
Future<Float32List> readLastInitializer(
  String path, {
  int? expectLength,
}) async {
  final file = await File(path).open();
  try {
    final reader = _Reader(file, await file.length());

    // ModelProto.graph is field 7.
    final graph = await reader.findLast(0, reader.length, 7);
    if (graph == null) {
      throw const FormatException('Not an ONNX model: no graph found');
    }
    // GraphProto.initializer is field 5 (repeated); we want the last one.
    final tensor = await reader.findLast(graph.start, graph.end, 5);
    if (tensor == null) {
      throw const FormatException('ONNX graph has no initializers');
    }

    // TensorProto: data_type = 2, float_data = 4, raw_data = 9.
    var dataType = 1;
    _Span? raw;
    _Span? floatData;
    await reader.walk(tensor.start, tensor.end, (field, wire, span, value) {
      if (field == 2 && wire == 0) dataType = value;
      if (field == 9 && wire == 2) raw = span;
      if (field == 4 && wire == 2) floatData = span;
    });

    final Float32List out;
    if (raw != null) {
      final bytes = await reader.read(raw!.start, raw!.end - raw!.start);
      final data = ByteData.sublistView(bytes);
      if (dataType == 1) {
        out = Float32List(bytes.length ~/ 4);
        for (var i = 0; i < out.length; i++) {
          out[i] = data.getFloat32(i * 4, Endian.little);
        }
      } else if (dataType == 10) {
        out = Float32List(bytes.length ~/ 2);
        for (var i = 0; i < out.length; i++) {
          out[i] = halfToDouble(data.getUint16(i * 2, Endian.little));
        }
      } else {
        throw FormatException('Unsupported initializer type $dataType');
      }
    } else if (floatData != null && dataType == 1) {
      final bytes = await reader.read(
        floatData!.start,
        floatData!.end - floatData!.start,
      );
      final data = ByteData.sublistView(bytes);
      out = Float32List(bytes.length ~/ 4);
      for (var i = 0; i < out.length; i++) {
        out[i] = data.getFloat32(i * 4, Endian.little);
      }
    } else {
      throw const FormatException('Initializer has no readable data');
    }

    if (expectLength != null && out.length != expectLength) {
      throw FormatException(
        'Unexpected initializer size ${out.length}, wanted $expectLength',
      );
    }
    return out;
  } finally {
    await file.close();
  }
}

/// Decodes an IEEE 754 half-precision value.
double halfToDouble(int h) {
  final sign = (h & 0x8000) != 0 ? -1.0 : 1.0;
  final exp = (h >> 10) & 0x1f;
  final frac = h & 0x3ff;
  if (exp == 0) return sign * frac * 5.960464477539063e-8; // 2^-24
  if (exp == 31) return frac == 0 ? sign * double.infinity : double.nan;
  var scale = 1.0;
  final e = exp - 15;
  if (e >= 0) {
    scale = (1 << e).toDouble();
  } else {
    scale = 1.0 / (1 << -e);
  }
  return sign * (1 + frac / 1024.0) * scale;
}

class _Span {
  const _Span(this.start, this.end);
  final int start;
  final int end;
}

typedef _FieldVisitor = void Function(
  int field,
  int wire,
  _Span span,
  int value,
);

class _Reader {
  _Reader(this.file, this.length);

  final RandomAccessFile file;
  final int length;

  Future<Uint8List> read(int offset, int count) async {
    await file.setPosition(offset);
    return file.read(count);
  }

  /// Visits each top-level field of the message stored in [start, end).
  Future<void> walk(int start, int end, _FieldVisitor visit) async {
    var pos = start;
    while (pos < end) {
      // A key plus a length varint never needs more than 20 bytes.
      final head = await read(pos, end - pos < 20 ? end - pos : 20);
      var i = 0;
      int varint() {
        var result = 0;
        var shift = 0;
        while (true) {
          final byte = head[i++];
          result |= (byte & 0x7f) << shift;
          if (byte & 0x80 == 0) return result;
          shift += 7;
        }
      }

      final key = varint();
      final field = key >> 3;
      final wire = key & 7;
      switch (wire) {
        case 0:
          final value = varint();
          visit(field, wire, _Span(pos, pos + i), value);
          pos += i;
        case 1:
          visit(field, wire, _Span(pos + i, pos + i + 8), 0);
          pos += i + 8;
        case 2:
          final size = varint();
          visit(field, wire, _Span(pos + i, pos + i + size), size);
          pos += i + size;
        case 5:
          visit(field, wire, _Span(pos + i, pos + i + 4), 0);
          pos += i + 4;
        default:
          throw FormatException('Unsupported protobuf wire type $wire');
      }
    }
  }

  Future<_Span?> findLast(int start, int end, int wanted) async {
    _Span? found;
    await walk(start, end, (field, wire, span, _) {
      if (field == wanted && wire == 2) found = span;
    });
    return found;
  }
}
