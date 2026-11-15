import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class _Page {
  const _Page(this.before, this.accent, this.after, this.body, this.icon);

  final String before;
  final String accent;
  final String after;
  final String body;
  final IconData icon;
}

const _pages = [
  _Page(
    'Swap any',
    'face',
    'in one tap.',
    'Pick one photo of a face and Joshdepp puts it on any picture, right on your phone.',
    Icons.face_retouching_natural_rounded,
  ),
  _Page(
    'Go live with',
    'your camera',
    'in real time.',
    'Turn on Live Swap to see the new face on the camera preview as you move.',
    Icons.videocam_rounded,
  ),
  _Page(
    'Use it with',
    'consent',
    'and honesty.',
    'Only use the face of a real person with their permission, and say that what you share is AI-generated. You are responsible for how you use this app.',
    Icons.verified_user_rounded,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _last => _index == _pages.length - 1;

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _PageView(page: _pages[i]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 22 : 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? Palette.lime
                                : Palette.cardRaised,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_last)
                    LimeButton(
                      label: 'I agree, get started',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: AppState.instance.finishOnboarding,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: GhostButton(
                            label: 'Skip',
                            onPressed: () => _goTo(_pages.length - 1),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: LimeButton(
                            label: 'Next',
                            onPressed: () => _goTo(_index + 1),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageView extends StatelessWidget {
  const _PageView({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    const headline = TextStyle(
      fontSize: 40,
      height: 1.3,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _HeroPainter()),
              Center(
                child: Container(
                  width: 148,
                  height: 148,
                  decoration: const BoxDecoration(
                    color: Palette.lime,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(page.icon, size: 72, color: Palette.onLime),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(page.before, style: headline),
              Text(page.accent, style: headline.copyWith(color: Palette.lime)),
              Text(page.after, style: headline),
              const SizedBox(height: 16),
              Text(
                page.body,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Palette.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Palette.card;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.25),
        width: size.width * 0.9,
        height: size.height * 0.7,
      ),
      paint,
    );
    paint.color = Palette.cardRaised.withValues(alpha: 0.6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.9, size.height * 0.75),
        width: size.width * 0.9,
        height: size.height * 0.75,
      ),
      paint,
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Palette.lime.withValues(alpha: 0.35);
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 104, ring);
    ring.color = Palette.lime.withValues(alpha: 0.15);
    canvas.drawCircle(center, 138, ring);
  }

  @override
  bool shouldRepaint(_HeroPainter oldDelegate) => false;
}
