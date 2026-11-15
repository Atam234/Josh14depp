import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../engine/model_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'engine_screen.dart';

/// Asks where to take a picture from. Returns the picked file path.
Future<String?> pickImage(BuildContext context, {required String title}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            LimeButton(
              label: 'Choose from gallery',
              icon: Icons.photo_library_rounded,
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
            GhostButton(
              label: 'Take a photo',
              icon: Icons.photo_camera_rounded,
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;
  try {
    final file = await ImagePicker().pickImage(source: source);
    return file?.path;
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not open the picker.');
    return null;
  }
}

/// Sends the person to the Engine screen when the models are missing.
/// Returns true when the models are ready to use.
bool ensureModels(BuildContext context) {
  if (ModelStore.instance.allReady) return true;
  showMessage(context, 'Download the face models first.');
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const EngineScreen()));
  return false;
}

/// Full flow for choosing the source face, with a blocking progress dialog
/// while the face is analysed.
Future<void> chooseSourceFace(BuildContext context) async {
  if (!ensureModels(context)) return;
  final path = await pickImage(context, title: 'Source face');
  if (path == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _BusyDialog('Reading the face…'),
  );
  String? error;
  try {
    await AppState.instance.setSource(path);
  } on SwapException catch (e) {
    error = e.message;
  } catch (e) {
    error = 'Could not read that face. ($e)';
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  showMessage(context, error ?? 'Source face is ready.');
}

class _BusyDialog extends StatelessWidget {
  const _BusyDialog(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Palette.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Palette.lime,
                ),
              ),
              const SizedBox(width: 20),
              Flexible(child: Text(text, style: const TextStyle(fontSize: 16))),
            ],
          ),
        ),
      ),
    );
  }
}
