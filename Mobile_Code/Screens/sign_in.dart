// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hass_project/Screens/home.dart';
import 'package:hass_project/Screens/log_in.dart';
import 'package:hass_project/constants/app_colors.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey           = GlobalKey<FormState>();
  final _emailController   = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading         = false;

  // ── Firebase login ────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

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

  // ── Reset password ────────────────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Enter your email above first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      _snack('Reset link sent to $email', success: true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _snack(_firebaseError(e.code));
    }
  }

  String _firebaseError(String code) {
    switch (code) {
      case 'user-not-found':    return 'No account found with this email.';
      case 'wrong-password':    return 'Incorrect password.';
      case 'invalid-email':     return 'Invalid email address.';
      case 'user-disabled':     return 'This account has been disabled.';
      case 'too-many-requests': return 'Too many attempts. Try again later.';
      case 'invalid-credential':return 'Email or password is incorrect.';
      default:                  return 'Login failed. Please try again.';
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final cardColor    = isDark ? AppColors.darkSurface : Colors.white;
    final textColor    = Theme.of(context).textTheme.bodyLarge?.color;
    final labelColor   = isDark ? Colors.white70 : Colors.grey.shade700;
    final borderColor  = isDark ? Colors.grey.shade600 : Colors.grey.shade300;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(children: [

              // Logo
              Image.asset('Assets/images/HASS-project-LOGO.png',
                  width: 150, height: 150),
              const SizedBox(height: 20),

              Text('Login',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                      color: textColor)),
              const SizedBox(height: 8),
              Text('Sign in to your account',
                  style: TextStyle(fontSize: 16,
                      color: isDark ? Colors.white60 : Colors.grey)),
              const SizedBox(height: 40),

              // ── Email ──────────────────────────────────────────────────────
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textColor),
                decoration: _inputDec(
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  labelColor: labelColor,
                  borderColor: borderColor,
                  cardColor: cardColor,
                  isDark: isDark,
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
                decoration: _inputDec(
                  label: 'Password',
                  hint: 'Enter your password',
                  icon: Icons.lock_outline,
                  labelColor: labelColor,
                  borderColor: borderColor,
                  cardColor: cardColor,
                  isDark: isDark,
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
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // ── Forgot password ────────────────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: Text('Forgot Password?',
                      style: TextStyle(color: AppColors.gradientEnd)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Login button ───────────────────────────────────────────────
              Container(
                width: double.infinity, height: 55,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(
                      color: AppColors.gradientEnd.withOpacity(0.3),
                      blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
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
                      : const Text('Log in',
                          style: TextStyle(fontSize: 18,
                              fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 24),

              // ── Create account link ────────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("Don't have an account? ",
                    style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.grey[600])),
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const LogInScreen())),
                  child: Text('Create one',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.gradientEnd,
                          fontSize: 16)),
                ),
              ]),
              const SizedBox(height: 12),

              // ── Terms ──────────────────────────────────────────────────────
              Text(
                'By signing in you agree with our Terms and Conditions',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[600]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec({
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