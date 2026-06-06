// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:hass_project/constants/app_colors.dart';
import 'package:hass_project/providers/theme_provider.dart';

class SettingsTab extends StatefulWidget {
  final String boardId;
  final bool isPaired;
  final Future<bool> Function(String code) onPair;
  final Future<void> Function() onUnpair;

  const SettingsTab({
    super.key,
    required this.boardId,
    required this.isPaired,
    required this.onPair,
    required this.onUnpair,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _codeCtrl  = TextEditingController();
  bool  _isLoading = false;

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _pair() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      _snack('Enter a board code first.', Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    final success = await widget.onPair(code);
    setState(() => _isLoading = false);

    if (success) {
      _codeCtrl.clear();
      _snack('Board "$code" paired successfully! 🎉', Colors.green);
    } else {
      _snack('Board "$code" not found. Check the code.', Colors.red);
    }
  }

  Future<void> _unpair() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Unpair Board',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
              'Are you sure you want to unpair board "${widget.boardId}"?\n'
              'You will lose access to its devices.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Unpair',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await widget.onUnpair();
      _snack('Board unpaired.', Colors.orange);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final cardColor   = isDark ? AppColors.darkSurface : Colors.white;
    final textColor   = Theme.of(context).textTheme.bodyLarge?.color;
    final sub         = isDark ? Colors.white60 : Colors.grey[600];
    final border      = isDark ? Colors.grey.shade700 : Colors.grey.shade200;
    final user        = FirebaseAuth.instance.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 20),

        Text('Settings', style: TextStyle(fontSize: 28,
            fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 24),

        // ── Profile card ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.07),
                blurRadius: 10, spreadRadius: 2)],
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.gradientEnd,
              child: Text(
                _letter(user),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? 'HASS User',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold, color: textColor)),
                    Text(user?.email ?? '',
                        style: TextStyle(color: sub, fontSize: 13)),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Board pairing ──────────────────────────────────────────────────
        Text('Board Pairing', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),

        widget.isPaired
            // ── Already paired ─────────────────────────────────────────────
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gradientEnd, width: 1.5),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.gradientEnd.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.link,
                              color: AppColors.gradientEnd, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Paired Board',
                                  style: TextStyle(fontSize: 12, color: sub)),
                              Text(widget.boardId,
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gradientEnd)),
                            ]),
                      ]),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _unpair,
                          icon: const Icon(Icons.link_off,
                              color: Colors.red, size: 18),
                          label: const Text('Unpair Board',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),
              )

            // ── Not paired — enter code ─────────────────────────────────────
            : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.gradientEnd.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.gradientEnd, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Enter the board code found on your HASS device '
                              'to start controlling it.',
                              style: TextStyle(
                                  fontSize: 12, color: sub),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),

                      // Code input
                      TextField(
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: 4),
                        decoration: InputDecoration(
                          hintText: 'e.g. ABC1234',
                          hintStyle: TextStyle(
                              color: sub, fontWeight: FontWeight.normal,
                              fontSize: 15, letterSpacing: 1),
                          prefixIcon: const Icon(Icons.qr_code,
                              color: AppColors.gradientEnd),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.gradientEnd, width: 2)),
                          filled: true, fillColor: cardColor,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Pair button
                      Container(
                        width: double.infinity, height: 50,
                        decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(30)),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _pair,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text('Pair Board',
                                  style: TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                        ),
                      ),
                    ]),
              ),

        const SizedBox(height: 28),

        // ── App settings ───────────────────────────────────────────────────
        Text('App Settings', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),

        _switchTile(context,
          title: 'Dark Mode',
          icon: Icons.dark_mode_outlined,
          value: themeProvider.isDarkMode,
          onChanged: (_) => themeProvider.toggleTheme(),
        ),

        const SizedBox(height: 24),

        // ── Language options ───────────────────────────────────────────────
        Text('Language', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 12),
        _langOption(context, 'English', true,  isDark),
        _langOption(context, 'Arabic',  false, isDark),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _switchTile(BuildContext context, {
    required String title,
    required IconData icon,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppColors.gradientStart.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.gradientEnd),
      ),
      title: Text(title,
          style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color)),
      trailing: Switch(
        value: value, onChanged: onChanged,
        activeColor: AppColors.gradientEnd,
      ),
    );
  }

  Widget _langOption(BuildContext context, String lang,
      bool selected, bool isDark) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gradientEnd.withOpacity(0.1)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.gradientEnd
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
          ),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang, style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? AppColors.gradientEnd
                      : (isDark ? Colors.white : Colors.black))),
              if (selected)
                const Icon(Icons.check, color: AppColors.gradientEnd),
            ]),
      );

  String _letter(User? user) {
    if (user?.displayName?.isNotEmpty == true) {
      return user!.displayName![0].toUpperCase();
    }
    if (user?.email?.isNotEmpty == true) return user!.email![0].toUpperCase();
    return '?';
  }
}