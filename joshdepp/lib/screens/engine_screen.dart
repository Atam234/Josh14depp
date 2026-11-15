import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../engine/model_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart' show formatMillis;

class EngineScreen extends StatelessWidget {
  const EngineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final models = ModelStore.instance;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([app, models]),
          builder: (context, _) {
            final avg = app.averageMillis;
            return Column(
              children: [
                const ScreenHeader(title: 'Engine'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      const SectionTitle('Statistics'),
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(
                              icon: Icons.auto_awesome_rounded,
                              value: '${app.totalSwaps}',
                              label: 'Swaps',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(
                              icon: Icons.face_rounded,
                              value: '${app.totalFaces}',
                              label: 'Faces',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatTile(
                              icon: Icons.timer_rounded,
                              value: avg == null ? '–' : formatMillis(avg),
                              label: 'Avg. time',
                            ),
                          ),
                        ],
                      ),
                      const SectionTitle('Face models'),
                      Row(
                        children: [
                          const Text(
                            'Download',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 10),
                          Chip2(
                            models.allReady
                                ? 'Ready'
                                : models.downloading
                                ? 'Downloading'
                                : 'Needed',
                          ),
                          const Spacer(),
                          Text(
                            '${(models.progress * 100).round()}%',
                            style: const TextStyle(color: Palette.lime),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ThickBar(value: models.progress),
                      const SizedBox(height: 16),
                      for (final m in allModels) _ModelRow(spec: m),
                      const SizedBox(height: 12),
                      if (!models.allReady)
                        LimeButton(
                          label: models.downloading
                              ? 'Downloading…'
                              : 'Download models',
                          icon: Icons.download_rounded,
                          busy: models.downloading,
                          onPressed: models.downloadAll,
                        )
                      else
                        GhostButton(
                          label: 'Delete models',
                          icon: Icons.delete_outline_rounded,
                          color: Palette.danger,
                          onPressed: models.deleteAll,
                        ),
                      if (models.downloading) ...[
                        const SizedBox(height: 12),
                        GhostButton(label: 'Cancel', onPressed: models.cancel),
                      ],
                      const SectionTitle('Settings'),
                      _SwitchCard(
                        title: 'Swap all faces',
                        subtitle: 'Otherwise only the largest face changes.',
                        value: app.swapAllFaces,
                        onChanged: app.setSwapAllFaces,
                      ),
                      const SizedBox(height: 12),
                      _SwitchCard(
                        title: 'Label as AI generated',
                        subtitle: 'Adds a small mark to saved results.',
                        value: app.labelResults,
                        onChanged: app.setLabelResults,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Only use a real person\'s face with their consent, and say that what you share is AI-generated.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.spec});

  final ModelSpec spec;

  @override
  Widget build(BuildContext context) {
    final state = ModelStore.instance.stateOf(spec);
    final (icon, text) = switch (state.status) {
      ModelStatus.ready => (Icons.check_circle_rounded, 'Ready'),
      ModelStatus.downloading => (
        Icons.downloading_rounded,
        '${(state.received / 1e6).round()} / ${(spec.bytes / 1e6).round()} MB',
      ),
      ModelStatus.failed => (Icons.error_rounded, state.error ?? 'Failed'),
      ModelStatus.missing => (
        Icons.cloud_download_rounded,
        '${(spec.bytes / 1e6).round()} MB',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: state.status == ModelStatus.failed
                  ? Palette.danger
                  : Palette.lime,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spec.title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.subtitle,
                    style: const TextStyle(fontSize: 12, color: Palette.muted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, color: Palette.lime),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Palette.muted),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
