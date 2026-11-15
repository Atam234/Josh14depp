import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../engine/face_finder.dart';
import '../engine/face_swapper.dart';
import '../engine/geometry.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'source_picker.dart';

class LiveSwapScreen extends StatefulWidget {
  const LiveSwapScreen({super.key});

  @override
  State<LiveSwapScreen> createState() => _LiveSwapScreenState();
}

class _LiveSwapScreenState extends State<LiveSwapScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  final _finder = FaceFinder(fast: true);

  bool _busy = false;
  bool _swapOn = true;
  String? _error;
  ui.Image? _output;
  Frame? _lastFrame;
  int _lastFaces = 0;
  double _fps = 0;
  DateTime? _lastTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    try {
      await FaceSwapper.instance.load();
      _cameras = await availableCameras();
      if (_cameras.isEmpty) throw CameraException('none', 'No camera found');
      final front = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _cameraIndex = front < 0 ? 0 : front;
      await _open();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start the camera. ($e)');
    }
  }

  Future<void> _open() async {
    final old = _camera;
    _camera = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );
    await controller.initialize();
    await controller.startImageStream(_onFrame);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _camera = controller;
      _output = null;
      _error = null;
    });
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final description = _cameras[_cameraIndex];
      final rotation = description.sensorOrientation;
      final plane = image.planes.first;
      final Frame frame;
      final InputImageFormat format;
      if (Platform.isIOS) {
        format = InputImageFormat.bgra8888;
        frame = bgraToFrame(
          plane.bytes,
          image.width,
          image.height,
          0,
          plane.bytesPerRow,
        );
      } else {
        format = InputImageFormat.nv21;
        frame = nv21ToFrame(plane.bytes, image.width, image.height, rotation);
      }

      var faces = <FoundFace>[];
      final app = AppState.instance;
      if (_swapOn && app.hasSource) {
        faces = await _finder.inCameraBytes(
          plane.bytes,
          width: image.width,
          height: image.height,
          rotation: Platform.isIOS ? 0 : rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        );
        final targets = app.swapAllFaces ? faces : faces.take(1);
        for (final face in targets) {
          await FaceSwapper.instance.swap(frame, face, app.identity!);
        }
      }

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        frame.rgba,
        frame.width,
        frame.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final out = await completer.future;
      if (!mounted) {
        out.dispose();
        return;
      }
      final now = DateTime.now();
      final last = _lastTime;
      _lastTime = now;
      setState(() {
        _output?.dispose();
        _output = out;
        _lastFrame = frame;
        _lastFaces = faces.isEmpty ? 0 : (app.swapAllFaces ? faces.length : 1);
        if (last != null) {
          final f = 1000 / now.difference(last).inMilliseconds.clamp(1, 100000);
          _fps = _fps == 0 ? f : _fps * 0.8 + f * 0.2;
        }
      });
    } catch (e) {
      debugPrint('Live frame: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _capture() async {
    final frame = _lastFrame;
    if (frame == null) return;
    final copy = Frame(
      frame.width,
      frame.height,
      Uint8List.fromList(frame.rgba),
    );
    final mirrored = _isFront ? _mirror(copy) : copy;
    await AppState.instance.addResult(
      mirrored,
      millis: 0,
      faces: _lastFaces,
      live: true,
    );
    if (mounted) showMessage(context, 'Saved to Recent swaps.');
  }

  Frame _mirror(Frame f) {
    final out = Uint8List.fromList(f.rgba);
    for (var y = 0; y < f.height; y++) {
      for (var x = 0; x < f.width; x++) {
        final s = (y * f.width + x) * 4;
        final d = (y * f.width + (f.width - 1 - x)) * 4;
        out[d] = f.rgba[s];
        out[d + 1] = f.rgba[s + 1];
        out[d + 2] = f.rgba[s + 2];
        out[d + 3] = 255;
      }
    }
    return Frame(f.width, f.height, out);
  }

  bool get _isFront =>
      _cameras.isNotEmpty &&
      _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;

  Future<void> _flip() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    try {
      await _open();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not switch camera. ($e)');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _camera;
    if (state == AppLifecycleState.inactive) {
      _camera = null;
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed && _cameras.isNotEmpty) {
      _open().catchError((Object e) {
        if (mounted) setState(() => _error = '$e');
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _finder.close();
    _output?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) => Column(
            children: [
              ScreenHeader(
                title: 'Live Swap',
                action: IconButton(
                  onPressed: _cameras.length < 2 ? null : _flip,
                  icon: const Icon(Icons.cameraswitch_rounded),
                  color: Palette.lime,
                  tooltip: 'Switch camera',
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: ColoredBox(
                      color: Palette.card,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_error != null)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Palette.muted),
                                ),
                              ),
                            )
                          else if (_output == null)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Palette.lime,
                              ),
                            )
                          else
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(
                                _isFront ? -1 : 1,
                                1,
                                1,
                              ),
                              child: RawImage(
                                image: _output,
                                fit: BoxFit.cover,
                              ),
                            ),
                          Positioned(
                            left: 16,
                            top: 16,
                            child: Row(
                              children: [
                                Chip2(
                                  '${_fps.toStringAsFixed(1)} FPS',
                                  icon: Icons.speed_rounded,
                                ),
                                const SizedBox(width: 8),
                                Chip2(
                                  _lastFaces == 0
                                      ? 'No face'
                                      : '$_lastFaces swapped',
                                  icon: Icons.face_rounded,
                                ),
                              ],
                            ),
                          ),
                          const Positioned(
                            right: 16,
                            bottom: 16,
                            child: Chip2('AI generated', filled: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => chooseSourceFace(context),
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          color: Palette.lime,
                          shape: BoxShape.circle,
                        ),
                        child: PhotoThumb(
                          path: app.sourcePath,
                          size: 54,
                          radius: 27,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: app.hasSource
                          ? LimeButton(
                              label: _swapOn ? 'Swap on' : 'Swap off',
                              icon: _swapOn
                                  ? Icons.toggle_on_rounded
                                  : Icons.toggle_off_rounded,
                              onPressed: () =>
                                  setState(() => _swapOn = !_swapOn),
                            )
                          : LimeButton(
                              label: 'Choose face',
                              icon: Icons.person_add_alt_1_rounded,
                              onPressed: () => chooseSourceFace(context),
                            ),
                    ),
                    const SizedBox(width: 14),
                    LimeIconButton(
                      icon: Icons.camera_rounded,
                      tooltip: 'Capture',
                      size: 60,
                      filled: false,
                      onPressed: _lastFrame == null ? null : _capture,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
