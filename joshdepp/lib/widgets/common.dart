import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The app's mark: two overlapping faces.
class JoshdeppLogo extends StatelessWidget {
  const JoshdeppLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.35,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Icon(
              Icons.face_retouching_natural_rounded,
              size: size,
              color: Palette.limeDeep.withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Icon(Icons.face_rounded, size: size, color: Palette.lime),
          ),
        ],
      ),
    );
  }
}

/// Full-width lime pill button.
class LimeButton extends StatelessWidget {
  const LimeButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: Material(
        color: Palette.lime,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: 60,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Palette.onLime,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Palette.onLime, size: 22),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Palette.onLime,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          const SizedBox(width: 8),
                          Icon(trailingIcon, color: Palette.onLime, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lime-outlined pill button.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = Palette.lime,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: color, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen header: back chevron, title and an optional lime action.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left_rounded, size: 30),
            color: Palette.text,
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Card with the soft organic shapes used across the design.
class BlobCard extends StatelessWidget {
  const BlobCard({
    super.key,
    required this.child,
    this.onTap,
    this.lime = false,
    this.radius = 36,
    this.padding = const EdgeInsets.all(24),
    this.seed = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool lime;
  final double radius;
  final EdgeInsets padding;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: lime ? Palette.lime : Palette.card,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: CustomPaint(
          painter: _BlobPainter(
            lime ? const Color(0xFFD3F032) : Palette.cardRaised,
            seed,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter(this.color, this.seed);

  final Color color;
  final int seed;

  static const _layouts = [
    [0.78, 0.10, 0.42, 0.18, 1.05, 0.55, 0.50, 0.62, 0.30],
    [0.15, 0.95, 0.50, 0.92, 0.05, 0.40, 0.55, 0.40, 0.28],
    [0.90, 0.85, 0.48, 0.10, 0.20, 0.36, 0.60, -0.10, 0.34],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final layout = _layouts[seed % _layouts.length];
    final paint = Paint()..color = color.withValues(alpha: 0.55);
    final unit = size.shortestSide;
    for (var i = 0; i < 3; i++) {
      final cx = layout[i * 3] * size.width;
      final cy = layout[i * 3 + 1] * size.height;
      final r = layout[i * 3 + 2] * unit * 1.6;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: r * 2.3,
          height: r * 1.7,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.color != color || old.seed != seed;
}

/// Small statistic tile: lime icon, value, lime caption.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 6),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Palette.lime, size: 24),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Palette.lime),
          ),
        ],
      ),
    );
  }
}

/// Thick rounded progress bar.
class ThickBar extends StatelessWidget {
  const ThickBar({
    super.key,
    required this.value,
    this.track = Palette.card,
    this.height = 26,
  });

  final double value;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Progress',
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height,
          color: track,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: Palette.lime,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded label, e.g. "Running" in the design.
class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.icon, this.filled = false});

  final String text;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Palette.onLime : Palette.lime;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? Palette.lime : Palette.cardRaised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round lime icon button.
class LimeIconButton extends StatelessWidget {
  const LimeIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 52,
    this.filled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? Palette.lime : Palette.cardRaised,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.44,
              color: filled ? Palette.onLime : Palette.lime,
            ),
          ),
        ),
      ),
    );
  }
}

/// A picture from disk with rounded corners, or a placeholder icon.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.path,
    required this.size,
    this.radius = 24,
    this.placeholder = Icons.face_rounded,
  });

  final String? path;
  final double size;
  final double radius;
  final IconData placeholder;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: path == null
            ? ColoredBox(
                color: Palette.cardRaised,
                child: Icon(placeholder, color: Palette.lime, size: size * 0.5),
              )
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Palette.cardRaised,
                  child: Icon(Icons.broken_image_rounded, color: Palette.muted),
                ),
              ),
      ),
    );
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
