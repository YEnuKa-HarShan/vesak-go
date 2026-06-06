import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────
//  Glass helper (shared with MemoriesScreen / HomeScreen)
// ─────────────────────────────────────────────────────────────

class _Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color tint;
  final double blur;
  final double opacity;
  final Border? border;

  const _Glass({
    required this.child,
    this.borderRadius,
    this.padding,
    this.tint = Colors.white,
    this.blur = 18,
    this.opacity = 0.10,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withOpacity(opacity),
            borderRadius: br,
            border: border ??
                Border.all(color: Colors.white.withOpacity(0.18), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Rotating ring painter
// ─────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  final double strokeWidth;
  final double gapFraction; // fraction of circumference that is a gap

  const _RingPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 1.5,
    this.gapFraction = 0.18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    final sweepAngle = (1 - gapFraction) * 2 * math.pi;
    final startAngle = progress * 2 * math.pi - math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Staggered entrance controllers ──
  late final AnimationController _blobCtrl;
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _pillCtrl;
  late final AnimationController _loadingCtrl;

  // ── Continuous spin for decorative rings ──
  late final AnimationController _spinCtrl;

  // ── Entrance animations ──
  late final Animation<double> _blobScale;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _pillOpacity;
  late final Animation<double> _loadingOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    // Blob
    _blobCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _blobScale = CurvedAnimation(parent: _blobCtrl, curve: Curves.easeOutCubic);

    // Logo orb
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.easeOutBack,
    ));
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    // Title
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _titleSlide = Tween<double>(begin: 24.0, end: 0.0).animate(CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));
    _titleOpacity = CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut));
    _subtitleSlide =
        Tween<double>(begin: 16.0, end: 0.0).animate(CurvedAnimation(
      parent: _textCtrl,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ));
    _subtitleOpacity = CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut));

    // Stat pills
    _pillCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _pillOpacity = CurvedAnimation(parent: _pillCtrl, curve: Curves.easeOut);

    // Loading dots
    _loadingCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _loadingOpacity =
        CurvedAnimation(parent: _loadingCtrl, curve: Curves.easeOut);

    // Continuous spin
    _spinCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 80));
    _blobCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 350));
    _textCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _pillCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _loadingCtrl.forward();

    // Navigate after splash duration
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pillCtrl.dispose();
    _loadingCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Ambient blobs ──
          _buildBlobs(),

          // ── Content ──
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // ── Logo orb ──
                  _buildLogoOrb(),

                  const SizedBox(height: 36),

                  // ── Title ──
                  _buildTitle(),

                  const SizedBox(height: 12),

                  // ── Subtitle pill ──
                  _buildSubtitle(),

                  const Spacer(flex: 2),

                  // ── Stat pills ──
                  _buildStatPills(),

                  const SizedBox(height: 36),

                  // ── Loading indicator ──
                  _buildLoadingDots(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // AMBIENT BLOBS
  // ─────────────────────────────────────────────

  Widget _buildBlobs() {
    return AnimatedBuilder(
      animation: _blobScale,
      builder: (_, __) => Stack(
        children: [
          // Top-left — primary indigo
          Positioned(
            top: -80,
            left: -80,
            child: Transform.scale(
              scale: _blobScale.value,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.13),
                ),
              ),
            ),
          ),
          // Top-right — amber
          Positioned(
            top: 60,
            right: -90,
            child: Transform.scale(
              scale: _blobScale.value,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withOpacity(0.10),
                ),
              ),
            ),
          ),
          // Bottom-centre — emerald
          Positioned(
            bottom: -100,
            left: 40,
            child: Transform.scale(
              scale: _blobScale.value,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withOpacity(0.09),
                ),
              ),
            ),
          ),
          // Bottom-right — violet accent
          Positioned(
            bottom: 80,
            right: -40,
            child: Transform.scale(
              scale: _blobScale.value,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.07),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LOGO ORB
  // ─────────────────────────────────────────────

  Widget _buildLogoOrb() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoCtrl, _spinCtrl]),
      builder: (_, __) {
        return FadeTransition(
          opacity: _logoOpacity,
          child: Transform.scale(
            scale: _logoScale.value,
            child: SizedBox(
              width: 148,
              height: 148,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Outer spinning ring 1 ──
                  SizedBox(
                    width: 148,
                    height: 148,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: _spinCtrl.value,
                        color: AppTheme.primary.withOpacity(0.22),
                        strokeWidth: 1.5,
                        gapFraction: 0.22,
                      ),
                    ),
                  ),

                  // ── Outer spinning ring 2 (counter) ──
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: 1.0 - _spinCtrl.value,
                        color: AppTheme.accent.withOpacity(0.20),
                        strokeWidth: 1.5,
                        gapFraction: 0.30,
                      ),
                    ),
                  ),

                  // ── Glass orb ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.60),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.70),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.14),
                              blurRadius: 36,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.10),
                              blurRadius: 24,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Lotus emoji as hero icon
                            const Text(
                              '🪷',
                              style: TextStyle(fontSize: 42),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // TITLE
  // ─────────────────────────────────────────────

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _textCtrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _titleSlide.value),
        child: Opacity(
          opacity: _titleOpacity.value,
          child: Column(
            children: [
              // App name
              const Text(
                'VesakGO',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 6),

              // Tagline glass pill
              Transform.translate(
                offset: Offset(0, _subtitleSlide.value),
                child: Opacity(
                  opacity: _subtitleOpacity.value,
                  child: _Glass(
                    borderRadius: BorderRadius.circular(20),
                    opacity: 0.55,
                    tint: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'සුබ වෙසක් පොහොය දිනයක් වේවා! 🌼',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary.withOpacity(0.85),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() => const SizedBox.shrink();

  // ─────────────────────────────────────────────
  // STAT PILLS
  // ─────────────────────────────────────────────

  Widget _buildStatPills() {
    return AnimatedBuilder(
      animation: _pillOpacity,
      builder: (_, __) => Opacity(
        opacity: _pillOpacity.value,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatPill(Icons.event_rounded, 'Events', AppTheme.primary),
            const SizedBox(width: 10),
            _buildStatPill(
                Icons.location_on_rounded, 'Map', const Color(0xFF10B981)),
            const SizedBox(width: 10),
            _buildStatPill(
                Icons.photo_library_rounded, 'Memories', AppTheme.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String label, Color accent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: Colors.white.withOpacity(0.70), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: accent),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LOADING DOTS
  // ─────────────────────────────────────────────

  Widget _buildLoadingDots() {
    return AnimatedBuilder(
      animation: Listenable.merge([_loadingOpacity, _spinCtrl]),
      builder: (_, __) => Opacity(
        opacity: _loadingOpacity.value,
        child: _Glass(
          borderRadius: BorderRadius.circular(30),
          opacity: 0.55,
          tint: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Each dot pulses with a phase offset
              final phase = ((_spinCtrl.value * 3) - i) % 1.0;
              final pulse = math.sin(phase * math.pi).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 16),
                  width: 6 + pulse * 2,
                  height: 6 + pulse * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.3 + pulse * 0.55),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
