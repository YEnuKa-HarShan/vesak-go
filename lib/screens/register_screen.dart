import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  // Form state
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  // Animation controllers
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

    // Listen for password changes to rebuild requirement indicators
    _passwordController.addListener(() => setState(() {}));

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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _blobCtrl.dispose();
    _contentCtrl.dispose();
    _formCtrl.dispose();
    _spinCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, IconData icon, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Register handler
  Future<void> _handleRegister() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Icons.warning_rounded,
          isError: true);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match', Icons.warning_rounded,
          isError: true);
      return;
    }

    if (_passwordController.text.length < 6) {
      _showSnackBar(
          'Password must be at least 6 characters', Icons.warning_rounded,
          isError: true);
      return;
    }

    if (!_agreeToTerms) {
      _showSnackBar(
          'Please agree to the terms and conditions', Icons.warning_rounded,
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final userData = await ApiService.register(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (userData != null) {
      _showSnackBar(
        'Registration successful! +50 XP bonus! Please login.',
        Icons.check_circle_rounded,
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } else {
      _showSnackBar(
        'User already exists with this email',
        Icons.error_outline_rounded,
        isError: true,
      );
    }
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
                    _buildBonusPill(),
                    const SizedBox(height: 32),
                    _buildFormCard(),
                    const SizedBox(height: 32),
                  ],
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
                'Create Account',
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
                  'Join the Vesak community today! 🌼',
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

  Widget _buildBonusPill() {
    return AnimatedBuilder(
      animation: _pillOpacity,
      builder: (_, __) => Opacity(
        opacity: _pillOpacity.value,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.62),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.70), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.10),
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
                      color: AppTheme.accent.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        size: 14, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Get +50 XP bonus on registration!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
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
                  'Your Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        controller: _firstNameController,
                        label: 'First Name',
                        hint: 'John',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInputField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        hint: 'Doe',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'john@example.com',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a strong password',
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
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Confirm your password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscureConfirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                const SizedBox(height: 14),
                _buildPasswordRequirements(),
                const SizedBox(height: 16),
                _buildTermsRow(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
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
                            'Create Account',
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                      ),
                      child: const Text(
                        'Sign In',
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
                  TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 13),
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
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    final hasMinLength = _passwordController.text.length >= 6;
    final isNonEmpty = _passwordController.text.isNotEmpty;

    return _Glass(
      borderRadius: BorderRadius.circular(16),
      opacity: 0.40,
      tint: Colors.white,
      blur: 10,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildRequirementRow(
            met: hasMinLength,
            label: 'At least 6 characters',
          ),
          const SizedBox(height: 4),
          _buildRequirementRow(
            met: isNonEmpty,
            label: 'Non-empty password',
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementRow({required bool met, required String label}) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 14,
          color: met ? AppTheme.success : AppTheme.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: met ? AppTheme.success : AppTheme.textSecondary,
            fontWeight: met ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildTermsRow() {
    return GestureDetector(
      onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
      child: _Glass(
        borderRadius: BorderRadius.circular(14),
        opacity: _agreeToTerms ? 0.18 : 0.30,
        tint: _agreeToTerms ? AppTheme.primary : Colors.white,
        blur: 10,
        border: Border.all(
          color: _agreeToTerms
              ? AppTheme.primary.withOpacity(0.35)
              : Colors.white.withOpacity(0.50),
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: _agreeToTerms,
              onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
              activeColor: AppTheme.primary,
              checkColor: Colors.white,
              side: BorderSide(color: AppTheme.textSecondary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: 'I agree to the ',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: ' and ',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
