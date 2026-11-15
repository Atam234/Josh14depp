import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'engine/face_finder.dart';
import 'engine/face_swapper.dart';
import 'engine/geometry.dart';
import 'engine/model_store.dart';
import 'engine/photo.dart';

/// A finished swap kept in the app's history.
class SwapRecord {
  SwapRecord({
    required this.path,
    required this.time,
    required this.millis,
    required this.faces,
    required this.live,
    this.videoPath,
  });

  final String path;
  final DateTime time;
  final int millis;
  final int faces;
  final bool live;

  /// Set for video swaps; [path] is then the thumbnail.
  final String? videoPath;

  bool get isVideo => videoPath != null;

  Map<String, Object> toJson() => {
    'path': path,
    'time': time.millisecondsSinceEpoch,
    'millis': millis,
    'faces': faces,
    'live': live,
    'video': ?videoPath,
  };

  static SwapRecord fromJson(Map<String, dynamic> json) => SwapRecord(
    path: json['path'] as String,
    time: DateTime.fromMillisecondsSinceEpoch(json['time'] as int),
    millis: json['millis'] as int,
    faces: json['faces'] as int,
    live: json['live'] as bool,
    videoPath: json['video'] as String?,
  );
}

/// Thrown for problems the person can fix (no face in the photo, etc.).
class SwapException implements Exception {
  SwapException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  SharedPreferences? _prefs;
  Directory? _docs;
  Directory? _temp;

  bool onboarded = false;
  bool labelResults = true;
  bool swapAllFaces = false;
  String? sourcePath;
  Float32List? identity;
  List<SwapRecord> history = [];

  bool get hasSource => identity != null && sourcePath != null;

  int get totalSwaps => history.length;

  int get totalFaces => history.fold(0, (sum, r) => sum + r.faces);

  int? get averageMillis {
    final timed = history.where((r) => r.millis > 0).toList();
    if (timed.isEmpty) return null;
    return timed.fold(0, (sum, r) => sum + r.millis) ~/ timed.length;
  }

  Future<void> init() async {
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();
      onboarded = prefs.getBool('onboarded') ?? false;
      labelResults = prefs.getBool('labelResults') ?? true;
      swapAllFaces = prefs.getBool('swapAllFaces') ?? false;
      final raw = prefs.getString('history');
      if (raw != null) {
        history = [
          for (final item in jsonDecode(raw) as List)
            SwapRecord.fromJson(item as Map<String, dynamic>),
        ];
      }
    } catch (e) {
      debugPrint('AppState prefs: $e');
    }
    try {
      _docs = await getApplicationDocumentsDirectory();
      _temp = await getTemporaryDirectory();
      await Directory('${_docs!.path}/swaps').create(recursive: true);
      history.removeWhere((r) => !File(r.path).existsSync());
      final savedSource = _prefs?.getString('sourcePath');
      final savedIdentity = _prefs?.getString('identity');
      if (savedSource != null &&
          savedIdentity != null &&
          File(savedSource).existsSync()) {
        sourcePath = savedSource;
        identity = Float32List.sublistView(
          Uint8List.fromList(base64Decode(savedIdentity)),
        );
      }
    } catch (e) {
      debugPrint('AppState storage: $e');
    }
    await ModelStore.instance.init();
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    await _prefs?.setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> setLabelResults(bool value) async {
    labelResults = value;
    await _prefs?.setBool('labelResults', value);
    notifyListeners();
  }

  Future<void> setSwapAllFaces(bool value) async {
    swapAllFaces = value;
    await _prefs?.setBool('swapAllFaces', value);
    notifyListeners();
  }

  String tempPath(String name) => '${_temp!.path}/$name';

  String _newSwapPath() =>
      '${_docs!.path}/swaps/swap_${DateTime.now().millisecondsSinceEpoch}.jpg';

