import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'register_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

// Glass helper
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

// Rotating ring painter
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double gapFraction;

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Form state
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final SessionService _sessionService = SessionService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  // Entrance animations
  late final AnimationController _blobCtrl;
  late final AnimationController _contentCtrl;
  late final AnimationController _formCtrl;
  late final AnimationController _spinCtrl;

  late final Animation<double> _blobScale;
  late final Animation<double> _orbScale;
  late final Animation<double> _orbOpacity;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _pillOpacity;
  late final Animation<double> _formSlide;
  late final Animation<double> _formOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    _blobCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _blobScale = CurvedAnimation(parent: _blobCtrl, curve: Curves.easeOutCubic);

    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _orbScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutBack));
    _orbOpacity = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _titleSlide = Tween<double>(begin: 20.0, end: 0.0).animate(CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    _titleOpacity = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _pillOpacity = CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut));

    _formCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _formSlide = Tween<double>(begin: 40.0, end: 0.0)
        .animate(CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut));
    _formOpacity = CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut);

    _spinCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 60));
    _blobCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 180));
    _contentCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _formCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _blobCtrl.dispose();
    _contentCtrl.dispose();
    _formCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  // Login handler
  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Icons.warning_rounded);
      return;
    }

    setState(() => _isLoading = true);

    final userData = await ApiService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (userData != null) {
      final user = UserModel(
        id: userData['id'],
        firstName: userData['firstName'],
        lastName: userData['lastName'],
        email: userData['email'],
        passwordHash: '',
        role: userData['role'],
        createdAt: DateTime.parse(userData['createdAt']),
        totalXp: userData['totalXp'],
        currentLevel: userData['currentLevel'],
      );

      await _sessionService.login(user);
      _showSnackBar(userData['message'] ?? 'Login successful!',
          Icons.check_circle_rounded);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      _showSnackBar('Invalid email or password', Icons.error_outline_rounded);
    }
  }

  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildBlobs(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      _buildBackButton(),
                      const SizedBox(height: 36),
                      _buildLogoOrb(),
                      const SizedBox(height: 28),
                      _buildTitle(),
                      const SizedBox(height: 16),
                      _buildFeaturePills(),
                      const SizedBox(height: 32),
                      _buildFormCard(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlobs() {
    return AnimatedBuilder(
      animation: _blobScale,
      builder: (_, __) => Stack(
        children: [
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
                  color: AppTheme.blobEmerald.withOpacity(0.09),
                ),
              ),
            ),
          ),
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

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: _Glass(
        borderRadius: BorderRadius.circular(20),
        opacity: 0.55,
        tint: Colors.white,
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          color: AppTheme.textPrimary,
          padding: const EdgeInsets.all(10),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
      ),
    );
  }

  Widget _buildLogoOrb() {
    return AnimatedBuilder(
      animation: Listenable.merge([_contentCtrl, _spinCtrl]),
      builder: (_, __) {
        return FadeTransition(
          opacity: _orbOpacity,
          child: Transform.scale(
            scale: _orbScale.value,
            child: SizedBox(
              width: 148,
              height: 148,
              child: Stack(
                alignment: Alignment.center,
                children: [
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
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('🪷', style: TextStyle(fontSize: 42)),
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

  Widget _buildTitle() {
    return AnimatedBuilder(
      animation: _contentCtrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _titleSlide.value),
        child: Opacity(
          opacity: _titleOpacity.value,
          child: Column(
            children: [
              const Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 10),
              _Glass(
                borderRadius: BorderRadius.circular(20),
                opacity: 0.55,
                tint: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Sign in to continue your Vesak journey 🌼',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary.withOpacity(0.85),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturePills() {
    return AnimatedBuilder(
      animation: _pillOpacity,
      builder: (_, __) => Opacity(
        opacity: _pillOpacity.value,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPill(Icons.event_rounded, 'Events', AppTheme.primary),
            const SizedBox(width: 10),
            _buildPill(
                Icons.location_on_rounded, 'Map', const Color(0xFF10B981)),
            const SizedBox(width: 10),
            _buildPill(
                Icons.photo_library_rounded, 'Memories', AppTheme.accent),
          ],
        ),
      ),
    );
  }

  Widget _buildPill(IconData icon, String label, Color accent) {
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

  Widget _buildFormCard() {
    return AnimatedBuilder(
      animation: _formCtrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _formSlide.value),
        child: Opacity(
          opacity: _formOpacity.value,
          child: _Glass(
            borderRadius: BorderRadius.circular(28),
            opacity: 0.65,
            tint: Colors.white,
            blur: 20,
            border:
                Border.all(color: Colors.white.withOpacity(0.55), width: 1.2),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 20),
                _buildInputField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      _showSnackBar('Contact support to reset password',
                          Icons.help_outline);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppTheme.timelineInactive.withOpacity(0.5),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppTheme.timelineInactive.withOpacity(0.5),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                          color: AppTheme.primary.withOpacity(0.6), width: 1.2),
                      foregroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Continue as Guest',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.70),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.60), width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle:
                  TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 14),
              prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
              suffixIcon: suffixIcon,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}
