import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// A detected face: five key points in image pixels, ordered the way the
/// ArcFace template expects (image-left eye, image-right eye, nose,
/// image-left mouth corner, image-right mouth corner).
class FoundFace {
  FoundFace(this.points, this.area);

  final List<double> points;
  final double area;
}

/// Finds faces and their key points with on-device ML Kit.
class FaceFinder {
  FaceFinder({bool fast = false})
    : _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          performanceMode: fast
              ? FaceDetectorMode.fast
              : FaceDetectorMode.accurate,
          minFaceSize: fast ? 0.2 : 0.08,
        ),
      );

  final FaceDetector _detector;

  /// Faces in an image file, largest first.
  Future<List<FoundFace>> inFile(String path) =>
      _run(InputImage.fromFilePath(path));

  /// Faces in a raw camera buffer. Coordinates are returned for the
  /// upright image, i.e. after applying [rotation].
  Future<List<FoundFace>> inCameraBytes(
    Uint8List bytes, {
    required int width,
    required int height,
    required int rotation,
    required InputImageFormat format,
    required int bytesPerRow,
  }) {
    return _run(
      InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation:
              InputImageRotationValue.fromRawValue(rotation) ??
              InputImageRotation.rotation0deg,
          format: format,
          bytesPerRow: bytesPerRow,
        ),
      ),
    );
  }

  Future<List<FoundFace>> _run(InputImage image) async {
    final faces = await _detector.processImage(image);
    final found = <FoundFace>[];
    for (final face in faces) {
      final points = _keyPoints(face);
      if (points == null) continue;
      final box = face.boundingBox;
      found.add(FoundFace(points, box.width * box.height));
    }
    found.sort((a, b) => b.area.compareTo(a.area));
    return found;
  }

  List<double>? _keyPoints(Face face) {
    math.Point<int>? at(FaceLandmarkType type) =>
        face.landmarks[type]?.position;
    final eyeA = at(FaceLandmarkType.leftEye);
    final eyeB = at(FaceLandmarkType.rightEye);
    final nose = at(FaceLandmarkType.noseBase);
    final mouthA = at(FaceLandmarkType.leftMouth);
    final mouthB = at(FaceLandmarkType.rightMouth);
    if (eyeA == null ||
        eyeB == null ||
        nose == null ||
        mouthA == null ||
        mouthB == null) {
      return null;
    }
    // "Left" and "right" differ between detectors, so order by position.
    final eyes = [eyeA, eyeB]..sort((a, b) => a.x.compareTo(b.x));
    final mouth = [mouthA, mouthB]..sort((a, b) => a.x.compareTo(b.x));
    return [
      for (final p in [eyes[0], eyes[1], nose, mouth[0], mouth[1]]) ...[
        p.x.toDouble(),
        p.y.toDouble(),
      ],
    ];
  }

  Future<void> close() => _detector.close();
}