  /// Checks that a swap can start and returns a fresh working folder.
  Future<Directory> prepareVideoJob() async {
    _requireModels();
    if (!hasSource) throw SwapException('Choose a source face first.');
    final dir = Directory('${_temp!.path}/video_job');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    return dir;
  }

  /// Moves a finished video and its thumbnail into the history.
  Future<SwapRecord> addVideoResult({
    required String videoFile,
    required String thumbFile,
    required int millis,
    required int faces,
  }) async {
    final thumb = _newSwapPath();
    final video = thumb.replaceAll('.jpg', '.mp4');
    await File(thumbFile).copy(thumb);
    await File(videoFile).copy(video);
    final record = SwapRecord(
      path: thumb,
      time: DateTime.now(),
      millis: millis,
      faces: faces,
      live: false,
      videoPath: video,
    );
    history.insert(0, record);
    await _saveHistory();
    notifyListeners();
    return record;
  }

  /// Uses the largest face in the picked image as the face to swap in.
  Future<void> setSource(String pickedPath) async {
    _requireModels();
    final previous = sourcePath;
    final kept =
        '${_docs!.path}/source_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final photo = await loadPhoto(pickedPath, tempPath('source_in.jpg'));
    final finder = FaceFinder();
    try {
      final faces = await finder.inFile(photo.path);
      if (faces.isEmpty) {
        throw SwapException('No face found in that photo. Try a clearer one.');
      }
      final vector = await FaceSwapper.instance.identityOf(
        photo.frame,
        faces.first,
      );
      await File(photo.path).copy(kept);
      sourcePath = kept;
      identity = vector;
      await _prefs?.setString('sourcePath', kept);
      await _prefs?.setString(
        'identity',
        base64Encode(vector.buffer.asUint8List()),
      );
      notifyListeners();
      if (previous != null && File(previous).existsSync()) {
        File(previous).deleteSync();
      }
    } finally {
      await finder.close();
    }
  }

  /// Swaps the source face into the picked photo and stores the result.
  Future<SwapRecord> swapPhoto(String pickedPath) async {
    _requireModels();
    if (!hasSource) throw SwapException('Choose a source face first.');
    final watch = Stopwatch()..start();
    final photo = await loadPhoto(pickedPath, tempPath('target_in.jpg'));
    final finder = FaceFinder();
    try {
      final faces = await finder.inFile(photo.path);
      if (faces.isEmpty) {
        throw SwapException('No face found in the target photo.');
      }
      final targets = swapAllFaces ? faces : [faces.first];
      for (final face in targets) {
        await FaceSwapper.instance.swap(photo.frame, face, identity!);
      }
      watch.stop();
      return await addResult(
        photo.frame,
        millis: watch.elapsedMilliseconds,
        faces: targets.length,
        live: false,
      );
    } finally {
      await finder.close();
    }
  }

  /// Saves [frame] to the history.
  Future<SwapRecord> addResult(
    Frame frame, {
    required int millis,
    required int faces,
    required bool live,
  }) async {
    final path = _newSwapPath();
    await saveFrame(frame, path, label: labelResults);
    final record = SwapRecord(
      path: path,
      time: DateTime.now(),
      millis: millis,
      faces: faces,
      live: live,
    );
    history.insert(0, record);
    await _saveHistory();
    notifyListeners();
    return record;
  }

  Future<void> deleteRecord(SwapRecord record) async {
    history.remove(record);
    final file = File(record.path);
    if (await file.exists()) await file.delete();
    final video = record.videoPath == null ? null : File(record.videoPath!);
    if (video != null && await video.exists()) await video.delete();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    await _prefs?.setString(
      'history',
      jsonEncode([for (final r in history) r.toJson()]),
    );
  }

  void _requireModels() {
    if (!ModelStore.instance.allReady) {
      throw SwapException('Download the face models first.');
    }
    if (_docs == null || _temp == null) {
      throw SwapException('Storage is not available on this device.');
    }
  }
}
