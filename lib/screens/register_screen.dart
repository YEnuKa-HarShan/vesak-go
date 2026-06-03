import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please agree to the terms and conditions')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _supabaseService.registerUser(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Registration successful! +50 XP bonus! Please login.')),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User already exists with this email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.sand,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Back Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: AppTheme.charcoal),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: 20),
              // Header Section
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.gold, AppTheme.saffron],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_add,
                        size: 50,
                        color: AppTheme.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.charcoal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join the Vesak community today!',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.charcoal.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Form Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // First Name & Last Name Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name',
                              labelStyle:
                                  const TextStyle(color: AppTheme.charcoal),
                              hintText: 'John',
                              hintStyle: TextStyle(
                                  color: AppTheme.charcoal.withOpacity(0.5)),
                              prefixIcon: Icon(Icons.person_outline,
                                  color: AppTheme.saffron),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppTheme.saffron, width: 2),
                              ),
                              filled: true,
                              fillColor: AppTheme.sand,
                            ),
                            style: const TextStyle(color: AppTheme.charcoal),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Last Name',
                              labelStyle:
                                  const TextStyle(color: AppTheme.charcoal),
                              hintText: 'Doe',
                              hintStyle: TextStyle(
                                  color: AppTheme.charcoal.withOpacity(0.5)),
                              prefixIcon: Icon(Icons.person_outline,
                                  color: AppTheme.saffron),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: AppTheme.saffron, width: 2),
                              ),
                              filled: true,
                              fillColor: AppTheme.sand,
                            ),
                            style: const TextStyle(color: AppTheme.charcoal),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Email Field
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: AppTheme.charcoal),
                        hintText: 'john@example.com',
                        hintStyle: TextStyle(
                            color: AppTheme.charcoal.withOpacity(0.5)),
                        prefixIcon:
                            Icon(Icons.email_outlined, color: AppTheme.saffron),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.saffron, width: 2),
                        ),
                        filled: true,
                        fillColor: AppTheme.sand,
                      ),
                      style: const TextStyle(color: AppTheme.charcoal),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    // Password Field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: const TextStyle(color: AppTheme.charcoal),
                        hintText: 'Create a strong password',
                        hintStyle: TextStyle(
                            color: AppTheme.charcoal.withOpacity(0.5)),
                        prefixIcon:
                            Icon(Icons.lock_outline, color: AppTheme.saffron),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.charcoal,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.saffron, width: 2),
                        ),
                        filled: true,
                        fillColor: AppTheme.sand,
                      ),
                      style: const TextStyle(color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 16),
                    // Confirm Password Field
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: const TextStyle(color: AppTheme.charcoal),
                        hintText: 'Confirm your password',
                        hintStyle: TextStyle(
                            color: AppTheme.charcoal.withOpacity(0.5)),
                        prefixIcon:
                            Icon(Icons.lock_outline, color: AppTheme.saffron),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.charcoal,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.saffron, width: 2),
                        ),
                        filled: true,
                        fillColor: AppTheme.sand,
                      ),
                      style: const TextStyle(color: AppTheme.charcoal),
                    ),
                    const SizedBox(height: 8),
                    // Password Requirements
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.sand,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password requirements:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.charcoal.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                _passwordController.text.length >= 6
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 14,
                                color: _passwordController.text.length >= 6
                                    ? AppTheme.forestGreen
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'At least 6 characters',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.charcoal.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                _passwordController.text.isNotEmpty
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 14,
                                color: _passwordController.text.isNotEmpty
                                    ? AppTheme.forestGreen
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Non-empty password',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.charcoal.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Terms and Conditions
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                            });
                          },
                          activeColor: AppTheme.saffron,
                          checkColor: AppTheme.white,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _agreeToTerms = !_agreeToTerms;
                              });
                            },
                            child: RichText(
                              text: TextSpan(
                                text: 'I agree to the ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.charcoal.withOpacity(0.6),
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: TextStyle(
                                      color: AppTheme.saffron,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' and ',
                                    style: TextStyle(
                                      color: AppTheme.charcoal.withOpacity(0.6),
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: AppTheme.saffron,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.saffron,
                          foregroundColor: AppTheme.white,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: AppTheme.white)
                            : const Text('Create Account',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Divider
                    Row(
                      children: [
                        Expanded(
                            child: Divider(color: AppTheme.sand, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                                color: AppTheme.charcoal.withOpacity(0.5)),
                          ),
                        ),
                        Expanded(
                            child: Divider(color: AppTheme.sand, thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: TextStyle(
                              color: AppTheme.charcoal.withOpacity(0.6)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoginScreen()),
                            );
                          },
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: AppTheme.saffron,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Bonus Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppTheme.gold.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.emoji_events,
                              size: 20, color: AppTheme.gold),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Get +50 XP bonus on registration!',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.charcoal.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
