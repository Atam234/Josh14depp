import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../engine/model_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'engine_screen.dart';
import 'live_swap_screen.dart';
import 'photo_swap_screen.dart';
import 'result_screen.dart';
import 'source_picker.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final models = ModelStore.instance;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([app, models]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      color: Palette.lime,
                      shape: BoxShape.circle,
                    ),
                    child: PhotoThumb(
                      path: app.sourcePath,
                      size: 50,
                      radius: 25,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to',
                          style: TextStyle(fontSize: 13, color: Palette.muted),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Joshdepp!',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _open(context, const EngineScreen()),
                    icon: const Icon(Icons.settings_rounded),
                    color: Palette.lime,
                    tooltip: 'Engine and settings',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!models.allReady) ...[
                _ModelsBanner(
                  models: models,
                  onTap: () => _open(context, const EngineScreen()),
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                height: 150,
                child: BlobCard(
                  onTap: () {
                    if (!ensureModels(context)) return;
                    _open(context, const LiveSwapScreen());
                  },
                  child: const _TileContent(
                    title: 'Live Swap',
                    caption: 'Camera, in real time',
                    icon: Icons.videocam_rounded,
                    large: true,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    Expanded(
                      child: BlobCard(
                        seed: 1,
                        onTap: () => _open(context, const PhotoSwapScreen()),
                        child: const _TileContent(
                          title: 'Photo\nSwap',
                          icon: Icons.photo_library_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: BlobCard(
                        seed: 2,
                        onTap: () => chooseSourceFace(context),
                        child: _TileContent(
                          title: 'Source\nFace',
                          icon: app.hasSource
                              ? Icons.how_to_reg_rounded
                              : Icons.person_add_alt_1_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Recent swaps'),
              if (app.history.isEmpty)
                const _EmptyHistory()
              else
                for (final record in app.history.take(20))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _RecordCard(record: record),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileContent extends StatelessWidget {
  const _TileContent({
    required this.title,
    required this.icon,
    this.caption,
    this.large = false,
  });

  final String title;
  final String? caption;
  final IconData icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: large ? 24 : 20,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 6),
              Text(
                caption!,
                style: const TextStyle(fontSize: 13, color: Palette.muted),
              ),
            ],
          ],
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Icon(icon, color: Palette.lime, size: large ? 38 : 32),
        ),
      ],
    );
  }
}

class _ModelsBanner extends StatelessWidget {
  const _ModelsBanner({required this.models, required this.onTap});

  final ModelStore models;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final megabytes = (models.totalBytes / 1e6).round();
    final downloading = models.downloading;
    return BlobCard(
      lime: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  downloading
                      ? 'Getting the face models…'
                      : 'Download the face models',
                  style: const TextStyle(
                    color: Palette.onLime,
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.download_for_offline_rounded,
                color: Palette.onLime,
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            downloading
                ? '${(models.progress * 100).round()}% of $megabytes MB'
                : 'One-time download, $megabytes MB. Swaps then run on your phone.',
            style: const TextStyle(color: Palette.onLime, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(36),
      ),
      child: const Column(
        children: [
          JoshdeppLogo(size: 44),
          SizedBox(height: 16),
          Text(
            'No swaps yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 6),
          Text(
            'Choose a source face, then try Photo Swap.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Palette.muted),
          ),
        ],
      ),
    );
  }
}

String formatWhen(DateTime time) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final half = time.hour < 12 ? 'AM' : 'PM';
  return '${months[time.month - 1]} ${time.day}, ${time.year} - $hour:$minute $half';
}

String formatMillis(int millis) =>
    millis >= 1000 ? '${(millis / 1000).toStringAsFixed(1)} s' : '$millis ms';

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final SwapRecord record;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(36),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ResultScreen(record: record)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PhotoThumb(
                path: record.path,
                size: 108,
                radius: 26,
                placeholder: Icons.image_rounded,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          record.live
                              ? Icons.videocam_rounded
                              : Icons.photo_rounded,
                          color: Palette.lime,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          record.live ? 'Live Swap' : 'Photo Swap',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      record.live
                          ? '${record.faces} ${record.faces == 1 ? 'face' : 'faces'}'
                          : '${record.faces} ${record.faces == 1 ? 'face' : 'faces'} · ${formatMillis(record.millis)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Palette.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Chip2(formatWhen(record.time)),
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
