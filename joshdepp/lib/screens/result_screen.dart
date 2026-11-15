import 'dart:io';

import 'package:gal/gal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

import 'package:video_player/video_player.dart';

import 'home_screen.dart' show formatWhen, recordTitle;

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.record});

  final SwapRecord record;

  Future<void> _save(BuildContext context) async {
    try {
      if (!await Gal.hasPermission(toAlbum: true)) {
        await Gal.requestPermission(toAlbum: true);
      }
      if (record.isVideo) {
        await Gal.putVideo(record.videoPath!, album: 'Joshdepp');
      } else {
        await Gal.putImage(record.path, album: 'Joshdepp');
      }
      if (context.mounted) showMessage(context, 'Saved to your gallery.');
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Could not save it to the gallery.');
      }
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(record.videoPath ?? record.path)],
        text: 'Made with Joshdepp (AI-generated)',
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    await AppState.instance.deleteRecord(record);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Result',
              action: IconButton(
                onPressed: () => _delete(context),
                icon: const Icon(Icons.delete_outline_rounded),
                color: Palette.lime,
                tooltip: 'Delete',
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: ColoredBox(
                    color: Palette.card,
                    child: record.isVideo
                        ? _VideoView(path: record.videoPath!)
                        : InteractiveViewer(
                            maxScale: 5,
                            child: Center(
                              child: Image.file(
                                File(record.path),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Chip2(recordTitle(record), filled: true),
                  const SizedBox(width: 8),
                  Flexible(child: Chip2(formatWhen(record.time))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Share',
                      icon: Icons.ios_share_rounded,
                      onPressed: _share,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: LimeButton(
                      label: 'Save',
                      icon: Icons.download_rounded,
                      onPressed: () => _save(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Looping player with tap to pause.
class _VideoView extends StatefulWidget {
  const _VideoView({required this.path});

  final String path;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path))
      ..setLooping(true)
      ..addListener(_changed);
    _controller.initialize().then((_) => _controller.play()).catchError((
      Object _,
    ) {
      if (mounted) setState(() => _failed = true);
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This video cannot be played here. Save it to open it in your gallery.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.muted),
          ),
        ),
      );
    }
    final value = _controller.value;
    if (!value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Palette.lime),
      );
    }
    return GestureDetector(
      onTap: () => value.isPlaying ? _controller.pause() : _controller.play(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!value.isPlaying)
            const Center(
              child: LimeIconButton(
                icon: Icons.play_arrow_rounded,
                tooltip: 'Play',
                size: 72,
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Palette.lime,
                bufferedColor: Palette.cardRaised,
                backgroundColor: Palette.field,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
