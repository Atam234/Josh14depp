import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// One downloadable ONNX model.
class ModelSpec {
  const ModelSpec({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fileName,
    required this.url,
    required this.bytes,
  });

  final String id;
  final String title;
  final String subtitle;
  final String fileName;
  final String url;
  final int bytes;
}

/// The same models Deep-Live-Cam uses on desktop.
const swapperModel = ModelSpec(
  id: 'swapper',
  title: 'Face Swapper',
  subtitle: 'inswapper_128_fp16',
  fileName: 'inswapper_128_fp16.onnx',
  url: 'https://huggingface.co/hacksider/deep-live-cam/resolve/main/inswapper_128_fp16.onnx',
  bytes: 277680638,
);

const recognizerModel = ModelSpec(
  id: 'recognizer',
  title: 'Face Recognizer',
  subtitle: 'arcface_w600k_r50',
  fileName: 'w600k_r50.onnx',
  url: 'https://huggingface.co/public-data/insightface/resolve/main/models/buffalo_l/w600k_r50.onnx',
  bytes: 174383860,
);

const allModels = [swapperModel, recognizerModel];

enum ModelStatus { missing, downloading, ready, failed }

class ModelState {
  ModelStatus status = ModelStatus.missing;
  int received = 0;
  String? error;
}

/// Downloads the models on first use and keeps them in app storage.
class ModelStore extends ChangeNotifier {
  ModelStore._();
  static final ModelStore instance = ModelStore._();

  final Map<String, ModelState> _states = {
    for (final m in allModels) m.id: ModelState(),
  };
  Directory? _dir;
  http.Client? _client;

  ModelState stateOf(ModelSpec spec) => _states[spec.id]!;

  bool get allReady =>
      allModels.every((m) => stateOf(m).status == ModelStatus.ready);

  bool get downloading =>
      allModels.any((m) => stateOf(m).status == ModelStatus.downloading);

  int get totalBytes => allModels.fold(0, (sum, m) => sum + m.bytes);

  int get receivedBytes => allModels.fold(0, (sum, m) {
    final s = stateOf(m);
    return sum + (s.status == ModelStatus.ready ? m.bytes : s.received);
  });

  double get progress => receivedBytes / totalBytes;

  String pathOf(ModelSpec spec) => '${_dir!.path}/${spec.fileName}';

  Future<void> init() async {
    try {
      final base = await getApplicationSupportDirectory();
      _dir = Directory('${base.path}/models');
      await _dir!.create(recursive: true);
      for (final m in allModels) {
        final file = File(pathOf(m));
        if (await file.exists() && await file.length() == m.bytes) {
          stateOf(m).status = ModelStatus.ready;
        }
      }
    } catch (e) {
      // No file storage on this platform (for example the web preview).
      debugPrint('ModelStore.init: $e');
    }
    notifyListeners();
  }

  /// Downloads every model that is not on the device yet.
  Future<void> downloadAll() async {
    if (downloading || _dir == null) return;
    _client = http.Client();
    try {
      for (final m in allModels) {
        if (stateOf(m).status == ModelStatus.ready) continue;
        await _download(m);
        if (stateOf(m).status != ModelStatus.ready) break;
      }
    } finally {
      _client?.close();
      _client = null;
    }
  }

  void cancel() {
    _client?.close();
  }

  Future<void> deleteAll() async {
    if (downloading || _dir == null) return;
    for (final m in allModels) {
      final file = File(pathOf(m));
      if (await file.exists()) await file.delete();
      _states[m.id] = ModelState();
    }
    notifyListeners();
  }

  Future<void> _download(ModelSpec spec) async {
    final state = stateOf(spec)
      ..status = ModelStatus.downloading
      ..received = 0
      ..error = null;
    notifyListeners();

    final part = File('${pathOf(spec)}.part');
    IOSink? sink;
    try {
      final response = await _client!.send(
        http.Request('GET', Uri.parse(spec.url)),
      );
      if (response.statusCode != 200) {
        throw HttpException('Server answered ${response.statusCode}');
      }
      sink = part.openWrite();
      var lastNotify = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        state.received += chunk.length;
        if (state.received - lastNotify > 512 * 1024) {
          lastNotify = state.received;
          notifyListeners();
        }
      }
      await sink.close();
      sink = null;
      if (await part.length() != spec.bytes) {
        throw const HttpException('Download was incomplete');
      }
      await part.rename(pathOf(spec));
      state.status = ModelStatus.ready;
    } catch (e) {
      await sink?.close().catchError((_) {});
      if (await part.exists()) await part.delete();
      state
        ..status = ModelStatus.failed
        ..received = 0
        ..error = e is HttpException ? e.message : 'Download stopped';
    }
    notifyListeners();
  }
}
