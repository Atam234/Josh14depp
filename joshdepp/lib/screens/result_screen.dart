import 'dart:io';

import 'package:gal/gal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show formatWhen;

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.record});

  final SwapRecord record;

  Future<void> _save(BuildContext context) async {
    try {
      if (!await Gal.hasPermission(toAlbum: true)) {
        await Gal.requestPermission(toAlbum: true);
      }
      await Gal.putImage(record.path, album: 'Joshdepp');
      if (context.mounted) showMessage(context, 'Saved to your gallery.');
    } catch (_) {
      if (context.mounted) showMessage(context, 'Could not save the photo.');
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(record.path)],
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
                    child: InteractiveViewer(
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
                  Chip2(record.live ? 'Live Swap' : 'Photo Swap', filled: true),
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
