// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hass_project/Screens/home.dart';
import 'package:hass_project/constants/app_colors.dart';

class LogInScreen extends StatefulWidget {
  const LogInScreen({super.key});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final _formKey                  = GlobalKey<FormState>();
  final _nameController           = TextEditingController();
  final _emailController          = TextEditingController();
  final _passwordController       = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible        = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms             = false;
  bool _isLoading                = false;

  // ── Firebase register ─────────────────────────────────────────────────────
  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _snack('Please agree to the Terms and Conditions.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create the user
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Save the display name
      await credential.user
          ?.updateDisplayName(_nameController.text.trim());

      if (!mounted) return;
      _snack('Account created successfully!', success: true);

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _snack(_firebaseError(e.code));
    } catch (_) {
      if (!mounted) return;
      _snack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':    return 'This email is already registered.';
      case 'invalid-email':           return 'Invalid email address.';
      case 'weak-password':           return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':   return 'Email/password sign-up is disabled.';
      default:                        return 'Registration failed. Please try again.';
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final cardColor   = isDark ? AppColors.darkSurface : Colors.white;
    final textColor   = Theme.of(context).textTheme.bodyLarge?.color;
    final labelColor  = isDark ? Colors.white70 : Colors.grey.shade700;
    final borderColor = isDark ? Colors.grey.shade600 : Colors.grey.shade300;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(children: [

              // Back + Logo
              Stack(children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.arrow_back, color: textColor),
                    ),
                  ),
                ),
                Center(
                  child: Image.asset('Assets/images/HASS-project-LOGO.png',
                      width: 150, height: 150),
                ),
              ]),
              const SizedBox(height: 20),

              Text('Create Account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 8),
              Text('Sign up to get started',
                  style: TextStyle(fontSize: 16,
                      color: isDark ? Colors.white60 : Colors.grey[600])),
              const SizedBox(height: 30),

              // ── Name ───────────────────────────────────────────────────────
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: textColor),
                decoration: _dec(
                  label: 'Name', hint: 'Enter your name',
                  icon: Icons.person_outline,
                  labelColor: labelColor, borderColor: borderColor,
                  cardColor: cardColor, isDark: isDark,
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 20),

              // ── Email ──────────────────────────────────────────────────────
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textColor),
                decoration: _dec(
                  label: 'Email', hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  labelColor: labelColor, borderColor: borderColor,
                  cardColor: cardColor, isDark: isDark,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter your email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Password ───────────────────────────────────────────────────
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: TextStyle(color: textColor),
                decoration: _dec(
                  label: 'Password', hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  labelColor: labelColor, borderColor: borderColor,
                  cardColor: cardColor, isDark: isDark,
                  suffix: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: labelColor,
                    ),
                    onPressed: () =>
                        setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter your password';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Confirm password ───────────────────────────────────────────
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                style: TextStyle(color: textColor),
                decoration: _dec(
                  label: 'Confirm Password', hint: 'Re-enter your password',
                  icon: Icons.lock_outline,
                  labelColor: labelColor, borderColor: borderColor,
                  cardColor: cardColor, isDark: isDark,
                  suffix: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: labelColor,
                    ),
                    onPressed: () => setState(() =>
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your password';
                  if (v != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Terms checkbox ─────────────────────────────────────────────
              Row(children: [
                Checkbox(
                  value: _agreeToTerms,
                  onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
                  activeColor: AppColors.gradientEnd,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey[600]),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(text: 'Terms of Service',
                            style: TextStyle(color: AppColors.gradientEnd,
                                fontWeight: FontWeight.bold)),
                        const TextSpan(text: ' and '),
                        TextSpan(text: 'Privacy Policy',
                            style: TextStyle(color: AppColors.gradientEnd,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 30),

              // ── Create account button ──────────────────────────────────────
              Container(
                width: double.infinity, height: 55,
                decoration: BoxDecoration(
                  gradient: _agreeToTerms ? AppColors.primaryGradient : null,
                  color: _agreeToTerms ? null : Colors.grey,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _agreeToTerms
                      ? [BoxShadow(
                          color: AppColors.gradientEnd.withOpacity(0.3),
                          blurRadius: 10, offset: const Offset(0, 5))]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: (_agreeToTerms && !_isLoading)
                      ? _createAccount
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 18,
                              fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),

              // ── Sign in link ───────────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Already have an account? ',
                    style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey[600])),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text('Sign In',
                      style: TextStyle(
                          color: AppColors.gradientEnd,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec({
    required String label,
    required String hint,
    required IconData icon,
    required Color labelColor,
    required Color borderColor,
    required Color cardColor,
    required bool isDark,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: labelColor),
      hintStyle: TextStyle(
          color: isDark ? Colors.white38 : Colors.grey.shade400),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.gradientEnd, width: 2)),
      prefixIcon: Icon(icon, color: labelColor),
      suffixIcon: suffix,
      filled: true,
      fillColor: cardColor,
    );
  }
}