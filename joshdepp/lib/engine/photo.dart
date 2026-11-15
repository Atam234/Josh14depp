import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'geometry.dart';

/// A photo prepared for the pipeline: an upright, size-limited JPEG on disk
/// (for the face detector) plus the same pixels in memory.
class LoadedPhoto {
  LoadedPhoto(this.path, this.frame);

  final String path;
  final Frame frame;
}

const _maxSide = 1600;

/// Decodes [sourcePath], applies its EXIF rotation, limits its size and
/// writes the normalised copy to [outPath].
Future<LoadedPhoto> loadPhoto(String sourcePath, String outPath) async {
  final result = await compute(_decode, [sourcePath, outPath]);
  if (result == null) {
    throw const FormatException('That file is not a readable image');
  }
  return LoadedPhoto(
    outPath,
    Frame(result[0] as int, result[1] as int, result[2] as Uint8List),
  );
}

List<Object>? _decode(List<String> args) {
  final decoded = img.decodeImage(File(args[0]).readAsBytesSync());
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  if (image.width > _maxSide || image.height > _maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: _maxSide)
        : img.copyResize(image, height: _maxSide);
  }
  File(args[1]).writeAsBytesSync(img.encodeJpg(image, quality: 95));
  final rgba = image
      .convert(format: img.Format.uint8, numChannels: 4)
      .getBytes(order: img.ChannelOrder.rgba);
  return [image.width, image.height, rgba];
}

/// Encodes [frame] as a JPEG file at [path]. With [label] set, a small
/// "AI generated" mark is drawn in the bottom-left corner.
Future<void> saveFrame(Frame frame, String path, {bool label = false}) {
  return compute(_encode, [frame.width, frame.height, frame.rgba, path, label]);
}

void _encode(List<Object> args) {
  final image = img.Image.fromBytes(
    width: args[0] as int,
    height: args[1] as int,
    bytes: (args[2] as Uint8List).buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  if (args[4] as bool) {
    const text = 'AI generated';
    final font = image.width >= 900 ? img.arial24 : img.arial14;
    final y = image.height - font.lineHeight - 12;
    img.drawString(
      image,
      text,
      font: font,
      x: 13,
      y: y + 1,
      color: img.ColorRgba8(0, 0, 0, 160),
    );
    img.drawString(
      image,
      text,
      font: font,
      x: 12,
      y: y,
      color: img.ColorRgba8(255, 255, 255, 220),
    );
  }
  File(args[3] as String).writeAsBytesSync(img.encodeJpg(image, quality: 92));
}
