// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hass_project/constants/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  bool _isEditing = false;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: _user?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;
    try {
      await _user?.updateDisplayName(newName);
      await _user?.reload();
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated!'),
              backgroundColor: Colors.green));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update name.'),
              backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _user?.email ?? '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to ${_user?.email}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send reset email.'),
              backgroundColor: Colors.red));
      }
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  String _letter() {
    if (_user?.displayName?.isNotEmpty == true) {
      return _user!.displayName![0].toUpperCase();
    }
    if (_user?.email?.isNotEmpty == true) {
      return _user!.email![0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final card      = isDark ? AppColors.darkSurface : Colors.white;
    final text      = Theme.of(context).textTheme.bodyLarge?.color;
    final sub       = isDark ? Colors.white60 : Colors.grey[600];
    final border    = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final createdAt = _user?.metadata.creationTime;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Profile',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            child: Text(
              _isEditing ? 'Cancel' : 'Edit',
              style: TextStyle(
                  color: AppColors.gradientEnd,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── Avatar ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              child: Text(
                _letter(),
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gradientEnd),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name (editable)
          _isEditing
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _nameCtrl,
                    style: TextStyle(
                        color: text,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Enter your name',
                      hintStyle: TextStyle(color: sub),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: AppColors.gradientEnd, width: 2)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                              color: AppColors.gradientEnd, width: 2)),
                    ),
                  ),
                )
              : Text(
                  _user?.displayName ?? 'No name set',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: text),
                ),
          const SizedBox(height: 6),

          Text(_user?.email ?? '',
              style: TextStyle(fontSize: 15, color: sub)),

          if (_isEditing) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(30)),
              child: ElevatedButton(
                onPressed: _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Save Name',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ],

          const SizedBox(height: 30),

          // ── Info cards ─────────────────────────────────────────────────────
          _infoCard(
            card: card, border: border, isDark: isDark,
            icon: Icons.email_outlined,
            label: 'Email',
            value: _user?.email ?? 'Not available',
            text: text, sub: sub,
          ),
          const SizedBox(height: 12),

          _infoCard(
            card: card, border: border, isDark: isDark,
            icon: Icons.calendar_today_outlined,
            label: 'Account created',
            value: _formatDate(createdAt),
            text: text, sub: sub,
          ),
          const SizedBox(height: 12),

          _infoCard(
            card: card, border: border, isDark: isDark,
            icon: Icons.access_time_outlined,
            label: 'Last sign in',
            value: _formatDate(_user?.metadata.lastSignInTime),
            text: text, sub: sub,
          ),
          const SizedBox(height: 12),

          _infoCard(
            card: card, border: border, isDark: isDark,
            icon: Icons.verified_outlined,
            label: 'Email verified',
            value: _user?.emailVerified == true ? 'Yes ✓' : 'No',
            valueColor: _user?.emailVerified == true
                ? Colors.green
                : Colors.orange,
            text: text, sub: sub,
          ),

          const SizedBox(height: 32),

          // ── Actions ────────────────────────────────────────────────────────
          _actionBtn(
            label: 'Send Password Reset Email',
            icon: Icons.lock_reset_outlined,
            onTap: _sendPasswordReset,
            isDark: isDark,
            card: card,
            text: text,
          ),

          const SizedBox(height: 12),

          _actionBtn(
            label: 'Sign Out',
            icon: Icons.logout,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/signin');
              }
            },
            isDark: isDark,
            card: card,
            text: text,
            isDestructive: true,
          ),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _infoCard({
    required Color card,
    required Color border,
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color? text,
    required Color? sub,
    Color? valueColor,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gradientEnd.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.gradientEnd, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 12, color: sub)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: valueColor ?? text)),
                ]),
          ),
        ]),
      );

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color card,
    required Color? text,
    bool isDestructive = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.08)
                : card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDestructive
                  ? Colors.red.shade200
                  : (isDark
                      ? Colors.grey.shade700
                      : Colors.grey.shade200),
            ),
          ),
          child: Row(children: [
            Icon(icon,
                color: isDestructive ? Colors.red : AppColors.gradientEnd,
                size: 22),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDestructive ? Colors.red : text)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                size: 14,
                color: isDestructive
                    ? Colors.red.shade300
                    : (isDark ? Colors.white38 : Colors.grey.shade400)),
          ]),
        ),
      );
}