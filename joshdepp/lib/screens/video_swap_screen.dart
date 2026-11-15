import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../engine/video_swapper.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'result_screen.dart';
import 'source_picker.dart';

class VideoSwapScreen extends StatefulWidget {
  const VideoSwapScreen({super.key});

  @override
  State<VideoSwapScreen> createState() => _VideoSwapScreenState();
}

class _VideoSwapScreenState extends State<VideoSwapScreen> {
  String? _video;

  Future<void> _pickVideo() async {
    try {
      final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (file != null) setState(() => _video = file.path);
    } catch (_) {
      if (mounted) showMessage(context, 'Could not open the picker.');
    }
  }

  Future<void> _run() async {
    if (!ensureModels(context)) return;
    try {
      final record = await VideoSwapper.instance.run(_video!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ResultScreen(record: record)),
      );
    } on SwapException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (e) {
      if (mounted) showMessage(context, 'Video swap failed. ($e)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final job = VideoSwapper.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([app, job]),
      builder: (context, _) => PopScope(
        canPop: !job.running,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) showMessage(context, 'Cancel the video swap first.');
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                const ScreenHeader(title: 'Video Swap'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: job.running
                        ? [_Progress(job: job)]
                        : [
                            BlobCard(
                              seed: 1,
                              padding: const EdgeInsets.all(16),
                              onTap: () => chooseSourceFace(context),
                              child: _SlotRow(
                                step: '1',
                                title: 'Source face',
                                caption: app.hasSource
                                    ? 'This face will be used'
                                    : 'Whose face to put in',
                                thumb: PhotoThumb(
                                  path: app.sourcePath,
                                  size: 120,
                                  radius: 26,
                                  placeholder: Icons.person_add_alt_1_rounded,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            BlobCard(
                              seed: 2,
                              padding: const EdgeInsets.all(16),
                              onTap: _pickVideo,
                              child: _SlotRow(
                                step: '2',
                                title: 'Target video',
                                caption: _video == null
                                    ? 'The video to change'
                                    : 'Video chosen. Tap to change',
                                thumb: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: _video == null
                                        ? Palette.cardRaised
                                        : Palette.lime,
                                    borderRadius: BorderRadius.circular(26),
                                  ),
                                  child: Icon(
                                    _video == null
                                        ? Icons.video_call_rounded
                                        : Icons.movie_rounded,
                                    size: 56,
                                    color: _video == null
                                        ? Palette.lime
                                        : Palette.onLime,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'The first ${VideoSwapper.maxSeconds} seconds are processed, frame by frame, on your phone. '
                              'Expect several minutes for a short clip. Keep the app open until it finishes.',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Palette.muted,
                              ),
                            ),
                          ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: job.running
                      ? GhostButton(
                          label: 'Cancel',
                          icon: Icons.close_rounded,
                          onPressed: job.cancel,
                        )
                      : LimeButton(
                          label: 'Swap video',
                          icon: Icons.auto_awesome_rounded,
                          onPressed: app.hasSource && _video != null
                              ? _run
                              : null,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.step,
    required this.title,
    required this.caption,
    required this.thumb,
  });

  final String step;
  final String title;
  final String caption;
  final Widget thumb;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        thumb,
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip2('STEP $step', filled: true),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: const TextStyle(fontSize: 13, color: Palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.job});

  final VideoSwapper job;

  String _left(Duration d) {
    if (d.inMinutes >= 1) return 'About ${d.inMinutes + 1} min left';
    return 'Less than a minute left';
  }

  @override
  Widget build(BuildContext context) {
    final (title, detail) = switch (job.stage) {
      VideoStage.reading => ('Reading the video…', 'Splitting it into frames'),
      VideoStage.swapping => (
        'Swapping faces…',
        'Frame ${job.done} of ${job.total}',
      ),
      VideoStage.building => ('Building the video…', 'Adding the sound back'),
      VideoStage.idle => ('', ''),
    };
    final remaining = job.remaining;
    final swapping = job.stage == VideoStage.swapping;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(36),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Palette.lime,
                  ),
                ),
              ),
              if (swapping)
                Chip2('${(job.progress * 100).round()}%', filled: true),
            ],
          ),
          const SizedBox(height: 18),
          if (job.previewPath != null)
            Center(
              child: PhotoThumb(
                key: ValueKey(job.previewPath),
                path: job.previewPath,
                size: 220,
                radius: 28,
              ),
            )
          else
            const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: Palette.lime),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text(detail)),
              if (swapping && remaining != null)
                Text(
                  _left(remaining),
                  style: const TextStyle(fontSize: 12, color: Palette.lime),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (swapping)
            ThickBar(value: job.progress, track: Palette.field)
          else
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              child: LinearProgressIndicator(
                minHeight: 26,
                color: Palette.lime,
                backgroundColor: Palette.field,
              ),
            ),
        ],
      ),
    );
  }
}
