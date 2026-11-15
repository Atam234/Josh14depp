import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'result_screen.dart';
import 'source_picker.dart';

class PhotoSwapScreen extends StatefulWidget {
  const PhotoSwapScreen({super.key});

  @override
  State<PhotoSwapScreen> createState() => _PhotoSwapScreenState();
}

class _PhotoSwapScreenState extends State<PhotoSwapScreen> {
  String? _target;
  bool _busy = false;

  Future<void> _pickTarget() async {
    final path = await pickImage(context, title: 'Target photo');
    if (path != null) setState(() => _target = path);
  }

  Future<void> _run() async {
    if (!ensureModels(context)) return;
    setState(() => _busy = true);
    try {
      final record = await AppState.instance.swapPhoto(_target!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => ResultScreen(record: record)),
      );
    } on SwapException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (e) {
      if (mounted) showMessage(context, 'Swap failed. ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              const ScreenHeader(title: 'Photo Swap'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _Slot(
                      step: '1',
                      title: 'Source face',
                      caption: app.hasSource
                          ? 'This face will be used'
                          : 'Whose face to put in',
                      path: app.sourcePath,
                      onTap: _busy ? null : () => chooseSourceFace(context),
                    ),
                    const SizedBox(height: 14),
                    _Slot(
                      step: '2',
                      title: 'Target photo',
                      caption: _target == null
                          ? 'The photo to change'
                          : 'Tap to choose another',
                      path: _target,
                      placeholder: Icons.add_photo_alternate_rounded,
                      onTap: _busy ? null : _pickTarget,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: LimeButton(
                  label: _busy ? 'Swapping…' : 'Swap face',
                  icon: Icons.auto_awesome_rounded,
                  busy: _busy,
                  onPressed: app.hasSource && _target != null ? _run : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.step,
    required this.title,
    required this.caption,
    required this.path,
    required this.onTap,
    this.placeholder = Icons.person_add_alt_1_rounded,
  });

  final String step;
  final String title;
  final String caption;
  final String? path;
  final VoidCallback? onTap;
  final IconData placeholder;

  @override
  Widget build(BuildContext context) {
    return BlobCard(
      onTap: onTap,
      seed: int.parse(step),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          PhotoThumb(
            path: path,
            size: 120,
            radius: 26,
            placeholder: placeholder,
          ),
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
      ),
    );
  }
}
