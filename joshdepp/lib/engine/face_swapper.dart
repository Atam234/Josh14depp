import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'face_finder.dart';
import 'geometry.dart';
import 'model_store.dart';
import 'onnx_emap.dart';

/// Runs the Deep-Live-Cam pipeline on the device:
/// ArcFace turns the source face into an identity vector, and inswapper
/// redraws each target face with that identity.
class FaceSwapper {
  FaceSwapper._();
  static final FaceSwapper instance = FaceSwapper._();

  static const _cropSize = 128;
  static const _embedSize = 112;
  static const _latentSize = 512;

  final _ort = OnnxRuntime();
  final _template128 = arcfaceTemplate(_cropSize);
  final _template112 = arcfaceTemplate(_embedSize);
  final _mask = featherMask(_cropSize);

  OrtSession? _swapper;
  Float32List? _emap;

  bool get loaded => _swapper != null;

  /// Loads the swapper model. Safe to call more than once.
  Future<void> load() async {
    if (_swapper != null) return;
    final path = ModelStore.instance.pathOf(swapperModel);
    _emap ??= await readLastInitializer(
      path,
      expectLength: _latentSize * _latentSize,
    );
    _swapper = await _ort.createSession(
      path,
      options: OrtSessionOptions(intraOpNumThreads: 4),
    );
  }

  Future<void> unload() async {
    await _swapper?.close();
    _swapper = null;
  }

  /// Builds the identity vector for the face in [frame].
  ///
  /// The recognizer model is only kept in memory for the duration of this
  /// call, since it is needed once per source face.
  Future<Float32List> identityOf(Frame frame, FoundFace face) async {
    await load();
    final toCrop = estimateSimilarity(face.points, _template112);
    final input = warpToTensor(
      frame,
      toCrop,
      _embedSize,
      mean: 127.5,
      std: 127.5,
    );
    final session = await _ort.createSession(
      ModelStore.instance.pathOf(recognizerModel),
      options: OrtSessionOptions(intraOpNumThreads: 4),
    );
    try {
      final tensor = await OrtValue.fromList(input, [
        1,
        3,
        _embedSize,
        _embedSize,
      ]);
      try {
        final outputs = await session.run({session.inputNames.first: tensor});
        final embedding = await _floats(outputs.values.first);
        for (final value in outputs.values) {
          await value.dispose();
        }
        normalize(embedding);
        // latent = embedding . emap, then normalised again.
        final emap = _emap!;
        final latent = Float32List(_latentSize);
        for (var j = 0; j < _latentSize; j++) {
          var sum = 0.0;
          for (var i = 0; i < _latentSize; i++) {
            sum += embedding[i] * emap[i * _latentSize + j];
          }
          latent[j] = sum;
        }
        return normalize(latent);
      } finally {
        await tensor.dispose();
      }
    } finally {
      await session.close();
    }
  }

  /// Replaces [face] in [frame] (in place) with the given identity.
  Future<void> swap(Frame frame, FoundFace face, Float32List identity) async {
    await load();
    final session = _swapper!;
    final toCrop = estimateSimilarity(face.points, _template128);
    final input = warpToTensor(frame, toCrop, _cropSize, mean: 0, std: 255);
    final target = await OrtValue.fromList(input, [1, 3, _cropSize, _cropSize]);
    final source = await OrtValue.fromList(identity, [1, _latentSize]);
    try {
      final outputs = await session.run({
        session.inputNames[0]: target,
        session.inputNames[1]: source,
      });
      final generated = await _floats(outputs.values.first);
      for (final value in outputs.values) {
        await value.dispose();
      }
      for (var i = 0; i < generated.length; i++) {
        final v = generated[i];
        generated[i] = v < 0 ? 0 : (v > 1 ? 1 : v);
      }
      pasteBack(frame, toCrop, generated, _mask, _cropSize);
    } finally {
      await target.dispose();
      await source.dispose();
    }
  }

  Future<Float32List> _floats(OrtValue value) async {
    final data = await value.asFlattenedList();
    // Data from the plugin is read-only, so always work on a copy.
    if (data is Float32List) return Float32List.fromList(data);
    final out = Float32List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = (data[i] as num).toDouble();
    }
    return out;
  }
}
