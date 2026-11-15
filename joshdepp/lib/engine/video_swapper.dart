import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app_state.dart';
import 'face_finder.dart';
import 'face_swapper.dart';
import 'geometry.dart';
import 'photo.dart';

enum VideoStage { idle, reading, swapping, building }

/// Swaps the source face into every frame of a video.
///
/// The video is split into frames with FFmpeg, each frame goes through the
/// same pipeline as Photo Swap, and the frames are joined again with the
/// original sound.
class VideoSwapper extends ChangeNotifier {
  VideoSwapper._();
  static final VideoSwapper instance = VideoSwapper._();

  /// Longest part of a video that is processed, counted from its start.
  static const maxSeconds = 60;
  static const _maxFps = 24.0;
  static const _maxSide = 960;

  VideoStage stage = VideoStage.idle;
  int done = 0;
  int total = 0;
  int swappedFrames = 0;
  String? previewPath;
  DateTime? _swapStarted;
  bool _cancelled = false;

  bool get running => stage != VideoStage.idle;

  double get progress => total == 0 ? 0 : done / total;

  /// Estimated time left for the swapping stage.
  Duration? get remaining {
    final started = _swapStarted;
    if (started == null || done < 3 || total == 0) return null;
    final perFrame = DateTime.now().difference(started).inMilliseconds / done;
    return Duration(milliseconds: (perFrame * (total - done)).round());
  }

  void cancel() {
    if (!running) return;
    _cancelled = true;
    FFmpegKit.cancel();
  }

  /// Runs the whole job. Throws [SwapException] with a readable message
  /// when it cannot finish, including when it was cancelled.
  Future<SwapRecord> run(String videoPath) async {
    if (running) throw SwapException('A video is already being processed.');
    final app = AppState.instance;
    final work = await app.prepareVideoJob();
    final watch = Stopwatch()..start();
    _cancelled = false;
    done = 0;
    total = 0;
    swappedFrames = 0;
    previewPath = null;
    _swapStarted = null;
    _setStage(VideoStage.reading);
    await WakelockPlus.enable();
    final finder = FaceFinder();
    try {
      final inDir = Directory('${work.path}/in')..createSync();
      final outDir = Directory('${work.path}/out')..createSync();

      final fps = await _frameRate(videoPath);
      final fpsText = fps.toStringAsFixed(3);
      await _ffmpeg([
        '-y', '-t', '$maxSeconds', '-i', videoPath, '-an', //
        '-vf',
        "fps=$fpsText,scale='min($_maxSide,iw)':'min($_maxSide,ih)'"
            ':force_original_aspect_ratio=decrease:force_divisible_by=2',
        '-q:v', '3', '${inDir.path}/%06d.jpg',
      ], 'Could not read that video.');

      final frames =
          inDir.listSync().whereType<File>().map((f) => f.path).toList()
            ..sort();
      if (frames.isEmpty) {
        throw SwapException('That video has no frames to process.');
      }
      total = frames.length;
      _swapStarted = DateTime.now();
      _setStage(VideoStage.swapping);

      final identity = app.identity!;
      for (final path in frames) {
        _checkCancelled();
        final name = path.substring(path.lastIndexOf('/') + 1);
        final outPath = '${outDir.path}/$name';
        final faces = await finder.inFile(path);
        if (faces.isEmpty) {
          await File(path).rename(outPath);
        } else {
          final frame = await _decode(path);
          final targets = app.swapAllFaces ? faces : [faces.first];
          for (final face in targets) {
            await FaceSwapper.instance.swap(frame, face, identity);
          }
          await saveFrame(frame, outPath);
          await File(path).delete();
          swappedFrames++;
          previewPath = outPath;
        }
        done++;
        notifyListeners();
      }
      if (swappedFrames == 0) {
        throw SwapException('No face was found anywhere in that video.');
      }

      _setStage(VideoStage.building);
      final labelPath = app.labelResults ? _writeLabel(work.path) : null;
      final result = '${work.path}/result.mp4';
      List<String> build(List<String> codec) => [
        '-y', '-framerate', fpsText, '-i', '${outDir.path}/%06d.jpg', //
        '-t', '$maxSeconds', '-i', videoPath,
        if (labelPath != null) ...[
          '-i', labelPath, //
          '-filter_complex', '[0:v][2:v]overlay=12:H-h-12[v]',
          '-map', '[v]',
        ] else ...[
          '-map', '0:v', //
        ],
        '-map', '1:a?', ...codec, '-pix_fmt', 'yuv420p', //
        '-c:a', 'aac', '-b:a', '128k', '-shortest',
        '-movflags', '+faststart', result,
      ];
      try {
        await _ffmpeg(
          build(['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20']),
          'Could not build the video.',
        );
      } on SwapException {
        _checkCancelled();
        // Some devices lack x264; MPEG-4 is always available.
        await _ffmpeg(
          build(['-c:v', 'mpeg4', '-q:v', '4']),
          'Could not build the video.',
        );
      }

      watch.stop();
      return await app.addVideoResult(
        videoFile: result,
        thumbFile: previewPath!,
        millis: watch.elapsedMilliseconds,
        faces: swappedFrames,
      );
    } finally {
      await finder.close();
      await WakelockPlus.disable();
      try {
        await work.delete(recursive: true);
      } catch (_) {}
      stage = VideoStage.idle;
      notifyListeners();
    }
  }

  void _setStage(VideoStage value) {
    stage = value;
    notifyListeners();
  }

  void _checkCancelled() {
    if (_cancelled) throw SwapException('Video swap cancelled.');
  }

  Future<void> _ffmpeg(List<String> arguments, String failure) async {
    _checkCancelled();
    final session = await FFmpegKit.executeWithArguments(arguments);
    final code = await session.getReturnCode();
    if (ReturnCode.isSuccess(code)) return;
    _checkCancelled();
    final log = (await session.getOutput() ?? '').trim();
    final tail = log.length > 300 ? log.substring(log.length - 300) : log;
    throw SwapException('$failure\n$tail');
  }

  /// The video's frame rate, limited to [_maxFps].
  Future<double> _frameRate(String path) async {
    var fps = _maxFps;
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      for (final stream in info?.getStreams() ?? const []) {
        if (stream.getType() != 'video') continue;
        final text =
            stream.getAverageFrameRate() ?? stream.getRealFrameRate() ?? '';
        final parts = text.split('/');
        final top = double.tryParse(parts[0]) ?? 0;
        final bottom = parts.length > 1 ? double.tryParse(parts[1]) ?? 1 : 1;
        if (top > 0 && bottom > 0) fps = top / bottom;
        break;
      }
    } catch (e) {
      debugPrint('frame rate: $e');
    }
    return fps.clamp(1.0, _maxFps);
  }

  Future<Frame> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final image = (await codec.getNextFrame()).image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return Frame(
          image.width,
          image.height,
          Uint8List.fromList(data!.buffer.asUint8List()),
        );
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Writes the small "AI generated" mark laid over the finished video.
  String _writeLabel(String dir) {
    const text = 'AI generated';
    final font = img.arial24;
    final label = img.Image(width: 190, height: 40, numChannels: 4);
    img.fill(label, color: img.ColorRgba8(0, 0, 0, 110));
    img.drawString(
      label,
      text,
      font: font,
      x: 12,
      y: 7,
      color: img.ColorRgba8(255, 255, 255, 235),
    );
    final path = '$dir/label.png';
    File(path).writeAsBytesSync(img.encodePng(label));
    return path;
  }
}
